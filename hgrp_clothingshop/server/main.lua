local cfg = require 'config.shared'

local function normalizeImageBase(base)
  if type(base) ~= 'string' or base == '' then
    return 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/'
  end
  if base:sub(-1) ~= '/' then
    return base .. '/'
  end
  return base
end

local function shopEntry(storeIndex)
  return ShopRegistry.getByStoreIndex(storeIndex)
end

local function resolveCurrency(storeIndex)
  local shop = shopEntry(storeIndex)
  local fallback = (shop and shop.currency) or 'cash'
  if shop and shop.key then
    return RetailSettings.getCurrency(shop.key, fallback)
  end
  return fallback
end

local function pay(source, amount, reason, currency)
  return RetailSettings.pay(source, amount, reason or 'clothing', currency)
end

local function refund(source, amount, currency)
  RetailSettings.refund(source, amount, 'clothing-refund', currency)
end

local function buildClothingItemName(categoryId, gender, drawable, texture)
  return Catalog.buildItemName(categoryId, gender, drawable, texture)
end

local function shopKeyFromIndex(storeIndex)
    return ShopRegistry.getKeyFromStoreIndex(storeIndex) or 'clothing_normal'
end

local function captureStarted()
  return GetResourceState('hgrp_clothing_capture') == 'started'
end

local function resolveCatalogLine(gender, line, storeIndex)
  if type(line) ~= 'table' then return nil end

  gender = gender == 'female' and 'female' or 'male'
  local shopKey = shopKeyFromIndex(storeIndex)

  local imageKey = line.imageKey or line.image_key or line.item or line.name
  if type(imageKey) == 'string' and imageKey ~= '' then
    local resolved = Catalog.resolveConfigEntry({
      item = imageKey,
      price = line.price,
      label = line.label,
      rarity = line.rarity,
      tab = line.tab,
      drawable = line.drawable,
      texture = line.texture,
      hideHair = line.hideHair,
      hideNametag = line.hideNametag,
    }, gender, line.tab)
    if resolved then
      if cfg.admin and cfg.admin.dbOverridesConfig and Catalog.hasDbItems(gender, resolved.tab, shopKey) then
        local entry = Catalog.getEnabledEntry(gender, resolved.tab, resolved.drawable, resolved.texture, shopKey)
        if not entry then return nil end
        resolved.price = entry.price
        resolved.rarity = entry.rarity or resolved.rarity
        resolved.label = entry.label or resolved.label
        if type(entry.itemName) == 'string' and entry.itemName ~= '' then
          resolved.itemName = entry.itemName
          resolved.imageKey = entry.itemName
        end
        if type(entry.tab) == 'string' and entry.tab ~= '' then
          resolved.tab = entry.tab
        end
        resolved.hideNametag = entry.hideNametag
        resolved.hideHair = entry.hideHair
      end
      return resolved
    end
  end

  local tab = line.tab
  local drawable = tonumber(line.drawable)
  local texture = tonumber(line.texture) or 0

  if type(tab) ~= 'string' or tab == '' or drawable == nil or drawable < 0 then
    return nil
  end

  if not Catalog.isValidCategory(tab) then
    return nil
  end

  if GetResourceState('hgrp_clothing_capture') ~= 'started' then
    return nil
  end

  local itemName = buildClothingItemName(tab, gender, drawable, texture)
  if not itemName then return nil end

  local price = math.floor(tonumber(line.price) or 0)
  local rarity = line.rarity or 'common'
  local label = line.label
  local wearCategory = nil
  local wearComponentId = nil
  local extraComponents = nil

  if captureStarted() then
    local resolvedKey = exports['hgrp_clothing_capture']:resolveClothingImageKey(itemName)
    if type(resolvedKey) == 'string' and resolvedKey ~= '' then
      itemName = resolvedKey:gsub('%.png$', '')
    end
    local catalogItem = exports['hgrp_clothing_capture']:getClothingCatalogItem(itemName)
    if type(catalogItem) == 'table' then
      local fromCatalog = Catalog.resolveConfigEntry({ item = itemName, tab = tab, drawable = drawable, texture = texture, price = price, label = label, rarity = rarity }, gender, tab)
      if fromCatalog then
        tab = fromCatalog.tab
        drawable = fromCatalog.drawable
        texture = fromCatalog.texture
        itemName = fromCatalog.itemName or itemName
        wearCategory = fromCatalog.wearCategory
        wearComponentId = fromCatalog.wearComponentId
        extraComponents = fromCatalog.extraComponents
        if not label or label == '' then label = fromCatalog.label end
        if not line.price then price = fromCatalog.price end
        rarity = fromCatalog.rarity or rarity
      end
    end
  end

  if cfg.admin and cfg.admin.dbOverridesConfig and Catalog.hasDbItems(gender, tab, shopKey) then
    local entry = Catalog.getEnabledEntry(gender, tab, drawable, texture, shopKey)
    if not entry then return nil end
    price = entry.price
    rarity = entry.rarity or 'common'
    label = entry.label or label
    if type(entry.itemName) == 'string' and entry.itemName ~= '' then
      itemName = entry.itemName
    end
    if type(entry.tab) == 'string' and entry.tab ~= '' then
      tab = entry.tab
    end
    line.hideNametag = entry.hideNametag
    line.hideHair = entry.hideHair
  end

  return {
    tab = tab,
    drawable = drawable,
    texture = texture,
    price = price,
    rarity = rarity,
    label = label,
    itemName = itemName,
    imageKey = itemName,
    gender = gender,
    wearCategory = wearCategory,
    wearComponentId = wearComponentId,
    extraComponents = extraComponents,
    hideNametag = line.hideNametag == true,
    hideHair = line.hideHair == true,
  }
