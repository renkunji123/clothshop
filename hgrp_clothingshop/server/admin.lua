local cfg = require 'config.shared'



local function isAdmin(src)

    if src == 0 then return true end

    local ace = (cfg.admin and cfg.admin.ace) or 'group.admin'

    return IsPlayerAceAllowed(src, ace) or IsPlayerAceAllowed(src, 'command')

end



local function defaultPrice(category)

    local p = cfg.defaultPrices and cfg.defaultPrices[category]

    return math.floor(tonumber(p) or 100)

end



lib.callback.register('hgrp_clothingshop:server:isAdmin', function(source)

    return isAdmin(source)

end)



lib.callback.register('hgrp_clothingshop:server:adminMeta', function(source)

    if not isAdmin(source) then return { ok = false } end

    local shops = {}
    for i = 1, #ShopRegistry.list() do
        local shop = ShopRegistry.list()[i]
        shops[#shops + 1] = {
            index = tonumber(shop.illeniumStoreIndex) or i,
            key = shop.key,
            title = shop.title or shop.key,
            blipLabel = shop.blipLabel,
            currency = shop.currency,
            illeniumStoreIndex = shop.illeniumStoreIndex,
        }
    end

    return {

        ok = true,

        imageBase = cfg.imageBase,

        genders = {

            { id = 'male', label = 'Nam' },

            { id = 'female', label = 'Nữ' },

        },

        categories = cfg.adminCategories or {},

        rarities = cfg.rarities or {},

        defaultPrices = cfg.defaultPrices or {},

        shops = shops,

        defaultShopKey = (shops[1] and shops[1].key) or 'clothing_normal',

        listingCounts = Catalog.getAdminListingCounts(),

    }

end)



