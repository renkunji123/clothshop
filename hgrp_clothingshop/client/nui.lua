local cfg = require 'config.shared'

local isOpen = false
local originalAppearance = nil
local selectedItem = nil
local storeIndex = nil
local cachedItems = nil
local cart = {}

local cam = nil
local camThread = nil
local camSettings = nil

local categoryById = {}
for i = 1, #(cfg.categories or {}) do
  local c = cfg.categories[i]
  categoryById[c.id] = c
end

local function ensureCamOff()
  if cam and DoesCamExist(cam) then
    SetCamActive(cam, false)
    RenderScriptCams(false, true, 200, true, true)
    DestroyCam(cam, false)
  end
  cam = nil
  if IsCamRendering() then
    RenderScriptCams(false, false, 0, true, true)
  end
end

local FOCUS_BONES = {
  head = 0x796e,   -- SKEL_Head
  chest = 0x60f2,  -- SKEL_Spine3
  pelvis = 0x2e28, -- SKEL_Pelvis
}

local function getFocusPoint(ped, focus)
  if focus == 'feet' then
    local l = GetPedBoneCoords(ped, 0x3779, 0.0, 0.0, 0.0) -- SKEL_L_Foot
    local r = GetPedBoneCoords(ped, 0xCC4D, 0.0, 0.0, 0.0) -- SKEL_R_Foot
    return vector3((l.x + r.x) * 0.5, (l.y + r.y) * 0.5, (l.z + r.z) * 0.5)
  end
  local bone = FOCUS_BONES[focus] or FOCUS_BONES.head
  return GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
end

local function resolveCamera(tabId)
  local base = cfg.camera or {}
  local cat = tabId and categoryById[tabId]
  local c = (cat and cat.camera) or {}
  return {
    focus = c.focus or base.focus or 'chest',
    dist = c.dist or base.dist or 1.55,
    height = c.height or base.height or 0.12,
    lookZ = c.lookZ or base.lookZ or 0.0,
    fov = c.fov or base.fov or 35.0,
    orbitDeg = c.orbitDeg or base.orbitDeg or 35.0,
  }
end

local function startCam(settings)
  camSettings = settings or resolveCamera(nil)
  if camThread then return end
  camThread = CreateThread(function()
    while camThread do
      if not isOpen then
        camThread = nil
        break
      end
      local ped = cache.ped
      local heading = GetEntityHeading(ped) or 0.0
      local s = camSettings or resolveCamera(nil)
      local focus = getFocusPoint(ped, s.focus or 'chest')
      local orbit = s.orbitDeg or 35.0
      local dist = s.dist or 1.55
      local height = s.height or 0.12
      local lookZ = s.lookZ or 0.0
      local fov = s.fov or 35.0

      local rad = math.rad(heading + orbit)
      local x = focus.x + math.sin(rad) * dist
      local y = focus.y + math.cos(rad) * dist
      local z = focus.z + height

      if not cam or not DoesCamExist(cam) then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
      end
      SetCamCoord(cam, x, y, z)
      PointCamAtCoord(cam, focus.x, focus.y, focus.z + lookZ)
      SetCamFov(cam, fov)
      RenderScriptCams(true, false, 0, true, true)
      Wait(0)
    end
  end)
end

local function getGender()
  local model = GetEntityModel(cache.ped)
  if model == joaat('mp_f_freemode_01') then return 'female' end
  return 'male'
end

local function shopConfig()
  if not storeIndex then return nil end
  return ShopRegistry.getByStoreIndex(storeIndex)
end

local function allowedCategories()
  local shop = shopConfig()
  if shop and type(shop.categories) == 'table' and #shop.categories > 0 then
    local set = {}
    for i = 1, #shop.categories do
      set[shop.categories[i]] = true
    end
    return set
  end

  if type(cfg.sellCategories) == 'table' and #cfg.sellCategories > 0 then
    local set = {}
    for i = 1, #cfg.sellCategories do
      set[cfg.sellCategories[i]] = true
    end
    return set
  end

  if cfg.admin and cfg.admin.dbOverridesConfig and type(cfg.adminCategories) == 'table' then
    local set = {}
    for i = 1, #cfg.adminCategories do
      set[cfg.adminCategories[i].id] = true
    end
    return set
  end

  return nil
end

local function normalizeImageBase(base)
  if type(base) ~= 'string' or base == '' then
    return 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/'
  end
  if base:sub(-1) ~= '/' then
    return base .. '/'
  end
  return base
end

