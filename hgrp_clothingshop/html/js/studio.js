const configApp = document.getElementById('configApp');
const studioGenderTabs = document.getElementById('studioGenderTabs');
const studioCategoryTabs = document.getElementById('studioCategoryTabs');
const studioStatusFilters = document.getElementById('studioStatusFilters');
const studioSearch = document.getElementById('studioSearch');
const studioList = document.getElementById('studioList');
const studioStatus = document.getElementById('studioStatus');
const studioBtnAdd = document.getElementById('studioBtnAdd');
const studioBtnClose = document.getElementById('studioBtnClose');
const studioRotL = document.getElementById('studioRotL');
const studioRotR = document.getElementById('studioRotR');
const studioCamPresets = document.getElementById('studioCamPresets');
const studioFormTitle = document.getElementById('studioFormTitle');
const studioFormEmpty = document.getElementById('studioFormEmpty');
const studioForm = document.getElementById('studioForm');
const studioLabel = document.getElementById('studioLabel');
const studioRarity = document.getElementById('studioRarity');
const studioImageKey = document.getElementById('studioImageKey');
const studioDisplayType = document.getElementById('studioDisplayType');
const studioItemTag = document.getElementById('studioItemTag');
const studioEnabled = document.getElementById('studioEnabled');
const studioMaskFeatures = document.getElementById('studioMaskFeatures');
const studioHideNametag = document.getElementById('studioHideNametag');
const studioHideHair = document.getElementById('studioHideHair');
const studioCompSection = document.getElementById('studioCompSection');
const studioCompRows = document.getElementById('studioCompRows');
const studioBtnIllenium = document.getElementById('studioBtnIllenium');
const studioBtnRefresh = document.getElementById('studioBtnRefresh');
const studioBtnDelete = document.getElementById('studioBtnDelete');
const configPicker = document.getElementById('configPicker');
const configPickerGrid = document.getElementById('configPickerGrid');
const configPickerSearch = document.getElementById('configPickerSearch');
const configPickerClose = document.getElementById('configPickerClose');
const configPickerSave = document.getElementById('configPickerSave');
const configPickerCount = document.getElementById('configPickerCount');
const configPickerLabel = document.getElementById('configPickerLabel');
const configPickerRarity = document.getElementById('configPickerRarity');
const configPickerMaskFeatures = document.getElementById('configPickerMaskFeatures');
const configPickerHideNametag = document.getElementById('configPickerHideNametag');
const configPickerHideHair = document.getElementById('configPickerHideHair');

const studioState = {
  open: false,
  meta: null,
  gender: 'male',
  category: 'jacket',
  statusFilter: 'all',
  searchQuery: '',
  rows: [],
  selectedId: null,
  draft: null,
  componentState: {},
  componentSettings: {},
  wearComponentId: null,
  pickerItems: [],
  pickerSelected: null,
  pickerQuery: '',
  camPreset: 'chest',
};

const CAM_PRESETS = [
  { id: 'head', label: 'Đầu' },
  { id: 'chest', label: 'Ngực' },
  { id: 'pelvis', label: 'Hông' },
  { id: 'feet', label: 'Chân' },
];

function resName() {
  return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'hgrp_clothingshop';
}

