const adminApp = document.getElementById('adminApp');
const adminGenderTabs = document.getElementById('adminGenderTabs');
const adminShopTabs = document.getElementById('adminShopTabs');
const adminCategoryTabs = document.getElementById('adminCategoryTabs');
const adminShopPickGrid = document.getElementById('adminShopPickGrid');
const adminPanelPickShop = document.getElementById('adminPanelPickShop');
const adminBtnChangeShop = document.getElementById('adminBtnChangeShop');
const adminActiveShopLabel = document.getElementById('adminActiveShopLabel');
const adminGrid = document.getElementById('adminGrid');
const adminStatus = document.getElementById('adminStatus');
const adminSearch = document.getElementById('adminSearch');
const adminBtnClose = document.getElementById('adminBtnClose');
const adminBtnAdd = document.getElementById('adminBtnAdd');
const adminBtnRefresh = document.getElementById('adminBtnRefresh');
const adminPicker = document.getElementById('adminPicker');
const adminPickerGrid = document.getElementById('adminPickerGrid');
const adminPickerSearch = document.getElementById('adminPickerSearch');
const adminPickerClose = document.getElementById('adminPickerClose');
const adminPickerAdd = document.getElementById('adminPickerAdd');
const adminPickerCount = document.getElementById('adminPickerCount');
const adminPickerForm = document.getElementById('adminPickerForm');
const adminPickerPrice = document.getElementById('adminPickerPrice');
const adminPickerRarity = document.getElementById('adminPickerRarity');
const adminPickerLabel = document.getElementById('adminPickerLabel');
const adminPickerGenderTabs = document.getElementById('adminPickerGenderTabs');
const adminPickerCategoryTabs = document.getElementById('adminPickerCategoryTabs');
const adminPickerHideNametag = document.getElementById('adminPickerHideNametag');
const adminPickerHideHair = document.getElementById('adminPickerHideHair');
const adminPickerMaskFeatures = document.getElementById('adminPickerMaskFeatures');

const DEFAULT_CATEGORIES = [
  { id: 'pants', label: 'Quần' },
  { id: 'undershirt', label: 'Áo trong' },
  { id: 'hands', label: 'Tay (Hands)' },
  { id: 'jacket', label: 'Áo khoác' },
  { id: 'shoes', label: 'Giày' },
  { id: 'face', label: 'Đầu / Face' },
  { id: 'mask', label: 'Mặt nạ' },
  { id: 'armor', label: 'Giáp' },
  { id: 'chains', label: 'Phụ kiện' },
  { id: 'glasses', label: 'Kính' },
  { id: 'bag', label: 'Balo' },
  { id: 'hat', label: 'Mũ' },
];

const adminShopSettings = document.getElementById('adminShopSettings');
const adminMainTabs = document.getElementById('adminMainTabs');
const adminListingNav = document.getElementById('adminListingNav');
const adminPanelListings = document.getElementById('adminPanelListings');
const adminPanelSettings = document.getElementById('adminPanelSettings');
const adminPageTitle = document.getElementById('adminPageTitle');

const adminState = {
  open: false,
  meta: null,
  shopKey: null,
  step: 'pickShop',
  gender: 'male',
  category: 'all',
  listQuery: '',
  rows: [],
  pickerItems: [],
  pickerSelected: null,
  pickerQuery: '',
  shopSettings: [],
  panel: 'listings',
};

function resName() {
  if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  return 'hgrp_clothingshop';
}