local function resolveItemImage(imageKey, metaImage)
  local base = normalizeImageBase(cfg.imageBase)
  local file = metaImage
  if type(file) ~= 'string' or file == '' then
    file = imageKey .. '.png'
  end
  if not file:match('%.png$') and not file:match('%.jpg$') and not file:match('%.webp$') then
    file = file .. '.png'
  end
  if file:find('^[%w]+://') then
    return file
  end
  return base .. file
end

local WEAR_COMPONENT_BY_CATEGORY = {
  face = 0, mask = 1, hands = 3, jacket = 11, undershirt = 8, pants = 4, shoes = 6, bag = 5, armor = 9, chains = 7,
}

local PROP_SLOT_BY_CATEGORY = {
  hat = 0, glasses = 1,
}

local function applyPreview(item)
  if not item then return end
  local ped = cache.ped

  local wearCat = item.wearCategory or item.itemCategory or item.tab
  local propId = PROP_SLOT_BY_CATEGORY[wearCat] or PROP_SLOT_BY_CATEGORY[item.tab]
  if propId ~= nil and item.drawable ~= nil then
    exports['illenium-appearance']:setPedProp(ped, {
      prop_id = propId,
      drawable = item.drawable,
      texture = item.texture or 0,
    })
    return
  end

  local wearId = tonumber(item.wearComponentId) or tonumber(item.slot)
  if not wearId then
    wearId = WEAR_COMPONENT_BY_CATEGORY[wearCat] or WEAR_COMPONENT_BY_CATEGORY[item.tab]
  end
  if wearId and item.drawable ~= nil then
    exports['illenium-appearance']:setPedComponent(ped, {
      component_id = wearId,
      drawable = item.drawable,
      texture = item.texture or 0,
    })
  end

  local extras = item.extraComponents
  if type(extras) == 'table' then
    for i = 1, #extras do
      local row = extras[i]
      if type(row) == 'table' then
        local compId = tonumber(row.id or row.component_id)
        if compId and row.drawable ~= nil then
          exports['illenium-appearance']:setPedComponent(ped, {
            component_id = compId,
            drawable = tonumber(row.drawable),
            texture = tonumber(row.texture) or 0,
          })
        end
      end
    end
  end
end

local function findCachedItem(itemId)
  for i = 1, #(cachedItems or {}) do
    if cachedItems[i].id == itemId then
      return cachedItems[i]
    end
  end
  return nil
end

local function restoreOriginal()
  if not originalAppearance then return end
  exports['illenium-appearance']:setPedAppearance(cache.ped, originalAppearance)
end

local function applyCartPreview()
  restoreOriginal()
  for _, item in pairs(cart) do
    applyPreview(item)
  end
end

local function clearCart()
  cart = {}
end

