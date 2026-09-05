local cfg = require 'config.shared'

local adminOpen = false

local function forceReleaseFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    CreateThread(function()
        for _ = 1, 20 do
            if adminOpen then return end
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            Wait(50)
        end
    end)
end

local function closeAdminUi()
    adminOpen = false
    forceReleaseFocus()
    SendNUIMessage({ action = 'closeAdmin' })
end

local function openAdminUi()
    local allowed = lib.callback.await('hgrp_clothingshop:server:isAdmin', false)
    if not allowed then
        exports.qbx_core:Notify('Bạn không có quyền cấu hình shop quần áo.', 'error')
        return
    end
    if adminOpen then return end
    adminOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'openAdmin' })
end

RegisterNetEvent('hgrp_clothingshop:client:openAdmin', function()
    openAdminUi()
end)

RegisterNUICallback('adminClose', function(_, cb)
    closeAdminUi()
    cb({ ok = true })
end)

RegisterNUICallback('adminMeta', function(_, cb)
    local ok, data = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminMeta', false)
    end)
    cb((ok and data) or { ok = false })
end)

RegisterNUICallback('adminList', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminList', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi tải danh sách.' })
end)

RegisterNUICallback('adminBrowse', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminBrowse', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi tải catalog.' })
end)

RegisterNUICallback('adminUpsert', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminUpsert', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi lưu.' })
end)

RegisterNUICallback('adminToggle', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminToggle', false, data)
    end)
    cb((ok and res) or { ok = false })
end)

RegisterNUICallback('adminDelete', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminDelete', false, data)
    end)
    cb((ok and res) or { ok = false })
end)

RegisterNUICallback('adminShopSettings', function(_, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminShopSettings', false)
    end)
    cb((ok and res) or { ok = false })
end)

RegisterNUICallback('adminSetShopCurrency', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('hgrp_clothingshop:server:adminSetShopCurrency', false, data)
    end)
    cb((ok and res) or { ok = false, msg = 'Lỗi lưu.' })
end)

CreateThread(function()
    while true do
        if adminOpen then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    adminOpen = false
    forceReleaseFocus()
end)

exports('OpenAdminMenu', openAdminUi)
exports('CloseAdminMenu', closeAdminUi)
