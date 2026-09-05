local cfg = require 'config.shared'

local catalogOpen = false
local originalAppearance = nil
local adminPreviewGender = nil

local WEAR_COMPONENT_BY_CATEGORY = {
    face = 0, mask = 1, hands = 3, jacket = 11, undershirt = 8, pants = 4, shoes = 6, bag = 5, armor = 9, chains = 7,
}

local PROP_SLOT_BY_CATEGORY = {
    hat = 0, glasses = 1,
}

local SLOT_NAME_BY_ID = {
    [0] = 'face', [1] = 'mask', [3] = 'torso', [4] = 'legs', [5] = 'bag', [6] = 'shoes',
    [7] = 'chains', [8] = 'undershirt', [9] = 'armor', [10] = 'decals', [11] = 'jacket',
}

local function illeniumReady()
    return GetResourceState('illenium-appearance') == 'started'
end

local function saveOriginalAppearance()
    if originalAppearance or not illeniumReady() then return end
    originalAppearance = exports['illenium-appearance']:getPedAppearance(cache.ped)
end

local function restoreOriginalAppearance()
    if not originalAppearance or not illeniumReady() then return end
    exports['illenium-appearance']:setPedAppearance(cache.ped, originalAppearance)
end

local function pedModelGender()
    local model = GetEntityModel(cache.ped)
    if model == joaat('mp_f_freemode_01') then return 'female' end
    if model == joaat('mp_m_freemode_01') then return 'male' end
    return nil
end

local function setAdminPreviewGender(gender)
    if not illeniumReady() then return false, 'illenium-appearance chưa chạy.' end
    gender = gender == 'female' and 'female' or 'male'
    if pedModelGender() == gender then
        adminPreviewGender = gender
        return true
    end

    local model = gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    exports['illenium-appearance']:setPlayerModel(model)
    adminPreviewGender = gender
    return true
end

local function applyComponent(ped, componentId, drawable, texture)
    if not illeniumReady() then return end
    componentId = tonumber(componentId)
    drawable = tonumber(drawable)
    texture = tonumber(texture) or 0
    if not componentId or drawable == nil then return end
    exports['illenium-appearance']:setPedComponent(ped, {
        component_id = componentId,
        drawable = drawable,
        texture = texture,
    })
end

local function applyProp(ped, propId, drawable, texture)
    if not illeniumReady() then return end
    propId = tonumber(propId)
    drawable = tonumber(drawable)
    texture = tonumber(texture) or 0
    if propId == nil or drawable == nil then return end
    exports['illenium-appearance']:setPedProp(ped, {
        prop_id = propId,
        drawable = drawable,
        texture = texture,
    })
end

local function applyPreviewItem(item)
    if type(item) ~= 'table' then return end
    local ped = cache.ped
    restoreOriginalAppearance()

    local category = item.category
    local propId = PROP_SLOT_BY_CATEGORY[category]
    local drawable = tonumber(item.drawable)
    local texture = tonumber(item.texture) or 0

    if propId ~= nil and drawable ~= nil then
        applyProp(ped, propId, drawable, texture)
        return
    end

    local wearId = tonumber(item.wearComponentId) or WEAR_COMPONENT_BY_CATEGORY[category]
    if wearId and drawable ~= nil then
        applyComponent(ped, wearId, drawable, texture)
    end

    local extras = item.extraComponents
    if type(extras) == 'table' then
        for i = 1, #extras do
            local row = extras[i]
            if type(row) == 'table' then
                applyComponent(ped, row.id or row.component_id, row.drawable, row.texture)
            end
        end
    end
end

local function buildImageKey(gender, category, drawable, texture)
    local prefix = gender == 'female' and 'f_' or 'm_'
    return ('%s%s_%d_%d'):format(prefix, category, drawable, texture or 0)
end

