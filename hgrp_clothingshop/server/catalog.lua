local cfg = require 'config.shared'
local DrawableUtils = lib.load('shared.drawable_utils')

Catalog = Catalog or {}

local cache = {
    rows = nil,
    builtAt = 0,
    categoryCounts = {},
}

local VALID_CATEGORIES = {}
local VALID_RARITIES = {}

for i = 1, #(cfg.adminCategories or {}) do
    local c = cfg.adminCategories[i]
    VALID_CATEGORIES[c.id] = c.label or c.id
end

for i = 1, #(cfg.rarities or {}) do
    local r = cfg.rarities[i]
    VALID_RARITIES[r.id] = r
end

local categoryById = {}
for i = 1, #(cfg.categories or {}) do
    local c = cfg.categories[i]
    categoryById[c.id] = c
end

local function categoryDef(catId)
    if categoryById[catId] then return categoryById[catId] end
    local label = VALID_CATEGORIES[catId]
    if not label then return nil end
    return {
        id = catId,
        label = label,
        kind = 'component',
        slot = 0,
    }
end

local function usesDbCatalog()
    return cfg.admin and cfg.admin.dbOverridesConfig == true
end

--- Danh sách đồ theo shop (shops[].items), fallback cfg.items legacy.
local function configItemsForShop(shopKey)
    local shop = ShopRegistry.getByKey(shopKey)
    if shop and type(shop.items) == 'table' then
        return shop.items
    end
    return cfg.items or {}
end

local function configUsesFlatGenderLists(source)
    return type(source) == 'table' and (type(source.male) == 'table' or type(source.female) == 'table')
end

local function iterConfigRawEntries(source, gender, categoryId)
    local entries = {}
    if type(source) ~= 'table' then return entries end

    if categoryId then
        local perTab = source[categoryId]
        local list = perTab and perTab[gender]
        if type(list) == 'table' then
            for i = 1, #list do entries[#entries + 1] = list[i] end
        end
        return entries
    end

    local flat = source[gender]
    if type(flat) == 'table' then
        for i = 1, #flat do entries[#entries + 1] = flat[i] end
    end
    return entries
end

local function shopConfigHasItems(shopKey, gender, categoryId)
    local source = configItemsForShop(shopKey)
    local list = iterConfigRawEntries(source, gender, categoryId)
    if #list > 0 then return true end

    if configUsesFlatGenderLists(source) and categoryId then
        local flat = iterConfigRawEntries(source, gender, nil)
        for i = 1, #flat do
            local resolved = Catalog.resolveConfigEntry(flat[i], gender, nil)
            if resolved and resolved.tab == categoryId then
                return true
            end
        end
    end
    return false
end

local function iterShopCategoryIds()
    local ids = {}
    local seen = {}
    if cfg.admin and cfg.admin.dbOverridesConfig then
        for i = 1, #(cfg.adminCategories or {}) do
            local id = cfg.adminCategories[i].id
            if id and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    for i = 1, #(cfg.categories or {}) do
        local id = cfg.categories[i].id
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

