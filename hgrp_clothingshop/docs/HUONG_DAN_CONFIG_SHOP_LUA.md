# Hướng dẫn config shop quần áo & salon tóc

Server HGRP dùng **config.lua** làm nguồn chính. Mỗi cửa hàng có **tiền tệ riêng** và **danh sách đồ riêng** — không cần MySQL để bán hàng.

| Hệ thống | File cấu hình |
|----------|----------------|
| Quần áo | `hgrp_clothingshop/config/shared.lua` |
| Salon tóc | `hgrp_barbershop/config/shared.lua` |
| Vị trí trên map | `illenium-appearance/shared/config.lua` → `Config.Stores` |
| **File mẫu copy-paste** | `hgrp_clothingshop/docs/MAU_CONFIG_SHOPS.lua` |

Sau khi sửa config:

```
ensure illenium-appearance
ensure hgrp_clothingshop
ensure hgrp_barbershop
```

---

## Tổng quan

```
Config.Stores (illenium)     →  vị trí zone trên map, bấm E vào cửa
        ↓
shops[] (hgrp config)        →  currency + items/styles theo từng shop
        ↓
Người chơi mua              →  trừ cash/bank hoặc v_medal
```

**Ba thứ tách biệt:**

| Thứ | Ý nghĩa | Ví dụ |
|-----|---------|-------|
| **Shop** | Cửa nào, trả bằng gì | `clothing_normal` → `cash` |
| **Món** | Drawable/style bán gì | áo `drawable = 12` |
| **Giá** | Bao nhiêu tiền | `price = 450` hoặc `50` v_medal |

Không có khái niệm “item cash” hay “item v_medal”. **Shop** quyết định loại tiền; **món** chỉ khai báo drawable + giá.

---

## Phần 1 — Shop quần áo

### 1.1. Chế độ config (mặc định)

```lua
admin = {
  dbOverridesConfig = false,  -- false = đọc shops[].items, không dùng DB listing
},
```

Chỉ bật `true` nếu muốn quản lý qua `/clothingshopadmin` + database.

### 1.2. Cấu trúc một shop

```lua
shops = {
  {
    key = 'clothing_normal',       -- ID nội bộ, khớp hgrpShopKey trên map
    title = 'Quần áo bình dân',    -- Tiêu đề UI
    currency = 'cash',             -- 'cash' hoặc 'v_medal'
    illeniumStoreIndex = 2,        -- Index shop trong illenium Config.Stores
    blipLabel = 'Cửa hàng quần áo',
    -- categories = { 'jacket', 'pants' },  -- tuỳ chọn: giới hạn tab bán
    items = {
      -- xem mẫu bên dưới
    },
  },
},
```

**Map hiện tại (illenium):**

| Index | `hgrpShopKey` | Shop config |
|-------|---------------|-------------|
| 2 | `clothing_normal` | Quần áo bình dân · cash |
| 6 | `clothing_premium` | Boutique cao cấp · v_medal |

Trong `illenium-appearance/shared/config.lua`, shop HGRP phải có:

```lua
hgrpShopKey = 'clothing_normal',  -- hoặc 'clothing_premium'
```

### 1.3. Cấu trúc `items`

**Cách 1 — chỉ tên item (gọn, khuyên dùng khi đã có catalog DB / capture):**

```lua
items = {
  jacket = {
    male = {
      'm_jacket_12_0',
      { item = 'm_jacket_24_0', price = 50, label = 'Áo VIP', rarity = 'rare' },
    },
    female = {
      'f_jacket_7_0',
    },
  },
}
```

Hoặc gom theo giới tính (tab tự suy từ catalog `display_type` / `category`):

```lua
items = {
  male = {
    'm_jacket_12_0',
    'm_pants_5_0',
  },
  female = {
    'f_jacket_7_0',
  },
}
```

- `item` / tên chuỗi = `image_key` trong bảng `hgrp_clothing_items` (catalog capture).
- Khi mua, server gọi `mergeIntoMetadata` như give bình thường → có `extraComponents`, `wearComponentId`, `hideHair`…
- Thử đồ trong shop cũng apply `extraComponents` (ví dụ áo khoác override tay `hands`).

**Cách 2 — drawable thủ công (legacy):**

```lua
items = {
  [category] = {
    male = {
      { drawable = 12, texture = 0, price = 450, label = 'Áo nam #12', rarity = 'common' },
    },
    female = {
      { drawable = 7, texture = 0, price = 520, label = 'Áo nữ #7' },
    },
  },
}
```

**Category hợp lệ:**

`hat` · `glasses` · `mask` · `jacket` · `undershirt` · `pants` · `shoes` · `bag` · `hands` · `face` · `armor` · `chains`

| Field | Bắt buộc | Ghi chú |
|-------|----------|---------|
| `item` / chuỗi | Cách 1 | `m_jacket_12_0` hoặc key custom trong catalog |
| `drawable` | Cách 2 | Số drawable GTA (xem trong Illenium / ped preview) |
| `texture` | Không | Mặc định `0` |
| `price` | Không | Bỏ trống → lấy `defaultPrices[category]` |
| `label` | Không | Tên hiển thị trong shop (ghi đè catalog) |
| `rarity` | Không | `common` · `uncommon` · `rare` · `legendary` · `mythical` |
| `hideHair` | Không | Chỉ `mask` — trọc đầu khi đeo |