local function visibleTabs(serverTabs)
  if type(serverTabs) == 'table' and #serverTabs > 0 then
    return serverTabs
  end

  local allow = allowedCategories()
  local tabs = {}
  local adminIds = {}
  for i = 1, #(cfg.adminCategories or {}) do
    adminIds[cfg.adminCategories[i].id] = cfg.adminCategories[i].label
  end

  local source = cfg.admin and cfg.admin.dbOverridesConfig and cfg.adminCategories or cfg.categories
  for i = 1, #(source or {}) do
    local c = source[i]
    local id = c.id
    if allow and not allow[id] then goto continue end
    tabs[#tabs + 1] = { id = id, label = c.label or adminIds[id] or id }
    ::continue::
  end
  return tabs
end

local function close()
  if not isOpen then return end
  isOpen = false
  storeIndex = nil
  cachedItems = nil
  clearCart()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  ensureCamOff()
  camThread = nil
  selectedItem = nil
end

RegisterNUICallback('close', function(_, cb)
  restoreOriginal()
  close()
  cb('ok')
end)

RegisterNUICallback('cancel', function(_, cb)
  restoreOriginal()
  close()
  cb('ok')
end)

RegisterNUICallback('preview', function(data, cb)
  local itemId = data and tonumber(data.id) or nil
  if not itemId or not isOpen then cb('ok'); return end
  local item = findCachedItem(itemId)
  if not item then cb('ok'); return end

  selectedItem = item
  cart[item.tab] = item
  camSettings = resolveCamera(item.wearCategory or item.tab)
  applyCartPreview()
  cb('ok')
end)

RegisterNUICallback('removeCart', function(data, cb)
  if not isOpen then cb('ok'); return end
  local tab = data and data.tab
  if type(tab) == 'string' and tab ~= '' then
    cart[tab] = nil
    applyCartPreview()
  end
  cb('ok')
end)

RegisterNUICallback('setTab', function(data, cb)
  if not isOpen then cb('ok'); return end
  local tabId = data and data.id
  if tabId then
    camSettings = resolveCamera(tabId)
  end
  cb('ok')
end)

RegisterNUICallback('rotate', function(data, cb)
  if not isOpen then cb('ok'); return end
  local dir = data and tonumber(data.dir) or 0
  if dir == 0 then cb('ok'); return end
  local ped = cache.ped
  local h = GetEntityHeading(ped) or 0.0
  SetEntityHeading(ped, h + (dir > 0 and -12.0 or 12.0))
  cb('ok')
end)

RegisterNUICallback('buyCart', function(data, cb)
  if not isOpen then cb('ok'); return end

  local ids = data and data.ids
  if type(ids) ~= 'table' or #ids == 0 then
    exports.qbx_core:Notify('Giỏ hàng trống.', 'error')
    cb('ok')
    return
  end

  local lines = {}
  local seenTabs = {}
  for i = 1, #ids do
    local item = findCachedItem(tonumber(ids[i]))
    if item and item.tab and not seenTabs[item.tab] then
      seenTabs[item.tab] = true
      if tonumber(item.drawable) ~= nil and tonumber(item.drawable) >= 0 then
        lines[#lines + 1] = {
          tab = item.tab,
          drawable = item.drawable,
          texture = item.texture,
          price = item.price,
          imageKey = item.imageKey,
        }
      end
    end
  end

  if #lines == 0 then
    exports.qbx_core:Notify('Giỏ hàng không hợp lệ.', 'error')
    cb('ok')
    return
  end

  local res = lib.callback.await('hgrp_clothingshop:server:buyCart', false, {
    items = lines,
    gender = getGender(),
    storeIndex = storeIndex,
  })

  if not res or res.ok ~= true then
    local reason = res and res.reason
    if reason == 'inventory_full' then
      exports.qbx_core:Notify('Túi đầy, không nhận thêm đồ.', 'error')
    elseif reason == 'not_found' then
      exports.qbx_core:Notify('Có món chưa có trong hệ thống item.', 'error')
    elseif reason == 'empty' then
      exports.qbx_core:Notify('Giỏ hàng trống.', 'error')
    elseif reason == 'give_failed' then
      exports.qbx_core:Notify('Không thể thêm đồ vào túi.', 'error')
    elseif res and res.currency == 'v_medal' then
      exports.qbx_core:Notify('Không đủ V Medal.', 'error')
    else
      exports.qbx_core:Notify('Không đủ tiền.', 'error')
    end
    cb('ok')
    return
  end

  restoreOriginal()
  local count = tonumber(res.count) or #lines
  if res.partial then
    exports.qbx_core:Notify(('Đã mua %d/%d món — kéo vào ô trang phục để mặc.'):format(count, #lines), 'success')
  else
    exports.qbx_core:Notify(('Đã mua %d món — kéo vào ô trang phục để mặc.'):format(count), 'success')
  end
  close()
  cb('ok')
end)

local function openShop(index)
  if isOpen then
    close()
    Wait(80)
  end

  local shop = ShopRegistry.getByStoreIndex(index)
  if not shop then
    exports.qbx_core:Notify('Cửa hàng này không bán đồ — chỉ có 2 shop quần áo trên map.', 'error')
    return
  end

  storeIndex = index
  isOpen = true
  selectedItem = nil
  clearCart()
  originalAppearance = exports['illenium-appearance']:getPedAppearance(cache.ped)

  local gender = getGender()

  local catalog = lib.callback.await('hgrp_clothingshop:server:getShopCatalog', false, {
    gender = gender,
    storeIndex = storeIndex,
  })

  cachedItems = (catalog and catalog.items) or {}
  if not catalog or catalog.ok == false then
    exports.qbx_core:Notify('Không tải được danh sách shop.', 'error')
    isOpen = false
    storeIndex = nil
    return
  end
  local tabs = visibleTabs(catalog and catalog.tabs)
  local title = (catalog and catalog.title) or shop.title or cfg.title or 'Cửa hàng quần áo'
  local imageBase = (catalog and catalog.imageBase) or normalizeImageBase(cfg.imageBase)
  local currency = (catalog and catalog.currency) or (shop and shop.currency) or 'cash'
  local activeTab = (tabs[1] and tabs[1].id) or 'jacket'

  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    title = title,
    accent = cfg.accent,
    gender = gender,
    imageBase = imageBase,
    currency = currency,
    tabs = tabs,
    items = cachedItems,
    rarities = (catalog and catalog.rarities) or cfg.rarities or {},
    activeTab = activeTab,
  })

  camSettings = resolveCamera(activeTab)
  startCam(camSettings)
end

RegisterNetEvent('hgrp_clothingshop:client:open', function(index)
  openShop(index)
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= cache.resource then return end
  if isOpen then
    restoreOriginal()
    close()
  end
end)