local function readPedPrimary(category, gender)
    local ped = cache.ped
    local propId = PROP_SLOT_BY_CATEGORY[category]
    if propId ~= nil then
        local drawable = GetPedPropIndex(ped, propId)
        local texture = GetPedPropTextureIndex(ped, propId)
        if drawable == -1 then
            return nil, 'Ped chưa đeo prop cho loại này.'
        end
        return {
            drawable = drawable,
            texture = texture,
            imageKey = buildImageKey(gender, category, drawable, texture),
            wearComponentId = propId,
        }
    end

    local wearId = WEAR_COMPONENT_BY_CATEGORY[category]
    if not wearId then return nil, 'Loại không hợp lệ.' end

    local drawable = GetPedDrawableVariation(ped, wearId)
    local texture = GetPedTextureVariation(ped, wearId)
    return {
        drawable = drawable,
        texture = texture,
        imageKey = buildImageKey(gender, category, drawable, texture),
        wearComponentId = wearId,
    }
end

local function readPedComponents(componentIds)
    local ped = cache.ped
    local out = {}
    if type(componentIds) ~= 'table' then return out end
    for i = 1, #componentIds do
        local compId = tonumber(componentIds[i])
        if compId then
            out[tostring(compId)] = {
                id = compId,
                drawable = GetPedDrawableVariation(ped, compId),
                texture = GetPedTextureVariation(ped, compId),
            }
        end
    end
    return out
end

local function captureComponentsByIds(componentIds)
    local ped = cache.ped
    local extras = {}
    if type(componentIds) ~= 'table' then return extras end
    for i = 1, #componentIds do
        local compId = tonumber(componentIds[i])
        if compId then
            extras[#extras + 1] = {
                slot = SLOT_NAME_BY_ID[compId] or ('comp' .. compId),
                id = compId,
                drawable = GetPedDrawableVariation(ped, compId),
                texture = GetPedTextureVariation(ped, compId),
                palette = GetPedPaletteVariation(ped, compId),
            }
        end
    end
    return extras
end

local function getIlleniumCatalogConfig()
    return {
        ped = false,
        headBlend = false,
        faceFeatures = false,
        headOverlays = false,
        components = true,
        props = true,
        tattoos = false,
        enableExit = true,
        hasTracker = false,
        hgrpCatalog = true,
        componentConfig = {
            masks = true,
            upperBody = true,
            lowerBody = true,
            bags = true,
            shoes = true,
            scarfAndChains = true,
            bodyArmor = true,
            shirts = true,
            decals = true,
            jackets = true,
        },
        propConfig = {
            hats = true,
            glasses = true,
            ear = false,
            watches = false,
            bracelets = false,
        },
    }
end

local function closeCatalogAdmin()
    catalogOpen = false
    restoreOriginalAppearance()
    originalAppearance = nil
    adminPreviewGender = nil
end

local function openConfigAdminUi()
    local allowed = lib.callback.await('hgrp_clothingshop:server:isAdmin', false)
    if not allowed then
        exports.qbx_core:Notify('Bạn không có quyền cấu hình quần áo.', 'error')
        return
    end
    if catalogOpen then return end
    if not illeniumReady() then
        exports.qbx_core:Notify('illenium-appearance chưa chạy.', 'error')
        return
    end

    catalogOpen = true
    saveOriginalAppearance()
    adminPreviewGender = pedModelGender() or 'male'

    exports['illenium-appearance']:startPlayerCustomization(function(_appearance)
        closeCatalogAdmin()
    end, getIlleniumCatalogConfig())
end

RegisterNetEvent('hgrp_clothingshop:client:openConfigAdmin', function()
    openConfigAdminUi()
end)

local function ensureCatalogOpen(cb)
    if not catalogOpen then
        cb({ ok = false, msg = 'Catalog chưa mở.' })
        return false
    end
    return true
end

RegisterNUICallback('hgrpCatalogMeta', function(_, cb)
    if not ensureCatalogOpen(cb) then return end
    local ok, data = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:configMeta', false)
    end)
    if ok and type(data) == 'table' then
        data.playerGender = pedModelGender() or 'male'
    end
    cb((ok and data) or { ok = false })
end)

RegisterNUICallback('hgrpCatalogList', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:configList', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi tải danh sách.' })
end)

RegisterNUICallback('hgrpCatalogGet', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:configGet', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi tải profile.' })
end)