### 1.4. Mẫu đầy đủ — 2 shop khác đồ, khác tiền

```lua
shops = {
  {
    key = 'clothing_normal',
    title = 'Quần áo bình dân',
    currency = 'cash',
    illeniumStoreIndex = 2,
    items = {
      jacket = {
        male = {
          { drawable = 12, texture = 0, price = 450, label = 'Áo bình dân' },
          { drawable = 15, texture = 0, price = 380 },
        },
        female = {
          { drawable = 7, texture = 0, price = 420 },
        },
      },
      pants = {
        male = { { drawable = 5, texture = 0, price = 350 } },
        female = { { drawable = 3, texture = 0, price = 380 } },
      },
      shoes = {
        male = { { drawable = 10, texture = 0, price = 280 } },
        female = { { drawable = 6, texture = 0, price = 300 } },
      },
    },
  },

  {
    key = 'clothing_premium',
    title = 'Boutique cao cấp',
    currency = 'v_medal',
    illeniumStoreIndex = 6,
    items = {
      jacket = {
        male = {
          { drawable = 24, texture = 0, price = 50, label = 'Áo VIP', rarity = 'rare' },
        },
        female = {
          { drawable = 18, texture = 1, price = 40, label = 'Áo nữ premium' },
        },
      },
      bag = {
        male = { { drawable = 0, texture = 0, price = 30, label = 'Balo đặc biệt' } },
        female = { { drawable = 0, texture = 0, price = 30 } },
      },
    },
  },
},
```

### 1.5. Giá mặc định & override (tuỳ chọn)

Dùng khi nhiều món cùng giá, không muốn ghi `price` từng dòng:

```lua
defaultPrices = {
  jacket = 450,
  pants = 350,
  shoes = 280,
},

priceOverrides = {
  jacket = {
    male = { [12] = 1200, [24] = 2000 },
    female = { [7] = 800 },
  },
},
```

### 1.6. Ảnh sản phẩm

- URL gốc: `imageBase` trong config (CDN / MinIO).
- Tên file: `m_jacket_12_0.png`, `f_pants_7_0.png` (`m`/`f` + category + drawable + texture).

### 1.7. Thêm cửa quần áo mới

1. Thêm zone `type = "clothing"` + `hgrpShopKey = 'ten_shop_moi'` trong `illenium Config.Stores`.
2. Đếm **index** của shop đó trong mảng `Config.Stores`.
3. Thêm block mới vào `shops` trong `hgrp_clothingshop/config/shared.lua`:

```lua
{
  key = 'ten_shop_moi',
  title = 'Tên hiển thị',
  currency = 'cash',           -- hoặc 'v_medal'
  illeniumStoreIndex = 99,       -- index vừa đếm
  items = { ... },
},
```

---

## Phần 2 — Salon tóc

### 2.1. Chế độ config (mặc định)

```lua
admin = {
  dbListingsOverridesConfig = false,  -- false = đọc shops[].styles
},
```

### 2.2. Cấu trúc một shop

Key của `shops` = **index barber** trong `illenium Config.Stores` (đếm từ 1).

**Map hiện tại:** barber bắt đầu từ **index 16** (sau 15 shop quần áo).

```lua
shops = {
  [16] = {
    key = 'barber_normal',
    title = 'Cắt tóc bình dân',
    currency = 'cash',
    styles = { ... },
  },
  [17] = {
    key = 'barber_premium',
    title = 'Salon cao cấp',
    currency = 'v_medal',
    styles = { ... },
  },
},
```

> Các salon barber khác trên map (index 18–22) chưa gắn trong config → mặc định dùng `barber_normal` + cash. Muốn salon index 18 cũng bán v_medal → thêm `[18] = { key = 'barber_premium', ... }`.

### 2.3. Cấu trúc `styles`

```lua
styles = {
  hair = {
    male = {
      { style = 0, label = 'Undercut', price = 50 },
      { style = 12, label = 'Tóc VIP', price = 500 },
    },
    female = {
      { style = 3, label = 'Bob', price = 80 },
    },
  },
  beard = {
    male = {
      { style = 0, label = 'Râu ngắn', price = 40 },
      { style = 255, label = 'Không', price = 0 },
    },
    female = {},
  },
  eyebrows = {
    male = {
      { style = 4, label = 'Mày đậm', price = 120 },
      { style = 255, label = 'Không', price = 0 },
    },
    female = {
      { style = 10, label = 'Mày cong', price = 150 },
      { style = 255, label = 'Không', price = 0 },
    },
  },
},
```

| Field | Ghi chú |
|-------|---------|
| `style` | Drawable tóc (component 2) hoặc index overlay râu/mày |
| `label` | Tên hiển thị; bỏ trống → `Style #xx` |
| `price` | Bỏ trống → `priceOverrides` → `defaultPrices` |
| `style = 255` | “Không” — chỉ dùng cho râu / lông mày |