function post(name, data = {}) {
  return fetch(`https://${resName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => null);
}

function metaCategories() {
  const cats = adminState.meta && adminState.meta.categories;
  return Array.isArray(cats) && cats.length ? cats : DEFAULT_CATEGORIES;
}

function categoryLabel(id) {
  const hit = metaCategories().find((c) => c.id === id);
  return (hit && hit.label) || id;
}

function listingCountFor(shopKey, gender, category) {
  const counts = (adminState.meta && adminState.meta.listingCounts) || {};
  const shop = counts[shopKey] || {};
  const g = shop[gender] || {};
  if (category === 'all') {
    return Object.values(g).reduce((sum, n) => sum + (Number(n) || 0), 0);
  }
  return Number(g[category]) || 0;
}

function shopList() {
  return (adminState.meta && adminState.meta.shops) || [];
}

function shopMeta(key) {
  return shopList().find((s) => s.key === key) || null;
}

function shopTotalListings(shopKey) {
  const counts = (adminState.meta && adminState.meta.listingCounts) || {};
  const shop = counts[shopKey] || {};
  let total = 0;
  ['male', 'female'].forEach((g) => {
    const genderCounts = shop[g] || {};
    total += Object.values(genderCounts).reduce((sum, n) => sum + (Number(n) || 0), 0);
  });
  return total;
}

function currencyLabel(code) {
  if (code === 'v_medal') return 'V Medal';
  return 'Cash / Bank ($)';
}

function updateActiveShopLabel() {
  if (!adminActiveShopLabel) return;
  const shop = shopMeta(adminState.shopKey);
  if (!shop) {
    adminActiveShopLabel.textContent = '';
    return;
  }
  const total = shopTotalListings(shop.key);
  adminActiveShopLabel.textContent = `Đang cấu hình: ${shop.title} · ${total} món · ${currencyLabel(shop.currency)}`;
}

function showShopPickStep() {
  adminState.step = 'pickShop';
  adminState.shopKey = null;
  if (adminPanelPickShop) adminPanelPickShop.classList.remove('hidden');
  if (adminPanelListings) adminPanelListings.classList.add('hidden');
  if (adminListingNav) adminListingNav.classList.add('hidden');
  if (adminPicker) closePicker();
  renderShopPickGrid();
  setAdminStatus('Chọn shop để xem và chỉnh danh sách bán.', '');
}

async function showManageStep(shopKey) {
  if (!shopKey) return showShopPickStep();
  adminState.step = 'manage';
  adminState.shopKey = shopKey;
  pickDefaultCategory();
  if (adminPanelPickShop) adminPanelPickShop.classList.add('hidden');
  if (adminPanelListings) adminPanelListings.classList.remove('hidden');
  if (adminListingNav) adminListingNav.classList.remove('hidden');
  updateActiveShopLabel();
  renderGenderTabs();
  renderCategoryTabs();
  await loadRows();
}

function renderShopPickGrid() {
  if (!adminShopPickGrid) return;
  adminShopPickGrid.innerHTML = '';
  const shops = shopList();
  if (!shops.length) {
    const empty = document.createElement('div');
    empty.className = 'admin-empty';
    empty.textContent = 'Chưa cấu hình shop trong config/shared.lua';
    adminShopPickGrid.appendChild(empty);
    return;
  }
  shops.forEach((shop) => {
    const total = shopTotalListings(shop.key);
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'admin-shop-pick-card';
    card.innerHTML = `
      <div class="admin-shop-pick-card__title">${shop.title || shop.key}</div>
      <div class="admin-shop-pick-card__meta">
        Key: <code>${shop.key}</code><br>
        Map index: ${shop.illeniumStoreIndex || '—'}<br>
        Tiền: ${currencyLabel(shop.currency)}<br>
        Đang bán: <strong>${total}</strong> món
      </div>
    `;
    card.onclick = () => showManageStep(shop.key);
    adminShopPickGrid.appendChild(card);
  });
}

function pickDefaultCategory() {
  const shopKey = adminState.shopKey || 'clothing_normal';
  const gender = adminState.gender || 'male';
  if (listingCountFor(shopKey, gender, 'all') > 0) {
    adminState.category = 'all';
    return;
  }
  for (const c of metaCategories()) {
    if (listingCountFor(shopKey, gender, c.id) > 0) {
      adminState.category = c.id;
      return;
    }
  }
  adminState.category = 'all';
}

function isMaskCategory() {
  return adminState.category === 'mask';
}

function updateMaskFeatureVisibility() {
  const show = isMaskCategory();
  if (adminPickerMaskFeatures) {
    adminPickerMaskFeatures.classList.toggle('hidden', !show);
  }
}

function buildMaskFeatureFields(container, row) {
  if (!isMaskCategory()) return;

  const wrap = document.createElement('div');
  wrap.className = 'admin-mask-features';

  const hideNametag = document.createElement('label');
  hideNametag.className = 'admin-check';
  const cbNametag = document.createElement('input');
  cbNametag.type = 'checkbox';
  cbNametag.checked = !!row.hideNametag;
  hideNametag.appendChild(cbNametag);
  hideNametag.appendChild(document.createTextNode(' Ẩn danh (ẩn name tag với người khác)'));

  const hideHair = document.createElement('label');
  hideHair.className = 'admin-check';
  const cbHair = document.createElement('input');
  cbHair.type = 'checkbox';
  cbHair.checked = !!row.hideHair;
  hideHair.appendChild(cbHair);
  hideHair.appendChild(document.createTextNode(' Không tóc (ẩn tóc khi đeo)'));

  wrap.appendChild(hideNametag);
  wrap.appendChild(hideHair);
  container.appendChild(wrap);

  return { cbNametag, cbHair };
}

function fmtMoney(n) {
  return new Intl.NumberFormat('de-DE').format(Math.floor(Number(n) || 0)) + '$';
}

async function loadShopSettings() {
  if (!adminShopSettings) return;
  const res = await post('adminShopSettings', {});
  if (!res || !res.ok) {
    adminShopSettings.innerHTML = '<p class="admin-status">Không tải được cài shop.</p>';
    return;
  }
  adminState.shopSettings = Array.isArray(res.shops) ? res.shops : [];
  const currencies = Array.isArray(res.currencies) ? res.currencies : [
    { id: 'cash', label: 'Cash / Bank ($)' },
    { id: 'v_medal', label: 'V Medal' },
  ];
  adminShopSettings.innerHTML = '';
  adminState.shopSettings.forEach((shop) => {
    const row = document.createElement('div');
    row.className = 'admin-shop-row';
    const title = document.createElement('strong');
    title.textContent = shop.title || shop.key;
    const key = document.createElement('div');
    key.className = 'admin-shop-key';
    key.textContent = shop.key;
    const label = document.createElement('label');
    label.textContent = 'Loại tiền thanh toán';
    label.style.fontSize = '12px';
    label.style.color = 'var(--adm-muted)';
    const sel = document.createElement('select');
    currencies.forEach((c) => {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = c.label;
      if (c.id === shop.currency) opt.selected = true;
      sel.appendChild(opt);
    });
    sel.addEventListener('change', async () => {
      setAdminStatus('Đang lưu tiền tệ...', '');
      const save = await post('adminSetShopCurrency', { key: shop.key, currency: sel.value });
      if (!save || !save.ok) {
        setAdminStatus(save && save.msg ? save.msg : 'Lưu thất bại', 'err');
        await loadShopSettings();
        return;
      }
      setAdminStatus('Đã lưu currency shop.', 'ok');
      if (Array.isArray(save.shops)) adminState.shopSettings = save.shops;
    });
    row.appendChild(title);
    row.appendChild(key);
    row.appendChild(label);
    row.appendChild(sel);
    adminShopSettings.appendChild(row);
  });
}

function setAdminPanel(panel) {
  adminState.panel = panel === 'settings' ? 'settings' : 'listings';
  if (adminMainTabs) {
    adminMainTabs.querySelectorAll('.admin-tab').forEach((btn) => {
      btn.classList.toggle('is-active', btn.dataset.panel === adminState.panel);
    });
  }
  if (adminPanelSettings) adminPanelSettings.classList.toggle('hidden', adminState.panel !== 'settings');
  if (adminPageTitle) {
    adminPageTitle.textContent = adminState.panel === 'settings'
      ? 'Cài đặt shop'
      : (adminState.step === 'pickShop' ? 'Chọn shop' : 'Danh sách bán shop');
  }
  if (adminState.panel === 'settings') {
    if (adminPanelPickShop) adminPanelPickShop.classList.add('hidden');
    if (adminPanelListings) adminPanelListings.classList.add('hidden');
    if (adminListingNav) adminListingNav.classList.add('hidden');
    loadShopSettings();
    return;
  }
  if (adminState.step === 'manage' && adminState.shopKey) {
    if (adminPanelPickShop) adminPanelPickShop.classList.add('hidden');
    if (adminPanelListings) adminPanelListings.classList.remove('hidden');
    if (adminListingNav) adminListingNav.classList.remove('hidden');
  } else {
    showShopPickStep();
  }
}

async function openAdmin() {
  adminState.open = true;
  if (adminApp) adminApp.classList.remove('hidden');
  setAdminStatus('Đang tải...', '');
  const ok = await loadMeta();
  if (!ok) return;
  setAdminPanel('listings');
}

const DEFAULT_IMAGE_BASE = 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/';

function normalizeImageBase(base) {
  let b = String(base || '').trim();
  if (!b) b = DEFAULT_IMAGE_BASE;
  if (!b.endsWith('/')) b += '/';
  return b;
}

function setAdminStatus(msg, kind) {
  if (!adminStatus) return;
  adminStatus.textContent = msg || '';
  adminStatus.className = 'admin-status' + (kind ? ` ${kind}` : '');
}

function rarityMeta(id) {
  const list = (adminState.meta && adminState.meta.rarities) || [];
  return list.find((r) => r.id === id) || { id: id || 'common', label: id || 'Thường', color: '#94a3b8' };
}

function defaultPriceForCategory(category) {
  const p = adminState.meta && adminState.meta.defaultPrices && adminState.meta.defaultPrices[category];
  return Math.floor(Number(p) || 100);
}

function bindImage(img, url, fallbackEl, imageKey) {
  img.alt = '';
  img.draggable = false;

  const candidates = [];
  if (url) candidates.push(url);
  if (imageKey) {
    const base = normalizeImageBase((adminState.meta && adminState.meta.imageBase) || '');
    candidates.push(base + imageKey + '.png');
    candidates.push(base + imageKey + '.webp');
  }

  if (!candidates.length) {
    img.hidden = true;
    if (fallbackEl) fallbackEl.hidden = false;
    return;
  }

  let idx = 0;
  const tryNext = () => {
    if (idx >= candidates.length) {
      img.hidden = true;
      if (fallbackEl) fallbackEl.hidden = false;
      return;
    }
    img.onload = () => {
      img.hidden = false;
      if (fallbackEl) fallbackEl.hidden = true;
    };
    img.onerror = () => {
      idx += 1;
      tryNext();
    };
    img.src = candidates[idx];
  };
  tryNext();
}

function shopTitle(key) {
  return (shopMeta(key) && shopMeta(key).title) || key;
}

function renderGenderTabs() {
  if (!adminGenderTabs) return;
  adminGenderTabs.innerHTML = '';
  const genders = (adminState.meta && adminState.meta.genders) || [
    { id: 'male', label: 'Nam' },
    { id: 'female', label: 'Nữ' },
  ];
  genders.forEach((g) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-tab ${g.id === adminState.gender ? 'is-active' : ''}`;
    b.textContent = g.label;
    b.onclick = () => {
      adminState.gender = g.id;
      adminState.pickerSelected = null;
      if (adminPickerAdd) adminPickerAdd.disabled = true;
      pickDefaultCategory();
      renderGenderTabs();
      renderCategoryTabs();
      renderPickerGenderTabs();
      loadRows();
    };
    adminGenderTabs.appendChild(b);
  });
}

