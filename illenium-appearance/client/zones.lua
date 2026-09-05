if Config.UseTarget then return end

local currentZone = nil

local Zones = {
    Store = {},
    ClothingRoom = {},
    PlayerOutfitRoom = {}
}

local function RemoveZones()
    for i = 1, #Zones.Store do
        if Zones.Store[i]["remove"] then
            Zones.Store[i]:remove()
        end
    end
    for i = 1, #Zones.ClothingRoom do
        Zones.ClothingRoom[i]:remove()
    end
    for i = 1, #Zones.PlayerOutfitRoom do
        Zones.PlayerOutfitRoom[i]:remove()
    end
end

local function lookupZoneIndexFromID(zones, id)
    for i = 1, #zones do
        if zones[i].id == id then
            return i
        end
    end
end

-- HGRP: fallback drawText3D (tránh phụ thuộc global `qbx`)
local function drawText3dFallback(coords, text)
    local x, y, z = coords.x, coords.y, coords.z
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local camX, camY, camZ = table.unpack(GetFinalRenderedCamCoord())
    local dist = #(vector3(camX, camY, camZ) - vector3(x, y, z))
    local scale = math.max(0.24, math.min(0.45, (1.0 / dist) * 1.6))
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function drawText3d(coords, text)
    if qbx and qbx.drawText3d then
        qbx.drawText3d({ coords = coords, text = text })
        return
    end
    drawText3dFallback(coords, text)
end

local function onStoreEnter(data)
    local index = lookupZoneIndexFromID(Zones.Store, data.id)
    local store = Config.Stores[index]

    -- Thêm dòng kiểm tra an toàn này để ngăn lỗi nil value
    if not store then return end

    local jobName = (store.job and client.job.name) or (store.gang and client.gang.name)
    if jobName == (store.job or store.gang) then
        currentZone = {
            name = store.type,
            index = index
        }
        local prefix = Config.UseRadialMenu and "" or "[E] "
        if currentZone.name == "clothing" then
            lib.hideTextUI()
        elseif currentZone.name == "barber" then
            lib.hideTextUI()
        elseif currentZone.name == "tattoo" then
            lib.showTextUI(prefix .. string.format(_L("textUI.tattoo"), Config.TattooCost), Config.TextUIOptions)
        elseif currentZone.name == "surgeon" then
            lib.hideTextUI()
        end
        Radial.AddOption(currentZone)
    end
end

local function matchesClothingRoomJob(clothingRoom)
    local required = clothingRoom.job or clothingRoom.gang
    if clothingRoom.job == 'police' then
        return client.job and client.job.type == 'leo'
    end
    if clothingRoom.job == 'ambulance' then
        return client.job and (client.job.type == 'ems' or client.job.name == 'ambulance')
    end
    if clothingRoom.gang then
        return client.gang and client.gang.name == required
    end
    return client.job and client.job.name == required
end

local function onClothingRoomEnter(data)
    local index = lookupZoneIndexFromID(Zones.ClothingRoom, data.id)
    local clothingRoom = Config.ClothingRooms[index]

    if matchesClothingRoomJob(clothingRoom) then
        if CheckDuty() or clothingRoom.gang then
            currentZone = {
                name = "clothingRoom",
                index = index
            }
            Radial.AddOption(currentZone)
        end
    end
end

local function onPlayerOutfitRoomEnter(data)
    local index = lookupZoneIndexFromID(Zones.PlayerOutfitRoom, data.id)
    local playerOutfitRoom = Config.PlayerOutfitRooms[index]

    local isAllowed = IsPlayerAllowedForOutfitRoom(playerOutfitRoom)
    if isAllowed then
        currentZone = {
            name = "playerOutfitRoom",
            index = index
        }
        local prefix = Config.UseRadialMenu and "" or "[E] "
        lib.showTextUI(prefix .. _L("textUI.playerOutfitRoom"), Config.TextUIOptions)
        Radial.AddOption(currentZone)
    end
end

local function onZoneExit()
    currentZone = nil
    Radial.RemoveOption()
    -- HGRP: barber dùng prompt 3D, không cần hide
    lib.hideTextUI()
end