function post(name, data = {}) {
  return fetch(`https://${resName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => null);
}

function setStudioStatus(msg, kind) {
  if (!studioStatus) return;
  studioStatus.textContent = msg || '';
  studioStatus.className = 'admin-status' + (kind ? ` ${kind}` : '');
}

function isMaskCategory() {
  return studioState.category === 'mask';
}

function rarityMeta(id) {
  const list = (studioState.meta && studioState.meta.rarities) || [];
  return list.find((r) => r.id === id) || { id: id || 'common', label: id || 'Thường', color: '#94a3b8' };
}

function categoryLabel(id) {
  const cats = (studioState.meta && studioState.meta.categories) || [];
  const hit = cats.find((c) => c.id === id);
  return (hit && hit.label) || id || '';
}

function buildRaritySelect(el, value) {
  if (!el) return;
  el.innerHTML = '';
  const list = (studioState.meta && studioState.meta.rarities) || [];
  list.forEach((r) => {
    const opt = document.createElement('option');
    opt.value = r.id;
    opt.textContent = r.label;
    el.appendChild(opt);
  });
  el.value = value || 'common';
}

function buildItemTagSelect(el, value) {
  if (!el) return;
  el.innerHTML = '';
  const blank = document.createElement('option');
  blank.value = '';
  blank.textContent = '— Tự động —';
  el.appendChild(blank);
  const list = (studioState.meta && studioState.meta.itemTags) || [];
  list.forEach((t) => {
    const opt = document.createElement('option');
    opt.value = t.id;
    opt.textContent = t.label;
    el.appendChild(opt);
  });
  el.value = value || '';
}

function buildDisplayTypeSelect(el, value) {
  if (!el) return;
  el.innerHTML = '';
  const cats = (studioState.meta && studioState.meta.categories) || [];
  cats.forEach((c) => {
    const opt = document.createElement('option');
    opt.value = c.id;
    opt.textContent = c.label;
    el.appendChild(opt);
  });
  el.value = value || studioState.category;
}

function isSimpleCategory() {
  const cats = (studioState.meta && studioState.meta.categories) || [];
  const hit = cats.find((c) => c.id === studioState.category);
  return !!(hit && hit.simple);
}

function updateMaskVisibility() {
  const showMask = isMaskCategory();
  const simple = isSimpleCategory();
  if (studioMaskFeatures) studioMaskFeatures.classList.toggle('hidden', !showMask);
  if (studioCompSection) studioCompSection.classList.toggle('hidden', showMask || simple);
  if (configPickerMaskFeatures) configPickerMaskFeatures.classList.toggle('hidden', !showMask);
}

const WEAR_BY_CATEGORY = { face: 0, mask: 1, hands: 3, jacket: 11, undershirt: 8, pants: 4, shoes: 6, bag: 5 };

function getComponentSlots() {
  return (studioState.meta && (studioState.meta.componentSlots || studioState.meta.extraSlots)) || [
    { id: 0, key: 'face', label: 'Comp 0 · Đầu / Face' },
    { id: 1, key: 'mask', label: 'Comp 1 · Khẩu trang' },
    { id: 3, key: 'torso', label: 'Comp 3 · Tay / thân trên' },
    { id: 4, key: 'legs', label: 'Comp 4 · Quần / chân' },
    { id: 5, key: 'bag', label: 'Comp 5 · Balo' },
    { id: 6, key: 'shoes', label: 'Comp 6 · Giày' },
    { id: 7, key: 'chains', label: 'Comp 7 · Cổ / phụ kiện' },
    { id: 8, key: 'undershirt', label: 'Comp 8 · Áo trong' },
    { id: 9, key: 'armor', label: 'Comp 9 · Giáp' },
    { id: 10, key: 'decals', label: 'Comp 10 · Decal' },
    { id: 11, key: 'jacket', label: 'Comp 11 · Áo khoác' },
  ];
}

function resolveWearComponentId(item) {
  if (item && item.wearComponentId != null) return item.wearComponentId;
  return WEAR_BY_CATEGORY[studioState.category] || 11;
}

function initComponentState(item) {
  const wearId = resolveWearComponentId(item);
  studioState.wearComponentId = wearId;
  const state = {};
  const extras = item.extraComponents || [];
  getComponentSlots().forEach((slot) => {
    const isWear = slot.id === wearId;
    const extra = extras.find((e) => e.id === slot.id);
    state[slot.id] = {
      enabled: isWear || !!extra,
      locked: isWear,
      drawable: isWear ? (item.drawable ?? 0) : (extra ? extra.drawable : 0),
      texture: isWear ? (item.texture ?? 0) : (extra ? (extra.texture || 0) : 0),
      key: slot.key,
      label: slot.label,
    };
  });
  studioState.componentState = state;
  studioState.componentSettings = {};
}

async function fetchComponentSettings(componentId) {
  const res = await post('configComponentSettings', { componentId });
  if (res && res.ok && res.settings) {
    studioState.componentSettings[componentId] = res.settings;
    return res.settings;
  }
  return studioState.componentSettings[componentId] || null;
}

function createStepper(label, value, min, max, disabled, onChange) {
  const wrap = document.createElement('div');
  wrap.className = 'studio-stepper';
  const lbl = document.createElement('div');
  lbl.className = 'studio-stepper__label';
  lbl.textContent = label;
  const btnPrev = document.createElement('button');
  btnPrev.type = 'button';
  btnPrev.className = 'studio-stepper__btn';
  btnPrev.textContent = '◀';
  const val = document.createElement('div');
  val.className = 'studio-stepper__value';
  const btnNext = document.createElement('button');
  btnNext.type = 'button';
  btnNext.className = 'studio-stepper__btn';
  btnNext.textContent = '▶';

  const render = () => {
    val.textContent = `${value} / ${max}`;
    btnPrev.disabled = disabled || value <= min;
    btnNext.disabled = disabled || value >= max;
  };

  btnPrev.onclick = () => { if (value > min) onChange(value - 1); };
  btnNext.onclick = () => { if (value < max) onChange(value + 1); };
  render();

  wrap.appendChild(lbl);
  wrap.appendChild(btnPrev);
  wrap.appendChild(val);
  wrap.appendChild(btnNext);
  return { wrap, render: (v, mn, mx, dis) => { value = v; min = mn; max = mx; disabled = dis; render(); } };
}

async function applyComponentOnPed(componentId, drawable, texture) {
  const res = await post('configApplyComponent', {
    component_id: componentId,
    drawable,
    texture,
  });
  if (res && res.ok && res.settings) {
    studioState.componentSettings[componentId] = res.settings;
  }
  return res;
}

async function renderComponentRows() {
  if (!studioCompRows) return;
  studioCompRows.innerHTML = '';
  const wearId = studioState.wearComponentId;

  for (const slot of getComponentSlots()) {
    const st = studioState.componentState[slot.id] || {
      enabled: false, locked: false, drawable: 0, texture: 0, key: slot.key, label: slot.label,
    };
    studioState.componentState[slot.id] = st;

    const block = document.createElement('div');
    block.className = `studio-comp-block ${slot.id === wearId ? 'is-wear' : ''}`;

    const title = document.createElement('div');
    title.className = 'studio-comp-block__title';
    const cbWrap = document.createElement('label');
    cbWrap.className = 'admin-check';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = !!st.enabled;
    cb.disabled = !!st.locked;
    cbWrap.appendChild(cb);
    title.appendChild(cbWrap);
    const titleText = document.createElement('span');
    titleText.textContent = slot.label;
    title.appendChild(titleText);
    if (st.locked) {
      const badge = document.createElement('span');
      badge.className = 'studio-comp-block__badge';
      badge.textContent = 'Mặc chính';
      title.appendChild(badge);
    }
    block.appendChild(title);

    let settings = await fetchComponentSettings(slot.id);
    if (!settings) {
      settings = {
        drawable: { min: 0, max: 0 },
        texture: { min: 0, max: 0 },
      };
    }

    let drawStep = createStepper(
      'Drawable',
      st.drawable,
      settings.drawable.min,
      settings.drawable.max,
      !st.enabled,
      async (next) => {
        st.drawable = next;
        st.texture = 0;
        const res = await applyComponentOnPed(slot.id, st.drawable, 0);
        if (res && res.settings) {
          drawStep.render(st.drawable, res.settings.drawable.min, res.settings.drawable.max, !st.enabled);
          texStep.render(0, res.settings.texture.min, res.settings.texture.max, !st.enabled);
        }
      },
    );

    let texStep = createStepper(
      'Texture',
      st.texture,
      settings.texture.min,
      settings.texture.max,
      !st.enabled,
      async (next) => {
        st.texture = next;
        const res = await applyComponentOnPed(slot.id, st.drawable, st.texture);
        if (res && res.settings) {
          texStep.render(st.texture, res.settings.texture.min, res.settings.texture.max, !st.enabled);
        }
      },
    );

    cb.onchange = async () => {
      if (st.locked) return;
      st.enabled = cb.checked;
      drawStep.render(st.drawable, settings.drawable.min, settings.drawable.max, !st.enabled);
      texStep.render(st.texture, settings.texture.min, settings.texture.max, !st.enabled);
      if (st.enabled) {
        await applyComponentOnPed(slot.id, st.drawable, st.texture);
      }
      pushPreview();
    };

    block.appendChild(drawStep.wrap);
    block.appendChild(texStep.wrap);
    studioCompRows.appendChild(block);
  }
}

function collectExtraComponents() {
  const wearId = studioState.wearComponentId;
  const out = [];
  Object.keys(studioState.componentState).forEach((k) => {
    const id = Number(k);
    const st = studioState.componentState[k];
    if (!st || !st.enabled || id === wearId) return;
    out.push({
      id,
      slot: st.key,
      drawable: Number(st.drawable) || 0,
      texture: Number(st.texture) || 0,
      palette: 0,
    });
  });
  return out;
}

function getWearValues() {
  const wearId = studioState.wearComponentId;
  const st = studioState.componentState[wearId];
  return {
    drawable: st ? Number(st.drawable) || 0 : 0,
    texture: st ? Number(st.texture) || 0 : 0,
  };
}

function buildPreviewPayload() {
  const wear = getWearValues();
  return {
    wearComponentId: studioState.wearComponentId,
    drawable: wear.drawable,
    texture: wear.texture,
    extraComponents: collectExtraComponents(),
    category: studioState.category,
  };
}

function importIlleniumComponents(components) {
  if (!Array.isArray(components) || !studioState.draft) return;
  const wearId = studioState.wearComponentId;
  const map = {};
  components.forEach((row) => {
    if (row && row.component_id != null) map[row.component_id] = row;
  });

  getComponentSlots().forEach((slot) => {
    const row = map[slot.id];
    const isWear = slot.id === wearId;
    const st = studioState.componentState[slot.id] || {};
    st.key = slot.key;
    st.label = slot.label;
    st.locked = isWear;
    if (row) {
      st.enabled = true;
      st.drawable = row.drawable;
      st.texture = row.texture || 0;
    } else if (!isWear) {
      st.enabled = false;
    }
    studioState.componentState[slot.id] = st;
  });

  const wearRow = map[wearId];
  if (wearRow && studioState.draft) {
    studioState.draft.drawable = wearRow.drawable;
    studioState.draft.texture = wearRow.texture || 0;
  }

  renderComponentRows();
  pushPreview();
  setStudioStatus('Đã import component từ Illenium.', 'ok');
}

async function openIlleniumEditor() {
  if (!studioState.draft) return;
  await post('configPreview', buildPreviewPayload());
  const res = await post('configOpenIllenium', {});
  if (res && !res.ok) setStudioStatus((res && res.msg) || 'Không mở được Illenium.', 'err');
}

function filterRows(rows) {
  let out = rows || [];
  if (studioState.statusFilter === 'enabled') out = out.filter((r) => r.enabled !== false);
  if (studioState.statusFilter === 'disabled') out = out.filter((r) => r.enabled === false);
  const q = (studioState.searchQuery || '').trim().toLowerCase();
  if (q) {
    out = out.filter((r) => {
      const hay = [r.label, r.imageKey, r.drawable, r.texture].filter(Boolean).join(' ').toLowerCase();
      return hay.includes(q);
    });
  }
  return out;
}

function renderGenderTabs() {
  if (!studioGenderTabs) return;
  studioGenderTabs.innerHTML = '';
  const genders = (studioState.meta && studioState.meta.genders) || [];
  genders.forEach((g) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-tab ${g.id === studioState.gender ? 'is-active' : ''}`;
    b.textContent = g.label;
    b.onclick = () => {
      studioState.gender = g.id;
      studioState.selectedId = null;
      studioState.draft = null;
      renderGenderTabs();
      loadProfiles();
      clearForm();
    };
    studioGenderTabs.appendChild(b);
  });
}