**Tab:** `hair` · `beard` · `eyebrows` (khai báo trong `tabs`).

**Tóc — tính tiền khi mua:**

| Thay đổi | Giá lấy từ |
|----------|------------|
| Đổi kiểu tóc | `price` của dòng `style` đó |
| Chỉ đổi màu / highlight | `defaultPrices.hairColor` |

### 2.4. Mẫu — salon cash vs salon v_medal

```lua
shops = {
  [16] = {
    key = 'barber_normal',
    title = 'Cắt tóc bình dân',
    currency = 'cash',
    styles = {
      hair = {
        male = {
          { style = 0, label = 'Undercut', price = 50 },
          { style = 5, label = 'Buzz cut', price = 50 },
        },
        female = {
          { style = 3, label = 'Bob', price = 80 },
        },
      },
      beard = {
        male = {
          { style = 0, label = 'Râu ngắn', price = 40 },
          { style = 255, label = 'Không', price = 0 },
        },
        female = {},
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
          { style = 12, label = 'Tóc VIP', price = 30 },
          { style = 24, label = 'Tóc hiếm', price = 50 },
        },
        female = {
          { style = 7, label = 'Tóc dài premium', price = 25 },
        },
      },
    },
  },
},
```

### 2.5. Thêm salon mới trên map

1. Zone barber đã có sẵn trong `illenium Config.Stores` (index 16–22).
2. Gán index đó vào `shops` với `styles` + `currency` mong muốn.
3. Nhiều điểm map có thể dùng chung một `key` (cùng catalog, cùng tiền).

---

## Phần 3 — Tiền tệ

| `currency` | Cách trừ tiền |
|------------|--------------|
| `cash` | Tiền mặt trước, hết thì trừ bank |
| `v_medal` | V Medal qua `hgrp_f1_shop` |

Giá trong config:
- Shop **cash** → `price = 450` nghĩa là $450.
- Shop **v_medal** → `price = 50` nghĩa là 50 V Medal.

---

## Phần 4 — Quy trình config nhanh

### Quần áo

1. Mở `hgrp_clothingshop/config/shared.lua`.
2. Xác nhận `dbOverridesConfig = false`.
3. Trong `shops`, bỏ comment block `items` của từng shop.
4. Điền `drawable`, `texture`, `price`, `label`.
5. Kiểm tra `illeniumStoreIndex` / `hgrpShopKey` khớp map.
6. `ensure hgrp_clothingshop`.

### Salon tóc

1. Mở `hgrp_barbershop/config/shared.lua`.
2. Xác nhận `dbListingsOverridesConfig = false`.
3. Trong `shops[index]`, bỏ comment block `styles`.
4. Điền `style`, `price`, `label` theo tab.
5. Kiểm tra `index` khớp vị trí barber trong `Config.Stores`.
6. `ensure hgrp_barbershop`.

### Lấy số drawable / style

- Vào zone → mở Illenium ped menu (admin) hoặc dùng `/clothingconfigadmin` để xem comp đang mặc.
- Tóc: component **2** → số drawable = `style`.

---

## Phần 5 — Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| Shop trống, không có tab | `items` / `styles` rỗng hoặc sai category/tab | Điền món trong đúng shop block |
| Vào cửa mở shop sai tiền | Index map không khớp `shops` | Kiểm tra `illeniumStoreIndex` / index barber |
| Mua quần áo báo lỗi | `onlyRegisteredItems = true` mà chưa có trong capture | Bật item trong `hgrp_clothing_capture` hoặc tắt flag |
| Không có ảnh | Thiếu file CDN | Upload `m_category_drawable_texture.png` |
| V_medal không trừ được | `hgrp_f1_shop` chưa chạy | `ensure hgrp_f1_shop` |
| Vẫn hiện đồ từ DB cũ | `dbOverridesConfig` / `dbListingsOverridesConfig` = `true` | Đặt `false` và restart resource |

---

## Phần 6 — Chế độ DB (tuỳ chọn, không khuyến nghị)

Chỉ dùng khi cần admin chỉnh giá/listing trong game mà không restart server.

| Resource | Flag | Lệnh admin |
|----------|------|------------|
| Quần áo | `dbOverridesConfig = true` | `/clothingshopadmin` · `/clothingconfigadmin` |
| Tóc | `dbListingsOverridesConfig = true` | `/barbershopadmin` |

Khi bật DB mode, config `shops[].items` / `shops[].styles` **không được dùng** (quần áo) hoặc bị DB ghi đè (tóc).

---

## Tóm tắt

```
Mỗi shop trong shops[] =
  key          → ID shop
  currency     → cash hoặc v_medal
  items        → quần áo (theo category → male/female → drawable)
  styles       → tóc (theo tab → male/female → style)
  illeniumStoreIndex / [index] → liên kết vị trí trên map
```

**Config file là nguồn chính. DB chỉ là tuỳ chọn cho admin runtime.**
