--- Shared shop-level currency settings (cash | v_medal) for clothing + barber.
RetailSettings = RetailSettings or {}

local cache = {} ---@type table<string, string>
local tableReady = false

local VALID = {
    cash = true,
    v_medal = true,
}

function RetailSettings.ensureTable()
    if tableReady then return end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS hgrp_retail_shop_settings (
            shop_key VARCHAR(64) NOT NULL,
            currency VARCHAR(24) NOT NULL DEFAULT 'cash',
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (shop_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    tableReady = true
end

---@param currency any
---@return string|nil
local function normalizeCurrency(currency)
    if type(currency) ~= 'string' then return nil end
    currency = currency:lower():gsub('%s+', '')
    if currency == 'vmedal' then currency = 'v_medal' end
    if VALID[currency] then return currency end
    return nil
end

---@param shopKey string
---@param fallback? string
---@return string
function RetailSettings.getCurrency(shopKey, fallback)
    fallback = normalizeCurrency(fallback) or 'cash'
    if type(shopKey) ~= 'string' or shopKey == '' then
        return fallback
    end

    RetailSettings.ensureTable()

    if cache[shopKey] then
        return cache[shopKey]
    end

    local row = MySQL.single.await(
        'SELECT currency FROM hgrp_retail_shop_settings WHERE shop_key = ? LIMIT 1',
        { shopKey }
    )
    local cur = normalizeCurrency(row and row.currency) or fallback
    cache[shopKey] = cur
    return cur
end

---@param shopKey string
---@param currency string
---@return boolean, string?
function RetailSettings.setCurrency(shopKey, currency)
    if type(shopKey) ~= 'string' or shopKey == '' then
        return false, 'invalid_key'
    end
    local cur = normalizeCurrency(currency)
    if not cur then
        return false, 'invalid_currency'
    end

    RetailSettings.ensureTable()
    MySQL.query.await([[
        INSERT INTO hgrp_retail_shop_settings (shop_key, currency)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE currency = VALUES(currency)
    ]], { shopKey, cur })
    cache[shopKey] = cur
    return true
end

---@param shopsConfig table|nil map index -> { key, title, currency }
---@return table[]
function RetailSettings.listFromConfig(shopsConfig)
    local out = {}
    if type(shopsConfig) ~= 'table' then return out end

    local ordered = {}
    if shopsConfig[1] and type(shopsConfig[1]) == 'table' and shopsConfig[1].key then
        for i = 1, #shopsConfig do
            local shop = shopsConfig[i]
            if type(shop) == 'table' and type(shop.key) == 'string' then
                ordered[#ordered + 1] = { index = i, shop = shop }
            end
        end
    else
        for index, shop in pairs(shopsConfig) do
            if type(shop) == 'table' and type(shop.key) == 'string' then
                ordered[#ordered + 1] = {
                    index = tonumber(index) or index,
                    shop = shop,
                }
            end
        end
        table.sort(ordered, function(a, b)
            return tonumber(a.index) < tonumber(b.index)
        end)
    end

    for i = 1, #ordered do
        local entry = ordered[i]
        local shop = entry.shop
        local fallback = normalizeCurrency(shop.currency) or 'cash'
        out[#out + 1] = {
            index = entry.index,
            key = shop.key,
            title = shop.title or shop.key,
            currency = RetailSettings.getCurrency(shop.key, fallback),
            defaultCurrency = fallback,
        }
    end
    return out
end

---@param source number
---@param amount number
---@param reason string
---@param currency string
---@return boolean
function RetailSettings.pay(source, amount, reason, currency)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    currency = normalizeCurrency(currency) or 'cash'

    if currency == 'v_medal' then
        if GetResourceState('hgrp_f1_shop') ~= 'started' then
            return false
        end
        local ok = exports.hgrp_f1_shop:RemoveVMedal(source, amount, reason)
        return ok and true or false
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local cash = (player.PlayerData.money and player.PlayerData.money.cash) or 0
    local bank = (player.PlayerData.money and player.PlayerData.money.bank) or 0

    if cash >= amount then
        player.Functions.RemoveMoney('cash', amount, reason)
        return true
    end
    if bank >= amount then
        player.Functions.RemoveMoney('bank', amount, reason)
        return true
    end
    return false
end

---@param source number
---@param amount number
---@param reason string
---@param currency string
function RetailSettings.refund(source, amount, reason, currency)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    currency = normalizeCurrency(currency) or 'cash'

    if currency == 'v_medal' then
        if GetResourceState('hgrp_f1_shop') == 'started' then
            exports.hgrp_f1_shop:AddVMedal(source, amount, reason or 'retail-refund')
        end
        return
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    player.Functions.AddMoney('cash', amount, reason or 'retail-refund')
end
