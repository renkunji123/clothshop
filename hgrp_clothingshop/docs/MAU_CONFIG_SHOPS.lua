--[[
  MAU_CONFIG_SHOPS.lua — File mẫu, KHÔNG được load tự động.

  Cách dùng:
  1. Copy block "QUẦN ÁO" vào:  hgrp_clothingshop/config/shared.lua  (thay phần shops, defaultPrices...)
  2. Copy block "SALON TÓC" vào: hgrp_barbershop/config/shared.lua   (thay phần shops, defaultPrices...)
  3. ensure hgrp_clothingshop && ensure hgrp_barbershop

  Map index (illenium Config.Stores, đếm từ 1):
    Quần áo HGRP : index 2 = clothing_normal (cash), index 6 = clothing_premium (v_medal)
    Salon tóc    : index 16 = barber_normal (cash), index 17 = barber_premium (v_medal)
]]

-- =============================================================================
-- QUẦN ÁO — paste vào hgrp_clothingshop/config/shared.lua
-- =============================================================================

--[[
  admin = {
    command = 'clothingshopadmin',
    configCommand = 'clothingconfigadmin',
    ace = 'group.admin',
    dbOverridesConfig = false,
  },

  defaultPrices = {
    hat = 120,
    glasses = 80,
    mask = 150,
    jacket = 450,
    undershirt = 200,
    pants = 350,
    shoes = 280,
    bag = 220,
    chains = 180,
    face = 0,
  },

  priceOverrides = {
    jacket = {
      male = { [12] = 1200 },
      female = { [7] = 900 },
    },
  },

  items = {},

  shops = {
    {
      key = 'clothing_normal',
      title = 'Quần áo bình dân',
      currency = 'cash',
      illeniumStoreIndex = 2,
      blipLabel = 'Cửa hàng quần áo',
      items = {
        jacket = {
          male = {
            -- Cách gọn: chỉ tên catalog (metadata + extraComponents tự load)
            'm_jacket_12_0',
            { item = 'm_jacket_15_0', price = 380, label = 'Áo khoác nam #15' },
            -- Legacy drawable vẫn dùng được:
            -- { drawable = 12, texture = 0, price = 450, label = 'Áo khoác nam #12', rarity = 'common' },
          },
          female = {
            'f_jacket_7_0',
            { item = 'f_jacket_9_0', price = 400, label = 'Áo khoác nữ #9' },
          },
        },
        pants = {
          male = {
            { drawable = 5, texture = 0, price = 350 },
            { drawable = 8, texture = 0, price = 400 },
          },
          female = {
            { drawable = 3, texture = 0, price = 380 },
            { drawable = 6, texture = 1, price = 410, label = 'Quần nữ texture 1' },
          },
        },
        shoes = {
          male = {
            { drawable = 10, texture = 0, price = 280 },
          },
          female = {
            { drawable = 6, texture = 0, price = 300 },
          },
        },
        undershirt = {
          male = {
            { drawable = 15, texture = 0, price = 200 },
          },
          female = {
            { drawable = 14, texture = 0, price = 220 },
          },
        },
        hat = {
          male = {
            { drawable = 2, texture = 0, price = 120 },
          },
          female = {
            { drawable = 1, texture = 0, price = 150 },
          },
        },
        mask = {
          male = {
            { drawable = 0, texture = 0, price = 150, label = 'Mặt nạ', hideHair = true },
          },
          female = {
            { drawable = 0, texture = 0, price = 150, label = 'Mặt nạ', hideHair = true },
          },
        },
      },
    },

    {
      key = 'clothing_premium',
      title = 'Boutique cao cấp',
      currency = 'v_medal',
      illeniumStoreIndex = 6,
      blipLabel = 'Boutique cao cấp',
      -- categories = { 'jacket', 'bag', 'hat' },
      items = {
        jacket = {
          male = {
            { drawable = 24, texture = 0, price = 50, label = 'Áo VIP nam', rarity = 'rare' },
            { drawable = 28, texture = 0, price = 80, label = 'Áo limited', rarity = 'legendary' },
          },
          female = {
            { drawable = 18, texture = 1, price = 45, label = 'Áo nữ premium', rarity = 'rare' },
          },
        },
        bag = {
          male = {
            { drawable = 0, texture = 0, price = 30, label = 'Balo đặc biệt' },
          },
          female = {
            { drawable = 0, texture = 0, price = 30, label = 'Balo đặc biệt' },
          },
        },
        chains = {
          male = {
            { drawable = 3, texture = 0, price = 25, label = 'Dây chuyền VIP' },
          },
          female = {
            { drawable = 2, texture = 0, price = 25 },
          },
        },
        hat = {
          male = {
            { drawable = 5, texture = 0, price = 20, label = 'Mũ designer' },
          },
          female = {
            { drawable = 4, texture = 0, price = 20 },
          },
        },
      },
    },
  },
]]