end

--- Item ox_inventory khi bán: hands tattoo vào ô jacket; tab shop `tattoo` không phải loại đồ.
local function grantClothingType(validated)
  local wear = validated and validated.wearCategory
  if wear == 'hands' then return 'jacket' end
  if wear == 'jacket' or wear == 'pants' or wear == 'undershirt' or wear == 'shoes' then
    return wear
  end
  local tab = validated and validated.tab
  if tab == 'tattoo' or tab == 'hands' then return 'jacket' end
  return tab
end

local function giveShopClothing(source, validated)
  if type(validated.itemName) == 'string' and validated.itemName:sub(1, 2) == 'u_' then
    local extra = {}
    if validated.rarity and validated.rarity ~= '' then
      extra.rarity = validated.rarity
    end
    if validated.hideNametag then extra.hideNametag = true end
    if validated.hideHair then extra.hideHair = true end
    return exports['hgrp_clothing_capture']:addUnisexClothingItem(
      source,
      validated.itemName,
      validated.label,
      extra
    )
  end

  if cfg.useGenericMetadata ~= false then
  local extra = {
    image = validated.itemName,
  }
  if validated.rarity and validated.rarity ~= '' then
    extra.rarity = validated.rarity
  end
  if validated.hideNametag then
    extra.hideNametag = true
  end
  if validated.hideHair then
    extra.hideHair = true
  end
    return exports['hgrp_clothing_capture']:addGenericClothingItem(
      source,
      grantClothingType(validated),
      validated.drawable,
      validated.texture,
      validated.gender,
      nil,
      validated.label,
      extra
    )
  end

  local overrides = {}
  if validated.rarity and validated.rarity ~= '' and validated.rarity ~= 'common' then
    overrides.rarity = validated.rarity
  end
  if type(validated.label) == 'string' and validated.label ~= '' then
    overrides.label = validated.label
  end
  return exports['hgrp_clothing_capture']:addClothingItem(source, validated.itemName, 1, overrides)
end

local function carryItemName(validated)
  if cfg.useGenericMetadata ~= false then
    return grantClothingType(validated)
  end
  return 'clothing'
end

local function buySingle(source, gender, line, storeIndex)
  local validated = resolveCatalogLine(gender, line, storeIndex)
  if not validated then
    return { ok = false, reason = 'not_found' }
  end

  if not exports.ox_inventory:CanCarryItem(source, carryItemName(validated), 1) then
    return { ok = false, reason = 'inventory_full' }
  end

  local currency = resolveCurrency(storeIndex)
  if not pay(source, validated.price, 'paid-clothing', currency) then
    return { ok = false, reason = 'money', currency = currency }
  end

  local added = giveShopClothing(source, validated)
  if not added then
    refund(source, validated.price, currency)
    return { ok = false, reason = 'give_failed' }
  end

  return { ok = true, itemName = validated.itemName, currency = currency }
