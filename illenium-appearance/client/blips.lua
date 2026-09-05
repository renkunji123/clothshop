local Blips = {}
local client = client

local function ShowBlip(blipConfig, blip)
    if blip.job and blip.job ~= client.job.name then
        return false
    elseif blip.gang and blip.gang ~= client.gang.name then
        return false
    end

    if Config.RCoreTattoosCompatibility and blip.type == "tattoo" then
        return false
    end

    if blip.type == 'clothing' and (type(blip.hgrpShopKey) ~= 'string' or blip.hgrpShopKey == '') then
        return false
    end

    return (blipConfig.Show and blip.showBlip == nil) or blip.showBlip
end

local function CreateBlip(blipConfig, coords, nameOverride)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.Sprite)
    SetBlipColour(blip, blipConfig.Color)
    SetBlipScale(blip, blipConfig.Scale)
    SetBlipDisplay(blip, blipConfig.Display or 4)
    SetBlipAsShortRange(blip, true)
    exports.hgrp_vietnamese_font:SetBlipName(blip, nameOverride or blipConfig.Name)
    return blip
end

local function SetupBlips()
    for k, _ in pairs(Config.Stores) do
        local store = Config.Stores[k]
        local blipConfig = Config.Blips[store.type]
        if ShowBlip(blipConfig, store) then
            local blip = CreateBlip(blipConfig, store.coords, store.blipName)
            Blips[#Blips + 1] = blip
        end
    end
end

function ResetBlips()
    if Config.ShowNearestShopOnly then
        return
    end

    for i = 1, #Blips do
        RemoveBlip(Blips[i])
    end
    Blips = {}
    SetupBlips()
end

local function ShowNearestShopBlip()
    for k in pairs(Config.Blips) do
        Blips[k] = 0
    end
    while true do
        local coords = GetEntityCoords(cache.ped)
        for shopType, blipConfig in pairs(Config.Blips) do
            local closest = 1000000
            local closestCoords

            for _, shop in pairs(Config.Stores) do
                if shop.type == shopType and ShowBlip(blipConfig, shop) then
                    local dist = #(coords - vector3(shop.coords.xyz))
                    if dist < closest then
                        closest = dist
                        closestCoords = shop.coords
                    end
                end
            end
            if DoesBlipExist(Blips[shopType]) then
                RemoveBlip(Blips[shopType])
            end

            if closestCoords then
                Blips[shopType] = CreateBlip(blipConfig, closestCoords)
            end
        end
        Wait(Config.NearestShopBlipUpdateDelay)
    end
end

if Config.ShowNearestShopOnly then
    CreateThread(ShowNearestShopBlip)
end
