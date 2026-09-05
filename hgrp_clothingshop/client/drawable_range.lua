local DrawableUtils = lib.load('shared.drawable_utils')

local FREEMODE = {
    male = `mp_m_freemode_01`,
    female = `mp_f_freemode_01`,
}

local previewPed

local function deletePreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

local function getPreviewPed(gender)
    local model = FREEMODE[gender == 'female' and 'female' or 'male'] or FREEMODE.male

    -- Trong Illenium admin, ped người chơi đã stream addon cloth — đếm drawable thật (200+ balo).
    local playerPed = cache and cache.ped or PlayerPedId()
    if playerPed and playerPed ~= 0 and DoesEntityExist(playerPed) and GetEntityModel(playerPed) == model then
        return playerPed
    end

    if not lib.requestModel(model, 5000) then
        return nil
    end

    deletePreviewPed()
    previewPed = CreatePed(0, model, 0.0, 0.0, 0.0, 0.0, false, false)
    SetEntityVisible(previewPed, false, false)
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetModelAsNoLongerNeeded(model)
    return previewPed
end

---@return number maxDrawableCount
local function getComponentDrawableMax(category, gender)
    local ped = getPreviewPed(gender)
    if not ped then return 0 end

    if DrawableUtils.isPropCategory(category) then
        local propId = DrawableUtils.wearComponentId(category)
        return tonumber(GetNumberOfPedPropDrawableVariations(ped, propId)) or 0
    end

    local compId = DrawableUtils.wearComponentId(category)
    if not compId then return 0 end
    return tonumber(GetNumberOfPedDrawableVariations(ped, compId)) or 0
end

lib.callback.register('hgrp_clothingshop:client:getComponentDrawableMax', function(category, gender)
    gender = gender == 'female' and 'female' or 'male'
    category = type(category) == 'string' and category or 'bag'
    return getComponentDrawableMax(category, gender)
end)

---@return number maxTextureCount for drawable
local function getComponentTextureMax(category, gender, drawable)
    drawable = tonumber(drawable)
    if drawable == nil or drawable < 0 then return 0 end

    local ped = getPreviewPed(gender)
    if not ped then return 0 end

    if DrawableUtils.isPropCategory(category) then
        local propId = DrawableUtils.wearComponentId(category)
        return tonumber(GetNumberOfPedPropTextureVariations(ped, propId, drawable)) or 0
    end

    local compId = DrawableUtils.wearComponentId(category)
    if not compId then return 0 end
    return tonumber(GetNumberOfPedTextureVariations(ped, compId, drawable)) or 0
end

lib.callback.register('hgrp_clothingshop:client:getComponentTextureMax', function(category, gender, drawable)
    gender = gender == 'female' and 'female' or 'male'
    category = type(category) == 'string' and category or 'bag'
    return getComponentTextureMax(category, gender, drawable)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deletePreviewPed()
end)