local function SetupZone(store, onEnter, onExit)
    if Config.RCoreTattoosCompatibility and store.type == "tattoo" then
        return {}
    end

    if Config.UseRadialMenu or store.usePoly then
        return lib.zones.poly({
            points = store.points,
            debug = Config.Debug,
            onEnter = onEnter,
            onExit = onExit
        })
    end

    return lib.zones.box({
        coords = store.coords,
        size = store.size,
        rotation = store.rotation,
        debug = Config.Debug,
        onEnter = onEnter,
        onExit = onExit
    })
end

local function clothingRetailEnabled(store)
    if not store or store.type ~= 'clothing' then return true end
    return type(store.hgrpShopKey) == 'string' and store.hgrpShopKey ~= ''
end

local function SetupStoreZones()
    for k, v in ipairs(Config.Stores) do
        if clothingRetailEnabled(v) then
            Zones.Store[k] = SetupZone(v, onStoreEnter, onZoneExit)
        end
    end
end

local function SetupClothingRoomZones()
    for _, v in pairs(Config.ClothingRooms) do
        Zones.ClothingRoom[#Zones.ClothingRoom + 1] = SetupZone(v, onClothingRoomEnter, onZoneExit)
    end
end

local function SetupPlayerOutfitRoomZones()
    for _, v in pairs(Config.PlayerOutfitRooms) do
        Zones.PlayerOutfitRoom[#Zones.PlayerOutfitRoom + 1] = SetupZone(v, onPlayerOutfitRoomEnter, onZoneExit)
    end
end

local function SetupZones()
    SetupStoreZones()
    SetupClothingRoomZones()
    SetupPlayerOutfitRoomZones()
end

local function ZonesLoop()
    Wait(1000)
    while true do
        local sleep = 1000
        if currentZone then
            sleep = 5
            if currentZone.name == "barber" then
                local store = Config.Stores[currentZone.index]
                local c = store and store.coords
                if c then
                    local label = store.blipName or 'Salon'
                    drawText3d(vector3(c.x, c.y, c.z + 0.75), ('[E] %s'):format(label))
                end
            elseif currentZone.name == "clothing" then
                local store = Config.Stores[currentZone.index]
                local c = store and store.coords
                if c then
                    local label = store.blipName or 'Quan ao'
                    drawText3d(vector3(c.x, c.y, c.z + 0.75), ('[E] %s'):format(label))
                end
            elseif currentZone.name == "clothingRoom" then
                local clothingRoom = Config.ClothingRooms[currentZone.index]
                local c = clothingRoom and clothingRoom.coords
                if c then
                    drawText3d(vector3(c.x, c.y, c.z + 0.75), '[E] Trang phuc nghe')
                end
            elseif currentZone.name == "surgeon" then
                local store = Config.Stores[currentZone.index]
                local c = store and store.coords
                if c then
                    local cost = Config.SurgeonCost or 500000
                    local s = tostring(math.floor(cost))
                    local priceLabel = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
                    if priceLabel:sub(1, 1) == '.' then priceLabel = priceLabel:sub(2) end
                    drawText3d(vector3(c.x, c.y, c.z + 0.75), ('[E] Phau thuat %s$'):format(priceLabel))
                end
            end
            if IsControlJustReleased(0, 38) then
                if currentZone.name == "clothingRoom" then
                    -- HGRP: mo shop illenium mien phi — addon clothpack hien dung drawable, khong dung preset ID sai
                    TriggerEvent("illenium-appearance:client:openClothingShop", true)
                elseif currentZone.name == "playerOutfitRoom" then
                    local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
                    OpenOutfitRoom(outfitRoom)
                elseif currentZone.name == "clothing" then
                    TriggerEvent('hgrp_clothingshop:client:open', currentZone.index)
                elseif currentZone.name == "barber" then
                    -- HGRP: UI salon tóc custom (giống shop xe) — truyền store index
                    TriggerEvent('hgrp_barbershop:client:open', currentZone.index)
                elseif currentZone.name == "tattoo" then
                    OpenTattooShop()
                elseif currentZone.name == "surgeon" then
                    OpenSurgeonShop()
                end
            end
        end
        Wait(sleep)
    end
end


CreateThread(function()
    SetupZones()
    if not Config.UseRadialMenu then
        ZonesLoop()
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        RemoveZones()
    end
end)

RegisterNetEvent("illenium-appearance:client:OpenClothingRoom", function()
    TriggerEvent("illenium-appearance:client:openClothingShop", true)
end)

RegisterNetEvent("illenium-appearance:client:OpenPlayerOutfitRoom", function()
    local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
    OpenOutfitRoom(outfitRoom)
end)