function renderCategoryTabs() {
  if (!studioCategoryTabs) return;
  studioCategoryTabs.innerHTML = '';
  const cats = (studioState.meta && studioState.meta.categories) || [];
  if (!studioState.category && cats[0]) studioState.category = cats[0].id;
  cats.forEach((c) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `admin-subtab ${c.id === studioState.category ? 'is-active' : ''}`;
    b.textContent = c.label;
    b.onclick = () => {
      studioState.category = c.id;
      studioState.selectedId = null;
      studioState.draft = null;
      updateMaskVisibility();
      renderCategoryTabs();
      loadProfiles();
      clearForm();
      post('configSetCamera', { preset: camPresetForCategory(c.id) });
    };
    studioCategoryTabs.appendChild(b);
  });
}

function camPresetForCategory(cat) {
  const map = { face: 'head', mask: 'head', hat: 'head', shoes: 'feet', pants: 'pelvis', bag: 'chest' };
  return map[cat] || 'chest';
}

function renderStatusFilters() {
  if (!studioStatusFilters) return;
  const opts = [
    { id: 'all', label: 'Tất cả' },
    { id: 'enabled', label: 'Đang bật' },
    { id: 'disabled', label: 'Đã tắt' },
  ];
  studioStatusFilters.innerHTML = '';
  opts.forEach((o) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `studio-filter ${o.id === studioState.statusFilter ? 'is-active' : ''}`;
    b.textContent = o.label;
    b.onclick = () => {
      studioState.statusFilter = o.id;
      renderStatusFilters();
      renderProfileList();
    };
    studioStatusFilters.appendChild(b);
  });
}