function renderCategoryTabs() {
  if (!adminCategoryTabs) return;
  adminCategoryTabs.innerHTML = '';
  const shopKey = adminState.shopKey || 'clothing_normal';
  const gender = adminState.gender || 'male';
  const cats = metaCategories();
  if (!adminState.category) adminState.category = 'all';

  const allBtn = document.createElement('button');
  allBtn.type = 'button';
  const allCount = listingCountFor(shopKey, gender, 'all');
  allBtn.className = `admin-subtab ${adminState.category === 'all' ? 'is-active' : ''}`;
  allBtn.textContent = `Tất cả (${allCount})`;
  allBtn.onclick = () => {
    adminState.category = 'all';
    updateMaskFeatureVisibility();
    loadRows();
    renderCategoryTabs();
  };
  adminCategoryTabs.appendChild(allBtn);

  cats.forEach((c) => {
    const n = listingCountFor(shopKey, gender, c.id);
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-subtab ${c.id === adminState.category ? 'is-active' : ''}`;
    b.textContent = n > 0 ? `${c.label} (${n})` : c.label;
    b.onclick = () => {
      adminState.category = c.id;
      updateMaskFeatureVisibility();
      loadRows();
      renderCategoryTabs();
    };
    adminCategoryTabs.appendChild(b);
  });
}

function buildRaritySelect(selectEl, value) {
  if (!selectEl) return;
  selectEl.innerHTML = '';
  const list = (adminState.meta && adminState.meta.rarities) || [];
  list.forEach((r) => {
    const opt = document.createElement('option');
    opt.value = r.id;
    opt.textContent = r.label;
    selectEl.appendChild(opt);
  });
  selectEl.value = value || 'common';
}

function renderRows() {
  if (!adminGrid) return;
  adminGrid.innerHTML = '';
  const q = String(adminState.listQuery || '').trim().toLowerCase();
  let rows = adminState.rows || [];
  if (q) {
    rows = rows.filter((row) => {
      const hay = [
        row.label,
        row.itemName,
        row.category,
        row.categoryLabel,
        row.drawable,
        row.texture,
      ].join(' ').toLowerCase();
      return hay.includes(q);
    });
  }
  if (!rows.length) {
    const empty = document.createElement('div');
    empty.className = 'admin-empty';
    const total = listingCountFor(adminState.shopKey, adminState.gender, 'all');
    if (total > 0 && adminState.category !== 'all') {
      empty.textContent = `Không có món trong danh mục "${categoryLabel(adminState.category)}". Thử tab "Tất cả" hoặc đổi giới tính.`;
    } else if (total > 0 && q) {
      empty.textContent = 'Không khớp từ khóa tìm kiếm.';
    } else {
      empty.textContent = `Chưa có món trong ${shopTitle(adminState.shopKey)}. Cấu hình đồ ở /clothingconfigadmin rồi bấm "Thêm món".`;
    }
    adminGrid.appendChild(empty);
    return;
  }

  rows.forEach((row) => {
    const card = document.createElement('div');
    card.className = `admin-card ${row.enabled ? '' : 'is-disabled'}`;

    const thumb = document.createElement('div');
    thumb.className = 'admin-card__thumb';
    const img = document.createElement('img');
    img.className = 'admin-card__img';
    const fb = document.createElement('div');
    fb.className = 'admin-card__fallback';
    fb.textContent = '👕';
    bindImage(img, row.image, fb, row.imageKey);
    thumb.appendChild(img);
    thumb.appendChild(fb);

    const title = document.createElement('div');
    title.className = 'admin-card__title';
    title.textContent = row.label || row.itemName || `#${row.drawable}`;

    const meta = document.createElement('div');
    meta.className = 'admin-card__meta';
    const catHint = adminState.category === 'all' ? `${categoryLabel(row.category)} · ` : '';
    meta.textContent = `${catHint}${row.drawable}/${row.texture} · ${row.itemName || ''}`;

    const rarity = rarityMeta(row.rarity);
    const badge = document.createElement('span');
    badge.className = 'admin-rarity';
    badge.style.color = rarity.color;
    badge.textContent = rarity.label;

    const priceRow = document.createElement('div');
    priceRow.className = 'admin-card__row';
    const priceInput = document.createElement('input');
    priceInput.type = 'number';
    priceInput.min = '0';
    priceInput.placeholder = 'Giá bán ($)';
    priceInput.value = String(row.price || 0);
    priceRow.appendChild(priceInput);

    const configHint = document.createElement('div');
    configHint.className = 'admin-card__meta';
    configHint.textContent = 'Tên/hiếm chỉnh ở /clothingconfigadmin';

    const actions = document.createElement('div');
    actions.className = 'admin-card__actions';

    const btnSave = document.createElement('button');
    btnSave.className = 'admin-btn admin-btn--primary';
    btnSave.textContent = 'Lưu';
    btnSave.onclick = async () => {
      const res = await post('adminUpsert', {
        id: row.id,
        price: Number(priceInput.value) || 0,
        enabled: row.enabled !== false,
      });
      setAdminStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
      if (res && res.ok) loadRows();
    };

    const btnToggle = document.createElement('button');
    btnToggle.className = 'admin-btn';
    btnToggle.textContent = row.enabled ? 'Tắt' : 'Bật';
    btnToggle.onclick = async () => {
      const res = await post('adminToggle', { id: row.id, enabled: !row.enabled });
      setAdminStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
      if (res && res.ok) loadRows();
    };

    const btnDelete = document.createElement('button');
    btnDelete.className = 'admin-btn admin-btn--danger';
    btnDelete.textContent = 'Xóa';
    btnDelete.onclick = async () => {
      const res = await post('adminDelete', { id: row.id });
      setAdminStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
      if (res && res.ok) loadRows();
    };

    actions.appendChild(btnSave);
    actions.appendChild(btnToggle);
    actions.appendChild(btnDelete);

    card.appendChild(thumb);
    card.appendChild(title);
    card.appendChild(meta);
    card.appendChild(badge);
    card.appendChild(configHint);
    card.appendChild(priceRow);
    card.appendChild(actions);
    adminGrid.appendChild(card);
  });
}