function Catalog.buildShopTabs(gender, allowedCategories, shopKey)
    gender = Catalog.normalizeGender(gender)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    local allow = allowedCategories
    local tabs = {}
    local ids = iterShopCategoryIds()
    for i = 1, #ids do
        local catId = ids[i]
        if allow and not allow[catId] then goto continue end
        if not VALID_CATEGORIES[catId] then goto continue end
        local cat = categoryDef(catId)
        if not cat then goto continue end
        if usesDbCatalog() then
            if not Catalog.hasDbItems(gender, catId, shopKey) then goto continue end
        elseif not shopConfigHasItems(shopKey, gender, catId) then
            goto continue
        end
        tabs[#tabs + 1] = { id = cat.id, label = cat.label }
        ::continue::
    end
    return tabs
end

local function normalizeImageBase(base)
    if type(base) ~= 'string' or base == '' then
        return 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/'
    end
    if base:sub(-1) ~= '/' then return base .. '/' end
    return base
end

function Catalog.isValidCategory(id)
    return VALID_CATEGORIES[id] ~= nil
end

function Catalog.isValidRarity(id)
    if not id or id == '' or id == 'common' then return true end
    return VALID_RARITIES[id] ~= nil
end

function Catalog.normalizeGender(gender)
    return gender == 'female' and 'female' or 'male'
end

--- Tab shop/admin dùng `bag`; clothing_data.lua dùng type `backpack`.
local function normalizeShopCategory(cat)
    if type(cat) ~= 'string' then return nil end
    cat = cat:lower()
    if cat == 'backpack' or cat == 'balo' then return 'bag' end
    return cat
end

local function shopCategoryMatches(itemCat, filterCat)
    return normalizeShopCategory(itemCat) == normalizeShopCategory(filterCat)
end

function Catalog.buildItemName(categoryId, gender, drawable, texture)
    drawable = tonumber(drawable) or 0
    texture = tonumber(texture) or 0
    if drawable < 0 then return nil end
    local prefix = gender == 'female' and 'f_' or 'm_'
    return ('%s%s_%d_%d'):format(prefix, categoryId, drawable, texture)
end

local function stripImageExt(key)
    if type(key) ~= 'string' then return nil end
    return key:gsub('%.png$', ''):gsub('%.jpg$', ''):gsub('%.webp$', '')
end

local function captureStarted()
    return GetResourceState('hgrp_clothing_capture') == 'started'
end

local function fetchCatalogItem(imageKey)
    if not captureStarted() or type(imageKey) ~= 'string' or imageKey == '' then return nil end
    local ok, item = pcall(function()
        return exports['hgrp_clothing_capture']:getClothingCatalogItem(imageKey)
    end)
    if ok and type(item) == 'table' then return item end
    return nil
end

local function resolveCatalogImageKey(imageKey)
    if not captureStarted() or type(imageKey) ~= 'string' or imageKey == '' then
        return stripImageExt(imageKey)
    end
    local bare = stripImageExt(imageKey)
    local ok, resolved = pcall(function()
        return exports['hgrp_clothing_capture']:resolveClothingImageKey(bare)
    end)
    if ok and type(resolved) == 'string' and resolved ~= '' then
        return stripImageExt(resolved)
    end
    return bare
end

local function applyCatalogGender(item, gender)
    if type(item) ~= 'table' then return nil end
    if item.gender == 'unisex' then
        local variants = item.genderVariants
        if type(variants) == 'table' and type(variants[gender]) == 'table' then
            local variant = variants[gender]
            local out = {}
            for k, v in pairs(item) do out[k] = v end
            out.drawable = tonumber(variant.drawable) or item.drawable
            out.texture = math.floor(tonumber(variant.texture) or 0)
            if variant.wearComponentId ~= nil then
                out.wearComponentId = tonumber(variant.wearComponentId)
            end
            if type(variant.extraComponents) == 'table' and #variant.extraComponents > 0 then
                out.extraComponents = variant.extraComponents
            end
            return out
        end
        return item
    end
    if item.gender and item.gender ~= gender then return nil end
    return item
end

local function shopTabFromCatalog(item, hintCategory)
    -- Tab shop từ config (vd. tattoo) thắng displayType catalog (hands → jacket).
    local hint = normalizeShopCategory(hintCategory)
    if hint and Catalog.isValidCategory(hint) then
        return hint
    end
    local displayType = item.displayType
    if displayType == 'backpack' or displayType == 'balo' then displayType = 'bag' end
    local normalizedDisplay = displayType and normalizeShopCategory(displayType)
    if normalizedDisplay and Catalog.isValidCategory(normalizedDisplay) then
        return normalizedDisplay
    end
    return normalizeShopCategory(item.category)
end

local function enrichFromCatalog(catalogItem, gender, hintCategory, opts)
    opts = type(opts) == 'table' and opts or {}
    local item = applyCatalogGender(catalogItem, gender)
    if not item then return nil end

    local tab = shopTabFromCatalog(item, hintCategory or opts.tab)
    if not tab or not Catalog.isValidCategory(tab) then return nil end

    local drawable = tonumber(item.drawable)
    local texture = math.floor(tonumber(item.texture) or 0)
    if drawable == nil or drawable < 0 then return nil end

    local imageKey = stripImageExt(item.imageKey) or Catalog.buildItemName(tab, gender, drawable, texture)
    local price = tonumber(opts.price)
    if price == nil then
        price = tonumber(cfg.defaultPrices and cfg.defaultPrices[tab]) or 0
    end

    local label = opts.label
    if not label or label == '' then
        label = item.label
    end
    if not label or label == '' then
        local cat = categoryDef(tab)
        label = ('%s #%d'):format((cat and cat.label) or tab, drawable)
    end

    local wearCategory = normalizeShopCategory(item.category)

    return {
        tab = tab,
        drawable = drawable,
        texture = texture,
        price = math.floor(price),
        rarity = opts.rarity or item.rarity or 'common',
        label = label,
        itemName = imageKey,
        imageKey = imageKey,
        gender = gender,
        wearCategory = wearCategory,
        wearComponentId = item.wearComponentId and tonumber(item.wearComponentId) or nil,
        extraComponents = type(item.extraComponents) == 'table' and #item.extraComponents > 0 and item.extraComponents or nil,
        hideNametag = opts.hideNametag == true or item.hideNametag == true,
        hideHair = opts.hideHair == true or item.hideHair == true,
    }
end

--- Resolve 1 dòng config shop: chuỗi image_key hoặc bảng { item = 'm_jacket_12_0', price = ... }.
--- Vẫn hỗ trợ legacy { drawable, texture, price }.
function Catalog.resolveConfigEntry(raw, gender, hintCategory)
    gender = Catalog.normalizeGender(gender)
    hintCategory = normalizeShopCategory(hintCategory)

    local opts = {}
    local itemKey = nil

    if type(raw) == 'string' then
        itemKey = stripImageExt(raw)
    elseif type(raw) == 'table' then
        itemKey = stripImageExt(raw.item or raw.name or raw.imageKey or raw.image or raw.key)
        opts.price = raw.price
        opts.label = raw.label
        opts.rarity = raw.rarity
        opts.hideHair = raw.hideHair
        opts.hideNametag = raw.hideNametag
        opts.tab = normalizeShopCategory(raw.tab or raw.category)

        if raw.drawable ~= nil and tonumber(raw.drawable) >= 0 then
            local tab = opts.tab or hintCategory
            if not tab or not Catalog.isValidCategory(tab) then return nil end
            local drawable = tonumber(raw.drawable) or 0
            local texture = math.floor(tonumber(raw.texture) or 0)
            local imageKey = stripImageExt(raw.imageKey or raw.image or raw.item or raw.name)
            if not imageKey then
                imageKey = Catalog.buildItemName(tab, gender, drawable, texture)
            end
            imageKey = resolveCatalogImageKey(imageKey)

            local catalogItem = fetchCatalogItem(imageKey)
            if catalogItem then
                local merged = enrichFromCatalog(catalogItem, gender, tab, opts)
                if merged then return merged end
            end

            local price = tonumber(opts.price)
            if price == nil then
                price = tonumber(cfg.defaultPrices and cfg.defaultPrices[tab]) or 0
            end
            local label = opts.label
            if not label or label == '' then
                local cat = categoryDef(tab)
                label = ('%s #%d'):format((cat and cat.label) or tab, drawable)
            end
            return {
                tab = tab,
                drawable = drawable,
                texture = texture,
                price = math.floor(price),
                rarity = opts.rarity or 'common',
                label = label,
                itemName = imageKey,
                imageKey = imageKey,
                gender = gender,
                hideNametag = opts.hideNametag == true,
                hideHair = opts.hideHair == true,
            }
        end
    else
        return nil
    end

    if not itemKey or itemKey == '' then return nil end
    itemKey = resolveCatalogImageKey(itemKey)

    if itemKey:sub(1, 2) == 'u_' then
        local catalogItem = fetchCatalogItem(itemKey)
        if catalogItem then
            local merged = enrichFromCatalog(catalogItem, gender, hintCategory, opts)
            if merged then
                merged.itemName = itemKey
                merged.imageKey = itemKey
                return merged
            end
        end
        local tab = hintCategory or opts.tab
        if not tab or not Catalog.isValidCategory(tab) then return nil end
        local price = tonumber(opts.price)
        if price == nil then
            price = tonumber(cfg.defaultPrices and cfg.defaultPrices[tab]) or 0
        end
        return {
            tab = tab,
            drawable = 0,
            texture = 0,
            price = math.floor(price),
            rarity = opts.rarity or 'common',
            label = opts.label or itemKey,
            itemName = itemKey,
            imageKey = itemKey,
            gender = gender,
            hideNametag = opts.hideNametag == true,
            hideHair = opts.hideHair == true,
        }
    end

    local catalogItem = fetchCatalogItem(itemKey)
    if catalogItem then
        return enrichFromCatalog(catalogItem, gender, hintCategory or opts.tab, opts)
    end

    local parsedGender, parsedCategory, parsedDrawable, parsedTexture = itemKey:match('^([mf])_([^_]+)_(%d+)_(%d+)$')
    if parsedGender then
        local parsed = {
            gender = parsedGender == 'f' and 'female' or 'male',
            category = parsedCategory,
            drawable = tonumber(parsedDrawable),
            texture = tonumber(parsedTexture) or 0,
        }
        if parsed.gender ~= gender then return nil end
        local tab = normalizeShopCategory(hintCategory or opts.tab or parsed.category)
        if not tab or not Catalog.isValidCategory(tab) then return nil end
        local price = tonumber(opts.price)
        if price == nil then
            price = tonumber(cfg.defaultPrices and cfg.defaultPrices[tab]) or 0
        end
        local label = opts.label
        if not label or label == '' then
            local cat = categoryDef(tab)
            label = ('%s #%d'):format((cat and cat.label) or tab, parsed.drawable)
        end
        return {
            tab = tab,
            drawable = parsed.drawable,
            texture = parsed.texture,
            price = math.floor(price),
            rarity = opts.rarity or 'common',
            label = label,
            itemName = itemKey,
            imageKey = itemKey,
            gender = gender,
            wearCategory = normalizeShopCategory(parsed.category),
            hideNametag = opts.hideNametag == true,
            hideHair = opts.hideHair == true,
        }
    end

    return nil
end

local schemaReady = false
local schemaEnsuring = false
local tableColumns = {} -- tableName -> { [column]=true } | false = table missing

local function invalidateColumnCache(tableName)
    if tableName then
        tableColumns[tableName] = nil
    else
        tableColumns = {}
    end
end

local function loadTableColumns(tableName)
    if tableColumns[tableName] ~= nil then
        return tableColumns[tableName]
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName:gsub('`', '')))
    end)
    if not ok or type(rows) ~= 'table' or #rows == 0 then
        tableColumns[tableName] = false
        return false
    end

    local cols = {}
    for i = 1, #rows do
        local field = rows[i].Field or rows[i].field
        if field then cols[field] = true end
    end
    tableColumns[tableName] = cols
    return cols
