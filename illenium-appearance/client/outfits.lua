local function typeof(var)
    local _type = type(var);
    if (_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if (_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end

--- Reset quần áo về mặc định (giữ mặt + tóc) trước khi mặc đồ nghề — tránh dính đồ dân.
local function resetJobOutfitBase(ped)
    local gender = Framework.GetGender()
    local initial = Config.InitialPlayerClothes and Config.InitialPlayerClothes[gender]
    if not initial then return end

    for i = 0, 11 do
        if i ~= 0 and i ~= 2 then
            SetPedComponentVariation(ped, i, 0, 0, 0)
        end
    end

    for i = 0, 7 do
        ClearPedProp(ped, i)
    end

    if initial.Components then
        for _, comp in ipairs(initial.Components) do
            local cid = comp.component_id
            if cid ~= 0 and cid ~= 2 then
                SetPedComponentVariation(ped, cid, comp.drawable, comp.texture, 0)
            end
        end
    end

    if initial.Props then
        for _, prop in ipairs(initial.Props) do
            if prop.drawable == -1 then
                ClearPedProp(ped, prop.prop_id)
            else
                SetPedPropIndex(ped, prop.prop_id, prop.drawable, prop.texture, true)
            end
        end
    end
end

--- Giống qb-clothing migrate: palette 2 rồi texture thật — giảm lỗi caro/missing trên addon.
local function applyComponentSlot(ped, slot, item, texture)
    if item == nil or item < 0 then return end
    SetPedComponentVariation(ped, slot, item, 0, 2)
    SetPedComponentVariation(ped, slot, item, texture or 0, 0)
end

function LoadJobOutfit(oData)
    local ped = cache.ped

    local data = oData.outfitData

    if typeof(data) ~= "table" then
        data = json.decode(data)
    end

    resetJobOutfitBase(ped)

    applyComponentSlot(ped, 4, data["pants"] and data["pants"].item, data["pants"] and data["pants"].texture)
    applyComponentSlot(ped, 3, data["arms"] and data["arms"].item, data["arms"] and data["arms"].texture)
    applyComponentSlot(ped, 8, data["t-shirt"] and data["t-shirt"].item, data["t-shirt"] and data["t-shirt"].texture)
    applyComponentSlot(ped, 9, data["vest"] and data["vest"].item, data["vest"] and data["vest"].texture)
    applyComponentSlot(ped, 11, data["torso2"] and data["torso2"].item, data["torso2"] and data["torso2"].texture)
    applyComponentSlot(ped, 6, data["shoes"] and data["shoes"].item, data["shoes"] and data["shoes"].texture)
    applyComponentSlot(ped, 10, data["decals"] and data["decals"].item, data["decals"] and data["decals"].texture)
    applyComponentSlot(ped, 1, data["mask"] and data["mask"].item, data["mask"] and data["mask"].texture)
    applyComponentSlot(ped, 5, data["bag"] and data["bag"].item, data["bag"] and data["bag"].texture)

    local tracker = Config.TrackerClothingOptions
    if data["accessory"] ~= nil and data["accessory"].item ~= nil and data["accessory"].item >= 0 then
        if Framework.HasTracker() then
            applyComponentSlot(ped, 7, tracker.drawable, tracker.texture)
        else
            applyComponentSlot(ped, 7, data["accessory"].item, data["accessory"].texture)
        end
    elseif Framework.HasTracker() then
        applyComponentSlot(ped, 7, tracker.drawable, tracker.texture)
    end

    if data["hat"] ~= nil then
        if data["hat"].item ~= nil and data["hat"].item >= 0 then
            SetPedPropIndex(ped, 0, data["hat"].item, data["hat"].texture or 0, true)
        else
            ClearPedProp(ped, 0)
        end
    end

    if data["glass"] ~= nil then
        if data["glass"].item ~= nil and data["glass"].item >= 0 then
            SetPedPropIndex(ped, 1, data["glass"].item, data["glass"].texture or 0, true)
        else
            ClearPedProp(ped, 1)
        end
    end

    if data["ear"] ~= nil then
        if data["ear"].item ~= nil and data["ear"].item >= 0 then
            SetPedPropIndex(ped, 2, data["ear"].item, data["ear"].texture or 0, true)
        else
            ClearPedProp(ped, 2)
        end
    end

    local length = 0
    for _ in pairs(data) do
        length = length + 1
    end

    if Config.PersistUniforms and length > 1 then
        TriggerServerEvent("illenium-appearance:server:syncUniform", {
            jobName = oData.jobName,
            gender = oData.gender,
            label = oData.name
        })
    end
end

--- In ID từng slot ra F8 — mặc đúng bộ đồ trong shop rồi gõ /dumpoutfit để lấy config.
RegisterCommand('dumpoutfit', function()
    local ped = cache.ped
    local lines = {
        '-- Copy vao Config.Outfits outfitData (dang mac tren ped)',
        ('["pants"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 4), GetPedTextureVariation(ped, 4)),
        ('["arms"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3)),
        ('["t-shirt"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 8), GetPedTextureVariation(ped, 8)),
        ('["vest"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 9), GetPedTextureVariation(ped, 9)),
        ('["torso2"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 11), GetPedTextureVariation(ped, 11)),
        ('["shoes"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 6), GetPedTextureVariation(ped, 6)),
        ('["mask"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 1), GetPedTextureVariation(ped, 1)),
        ('["bag"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 5), GetPedTextureVariation(ped, 5)),
        ('["accessory"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 7), GetPedTextureVariation(ped, 7)),
        ('["decals"] = {item = %d, texture = %d},'):format(
            GetPedDrawableVariation(ped, 10), GetPedTextureVariation(ped, 10)),
    }

    local hat = GetPedPropIndex(ped, 0)
    if hat == -1 then
        lines[#lines + 1] = '["hat"] = {item = -1, texture = 0},'
    else
        lines[#lines + 1] = ('["hat"] = {item = %d, texture = %d},'):format(hat, GetPedPropTextureIndex(ped, 0))
    end

    local glass = GetPedPropIndex(ped, 1)
    if glass == -1 then
        lines[#lines + 1] = '["glass"] = {item = -1, texture = 0},'
    else
        lines[#lines + 1] = ('["glass"] = {item = %d, texture = %d},'):format(glass, GetPedPropTextureIndex(ped, 1))
    end

    for i = 1, #lines do
        print(lines[i])
    end

    lib.notify({
        title = 'Dump outfit',
        description = 'Da in ID vao F8 console (dumpoutfit)',
        type = 'inform',
        position = Config.NotifyOptions and Config.NotifyOptions.position or 'top-right',
    })
end, false)

RegisterNetEvent("illenium-appearance:client:loadJobOutfit", LoadJobOutfit)

RegisterNetEvent("illenium-appearance:client:openOutfitMenu", function()
    OpenMenu(nil, "outfit")
end)

RegisterNetEvent("illenium-apearance:client:outfitsCommand", function(isJob)
    local outfits = GetPlayerJobOutfits(isJob)
    TriggerEvent("illenium-appearance:client:openJobOutfitsMenu", outfits)
end)