async function loadMeta() {
  const res = await post('adminMeta');
  if (!res || !res.ok) {
    setAdminStatus('Không tải được cấu hình admin.', 'err');
    return false;
  }
  adminState.meta = res;
  buildRaritySelect(adminPickerRarity, 'common');
  return true;
}

async function loadRows() {
  if (!adminState.shopKey) {
    adminState.rows = [];
    renderRows();
    return;
  }
  const res = await post('adminList', {
    shopKey: adminState.shopKey,
    gender: adminState.gender,
    category: adminState.category,
  });
  if (!res || !res.ok) {
    setAdminStatus((res && res.msg) || 'Lỗi tải danh sách.', 'err');
    adminState.rows = [];
  } else {
    adminState.rows = res.rows || [];
    const total = listingCountFor(adminState.shopKey, adminState.gender, 'all');
    const shown = adminState.category === 'all'
      ? adminState.rows.length
      : listingCountFor(adminState.shopKey, adminState.gender, adminState.category);
    const catPart = adminState.category === 'all' ? 'Tất cả' : categoryLabel(adminState.category);
    setAdminStatus(
      `${shown} món · ${shopTitle(adminState.shopKey)} · ${adminState.gender === 'female' ? 'Nữ' : 'Nam'} · ${catPart}${total !== shown ? ` (shop có ${total} món)` : ''}.`,
      'ok'
    );
  }
  renderCategoryTabs();
  renderRows();
}