end

lib.callback.register('hgrp_clothingshop:server:buy', function(source, payload)
  if type(payload) ~= 'table' then
    return { ok = false, reason = 'invalid' }
  end

  local gender = payload.gender == 'female' and 'female' or 'male'
  return buySingle(source, gender, payload, tonumber(payload.storeIndex))
end)

lib.callback.register('hgrp_clothingshop:server:buyCart', function(source, payload)
  if type(payload) ~= 'table' then
    return { ok = false, reason = 'invalid' }
  end

  local lines = payload.items
  if type(lines) ~= 'table' or #lines == 0 then
    return { ok = false, reason = 'empty' }
  end

  local gender = payload.gender == 'female' and 'female' or 'male'
  local storeIndex = tonumber(payload.storeIndex)
  local currency = resolveCurrency(storeIndex)
  local validated = {}
  local seenTabs = {}

  for i = 1, #lines do
    local line = resolveCatalogLine(gender, lines[i], storeIndex)
    if line and not seenTabs[line.tab] then
      seenTabs[line.tab] = true
      validated[#validated + 1] = line
    end
  end

  if #validated == 0 then
    return { ok = false, reason = 'not_found' }
  end

  local carryName = carryItemName(validated[1])
  for i = 1, #validated do
    if not exports.ox_inventory:CanCarryItem(source, carryItemName(validated[i]), 1) then
      return { ok = false, reason = 'inventory_full' }
    end
  end

  local total = 0
  for i = 1, #validated do
    total = total + validated[i].price
  end

  if not pay(source, total, 'paid-clothing-cart', currency) then
    return { ok = false, reason = 'money', currency = currency }
  end

  local successCount = 0
  for i = 1, #validated do
    local line = validated[i]
    local added = giveShopClothing(source, line)
    if added then
      successCount = successCount + 1
    else
      refund(source, line.price, currency)
    end
  end

  if successCount == 0 then
    return { ok = false, reason = 'give_failed' }
  end

  return {
    ok = true,
    count = successCount,
    partial = successCount < #validated,
    currency = currency,
  }
end)

local function allowedCategorySet(storeIndex)
  local shop = shopEntry(storeIndex)
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

lib.callback.register('hgrp_clothingshop:server:getShopCatalog', function(source, payload)
  payload = type(payload) == 'table' and payload or {}
  local gender = payload.gender == 'female' and 'female' or 'male'
  local storeIndex = tonumber(payload.storeIndex)
  local shop = shopEntry(storeIndex)
  if not shop then
    return { ok = false, msg = 'not_a_retail_shop' }
  end
  local allow = allowedCategorySet(storeIndex)
  local shopKey = shop.key
  local items, imageBase = Catalog.buildShopItems(gender, allow, shopKey)
  local tabs = Catalog.buildShopTabs(gender, allow, shopKey)
  local shop = shopEntry(storeIndex)
  local currency = resolveCurrency(storeIndex)
  return {
    ok = true,
    items = items,
    tabs = tabs,
    imageBase = imageBase or normalizeImageBase(cfg.imageBase),
    rarities = cfg.rarities or {},
    title = (shop and shop.title) or cfg.title,
    currency = currency,
    storeIndex = storeIndex,
  }
end)

lib.callback.register('hgrp_clothingshop:server:filterItems', function(_, gender, items)
  if cfg.onlyRegisteredItems == false or cfg.useGenericMetadata ~= false then
    return items
  end

  if type(items) ~= 'table' then return {} end
  gender = gender == 'female' and 'female' or 'male'

  local out = {}
  local nextId = 0
  for i = 1, #items do
    local it = items[i]
    if it and it.tab and it.drawable ~= nil and tonumber(it.drawable) >= 0 then
      local itemName = buildClothingItemName(it.tab, gender, it.drawable, it.texture)
      if itemName and exports['hgrp_clothing_capture']:getClothingData(itemName) then
        local meta = exports['hgrp_clothing_capture']:getClothingData(itemName)
        nextId = nextId + 1
        it.id = nextId
        it.gender = gender
        it.imageKey = itemName
        it.image = Catalog.imageUrlFor(gender, it.tab, it.drawable, it.texture, meta and meta.image)
        out[#out + 1] = it
      end
    end
  end
  return out
end)