function renderProfileList() {
  if (!studioList) return;
  studioList.innerHTML = '';
  const rows = filterRows(studioState.rows);
  if (!rows.length) {
    const empty = document.createElement('div');
    empty.className = 'studio-empty';
    empty.textContent = studioState.rows.length
      ? 'Không có profile khớp bộ lọc.'
      : 'Chưa có profile. Override lua sync khi start — thử tab khác hoặc "+ Profile mới".';
    studioList.appendChild(empty);
    return;
  }

  rows.forEach((row) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `studio-list__item ${row.id === studioState.selectedId ? 'is-active' : ''} ${row.enabled === false ? 'is-disabled' : ''}`;
    const r = rarityMeta(row.rarity);
    btn.innerHTML = `<div class="studio-list__title">${row.label || row.imageKey}</div>
      <div class="studio-list__meta">#${row.drawable}/${row.texture} · ${row.imageKey} · ${r.label}${row.displayType && row.displayType !== row.category ? ' · slot ' + categoryLabel(row.displayType) : ''}</div>`;
    btn.onclick = () => selectProfile(row.id);
    studioList.appendChild(btn);
  });
}

let previewTimer = null;
function pushPreview() {
  if (!studioState.open) return;
  clearTimeout(previewTimer);
  previewTimer = setTimeout(() => {
    post('configPreview', buildPreviewPayload());
  }, 120);
}