function closePicker() {
  if (!adminPicker) return;
  adminPicker.classList.add('hidden');
  adminState.pickerSelected = null;
  adminState.pickerItems = [];
  if (adminPickerAdd) adminPickerAdd.disabled = true;
}

function renderPickerGenderTabs() {
  if (!adminPickerGenderTabs) return;
  adminPickerGenderTabs.innerHTML = '';
  const genders = (adminState.meta && adminState.meta.genders) || [
    { id: 'male', label: 'Nam' },
    { id: 'female', label: 'Nữ' },
  ];
  genders.forEach((g) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-tab ${g.id === adminState.gender ? 'is-active' : ''}`;
    b.textContent = g.label;
    b.onclick = () => {
      adminState.gender = g.id;
      adminState.pickerSelected = null;
      if (adminPickerAdd) adminPickerAdd.disabled = true;
      renderPickerGenderTabs();
      loadPickerItems();
    };
    adminPickerGenderTabs.appendChild(b);
  });
}

function renderPickerCategoryTabs() {
  if (!adminPickerCategoryTabs) return;
  adminPickerCategoryTabs.innerHTML = '';
  const cats = metaCategories();
  if (adminState.category === 'all' && cats[0]) {
    adminState.category = cats[0].id;
  }
  cats.forEach((c) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-subtab ${c.id === adminState.category ? 'is-active' : ''}`;
    b.textContent = c.label;
    b.onclick = () => {
      adminState.category = c.id;
      adminState.pickerSelected = null;
      if (adminPickerAdd) adminPickerAdd.disabled = true;
      if (adminPickerPrice) {
        adminPickerPrice.value = String(defaultPriceForCategory(adminState.category));
      }
      updateMaskFeatureVisibility();
      renderPickerCategoryTabs();
      loadPickerItems();
    };
    adminPickerCategoryTabs.appendChild(b);
  });
}