lib.callback.register('hgrp_clothingshop:server:adminList', function(source, payload)

    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end

    payload = type(payload) == 'table' and payload or {}

    local gender = Catalog.normalizeGender(payload.gender)

    local category = payload.category

    local shopKey = type(payload.shopKey) == 'string' and payload.shopKey ~= '' and payload.shopKey or 'clothing_normal'

    if category ~= 'all' and not Catalog.isValidCategory(category) then

        return { ok = false, msg = 'Danh mục không hợp lệ.' }

    end

    local rows = Catalog.listConfigured(gender, category or 'all', shopKey)

    local out = {}

    for i = 1, #rows do

        out[#out + 1] = Catalog.enrichRow(rows[i])

    end

    return { ok = true, rows = out }

end)



--- Picker shop: chỉ món đã cấu hình catalog, chưa có trong shop.

lib.callback.register('hgrp_clothingshop:server:adminBrowse', function(source, payload)

    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end

    payload = type(payload) == 'table' and payload or {}

    local gender = Catalog.normalizeGender(payload.gender)

    local category = payload.category

    if not Catalog.isValidCategory(category) then

        return { ok = false, msg = 'Danh mục không hợp lệ.' }

    end

    local items = Catalog.browseConfiguredForShop(gender, category, payload.query, payload.shopKey)

    if #items == 0 and GetResourceState('hgrp_clothing_capture') ~= 'started' then
        return { ok = true, items = {}, msg = 'Chưa có món trong catalog — dùng /clothingconfigadmin để thêm đồ trước.' }
    end

    return { ok = true, items = items }

end)



lib.callback.register('hgrp_clothingshop:server:adminUpsert', function(source, payload)

    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end

    if type(payload) ~= 'table' then return { ok = false, msg = 'Dữ liệu không hợp lệ.' } end



    local listingId = tonumber(payload.id)

    local clothingItemId = tonumber(payload.clothingItemId)

    local price = math.floor(tonumber(payload.price) or 0)

    local enabled = payload.enabled ~= false

    local sortOrder = math.floor(tonumber(payload.sortOrder) or 0)

    local shopKey = type(payload.shopKey) == 'string' and payload.shopKey ~= '' and payload.shopKey or 'clothing_normal'



    if price < 0 then price = 0 end



    if listingId then

        Catalog.updateListing(listingId, price, enabled, sortOrder)

        Catalog.invalidate()

        local row = MySQL.single.await([[

            SELECT l.id AS listing_id, l.price, l.enabled, l.sort_order, l.clothing_item_id,

                   i.id AS item_id, i.gender, i.category, i.drawable, i.texture, i.image_key,

                   i.label, i.rarity, i.hide_nametag, i.hide_hair

            FROM hgrp_clothingshop_listings l

            INNER JOIN hgrp_clothing_items i ON i.id = l.clothing_item_id

            WHERE l.id = ? LIMIT 1

        ]], { listingId })

        return { ok = true, msg = 'Đã cập nhật giá shop.', row = Catalog.enrichRow(row) }

    end



    if not clothingItemId then

        return { ok = false, msg = 'Chọn món đã cấu hình trước (/clothingconfigadmin).' }

    end



    local item = exports['hgrp_clothing_capture']:getClothingCatalogItemById(clothingItemId)

    if not item then

        return { ok = false, msg = 'Món chưa có trong catalog cấu hình.' }

    end



    local id, err = Catalog.addListing(clothingItemId, price, enabled, sortOrder, shopKey)

    if not id then

        return { ok = false, msg = err == 'already_listed' and 'Món đã có trong shop.' or 'Không thêm được.' }

    end



    local row = MySQL.single.await([[

        SELECT l.id AS listing_id, l.price, l.enabled, l.sort_order, l.clothing_item_id,

               i.id AS item_id, i.gender, i.category, i.drawable, i.texture, i.image_key,

               i.label, i.rarity, i.hide_nametag, i.hide_hair

        FROM hgrp_clothingshop_listings l

        INNER JOIN hgrp_clothing_items i ON i.id = l.clothing_item_id

        WHERE l.id = ? LIMIT 1

    ]], { id })



    return { ok = true, msg = 'Đã thêm vào shop.', row = Catalog.enrichRow(row) }

end)



lib.callback.register('hgrp_clothingshop:server:adminToggle', function(source, payload)

    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end

    local id = tonumber(payload and payload.id)

    if not id then return { ok = false, msg = 'Thiếu id.' } end

    local enabled = payload.enabled == true

    local row = MySQL.single.await(

        'SELECT price, sort_order FROM hgrp_clothingshop_listings WHERE id = ? LIMIT 1',

        { id }

    )

    if not row then return { ok = false, msg = 'Không tìm thấy món.' } end

    Catalog.updateListing(id, row.price, enabled, row.sort_order)

    return { ok = true, msg = enabled and 'Đã bật bán.' or 'Đã tắt bán.' }

end)



lib.callback.register('hgrp_clothingshop:server:adminDelete', function(source, payload)

    if not isAdmin(source) then return { ok = false, msg = 'Không có quyền.' } end

    local id = tonumber(payload and payload.id)

    if not id then return { ok = false, msg = 'Thiếu id.' } end

    if not Catalog.deleteListing(id) then return { ok = false, msg = 'Không tìm thấy món.' } end

    return { ok = true, msg = 'Đã xóa khỏi shop (cấu hình đồ vẫn giữ).' }

end)



lib.addCommand((cfg.admin and cfg.admin.command) or 'clothingshopadmin', {

    help = 'Danh sách bán shop quần áo (chỉ giá — đồ lấy từ catalog đã cấu hình)',

    restricted = (cfg.admin and cfg.admin.ace) or 'group.admin',

}, function(source)

    if source == 0 then

        print('[hgrp_clothingshop] Dùng in-game: /clothingshopadmin')

        return

    end

    TriggerClientEvent('hgrp_clothingshop:client:openAdmin', source)

end)

lib.callback.register('hgrp_clothingshop:server:adminShopSettings', function(source)
    if not isAdmin(source) then return { ok = false } end
    return {
        ok = true,
        shops = RetailSettings.listFromConfig(cfg.shops),
        currencies = {
            { id = 'cash', label = 'Cash / Bank ($)' },
            { id = 'v_medal', label = 'V Medal' },
        },
    }
end)

lib.callback.register('hgrp_clothingshop:server:adminSetShopCurrency', function(source, payload)
    if not isAdmin(source) then return { ok = false, msg = 'no_perm' } end
    payload = type(payload) == 'table' and payload or {}
    local key = payload.key
    local currency = payload.currency
    local ok, err = RetailSettings.setCurrency(key, currency)
    if not ok then
        return { ok = false, msg = err or 'fail' }
    end
    return { ok = true, shops = RetailSettings.listFromConfig(cfg.shops) }
end)