end

local function columnExists(tableName, columnName)
    local cols = loadTableColumns(tableName)
    if cols == false then return false end
    return cols[columnName] == true
end

local function migrateListingShopKey()
    if not columnExists('hgrp_clothingshop_listings', 'shop_key') then
        MySQL.query.await(
            "ALTER TABLE hgrp_clothingshop_listings ADD COLUMN shop_key VARCHAR(64) NOT NULL DEFAULT 'clothing_normal' AFTER clothing_item_id"
        )
        invalidateColumnCache('hgrp_clothingshop_listings')
    end
    pcall(function()
        MySQL.query.await('ALTER TABLE hgrp_clothingshop_listings DROP INDEX uk_clothing_item')
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE hgrp_clothingshop_listings ADD UNIQUE KEY uk_shop_clothing (shop_key, clothing_item_id)')
    end)
end

local function migrateShopColumns()
    if not columnExists('hgrp_clothingshop_items', 'hide_nametag') then
        MySQL.query.await(
            'ALTER TABLE hgrp_clothingshop_items ADD COLUMN hide_nametag TINYINT(1) NOT NULL DEFAULT 0 AFTER sort_order'
        )
        invalidateColumnCache('hgrp_clothingshop_items')
    end
    if not columnExists('hgrp_clothingshop_items', 'hide_hair') then
        MySQL.query.await(
            'ALTER TABLE hgrp_clothingshop_items ADD COLUMN hide_hair TINYINT(1) NOT NULL DEFAULT 0 AFTER hide_nametag'
        )
        invalidateColumnCache('hgrp_clothingshop_items')
    end
end

