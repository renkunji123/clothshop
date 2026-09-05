function CheckDuty()
    return not Config.OnDutyOnlyClothingRooms or (Config.OnDutyOnlyClothingRooms and client.job.onduty)
end

function IsPlayerAllowedForOutfitRoom(outfitRoom)
    local isAllowed = false
    local count = #outfitRoom.citizenIDs
    for i = 1, count, 1 do
        if Framework.IsPlayerAllowed(outfitRoom.citizenIDs[i]) then
            isAllowed = true
            break
        end
    end
    return isAllowed or not outfitRoom.citizenIDs or count == 0
end

function GetPlayerJobOutfits(outfitJobKey)
    local outfits = {}
    local gender = Framework.GetGender()
    local isJob = outfitJobKey ~= nil
    local gradeLevel = isJob and Framework.GetJobGrade() or Framework.GetGangGrade()

    local configKey = outfitJobKey
    if not configKey then
        configKey = client.gang and client.gang.name or client.job.name
    end

    if client.job then
        if client.job.type == 'leo' and Config.Outfits['police'] and not Config.Outfits[configKey] then
            configKey = 'police'
        elseif (client.job.type == 'ems' or client.job.name == 'ambulance') and Config.Outfits['ambulance'] and not Config.Outfits[configKey] then
            configKey = 'ambulance'
        end
    end

    if Config.BossManagedOutfits then
        local mType = isJob and "Job" or "Gang"
        local result = lib.callback.await("illenium-appearance:server:getManagementOutfits", false, mType, gender)
        for i = 1, #result, 1 do
            outfits[#outfits + 1] = {
                type = mType,
                model = result[i].model,
                components = result[i].components,
                props = result[i].props,
                disableSave = true,
                name = result[i].name
            }
        end
    elseif Config.Outfits[configKey] and Config.Outfits[configKey][gender] then
        for i = 1, #Config.Outfits[configKey][gender], 1 do
            for _, v in pairs(Config.Outfits[configKey][gender][i].grades) do
                if tonumber(v) == tonumber(gradeLevel) then
                    outfits[#outfits + 1] = Config.Outfits[configKey][gender][i]
                    outfits[#outfits].gender = gender
                    outfits[#outfits].jobName = configKey
                end
            end
        end
    end

    return outfits
end

function OpenOutfitRoom(outfitRoom)
    local isAllowed = IsPlayerAllowedForOutfitRoom(outfitRoom)
    if isAllowed then
        OpenMenu(nil, "outfit")
    end
end

function OpenBarberShop()
    local config = GetDefaultConfig()
    config.headOverlays = true
    OpenShop(config, false, "barber")
end

function OpenTattooShop()
    local config = GetDefaultConfig()
    config.tattoos = true
    OpenShop(config, false, "tattoo")
end

function OpenSurgeonShop()
    local cost = Config.SurgeonCost or 500000

    local function formatCash(amount)
        local s = tostring(math.floor(tonumber(amount) or 0))
        local formatted = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
        if formatted:sub(1, 1) == '.' then
            formatted = formatted:sub(2)
        end
        return formatted .. '$'
    end

    lib.callback("illenium-appearance:server:hasMoney", false, function(hasMoney)
        if not hasMoney then
            lib.notify({
                title = "Phẫu thuật thẩm mỹ",
                description = ("Giá %s/lần (cash). Bạn chưa đủ tiền — chỉ trừ khi bấm Lưu. Hãy thoát menu nếu không muốn tiếp tục."):format(formatCash(cost)),
                type = "error",
                position = Config.NotifyOptions.position,
                duration = 9000,
            })
        end

        local config = GetDefaultConfig()
        config.headBlend = true
        config.faceFeatures = true

        TriggerServerEvent("illenium-appearance:server:ChangeRoutingBucket")
        client.startPlayerCustomization(function(appearance)
            TriggerServerEvent("illenium-appearance:server:ResetRoutingBucket")
            Framework.CachePed()

            if not appearance then
                lib.notify({
                    title = _L("cancelled.title"),
                    description = _L("cancelled.description"),
                    type = "inform",
                    position = Config.NotifyOptions.position
                })
                return
            end

            local paid = lib.callback.await("illenium-appearance:server:tryChargeCustomer", false, "surgeon")
            if paid then
                TriggerServerEvent("illenium-appearance:server:saveAppearance", appearance)
            else
                lib.notify({
                    title = "Phẫu thuật thẩm mỹ",
                    description = ("Không đủ %s cash — thay đổi không được lưu."):format(formatCash(cost)),
                    type = "error",
                    position = Config.NotifyOptions.position,
                })
                lib.callback("illenium-appearance:server:getAppearance", false, function(saved)
                    if saved then
                        client.setPlayerAppearance(saved)
                    end
                end)
            end
        end, config)
    end, "surgeon")
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if Config.BossManagedOutfits then
            Management.RemoveItems()
        end
    end
end)
