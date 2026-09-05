fx_version 'cerulean'
game 'gta5'

name 'hgrp_clothingshop'
description 'Custom clothing NUI (shop-like UI) with configurable items/prices'
  version '1.7.0'

lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config/shared.lua',
  'shared/drawable_utils.lua',
  'shared/shop_registry.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/css/*.css',
  'html/js/*.js',
  'data/*.lua',
}

client_scripts {
  'client/drawable_range.lua',
  'client/main.lua',
  'client/nui.lua',
  'client/admin.lua',
  'client/config_admin.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/catalog.lua',
  'server/retail_settings.lua',
  'server/config_admin.lua',
  'server/admin.lua',
  'server/seed_shop.lua',
  'server/main.lua',
}

dependencies {
  'ox_lib',
  'qbx_core',
  'ox_inventory',
  'hgrp_clothing_capture',
  'illenium-appearance',
  'hgrp_f1_shop',
}
