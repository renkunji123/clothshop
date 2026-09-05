local cfg = require 'config.shared'

local COMPONENT_CHECKS_BY_CATEGORY = {
    jacket = {
        { id = 3, label = 'Tay / body (comp 3)' },
        { id = 4, label = 'Quần / chân (comp 4)' },
        { id = 6, label = 'Giày (comp 6)' },
        { id = 8, label = 'Áo trong (comp 8)' },
    },
    undershirt = {
        { id = 3, label = 'Tay / body (comp 3)' },
        { id = 4, label = 'Quần / chân (comp 4)' },
        { id = 6, label = 'Giày (comp 6)' },
    },
}

local function enrichPanelCategories(categories)
    local out = {}
    for i = 1, #(categories or {}) do
        local row = categories[i]
        local copy = {
            id = row.id,
            label = row.label,
            saveLabel = row.saveLabel,
            primaryComp = row.primaryComp,
            simple = row.simple or false,
            unisex = row.unisex or false,
            maskOptions = row.maskOptions or false,
            armorOptions = row.armorOptions or false,
            overrideSlot = row.overrideSlot or false,
            kind = row.kind or 'component',
            componentChecks = row.componentChecks or COMPONENT_CHECKS_BY_CATEGORY[row.id] or {},
        }
        out[#out + 1] = copy
    end
    return out
end

local function isUnisexPanelCategory(category)
    if type(category) ~= 'string' or category == '' then return false end
    local cats = cfg.panelCategories or {}
    for i = 1, #cats do
        local row = cats[i]
        if row.id == category and row.unisex == true then
            return true
        end
    end
    return false
end

local function isAdmin(src)
    if src == 0 then return true end
    local ace = (cfg.admin and cfg.admin.ace) or 'group.admin'
    return IsPlayerAceAllowed(src, ace) or IsPlayerAceAllowed(src, 'command')
end

local EXTRA_SLOTS = {
    { id = 0, key = 'face', label = 'Comp 0 · Đầu / Face' },
    { id = 1, key = 'mask', label = 'Comp 1 · Khẩu trang' },
    { id = 3, key = 'torso', label = 'Comp 3 · Tay / thân trên (Hands)' },
    { id = 4, key = 'legs', label = 'Comp 4 · Quần / chân (Legs)' },
    { id = 5, key = 'bag', label = 'Comp 5 · Balo' },
    { id = 6, key = 'shoes', label = 'Comp 6 · Giày' },
    { id = 7, key = 'chains', label = 'Comp 7 · Cổ / phụ kiện' },
    { id = 8, key = 'undershirt', label = 'Comp 8 · Áo trong' },
    { id = 9, key = 'armor', label = 'Comp 9 · Giáp' },
    { id = 10, key = 'decals', label = 'Comp 10 · Decal' },
    { id = 11, key = 'jacket', label = 'Comp 11 · Áo khoác' },
}

local WEAR_COMPONENT_BY_CATEGORY = {
    face = 0, mask = 1, hands = 3, jacket = 11, undershirt = 8, pants = 4, shoes = 6, bag = 5, armor = 9, chains = 7,
}

local VALID_ARMOR_LEVELS = {}
for i = 1, #(cfg.armorTiers or {}) do
    local row = cfg.armorTiers[i]
    if row and row.level then
        VALID_ARMOR_LEVELS[tonumber(row.level)] = true
    end
end

local function resolveArmorLevel(category, payload)
    if category ~= 'armor' then return nil end
    local level = math.floor(tonumber(payload and payload.armorLevel) or 0)
    if level < 1 or not VALID_ARMOR_LEVELS[level] then
        return nil, 'Chọn cấp giáp hợp lệ.'
    end
    return level
end

local PROP_SLOT_BY_CATEGORY = {
    glasses = 1, hat = 0,
}

local function itemToPayload(item)
    if not item then return nil end
    return {
        id = item.id,
        gender = item.gender,
        category = item.category,
        shopCategory = item.displayType or item.category,
        displayType = item.displayType,
        itemTag = item.itemTag,
        drawable = item.drawable,
        texture = item.texture,
        imageKey = item.imageKey,
        label = item.label,
        rarity = item.rarity or 'common',
        hideNametag = item.hideNametag,
        hideHair = item.hideHair,
        armorLevel = item.armorLevel,
        wearComponentId = item.wearComponentId,
        extraComponents = item.extraComponents,
        enabled = item.enabled ~= false,
        hasExtraComponents = type(item.extraComponents) == 'table' and #item.extraComponents > 0,
        unisex = item.gender == 'unisex' or item.unisex == true,
        genderVariants = item.genderVariants,
        image = Catalog.resolveItemImage(item.imageKey, item.imageKey),
    }
end

lib.callback.register('hgrp_clothingshop:server:configMeta', function(source)
    if not isAdmin(source) then return { ok = false } end
    return {
        ok = true,
        imageBase = cfg.imageBase,
        genders = {
            { id = 'male', label = 'Nam' },
            { id = 'female', label = 'Nữ' },
        },
        categories = enrichPanelCategories(cfg.panelCategories or cfg.adminCategories or {}),
        componentChecksByCategory = COMPONENT_CHECKS_BY_CATEGORY,
        rarities = cfg.rarities or {},
        itemTags = cfg.itemTags or {},
        undershirtOverrideSlots = {
            { id = 'pants', label = 'Quần (comp 4)' },
            { id = 'bag', label = 'Balo (comp 5)' },
        },
        handsOverrideSlots = {
            { id = 'jacket', label = 'Áo khoác (slot 104 · comp 11)' },
        },
        armorTiers = cfg.armorTiers or {},
        componentSlots = EXTRA_SLOTS,
    }
end)

lib.callback.register('hgrp_clothingshop:server:configList', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end
    payload = type(payload) == 'table' and payload or {}
    local gender = Catalog.normalizeGender(payload.gender)
    local category = payload.category
    if not Catalog.isValidCategory(category) then
        return { ok = false, msg = 'Danh mục không hợp lệ.' }
    end

    if GetResourceState('hgrp_clothing_capture') ~= 'started' then
        return { ok = false, msg = 'hgrp_clothing_capture chưa chạy.' }
    end

    local ok, rowsOrErr = pcall(function()
        return exports['hgrp_clothing_capture']:listClothingCatalogItems(gender, category)
    end)
    if not ok then
        return { ok = false, msg = 'Lỗi catalog DB: ' .. tostring(rowsOrErr) }
    end

    local out = {}
    for i = 1, #(rowsOrErr or {}) do
        out[#out + 1] = itemToPayload(rowsOrErr[i])
    end
    return { ok = true, rows = out }
end)

lib.callback.register('hgrp_clothingshop:server:configGet', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end
    local id = tonumber(payload and payload.id)
    if not id then return { ok = false, msg = 'Thiếu id.' } end
    if GetResourceState('hgrp_clothing_capture') ~= 'started' then
        return { ok = false, msg = 'hgrp_clothing_capture chưa chạy.' }
    end

    local item = exports['hgrp_clothing_capture']:getClothingCatalogItemById(id)
    if not item then return { ok = false, msg = 'Không tìm thấy profile.' } end
    return { ok = true, item = itemToPayload(item) }
end)

lib.callback.register('hgrp_clothingshop:server:configBrowse', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end
    payload = type(payload) == 'table' and payload or {}
    local gender = Catalog.normalizeGender(payload.gender)
    local category = payload.category
    if not Catalog.isValidCategory(category) then
        return { ok = false, msg = 'Danh mục không hợp lệ.' }
    end

    local configured = {}
    if GetResourceState('hgrp_clothing_capture') == 'started' then
        local ok, rows = pcall(function()
            return exports['hgrp_clothing_capture']:listClothingCatalogItems(gender, category)
        end)
        if ok and type(rows) == 'table' then
            for i = 1, #rows do
                local key = rows[i].imageKey
                if key then configured[key] = true end
            end
        end
    end

    local maxDrawable = lib.callback.await('hgrp_clothingshop:client:getComponentDrawableMax', source, category, gender)
    local items
    if category == 'bag' and tonumber(maxDrawable) and maxDrawable > 0 then
        items = Catalog.browseCatalogLive(gender, category, maxDrawable, payload.query, configured) or {}
    else
        items = Catalog.browseCatalog(gender, category, payload.query) or {}
    end

    local wearId = WEAR_COMPONENT_BY_CATEGORY[category]
    local out = {}
    for i = 1, #items do
        local it = items[i]
        local key = it.name or it.imageKey
        if key and not configured[key] then
            it.wearComponentId = wearId
            it.propId = PROP_SLOT_BY_CATEGORY[category]
            out[#out + 1] = it
        end
    end
    return { ok = true, items = out, maxDrawable = maxDrawable }
end)

local function upsertCatalogPayload(payload)
    local category = payload.category
    if not Catalog.isValidCategory(category) then
        return nil, 'Danh mục không hợp lệ.'
    end
    if not Catalog.isValidRarity(payload.rarity) then
        return nil, 'Độ hiếm không hợp lệ.'
    end

    local wearComponentId = tonumber(payload.wearComponentId) or WEAR_COMPONENT_BY_CATEGORY[category]

    local displayType = type(payload.displayType) == 'string' and payload.displayType or nil
    if category == 'bag' then
        displayType = 'backpack'
    elseif category == 'hands' then
        displayType = 'jacket'
        wearComponentId = 3
    elseif displayType == category or displayType == '' then
        displayType = nil
    end

    local armorLevel, armorErr = resolveArmorLevel(category, payload)
    if armorErr then
        return nil, armorErr
    end

    local item, err = exports['hgrp_clothing_capture']:upsertClothingCatalogItem({
        gender = payload.gender,
        category = category,
        drawable = payload.drawable,
        texture = payload.texture,
        imageKey = payload.imageKey,
        label = payload.label,
        rarity = payload.rarity or 'common',
        displayType = displayType,
        itemTag = type(payload.itemTag) == 'string' and payload.itemTag ~= '' and payload.itemTag or nil,
        wearComponentId = wearComponentId,
        extraComponents = payload.extraComponents,
        hideNametag = category == 'mask' and payload.hideNametag == true,
        hideHair = category == 'mask' and payload.hideHair == true,
        armorLevel = armorLevel,
        enabled = payload.enabled ~= false,
        saveAsUnisex = payload.saveAsUnisex == true,
        genderSnapshots = payload.genderSnapshots,
    })

    if not item then
        return nil, 'Không lưu được cấu hình.' .. (err and (' (' .. tostring(err) .. ')') or '')
    end

    return item
end

lib.callback.register('hgrp_clothingshop:server:configUpsert', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end
    if type(payload) ~= 'table' then return { ok = false, msg = 'Dữ liệu không hợp lệ.' } end

    local category = payload.category
    if not Catalog.isValidCategory(category) then
        return { ok = false, msg = 'Danh mục không hợp lệ.' }
    end

    if isUnisexPanelCategory(category) and payload.saveBothGenders ~= true then
        return {
            ok = false,
            msg = 'Loại này chỉ lưu dạng unisex. Tick "Lưu 1 item unisex", cấu hình comp Nam + Nữ rồi lưu lại.',
        }
    end

    local saved = {}
    local lastItem

    local function saveOne(row)
        local item, err = upsertCatalogPayload(row)
        if not item then return false, err end
        saved[#saved + 1] = item
        lastItem = item
        return true
    end

    if payload.applyAllTextures == true then
        local drawable = tonumber(payload.drawable)
        if drawable == nil or drawable < 0 then
            return { ok = false, msg = 'Drawable không hợp lệ.' }
        end
        local gender = Catalog.normalizeGender(payload.gender)
        local maxTex = lib.callback.await(
            'hgrp_clothingshop:client:getComponentTextureMax',
            source,
            category,
            gender,
            drawable
        )
        maxTex = math.floor(tonumber(maxTex) or 0)
        if maxTex < 1 then
            return { ok = false, msg = 'Không đọc được số texture cho drawable này.' }
        end

        for texture = 0, maxTex - 1 do
            local row = {}
            for k, v in pairs(payload) do row[k] = v end
            row.id = nil
            row.texture = texture
            row.applyAllTextures = nil
            row.saveBothGenders = nil
            row.genderSnapshots = nil
            local prefix = gender == 'female' and 'f_' or 'm_'
            row.imageKey = ('%s%s_%d_%d'):format(prefix, category, drawable, texture)
            local okSave, err = saveOne(row)
            if not okSave then
                return { ok = false, msg = err or 'Lỗi lưu texture.' }
            end
        end

        exports['hgrp_clothing_capture']:invalidateClothingCatalogCache()
        return {
            ok = true,
            msg = ('Đã lưu %d texture (drawable #%d) — override giống nhau.'):format(#saved, drawable),
            item = itemToPayload(lastItem),
            count = #saved,
        }
    end

    if payload.saveBothGenders == true and type(payload.genderSnapshots) == 'table' then
        local snapshots = payload.genderSnapshots
        for _, gender in ipairs({ 'male', 'female' }) do
            local snap = snapshots[gender]
            if type(snap) ~= 'table' or snap.drawable == nil then
                return { ok = false, msg = ('Chưa cấu hình comp cho %s — chuyển tab và bấm Cập nhật từ ped.'):format(gender == 'female' and 'Nữ' or 'Nam') }
            end
        end

        local row = {}
        for k, v in pairs(payload) do row[k] = v end
        row.saveAsUnisex = true
        row.genderSnapshots = snapshots
        row.saveBothGenders = nil
        row.applyAllTextures = nil
        row.gender = 'unisex'
        row.imageKey = nil
        row.drawable = nil
        row.texture = nil

        local item, err = upsertCatalogPayload(row)
        if not item then
            return { ok = false, msg = err or 'Lỗi lưu unisex.' }
        end

        exports['hgrp_clothing_capture']:invalidateClothingCatalogCache()
        return {
            ok = true,
            msg = ('Đã lưu item unisex: %s (1 item mặc được cả nam & nữ).'):format(item.imageKey or ''),
            item = itemToPayload(item),
            count = 1,
        }
    end

    local item, err = upsertCatalogPayload(payload)
    if not item then
        return { ok = false, msg = err or 'Không lưu được cấu hình.' }
    end

    exports['hgrp_clothing_capture']:invalidateClothingCatalogCache()
    return { ok = true, msg = 'Đã lưu profile.', item = itemToPayload(item) }
end)

lib.callback.register('hgrp_clothingshop:server:configDelete', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end
    local id = tonumber(payload and payload.id)
    if not id then return { ok = false, msg = 'Thiếu id.' } end

    local listed = MySQL.scalar.await(
        'SELECT id FROM hgrp_clothingshop_listings WHERE clothing_item_id = ? LIMIT 1',
        { id }
    )
    if listed then
        return { ok = false, msg = 'Món đang có trong shop — xóa khỏi shop trước.' }
    end

    local ok = MySQL.update.await('DELETE FROM hgrp_clothing_items WHERE id = ?', { id })
    exports['hgrp_clothing_capture']:invalidateClothingCatalogCache()
    if not ok or ok < 1 then return { ok = false, msg = 'Không tìm thấy món.' } end
    return { ok = true, msg = 'Đã xóa profile.' }
end)

lib.addCommand((cfg.admin and cfg.admin.configCommand) or 'clothingconfigadmin', {
    help = 'Cấu hình catalog đồ — Illenium + panel HGRP bên phải',
    restricted = (cfg.admin and cfg.admin.ace) or 'group.admin',
}, function(source)
    if source == 0 then
        print('[hgrp_clothingshop] Dùng in-game: /clothingconfigadmin')
        return
    end
    TriggerClientEvent('hgrp_clothingshop:client:openConfigAdmin', source)
end)