function showForm(item) {
  if (!studioForm || !studioFormEmpty) return;
  studioForm.classList.remove('hidden');
  studioFormEmpty.classList.add('hidden');
  if (studioFormTitle) {
    studioFormTitle.textContent = item.label || item.imageKey || 'Profile mới';
  }

  if (studioLabel) studioLabel.value = item.label || '';
  buildRaritySelect(studioRarity, item.rarity || 'common');
  if (studioImageKey) studioImageKey.value = item.imageKey || '';
  buildDisplayTypeSelect(studioDisplayType, item.displayType || item.shopCategory || studioState.category);
  buildItemTagSelect(studioItemTag, item.itemTag || (studioState.category === 'hands' ? 'tattoo' : ''));
  if (studioEnabled) studioEnabled.value = item.enabled === false ? '0' : '1';
  if (studioHideNametag) studioHideNametag.checked = !!item.hideNametag;
  if (studioHideHair) studioHideHair.checked = !!item.hideHair;

  initComponentState(item);
  updateMaskVisibility();
  renderComponentRows().then(() => pushPreview());
}

function clearForm() {
  studioState.selectedId = null;
  studioState.draft = null;
  if (studioForm) studioForm.classList.add('hidden');
  if (studioFormEmpty) studioFormEmpty.classList.remove('hidden');
  if (studioFormTitle) studioFormTitle.textContent = 'Chọn profile';
  post('configPreviewReset', {});
}

async function selectProfile(id) {
  studioState.selectedId = id;
  renderProfileList();
  const res = await post('configGet', { id });
  if (!res || !res.ok || !res.item) {
    setStudioStatus((res && res.msg) || 'Không tải được profile.', 'err');
    return;
  }
  studioState.draft = res.item;
  showForm(res.item);
}

function renderCamPresets() {
  if (!studioCamPresets) return;
  studioCamPresets.innerHTML = '';
  CAM_PRESETS.forEach((p) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `studio-cam-btn ${p.id === studioState.camPreset ? 'is-active' : ''}`;
    b.textContent = p.label;
    b.onclick = () => {
      studioState.camPreset = p.id;
      renderCamPresets();
      post('configSetCamera', { preset: p.id });
    };
    studioCamPresets.appendChild(b);
  });
}