RegisterNUICallback('hgrpCatalogSetGender', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    data = type(data) == 'table' and data or {}
    local gender = data.gender == 'female' and 'female' or 'male'
    local ok, err = setAdminPreviewGender(gender)
    if not ok then
        cb({ ok = false, msg = err or 'Không đổi được model.' })
        return
    end
    cb({ ok = true, gender = adminPreviewGender })
end)

RegisterNUICallback('hgrpCatalogReadPed', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    data = type(data) == 'table' and data or {}
    local category = data.category
    local gender = data.gender == 'female' and 'female' or 'male'

    local primary, err = readPedPrimary(category, gender)
    if not primary then
        cb({ ok = false, msg = err or 'Không đọc được ped.' })
        return
    end

    cb({
        ok = true,
        primary = primary,
        components = readPedComponents(data.componentIds),
    })
end)

RegisterNUICallback('hgrpCatalogSave', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    if type(data) ~= 'table' then
        cb({ ok = false, msg = 'Dữ liệu không hợp lệ.' })
        return
    end

    local category = data.category
    local gender = data.gender == 'female' and 'female' or 'male'
    local primary, err = readPedPrimary(category, gender)
    if not primary then
        cb({ ok = false, msg = err or 'Không đọc được component chính từ ped.' })
        return
    end

    local displayType = nil
    if category == 'hands' then
        displayType = 'jacket'
    elseif category == 'undershirt' and data.overrideEnabled == true then
        displayType = type(data.overrideSlot) == 'string' and data.overrideSlot or nil
        if not displayType or displayType == 'undershirt' then
            cb({ ok = false, msg = 'Chọn ô inventory override.' })
            return
        end
    end

    local componentIds = type(data.componentIds) == 'table' and data.componentIds or {}
    if category == 'undershirt' and displayType == 'pants' then
        local hasLegs = false
        for i = 1, #componentIds do
            if tonumber(componentIds[i]) == 4 then
                hasLegs = true
                break
            end
        end
        if not hasLegs then
            componentIds[#componentIds + 1] = 4
        end
    end

    if category == 'armor' then
        local level = tonumber(data.armorLevel)
        if not level or level < 1 then
            cb({ ok = false, msg = 'Chọn cấp giáp.' })
            return
        end
    end

    local payload = {
        id = data.id,
        gender = gender,
        category = category,
        drawable = data.saveBothGenders and nil or primary.drawable,
        texture = data.saveBothGenders and nil or primary.texture,
        imageKey = data.saveBothGenders and nil or primary.imageKey,
        label = type(data.label) == 'string' and data.label:gsub('^%s+', ''):gsub('%s+$', '') or nil,
        rarity = data.rarity or 'common',
        enabled = data.enabled ~= false,
        hideHair = category == 'mask' and data.hideHair == true,
        hideNametag = category == 'mask' and data.hideNametag == true,
        armorLevel = category == 'armor' and tonumber(data.armorLevel) or nil,
        displayType = displayType,
        wearComponentId = primary.wearComponentId,
        extraComponents = captureComponentsByIds(componentIds),
        applyAllTextures = data.applyAllTextures == true,
        saveBothGenders = data.saveBothGenders == true,
        saveAsUnisex = data.saveBothGenders == true,
        genderSnapshots = type(data.genderSnapshots) == 'table' and data.genderSnapshots or nil,
    }

    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:configUpsert', false, payload)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi lưu.' })
end)

RegisterNUICallback('hgrpCatalogDelete', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:configDelete', false, data)
    end)
    cb((ok and res) or { ok = false })
end)

RegisterNUICallback('hgrpCatalogPreview', function(data, cb)
    if not ensureCatalogOpen(cb) then return end
    if type(data) == 'table' and data.item then
        applyPreviewItem(data.item)
    end
    cb({ ok = true })
end)

RegisterNUICallback('hgrpCatalogPreviewReset', function(_, cb)
    if catalogOpen then restoreOriginalAppearance() end
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    catalogOpen = false
    restoreOriginalAppearance()
    originalAppearance = nil
    adminPreviewGender = nil
end)

exports('OpenConfigAdminMenu', openConfigAdminUi)