async function openPicker() {
  if (!adminState.shopKey) {
    setAdminStatus('Chọn shop trước khi thêm món.', 'err');
    return;
  }
  if (!adminPicker) return;
  const pickerHint = document.getElementById('adminPickerShopHint');
  if (pickerHint) {
    pickerHint.textContent = `Thêm vào: ${shopTitle(adminState.shopKey)} — món lấy từ /clothingconfigadmin`;
  }
  adminPicker.classList.remove('hidden');
  adminState.pickerSelected = null;
  adminState.pickerQuery = '';
  if (adminPickerSearch) adminPickerSearch.value = '';
  if (adminPickerLabel) adminPickerLabel.value = '';
  if (adminPickerHideNametag) adminPickerHideNametag.checked = false;
  if (adminPickerHideHair) adminPickerHideHair.checked = false;
  if (adminPickerPrice) adminPickerPrice.value = String(defaultPriceForCategory(adminState.category));
  buildRaritySelect(adminPickerRarity, 'common');
  updateMaskFeatureVisibility();
  renderPickerGenderTabs();
  renderPickerCategoryTabs();
  await loadPickerItems();
}

async function loadPickerItems() {
  const res = await post('adminBrowse', {
    shopKey: adminState.shopKey,
    gender: adminState.gender,
    category: adminState.category,
    query: adminState.pickerQuery,
  });
  if (!res || !res.ok) {
    adminState.pickerItems = [];
    if (adminPickerCount) {
      adminPickerCount.textContent = (res && res.msg) || 'Lỗi tải catalog';
    }
    renderPickerGrid();
    return;
  }
  adminState.pickerItems = res.items || [];
  renderPickerGrid();
}