async function loadMeta() {
  const res = await post('configMeta');
  if (!res || !res.ok) {
    setStudioStatus('Không tải được meta.', 'err');
    return false;
  }
  studioState.meta = res;
  if (!studioState.category && res.categories && res.categories[0]) {
    studioState.category = res.categories[0].id;
  }
  buildRaritySelect(studioRarity, 'common');
  buildRaritySelect(configPickerRarity, 'common');
  renderGenderTabs();
  renderCategoryTabs();
  renderStatusFilters();
  renderCamPresets();
  updateMaskVisibility();
  return true;
}

async function loadProfiles() {
  const res = await post('configList', {
    gender: studioState.gender,
    category: studioState.category,
  });
  if (!res || !res.ok) {
    setStudioStatus((res && res.msg) || 'Lỗi tải danh sách.', 'err');
    studioState.rows = [];
  } else {
    studioState.rows = res.rows || [];
    setStudioStatus(`${studioState.rows.length} profile trong tab này.`, 'ok');
  }
  renderProfileList();
}

async function openStudio() {
  studioState.open = true;
  if (configApp) configApp.classList.remove('hidden');
  setStudioStatus('Đang tải...', '');
  const ok = await loadMeta();
  if (!ok) return;
  await loadProfiles();
  post('configStudioOpen', { category: studioState.category });
}

function closeStudio() {
  studioState.open = false;
  closePicker();
  if (configApp) configApp.classList.add('hidden');
  clearForm();
  post('configClose', {});
}

function closePicker() {
  if (!configPicker) return;
  configPicker.classList.add('hidden');
  studioState.pickerSelected = null;
}

async function openPicker() {
  if (!configPicker) return;
  configPicker.classList.remove('hidden');
  studioState.pickerSelected = null;
  studioState.pickerQuery = '';
  if (configPickerSearch) configPickerSearch.value = '';
  if (configPickerSave) configPickerSave.disabled = true;
  await loadPickerItems();
}

async function loadPickerItems() {
  const res = await post('configBrowse', {
    gender: studioState.gender,
    category: studioState.category,
    query: studioState.pickerQuery,
  });
  studioState.pickerItems = (res && res.items) || [];
  studioState.pickerMaxDrawable = res && res.maxDrawable ? Number(res.maxDrawable) : 0;
  studioState.pickerItems.sort((a, b) => {
    const da = Number(a.drawable) || 0;
    const db = Number(b.drawable) || 0;
    if (db !== da) return db - da;
    return (Number(a.texture) || 0) - (Number(b.texture) || 0);
  });
  renderPickerGrid();
}

function renderPickerGrid() {
  if (!configPickerGrid) return;
  configPickerGrid.innerHTML = '';
  const items = studioState.pickerItems || [];
  if (configPickerCount) {
    const maxHint = studioState.pickerMaxDrawable
      ? ` · max #${studioState.pickerMaxDrawable - 1}`
      : '';
    configPickerCount.textContent = items.length
      ? `${items.length} drawable chưa có profile${maxHint}`
      : 'Đã cấu hình hết drawable trong tab này';
  }
  items.forEach((it) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `admin-picker__item ${studioState.pickerSelected && studioState.pickerSelected.name === it.name ? 'is-selected' : ''}`;
    const img = document.createElement('img');
    img.style.width = '100%';
    img.style.height = '90px';
    img.style.objectFit = 'contain';
    if (it.image) img.src = it.image;
    const title = document.createElement('div');
    title.style.fontSize = '12px';
    title.style.marginTop = '6px';
    title.textContent = `${it.label || it.name} · #${it.drawable}/${it.texture}`;
    btn.appendChild(img);
    btn.appendChild(title);
    btn.onclick = () => {
      studioState.pickerSelected = it;
      if (configPickerSave) configPickerSave.disabled = false;
      renderPickerGrid();
    };
    configPickerGrid.appendChild(btn);
  });
}

