--- Ánh xạ Illenium store index ↔ shop key (chỉ 2 cửa bán đồ HGRP).
local cfg = require 'config.shared'

ShopRegistry = ShopRegistry or {}

local byKey = {}
local byStoreIndex = {}

local function rebuild()
    byKey = {}
    byStoreIndex = {}
    local shops = cfg.shops
    if type(shops) ~= 'table' then return end

    local function register(shop)
        if type(shop) ~= 'table' or type(shop.key) ~= 'string' or shop.key == '' then return end
        byKey[shop.key] = shop
        local idx = tonumber(shop.illeniumStoreIndex)
        if idx then
            byStoreIndex[idx] = shop.key
        end
    end

    if shops[1] and type(shops[1]) == 'table' and shops[1].key then
        for i = 1, #shops do
            register(shops[i])
        end
    else
        for index, shop in pairs(shops) do
            register(shop)
            local num = tonumber(index)
            if num and shop.key then
                byStoreIndex[num] = shop.key
            end
        end
    end

    if type(cfg.storeBindings) == 'table' then
        for index, key in pairs(cfg.storeBindings) do
            local num = tonumber(index)
            if num and type(key) == 'string' and key ~= '' and byKey[key] then
                byStoreIndex[num] = key
            end
        end
    end
end

rebuild()

---@param shopKey string
---@return table|nil
function ShopRegistry.getByKey(shopKey)
    if type(shopKey) ~= 'string' or shopKey == '' then return nil end
    return byKey[shopKey]
end

---@param storeIndex number|nil
---@return string|nil shopKey
function ShopRegistry.getKeyFromStoreIndex(storeIndex)
    storeIndex = tonumber(storeIndex)
    if not storeIndex then return nil end
    return byStoreIndex[storeIndex]
end

---@param storeIndex number|nil
---@return table|nil
function ShopRegistry.getByStoreIndex(storeIndex)
    local key = ShopRegistry.getKeyFromStoreIndex(storeIndex)
    if not key then return nil end
    return byKey[key]
end

---@return table[]
function ShopRegistry.list()
    local out = {}
    local seen = {}
    local shops = cfg.shops or {}
    if shops[1] and type(shops[1]) == 'table' and shops[1].key then
        for i = 1, #shops do
            local shop = shops[i]
            if shop.key and not seen[shop.key] then
                seen[shop.key] = true
                out[#out + 1] = shop
            end
        end
    else
        for _, shop in pairs(shops) do
            if type(shop) == 'table' and shop.key and not seen[shop.key] then
                seen[shop.key] = true
                out[#out + 1] = shop
            end
        end
        table.sort(out, function(a, b)
            return tostring(a.key) < tostring(b.key)
        end)
    end
    return out
end

function ShopRegistry.reload()
    rebuild()
end

return ShopRegistry