function renderPickerGrid() {
  if (!adminPickerGrid) return;
  adminPickerGrid.innerHTML = '';
  const items = adminState.pickerItems || [];
  if (adminPickerCount) {
    adminPickerCount.textContent = items.length
      ? `${items.length} món khả dụng`
      : '0 món — cấu hình ở /clothingconfigadmin trước, hoặc đổi giới tính/danh mục';
  }

  if (!items.length) {
    const empty = document.createElement('div');
    empty.className = 'admin-empty';
    empty.textContent = 'Không có món nào để thêm (đã hết hoặc chưa cấu hình catalog).';
    adminPickerGrid.appendChild(empty);
    return;
  }

  items.forEach((it) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `admin-picker__item ${adminState.pickerSelected && adminState.pickerSelected.name === it.name ? 'is-selected' : ''}`;

    const img = document.createElement('img');
    img.style.width = '100%';
    img.style.height = '90px';
    img.style.objectFit = 'contain';
    bindImage(img, it.image, null, it.imageKey);

    const title = document.createElement('div');
    title.style.fontSize = '12px';
    title.style.marginTop = '6px';
    title.textContent = it.label || it.name;

    const sub = document.createElement('div');
    sub.style.fontSize = '10px';
    sub.style.opacity = '0.65';
    sub.textContent = `${it.drawable}/${it.texture}`;

    btn.appendChild(img);
    btn.appendChild(title);
    btn.appendChild(sub);
    btn.onclick = () => {
      adminState.pickerSelected = it;
      if (adminPickerPrice) {
        adminPickerPrice.value = String(defaultPriceForCategory(adminState.category));
      }
      if (adminPickerAdd) adminPickerAdd.disabled = false;
      renderPickerGrid();
    };
    adminPickerGrid.appendChild(btn);
  });
}

async function addSelectedPickerItem() {
  const it = adminState.pickerSelected;
  if (!it) return;
  const payload = {
    shopKey: adminState.shopKey,
    clothingItemId: it.clothingItemId,
    price: Number(adminPickerPrice && adminPickerPrice.value) || defaultPriceForCategory(adminState.category),
    enabled: true,
  };
  const res = await post('adminUpsert', payload);
  setAdminStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
  if (res && res.ok) {
    closePicker();
    loadRows();
  }
}

function closeAdmin() {
  adminState.open = false;
  closePicker();
  if (adminApp) adminApp.classList.add('hidden');
  post('adminClose', {});
}

if (adminBtnClose) adminBtnClose.onclick = closeAdmin;
if (adminBtnAdd) adminBtnAdd.onclick = openPicker;
if (adminBtnRefresh) adminBtnRefresh.onclick = loadRows;
if (adminBtnChangeShop) adminBtnChangeShop.onclick = () => showShopPickStep();
if (adminSearch) {
  adminSearch.disabled = false;
  adminSearch.placeholder = 'Tìm tên / drawable / item key...';
  adminSearch.addEventListener('input', () => {
    adminState.listQuery = adminSearch.value || '';
    renderRows();
  });
}
if (adminMainTabs) {
  adminMainTabs.querySelectorAll('.admin-tab').forEach((btn) => {
    btn.addEventListener('click', () => setAdminPanel(btn.dataset.panel));
  });
}
if (adminPickerClose) adminPickerClose.onclick = closePicker;
if (adminPickerAdd) adminPickerAdd.onclick = addSelectedPickerItem;
if (adminPickerSearch) {
  adminPickerSearch.addEventListener('input', () => {
    adminState.pickerQuery = adminPickerSearch.value || '';
    loadPickerItems();
  });
}

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && adminState.open) {
    if (adminPicker && !adminPicker.classList.contains('hidden')) closePicker();
    else closeAdmin();
  }
});

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'openAdmin') openAdmin();
  else if (d.action === 'closeAdmin') {
    adminState.open = false;
    if (adminApp) adminApp.classList.add('hidden');
    closePicker();
  }
});