function applyPickerSelection() {
  const it = studioState.pickerSelected;
  if (!it) return;
  studioState.selectedId = null;
  const draft = {
    id: null,
    gender: studioState.gender,
    category: studioState.category,
    drawable: it.drawable,
    texture: it.texture,
    imageKey: it.name || it.imageKey,
    label: (configPickerLabel && configPickerLabel.value.trim()) || it.label || it.name,
    rarity: (configPickerRarity && configPickerRarity.value) || 'common',
    displayType: studioState.category === 'hands' ? 'jacket' : studioState.category,
    wearComponentId: it.wearComponentId,
    extraComponents: [],
    enabled: true,
    hideNametag: !!(configPickerHideNametag && configPickerHideNametag.checked),
    hideHair: !!(configPickerHideHair && configPickerHideHair.checked),
  };
  studioState.draft = draft;
  closePicker();
  showForm(draft);
}

async function saveProfile(e) {
  if (e) e.preventDefault();
  const draft = studioState.draft;
  if (!draft) return;

  const wear = getWearValues();
  const payload = {
    id: draft.id,
    gender: draft.gender || studioState.gender,
    category: draft.category || studioState.category,
    drawable: wear.drawable,
    texture: wear.texture,
    imageKey: draft.imageKey || (studioImageKey && studioImageKey.value),
    label: (studioLabel && studioLabel.value.trim()) || '',
    rarity: studioRarity && studioRarity.value,
    displayType: (draft.category || studioState.category) === 'hands'
      ? 'jacket'
      : (studioDisplayType && studioDisplayType.value),
    itemTag: studioItemTag && studioItemTag.value ? studioItemTag.value : null,
    wearComponentId: studioState.wearComponentId,
    extraComponents: collectExtraComponents(),
    enabled: studioEnabled && studioEnabled.value === '1',
  };
  if (isMaskCategory()) {
    payload.hideNametag = !!(studioHideNametag && studioHideNametag.checked);
    payload.hideHair = !!(studioHideHair && studioHideHair.checked);
  }

  const res = await post('configUpsert', payload);
  setStudioStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
  if (res && res.ok) {
    await loadProfiles();
    if (res.item && res.item.id) {
      studioState.selectedId = res.item.id;
      studioState.draft = res.item;
      renderProfileList();
      showForm(res.item);
    }
  }
}

async function deleteProfile() {
  const id = studioState.selectedId;
  if (!id) return;
  const res = await post('configDelete', { id });
  setStudioStatus(res && res.msg, res && res.ok ? 'ok' : 'err');
  if (res && res.ok) {
    clearForm();
    await loadProfiles();
  }
}

if (studioForm) studioForm.addEventListener('submit', saveProfile);
if (studioBtnClose) studioBtnClose.onclick = closeStudio;
if (studioBtnAdd) studioBtnAdd.onclick = openPicker;
if (studioBtnRefresh) studioBtnRefresh.onclick = () => {
  if (studioState.selectedId) selectProfile(studioState.selectedId);
  else loadProfiles();
};
if (studioBtnDelete) studioBtnDelete.onclick = deleteProfile;
if (studioBtnIllenium) studioBtnIllenium.onclick = openIlleniumEditor;
if (studioRotL) studioRotL.onclick = () => post('configRotate', { dir: -1 });
if (studioRotR) studioRotR.onclick = () => post('configRotate', { dir: 1 });
if (studioSearch) {
  studioSearch.addEventListener('input', () => {
    studioState.searchQuery = studioSearch.value || '';
    renderProfileList();
  });
}
if (configPickerClose) configPickerClose.onclick = closePicker;
if (configPickerSave) configPickerSave.onclick = applyPickerSelection;
if (configPickerSearch) {
  configPickerSearch.addEventListener('input', () => {
    studioState.pickerQuery = configPickerSearch.value || '';
    loadPickerItems();
  });
}

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && studioState.open) {
    if (configPicker && !configPicker.classList.contains('hidden')) closePicker();
    else closeStudio();
  }
});

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'openConfigAdmin') openStudio();
  else if (d.action === 'closeConfigAdmin') {
    studioState.open = false;
    if (configApp) configApp.classList.add('hidden');
    closePicker();
  } else if (d.action === 'studioHidePanels') {
    if (configApp) configApp.classList.add('is-hidden-panels');
  } else if (d.action === 'studioShowPanels') {
    if (configApp) configApp.classList.remove('is-hidden-panels');
  } else if (d.action === 'illeniumComponentsImported') {
    importIlleniumComponents(d.components);
  }
});