-- =============================================================================
-- SALON TÓC — paste vào hgrp_barbershop/config/shared.lua
-- =============================================================================

--[[
  defaultPrices = {
    hair = 50,
    hairColor = 35,
    beard = 40,
    eyebrows = 25,
  },

  priceOverrides = {
    hair = {
      male = { [12] = 500, [24] = 2000 },
      female = { [7] = 800 },
    },
    beard = {
      male = { [3] = 300 },
      female = {},
    },
    eyebrows = {
      male = { [4] = 120 },
      female = { [10] = 150 },
    },
  },

  styles = {},

  shops = {
    [16] = {
      key = 'barber_normal',
      title = 'Cắt tóc bình dân',
      currency = 'cash',
      styles = {
        hair = {
          male = {
            { style = 0,  label = 'Undercut',     price = 50 },
            { style = 5,  label = 'Buzz cut',     price = 50 },
            { style = 8,  label = 'Side part',    price = 60 },
            { style = 12, label = 'Tóc vuốt',     price = 500 },
          },
          female = {
            { style = 3,  label = 'Bob',          price = 80 },
            { style = 6,  label = 'Tóc ngắn',    price = 70 },
            { style = 7,  label = 'Tóc dài',      price = 800 },
          },
        },
        beard = {
          male = {
            { style = 0,   label = 'Râu ngắn',   price = 40 },
            { style = 2,   label = 'Râu full',    price = 60 },
            { style = 3,   label = 'Râu dày',     price = 300 },
            { style = 255, label = 'Không',       price = 0 },
          },
          female = {},
        },
        eyebrows = {
          male = {
            { style = 0,   label = 'Mày thường', price = 25 },
            { style = 4,   label = 'Mày đậm',    price = 120 },
            { style = 255, label = 'Không',      price = 0 },
          },
          female = {
            { style = 5,   label = 'Mày mảnh',   price = 30 },
            { style = 10,  label = 'Mày cong',   price = 150 },
            { style = 255, label = 'Không',      price = 0 },
          },
        },
      },
    },

    [17] = {
      key = 'barber_premium',
      title = 'Salon cao cấp',
      currency = 'v_medal',
      styles = {
        hair = {
          male = {
            { style = 12, label = 'Tóc VIP',      price = 30 },
            { style = 24, label = 'Tóc hiếm',     price = 50 },
          },
          female = {
            { style = 7,  label = 'Tóc dài VIP', price = 25 },
            { style = 11, label = 'Tóc salon',    price = 40 },
          },
        },
        beard = {
          male = {
            { style = 5,   label = 'Râu styled',  price = 15 },
            { style = 255, label = 'Không',       price = 0 },
          },
          female = {},
        },
        eyebrows = {
          male = {
            { style = 6,   label = 'Mày salon',   price = 10 },
            { style = 255, label = 'Không',       price = 0 },
          },
          female = {
            { style = 12,  label = 'Mày premium', price = 12 },
            { style = 255, label = 'Không',       price = 0 },
          },
        },
      },
    },

    -- Gán thêm điểm barber khác trên map (index 18–22) nếu cần:
    -- [18] = { key = 'barber_normal', title = 'Cắt tóc bình dân', currency = 'cash', styles = { ... } },
  },

  admin = {
    command = 'barbershopadmin',
    ace = 'group.admin',
    dbListingsOverridesConfig = false,
  },
]]

-- =============================================================================
-- GHI CHÚ NHANH
-- =============================================================================
--[[
  QUẦN ÁO — field mỗi món (chọn 1 trong 2 cách):
    Cách gọn:  'm_jacket_12_0'  hoặc  { item = 'm_jacket_12_0', price = 450, label = '...' }
    Legacy:    { drawable = 12, texture = 0, price = 450, label = '...', rarity = 'common' }
    item/imageKey → load metadata catalog (extraComponents, wearComponentId, hideHair…)
    texture             mặc định 0 (legacy)
    price               bỏ trống → defaultPrices[category]
    label, rarity, hideHair (mask)

  TÓC — field mỗi kiểu:
    style   (bắt buộc)  drawable tóc hoặc overlay index
    label, price
    style = 255         "Không" (râu / lông mày)

  Category quần áo:
    hat, glasses, mask, jacket, undershirt, pants, shoes,
    bag, hands, face, armor, chains

  Tab salon:
    hair, beard, eyebrows
]]