function Catalog.ensureTables()
    if schemaReady then return end
    while schemaEnsuring do Wait(0) end
    if schemaReady then return end
    schemaEnsuring = true

    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS hgrp_clothingshop_listings (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                shop_key VARCHAR(64) NOT NULL DEFAULT 'clothing_normal',
                clothing_item_id INT UNSIGNED NOT NULL,
                price INT NOT NULL DEFAULT 0,
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                sort_order INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uk_shop_clothing (shop_key, clothing_item_id),
                KEY idx_enabled (enabled)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])

        --- Legacy table — giữ để item_catalog.lua migrate sang bảng mới.
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS hgrp_clothingshop_items (
                id INT NOT NULL AUTO_INCREMENT,
                gender VARCHAR(8) NOT NULL,
                category VARCHAR(32) NOT NULL,
                drawable INT NOT NULL,
                texture INT NOT NULL DEFAULT 0,
                label VARCHAR(128) NULL,
                price INT NOT NULL DEFAULT 0,
                rarity VARCHAR(24) NULL DEFAULT 'common',
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                sort_order INT NOT NULL DEFAULT 0,
                hide_nametag TINYINT(1) NOT NULL DEFAULT 0,
                hide_hair TINYINT(1) NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uk_slot (gender, category, drawable, texture),
                KEY idx_gender_cat (gender, category, enabled)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        invalidateColumnCache('hgrp_clothingshop_items')
        migrateShopColumns()
        migrateListingShopKey()

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS hgrp_retail_shop_settings (
                shop_key VARCHAR(64) NOT NULL,
                currency VARCHAR(24) NOT NULL DEFAULT 'cash',
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (shop_key)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)

    schemaEnsuring = false
    if not ok then
        error(err)
    end
    schemaReady = true
end

local function boolFromDb(value)
    return value == 1 or value == true
end

local function effectiveShopCategory(row)
    if type(row) ~= 'table' then return nil end
    if type(row.display_type) == 'string' and row.display_type ~= '' then
        return row.display_type
    end
    if type(row.displayType) == 'string' and row.displayType ~= '' then
        return row.displayType
    end
    return row.category
end

local function rowMatchesShopCategory(row, category)
    if type(row) ~= 'table' or type(category) ~= 'string' then return false end
    return row.category == category or effectiveShopCategory(row) == category
end

local function imageUrlFromRow(row, shopCategory)
    if type(row) ~= 'table' then return nil end
    local gender = Catalog.normalizeGender(row.gender)
    local drawable = tonumber(row.drawable) or 0
    local texture = tonumber(row.texture) or 0
    local itemName = row.image_key or row.imageKey
        or Catalog.buildItemName(row.category, gender, drawable, texture)
    if not itemName then return nil end
    return Catalog.resolveItemImage(itemName, itemName)
end

function Catalog.invalidate()
    cache.rows = nil
    cache.categoryCounts = {}
    cache.builtAt = 0
end

local function rebuildCategoryCounts(rows)
    cache.categoryCounts = {}
    for i = 1, #rows do
        local row = rows[i]
        if row.enabled == 1 or row.enabled == true then
            local shopCat = normalizeShopCategory(row.category)
            if shopCat then
                local shopKey = row.shop_key or 'clothing_normal'
                local genders = { row.gender }
                if row.gender == 'unisex' then
                    genders = { 'male', 'female' }
                end
                local tabCat = normalizeShopCategory(effectiveShopCategory(row) or row.category) or shopCat
                for gi = 1, #genders do
                    local key = ('%s:%s:%s'):format(shopKey, genders[gi], tabCat)
                    cache.categoryCounts[key] = (cache.categoryCounts[key] or 0) + 1
                end
            end
        end
    end
end

function Catalog.loadRows(force)
    if not force and cache.rows and (GetGameTimer() - cache.builtAt) < 3000 then
        return cache.rows
    end
    cache.rows = MySQL.query.await([[
        SELECT l.id AS listing_id, l.shop_key, l.price, l.enabled, l.sort_order, l.clothing_item_id,
               i.id AS item_id, i.gender, i.category, i.drawable, i.texture, i.image_key,
               i.label, i.rarity, i.hide_nametag, i.hide_hair, i.display_type
        FROM hgrp_clothingshop_listings l
        INNER JOIN hgrp_clothing_items i ON i.id = l.clothing_item_id
        ORDER BY l.shop_key ASC, l.sort_order ASC, l.id ASC
    ]]) or {}
    cache.builtAt = GetGameTimer()
    rebuildCategoryCounts(cache.rows)
    return cache.rows
end

function Catalog.hasDbItems(gender, category, shopKey)
    gender = Catalog.normalizeGender(gender)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    Catalog.loadRows(false)
    local key = ('%s:%s:%s'):format(shopKey, gender, category)
    return (cache.categoryCounts[key] or 0) > 0
end

function Catalog.findListing(gender, category, drawable, texture, shopKey)
    gender = Catalog.normalizeGender(gender)
    drawable = tonumber(drawable)
    texture = tonumber(texture) or 0
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or nil
    if not Catalog.isValidCategory(category) or drawable == nil or drawable < 0 then
        return nil
    end
    if shopKey then
        return MySQL.single.await([[
            SELECT l.id AS listing_id, l.shop_key, l.price, l.enabled, l.sort_order, l.clothing_item_id,
                   i.id AS item_id, i.gender, i.category, i.drawable, i.texture, i.image_key,
                   i.label, i.rarity, i.hide_nametag, i.hide_hair, i.display_type
            FROM hgrp_clothingshop_listings l
            INNER JOIN hgrp_clothing_items i ON i.id = l.clothing_item_id
            WHERE l.shop_key = ? AND (i.gender = ? OR i.gender = 'unisex') AND i.drawable = ? AND i.texture = ?
              AND (i.category = ? OR i.display_type = ?)
            LIMIT 1
        ]], { shopKey, gender, drawable, texture, category, category })
    end
    return MySQL.single.await([[
        SELECT l.id AS listing_id, l.shop_key, l.price, l.enabled, l.sort_order, l.clothing_item_id,
               i.id AS item_id, i.gender, i.category, i.drawable, i.texture, i.image_key,
               i.label, i.rarity, i.hide_nametag, i.hide_hair, i.display_type
        FROM hgrp_clothingshop_listings l
        INNER JOIN hgrp_clothing_items i ON i.id = l.clothing_item_id
        WHERE (i.gender = ? OR i.gender = 'unisex') AND i.drawable = ? AND i.texture = ?
          AND (i.category = ? OR i.display_type = ?)
        LIMIT 1
    ]], { gender, drawable, texture, category, category })
end

function Catalog.findRow(gender, category, drawable, texture, shopKey)
    return Catalog.findListing(gender, category, drawable, texture, shopKey)
end

function Catalog.getEnabledEntry(gender, category, drawable, texture, shopKey)
    local row = Catalog.findRow(gender, category, drawable, texture, shopKey)
    if not row then return nil end
    if row.enabled ~= 1 and row.enabled ~= true then return nil end
    local shopCategory = effectiveShopCategory(row) or category
    return {
        drawable = tonumber(row.drawable) or 0,
        texture = tonumber(row.texture) or 0,
        label = row.label,
        price = math.floor(tonumber(row.price) or 0),
        rarity = row.rarity or 'common',
        hideNametag = row.category == 'mask' and boolFromDb(row.hide_nametag),
        hideHair = row.category == 'mask' and boolFromDb(row.hide_hair),
        clothingItemId = tonumber(row.clothing_item_id),
        itemName = row.image_key,
        tab = shopCategory,
    }
end

function Catalog.listConfigured(gender, category, shopKey)
    gender = Catalog.normalizeGender(gender)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    local listAll = category == 'all'
    if not listAll and not Catalog.isValidCategory(category) then return {} end
    local rows = Catalog.loadRows(false)
    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        local rowShop = row.shop_key or 'clothing_normal'
        if rowShop == shopKey and (row.gender == gender or row.gender == 'unisex') then
            if listAll or rowMatchesShopCategory(row, category) then
                out[#out + 1] = row
            end
        end
    end
    return out
end

--- Đếm listing theo shop / giới tính / danh mục (admin UI).
function Catalog.getAdminListingCounts()
    Catalog.loadRows(false)
    local counts = {}
    for key, n in pairs(cache.categoryCounts or {}) do
        local shopKey, g, cat = key:match('^([^:]+):([^:]+):(.+)$')
        if shopKey and g and cat then
            counts[shopKey] = counts[shopKey] or {}
            counts[shopKey][g] = counts[shopKey][g] or {}
            counts[shopKey][g][cat] = n
        end
    end
    return counts
end

function Catalog.resolveItemImage(itemName, metaImage)
    local base = normalizeImageBase(cfg.imageBase)
    local file = itemName and (itemName .. '.png') or nil
    if type(metaImage) == 'string' and metaImage ~= '' then
        if metaImage:find('^[%w]+://') then return metaImage end
        file = metaImage
    end
    if type(file) ~= 'string' or file == '' then return nil end
    if not file:match('%.png$') and not file:match('%.jpg$') and not file:match('%.webp$') then
        file = file:gsub('%.png$', ''):gsub('%.jpg$', '') .. '.png'
    end
    return base .. file:gsub('^/+', '')
end

--- Ảnh chuẩn theo gender + category + drawable (f_jacket_12_0.png)
function Catalog.imageUrlFor(gender, category, drawable, texture, metaImage)
    gender = Catalog.normalizeGender(gender)
    drawable = tonumber(drawable) or 0
    texture = tonumber(texture) or 0
    local itemName = Catalog.buildItemName(category, gender, drawable, texture)
    if not itemName then return nil end

    if type(metaImage) == 'string' and metaImage ~= '' then
        local bare = metaImage:gsub('%.png$', ''):gsub('%.jpg$', '')
        local expectPrefix = gender == 'female' and 'f_' or 'm_'
        if bare:sub(1, 2) == expectPrefix or metaImage:find('^[%w]+://') then
            return Catalog.resolveItemImage(itemName, metaImage)
        end
    end

    return Catalog.resolveItemImage(itemName, nil)
end

function Catalog.enrichRow(row)
    if not row then return nil end
    local gender = Catalog.normalizeGender(row.gender)
    local shopCategory = effectiveShopCategory(row) or row.category
    local category = shopCategory
    local drawable = tonumber(row.drawable) or 0
    local texture = tonumber(row.texture) or 0
    local itemName = row.image_key or Catalog.buildItemName(row.category, gender, drawable, texture)
    local meta = itemName and exports['hgrp_clothing_capture']:getClothingData(itemName)
    local label = row.label
    if (not label or label == '') and meta and meta.label then label = meta.label end
    if (not label or label == '') and itemName then
        local ok, resolved = pcall(function()
            return exports['hgrp_clothing_capture']:resolveItemLabel(itemName)
        end)
        if ok and type(resolved) == 'string' and resolved ~= '' then label = resolved end
    end
    if not label or label == '' then
        label = ('%s #%d'):format(VALID_CATEGORIES[category] or category, drawable)
    end
    return {
        id = tonumber(row.listing_id) or tonumber(row.id),
        clothingItemId = tonumber(row.clothing_item_id) or tonumber(row.item_id),
        gender = gender,
        category = category,
        wearCategory = row.category,
        categoryLabel = VALID_CATEGORIES[category] or category,
        drawable = drawable,
        texture = texture,
        label = label,
        price = math.floor(tonumber(row.price) or 0),
        rarity = row.rarity or 'common',
        enabled = row.enabled == 1 or row.enabled == true,
        sortOrder = tonumber(row.sort_order) or 0,
        itemName = itemName,
        image = imageUrlFromRow(row, category) or Catalog.imageUrlFor(gender, row.category, drawable, texture, meta and meta.image),
        imageKey = itemName,
        hideNametag = row.category == 'mask' and boolFromDb(row.hide_nametag),
        hideHair = row.category == 'mask' and boolFromDb(row.hide_hair),
        readOnlyConfig = true,
    }
end

function Catalog.browseConfiguredForShop(gender, category, query, shopKey)
    gender = Catalog.normalizeGender(gender)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    if not Catalog.isValidCategory(category) then return {} end
    query = type(query) == 'string' and query:lower():gsub('%s+', ' ') or ''

    local listedIds = {}
    local listingRows = MySQL.query.await(
        'SELECT clothing_item_id, shop_key FROM hgrp_clothingshop_listings',
        {}
    ) or {}
    for i = 1, #listingRows do
        if (listingRows[i].shop_key or 'clothing_normal') == shopKey then
            listedIds[tonumber(listingRows[i].clothing_item_id)] = true
        end
    end

    local catalogRows = {}
    if GetResourceState('hgrp_clothing_capture') == 'started' then
        local ok, rows = pcall(function()
            return exports['hgrp_clothing_capture']:listClothingCatalogItems(gender, category)
        end)
        if ok and type(rows) == 'table' then
            catalogRows = rows
        end
    end

    if #catalogRows == 0 then
        if category == 'bag' then
            catalogRows = MySQL.query.await([[
                SELECT i.*
                FROM hgrp_clothing_items i
                WHERE (i.gender = ? OR i.gender = 'unisex') AND i.enabled = 1
                  AND i.category IN ('bag', 'backpack')
                ORDER BY i.drawable ASC, i.texture ASC
            ]], { gender }) or {}
        elseif category == 'hands' then
            catalogRows = MySQL.query.await([[
                SELECT i.*
                FROM hgrp_clothing_items i
                WHERE (i.gender = ? OR i.gender = 'unisex') AND i.enabled = 1
                  AND i.category = 'hands'
                ORDER BY i.drawable ASC, i.texture ASC
            ]], { gender }) or {}
        else
            catalogRows = MySQL.query.await([[
                SELECT i.*
                FROM hgrp_clothing_items i
                WHERE (i.gender = ? OR i.gender = 'unisex') AND i.enabled = 1
                  AND (i.category = ? OR i.display_type = ?)
                ORDER BY i.drawable ASC, i.texture ASC
            ]], { gender, category, category }) or {}
        end
    end

    local out = {}
    for i = 1, #catalogRows do
        local row = catalogRows[i]
        local id = tonumber(row.id)
        if id and listedIds[id] then goto continue end

        local drawable = tonumber(row.drawable) or 0
        local texture = tonumber(row.texture) or 0
        local itemName = row.imageKey or row.image_key
            or Catalog.buildItemName(row.category or category, gender, drawable, texture)
        local label = row.label or itemName

        if row.enabled == false or row.enabled == 0 then goto continue end

        if query ~= '' then
            local hay = ('%s %s %d %d'):format(itemName, label, drawable, texture):lower()
            if not hay:find(query, 1, true) then goto continue end
        end

        out[#out + 1] = {
            clothingItemId = id or tonumber(row.id),
            name = itemName,
            label = label,
            gender = gender,
            category = category,
            drawable = drawable,
            texture = texture,
            rarity = row.rarity or 'common',
            image = imageUrlFromRow(row, category)
                or Catalog.imageUrlFor(gender, row.category or category, drawable, texture, nil),
            imageKey = itemName,
        }
        ::continue::
    end
    return out
end

function Catalog.addListing(clothingItemId, price, enabled, sortOrder, shopKey)
    clothingItemId = tonumber(clothingItemId)
    price = math.floor(tonumber(price) or 0)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    if not clothingItemId or price < 0 then return nil, 'invalid' end

    local exists = MySQL.scalar.await(
        'SELECT id FROM hgrp_clothingshop_listings WHERE shop_key = ? AND clothing_item_id = ? LIMIT 1',
        { shopKey, clothingItemId }
    )
    if exists then return nil, 'already_listed' end

    local id = MySQL.insert.await(
        [[INSERT INTO hgrp_clothingshop_listings (shop_key, clothing_item_id, price, enabled, sort_order)
          VALUES (?, ?, ?, ?, ?)]],
        { shopKey, clothingItemId, price, (enabled ~= false) and 1 or 0, math.floor(tonumber(sortOrder) or 0) }
    )
    Catalog.invalidate()
    return id
end

function Catalog.updateListing(listingId, price, enabled, sortOrder)
    listingId = tonumber(listingId)
    if not listingId then return false end
    MySQL.update.await(
        [[UPDATE hgrp_clothingshop_listings SET price = ?, enabled = ?, sort_order = ? WHERE id = ?]],
        {
            math.floor(tonumber(price) or 0),
            enabled and 1 or 0,
            math.floor(tonumber(sortOrder) or 0),
            listingId,
        }
    )
    Catalog.invalidate()
    return true
end

function Catalog.deleteListing(listingId)
    listingId = tonumber(listingId)
    if not listingId then return false end
    local n = MySQL.update.await('DELETE FROM hgrp_clothingshop_listings WHERE id = ?', { listingId })
    Catalog.invalidate()
    return n and n > 0
end

function Catalog.buildShopItems(gender, allowedCategories, shopKey)
    gender = Catalog.normalizeGender(gender)
    shopKey = type(shopKey) == 'string' and shopKey ~= '' and shopKey or 'clothing_normal'
    local allow = allowedCategories
    local items = {}
    local nextId = 0
    local imageBase = normalizeImageBase(cfg.imageBase)
    local seenKeys = {}

    local function pushResolved(resolved)
        if not resolved or not resolved.tab then return end
        if allow and not allow[resolved.tab] then return end

        if captureStarted() and (not resolved.extraComponents or not resolved.wearComponentId) then
            local key = resolveCatalogImageKey(resolved.imageKey or resolved.itemName)
            if key then
                local catalogItem = applyCatalogGender(fetchCatalogItem(key), gender)
                if catalogItem then
                    resolved.wearComponentId = resolved.wearComponentId
                        or (catalogItem.wearComponentId and tonumber(catalogItem.wearComponentId))
                    if not resolved.extraComponents and type(catalogItem.extraComponents) == 'table' and #catalogItem.extraComponents > 0 then
                        resolved.extraComponents = catalogItem.extraComponents
                    end
                    resolved.wearCategory = resolved.wearCategory or normalizeShopCategory(catalogItem.category)
                end
            end
        end

        local dedupeKey = resolved.imageKey or resolved.itemName
            or ('%s:%d:%d'):format(resolved.tab, resolved.drawable or -1, resolved.texture or 0)
        if seenKeys[dedupeKey] then return end
        seenKeys[dedupeKey] = true

        local cat = categoryDef(resolved.tab)
        if not cat then return end

        local slot = resolved.wearComponentId or cat.slot
        local kind = cat.kind
        if DrawableUtils.isPropCategory(resolved.tab) then
            kind = 'prop'
            slot = DrawableUtils.wearComponentId(resolved.tab) or slot
        end

        local imageKey = resolved.imageKey or resolved.itemName
        local metaImage = imageKey
        if captureStarted() and imageKey then
            local meta = exports['hgrp_clothing_capture']:getClothingData(imageKey)
            if meta and meta.image then metaImage = meta.image end
        end

        nextId = nextId + 1
        items[#items + 1] = {
            id = nextId,
            tab = resolved.tab,
            tabLabel = cat.label,
            kind = kind,
            slot = slot,
            category = resolved.tab,
            drawable = resolved.drawable,
            texture = resolved.texture,
            style = resolved.drawable,
            gender = gender,
            wearCategory = resolved.wearCategory,
            itemCategory = resolved.wearCategory,
            wearComponentId = resolved.wearComponentId,
            extraComponents = resolved.extraComponents,
            imageKey = imageKey,
            image = Catalog.resolveItemImage(imageKey, metaImage),
            title = resolved.label,
            sub = (resolved.texture or 0) > 0 and ('Texture %d'):format(resolved.texture) or (imageKey or ''),
            price = math.floor(resolved.price or 0),
            rarity = resolved.rarity or 'common',
            hideHair = resolved.hideHair == true,
            hideNametag = resolved.hideNametag == true,
        }
    end

    local catIds = iterShopCategoryIds()
    for i = 1, #catIds do
        local cat = categoryDef(catIds[i])
        if not cat then goto continue end
        if allow and not allow[cat.id] then goto continue end
        if not VALID_CATEGORIES[cat.id] then goto continue end

        if usesDbCatalog() then
            local rows = Catalog.listConfigured(gender, cat.id, shopKey)
            for j = 1, #rows do
                local row = rows[j]
                if row.enabled == 1 or row.enabled == true then
                    local enriched = Catalog.enrichRow(row)
                    if enriched then
                        pushResolved({
                            tab = cat.id,
                            drawable = enriched.drawable,
                            texture = enriched.texture,
                            price = enriched.price,
                            rarity = enriched.rarity,
                            label = enriched.label,
                            imageKey = enriched.imageKey or enriched.itemName,
                            itemName = enriched.imageKey or enriched.itemName,
                            wearCategory = enriched.wearCategory or row.category,
                        })
                    end
                end
            end
        else
            local source = configItemsForShop(shopKey)
            local list = iterConfigRawEntries(source, gender, cat.id)
            for j = 1, #list do
                local resolved = Catalog.resolveConfigEntry(list[j], gender, cat.id)
                pushResolved(resolved)
            end
        end

        ::continue::
    end

    if not usesDbCatalog() then
        local source = configItemsForShop(shopKey)
        if configUsesFlatGenderLists(source) then
            local flat = iterConfigRawEntries(source, gender, nil)
            for j = 1, #flat do
                local resolved = Catalog.resolveConfigEntry(flat[j], gender, nil)
                pushResolved(resolved)
            end
        end
    end

    return items, imageBase
end

local clothingDataCache = nil

function Catalog.loadClothingData()
    if clothingDataCache then return clothingDataCache end
    if GetResourceState('hgrp_clothing_capture') ~= 'started' then
        clothingDataCache = {}
        return clothingDataCache
    end
    local raw = LoadResourceFile('hgrp_clothing_capture', 'data/clothing_data.lua')
    if not raw or raw == '' then
        clothingDataCache = {}
        return clothingDataCache
    end
    local fn, err = load(raw, '@hgrp_clothing_capture/data/clothing_data.lua')
    if not fn then
        print(('[hgrp_clothingshop] clothing_data load err: %s'):format(tostring(err)))
        clothingDataCache = {}
        return clothingDataCache
    end
    local ok, data = pcall(fn)
    clothingDataCache = (ok and type(data) == 'table') and data or {}
    return clothingDataCache
end

local function parseItemKey(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('%.png$', ''):gsub('%.jpg$', '')
    local gender, category, drawable, texture = name:match('^([mf])_([%w]+)_(%d+)_(%d+)$')
    if not gender then return nil end
    return {
        gender = gender == 'f' and 'female' or 'male',
        category = category,
        drawable = tonumber(drawable),
        texture = tonumber(texture) or 0,
    }
end

function Catalog.browseCatalog(gender, category, query)
    gender = Catalog.normalizeGender(gender)
    if not Catalog.isValidCategory(category) then return {} end
    query = type(query) == 'string' and query:lower():gsub('%s+', ' ') or ''
    local data = Catalog.loadClothingData()
    local out = {}
    local seen = {}

    local function push(name, meta, parsed)
        if seen[name] then return end

        local cat = category
        local g = gender
        local drawable
        local texture

        if parsed then
            g = parsed.gender
            drawable = parsed.drawable
            texture = parsed.texture or 0
            if not shopCategoryMatches(parsed.category, category) then return end
        elseif meta and shopCategoryMatches(meta.type, category) then
            g = inferGenderFromName(name, meta)
            drawable = meta.drawable
            texture = meta.texture or 0
        else
            return
        end

        if g ~= gender then return end
        if drawable == nil or drawable < 0 then return end

        seen[name] = true
        local label = meta and meta.label or name
        local ok, resolved = pcall(function()
            return exports['hgrp_clothing_capture']:resolveItemLabel(name)
        end)
        if ok and type(resolved) == 'string' and resolved ~= '' then label = resolved end
        if query ~= '' then
            local hay = ('%s %s %s %d %d'):format(name, label, category, drawable, texture):lower()
            if not hay:find(query, 1, true) then return end
        end
        out[#out + 1] = {
            name = name,
            label = label,
            gender = g,
            category = category,
            drawable = drawable,
            texture = texture,
            image = Catalog.imageUrlFor(g, category, drawable, texture, meta and meta.image),
            imageKey = Catalog.buildItemName(category, g, drawable, texture),
            defaultRarity = meta and meta.rarity or 'common',
        }
    end

    for name, meta in pairs(data) do
        if type(meta) == 'table' then
            local parsed = parseItemKey(name)
            if parsed then
                push(name, meta, parsed)
            elseif meta.type == category then
                push(name, meta, nil)
            end
        end
    end

    table.sort(out, function(a, b)
        if a.drawable ~= b.drawable then return (a.drawable or 0) < (b.drawable or 0) end
        if a.texture ~= b.texture then return (a.texture or 0) < (b.texture or 0) end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

--- Quét drawable thật trên freemode ped (200+ balo nam, 300+ nữ…) — chỉ liệt kê slot chưa có profile, không tạo sẵn DB.
function Catalog.browseCatalogLive(gender, category, maxDrawable, query, configuredKeys)
    gender = Catalog.normalizeGender(gender)
    category = category or 'bag'
    maxDrawable = tonumber(maxDrawable) or 0
    query = type(query) == 'string' and query:lower():gsub('%s+', ' ') or ''
    configuredKeys = configuredKeys or {}

    local DrawableUtils = lib.load('shared.drawable_utils')
    local out = {}
    local seen = {}

    local function addEntry(drawable, texture, label)
        drawable = tonumber(drawable)
        texture = tonumber(texture) or 0
        if drawable == nil or drawable < 0 then return end
        local imageKey = Catalog.buildItemName(category, gender, drawable, texture)
        if not imageKey or seen[imageKey] or configuredKeys[imageKey] then return end

        label = label or imageKey
        local ok, resolved = pcall(function()
            return exports['hgrp_clothing_capture']:resolveItemLabel(imageKey)
        end)
        if ok and type(resolved) == 'string' and resolved ~= '' then
            label = resolved
        end

        if query ~= '' then
            local hay = ('%s %s %d %d'):format(imageKey, label, drawable, texture):lower()
            if not hay:find(query, 1, true) then return end
        end

        seen[imageKey] = true
        out[#out + 1] = {
            name = imageKey,
            imageKey = imageKey,
            label = label,
            gender = gender,
            category = category,
            drawable = drawable,
            texture = texture,
            image = Catalog.imageUrlFor(gender, category, drawable, texture, nil),
        }
    end

    if maxDrawable > 0 and category == 'bag' and not DrawableUtils.isPropCategory(category) then
        for drawable = maxDrawable - 1, 0, -1 do
            addEntry(drawable, 0, ('%s #%d'):format(VALID_CATEGORIES[category] or category, drawable))
        end
    end

    local legacy = Catalog.browseCatalog(gender, category, query)
    for i = 1, #legacy do
        local it = legacy[i]
        local key = it.name or it.imageKey
        if key and not seen[key] and not configuredKeys[key] then
            seen[key] = true
            out[#out + 1] = it
        end
    end

    table.sort(out, function(a, b)
        if a.drawable ~= b.drawable then return (a.drawable or 0) > (b.drawable or 0) end
        if a.texture ~= b.texture then return (a.texture or 0) < (b.texture or 0) end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

function inferGenderFromName(name, meta)
    if type(meta) == 'table' and type(meta.gender) == 'string' then
        return meta.gender == 'female' and 'female' or 'male'
    end
    if type(name) == 'string' then
        if name:sub(1, 2) == 'f_' then return 'female' end
        if name:sub(1, 2) == 'm_' then return 'male' end
    end
    return 'male'
end

CreateThread(function()
    Wait(500)
    local ok, err = pcall(Catalog.ensureTables)
    if not ok then
        print(('[hgrp_clothingshop] catalog DB init failed: %s'):format(tostring(err)))
    end
end)
