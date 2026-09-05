const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const genderBadgeEl = document.getElementById('genderBadge');
const tabsEl = document.getElementById('tabs');
const listEl = document.getElementById('list');
const searchEl = document.getElementById('search');
const btnClose = document.getElementById('btnClose');
const btnCancel = document.getElementById('btnCancel');
const btnCheckout = document.getElementById('btnCheckout');
const btnRotL = document.getElementById('btnRotL');
const btnRotR = document.getElementById('btnRotR');
const detailTitle = document.getElementById('detailTitle');
const detailBadge = document.getElementById('detailBadge');
const detailPrice = document.getElementById('detailPrice');
const detailImg = document.getElementById('detailImg');
const detailImgFallback = document.getElementById('detailImgFallback');
const cartListEl = document.getElementById('cartList');
const cartEmptyEl = document.getElementById('cartEmpty');
const cartCountEl = document.getElementById('cartCount');
const cartTotalEl = document.getElementById('cartTotal');

let state = {
  open: false,
  accent: '#14f66c',
  shopTitle: 'Cửa hàng',
  gender: 'male',
  imageBase: 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/',
  tabs: [],
  items: [],
  rarities: [],
  activeTab: 'jacket',
  query: '',
  selectedId: null,
  cart: {},
  currency: 'cash',
};

function rarityMeta(id) {
  const list = state.rarities || [];
  return list.find((r) => r.id === id) || { id: id || 'common', label: id || 'Thường', color: '#94a3b8' };
}

const imageCache = new Map();

function fmtMoney(n) {
  const x = Math.floor(Number(n) || 0);
  const formatted = new Intl.NumberFormat('de-DE').format(x);
  if (state.currency === 'v_medal') return formatted + ' V Medal';
  return formatted + '$';
}

function setAccent(hex) {
  document.documentElement.style.setProperty('--accent', hex || '#14f66c');
}

function getItemById(id) {
  return state.items.find((x) => x.id === id) || null;
}

function cartEntries() {
  return Object.keys(state.cart)
    .map((tab) => getItemById(state.cart[tab]))
    .filter(Boolean);
}

function cartTotal() {
  return cartEntries().reduce((sum, it) => sum + (Number(it.price) || 0), 0);
}

function filteredItems() {
  const q = String(state.query || '').trim().toLowerCase();
  return state.items.filter((it) => {
    if (state.activeTab && it.tab !== state.activeTab) return false;
    if (!q) return true;
    const t = `${it.title || ''} ${it.sub || ''} ${it.imageKey || ''}`.toLowerCase();
    return t.includes(q);
  });
}

function isInCart(it) {
  return state.cart[it.tab] === it.id;
}

function addToCart(it) {
  state.cart[it.tab] = it.id;
  renderCart();
}

function removeFromCart(tab) {
  if (!state.cart[tab]) return;
  delete state.cart[tab];
  renderCart();
  renderList();
  renderDetail();
  post('removeCart', { tab });
}

function parseImageKeyCategory(imageKey) {
  if (!imageKey) return null;
  const m = String(imageKey).replace(/\.(png|webp|jpg)$/i, '').match(/^[mf]_([a-z]+)_\d+_\d+$/i);
  return m ? m[1].toLowerCase() : null;
}

function itemImageCandidates(it) {
  const out = [];
  if (!it) return out;
  if (it.image) out.push(it.image);
  const base = (state.imageBase || 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/').replace(/\/?$/, '/');
  if (it.imageKey) {
    out.push(base + it.imageKey + '.png');
    out.push(base + it.imageKey + '.webp');
  }
  const g = it.gender === 'female' ? 'f' : 'm';
  const wearCat = it.wearCategory || it.itemCategory || parseImageKeyCategory(it.imageKey) || parseImageKeyCategory(it.image);
  if (wearCat && it.drawable != null) {
    const tex = Number(it.texture) || 0;
    const key = `${g}_${wearCat}_${it.drawable}_${tex}`;
    out.push(base + key + '.png');
    out.push(base + key + '.webp');
  }
  return [...new Set(out.filter(Boolean))];
}

function bindItemImage(img, it, onDone) {
  const urls = itemImageCandidates(it);
  img.alt = it?.title || '';
  img.draggable = false;

  if (!urls.length) {
    img.hidden = true;
    if (onDone) onDone(false);
    return;
  }

  let idx = 0;
  const tryNext = () => {
    if (idx >= urls.length) {
      img.hidden = true;
      if (onDone) onDone(false);
      return;
    }
    const url = urls[idx++];
    const cached = imageCache.get(url);
    if (cached === true) {
      img.src = url;
      img.hidden = false;
      if (onDone) onDone(true);
      return;
    }
    if (cached === false) {
      tryNext();
      return;
    }
    img.onload = () => {
      imageCache.set(url, true);
      img.hidden = false;
      if (onDone) onDone(true);
    };
    img.onerror = () => {
      imageCache.set(url, false);
      tryNext();
    };
    img.src = url;
  };
  tryNext();
}

function renderTabs() {
  if (!tabsEl) return;
  tabsEl.innerHTML = '';
  const tabs = state.tabs || [];
  if (!tabs.length) {
    const hint = document.createElement('div');
    hint.className = 'shop-list__empty';
    hint.style.gridColumn = '1 / -1';
    hint.textContent = 'Chưa có danh mục — admin thêm đồ vào shop trước.';
    tabsEl.appendChild(hint);
    return;
  }
  tabs.forEach((t) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `shop-tab ${t.id === state.activeTab ? 'is-active' : ''}`;
    b.textContent = t.label || t.id;
    b.onclick = () => {
      state.activeTab = t.id;
      state.selectedId = null;
      post('setTab', { id: t.id });
      render();
    };
    tabsEl.appendChild(b);
  });
}

function renderList() {
  const items = filteredItems();
  listEl.innerHTML = '';

  if (items.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'shop-list__empty';
    empty.textContent = 'Không có món trong danh mục này.';
    listEl.appendChild(empty);
    return;
  }

  items.forEach((it) => {
    const inCart = isInCart(it);
    const card = document.createElement('button');
    card.type = 'button';
    card.className = `shop-card ${it.id === state.selectedId ? 'is-selected' : ''} ${inCart ? 'is-in-cart' : ''}`;
    card.onclick = () => {
      state.selectedId = it.id;
      addToCart(it);
      renderList();
      renderDetail();
      post('preview', { id: it.id });
    };

    const thumb = document.createElement('div');
    thumb.className = 'shop-card__thumb';

    const img = document.createElement('img');
    img.className = 'shop-card__img';
    const fallback = document.createElement('div');
    fallback.className = 'shop-card__fallback';
    fallback.textContent = (it.tabLabel || it.tab || '?').slice(0, 1).toUpperCase();

    bindItemImage(img, it, (ok) => {
      fallback.hidden = ok;
    });

    thumb.appendChild(img);
    thumb.appendChild(fallback);

    const body = document.createElement('div');
    body.className = 'shop-card__body';

    const title = document.createElement('div');
    title.className = 'shop-card__title';
    title.textContent = it.title || `Style #${it.style}`;

    const sub = document.createElement('div');
    sub.className = 'shop-card__sub';
    sub.textContent = inCart ? 'Đã thêm giỏ' : it.sub || it.imageKey || '';

    const price = document.createElement('div');
    price.className = 'shop-card__price';
    price.textContent = fmtMoney(it.price || 0);

    body.appendChild(title);
    body.appendChild(sub);
    if (it.rarity && it.rarity !== 'common') {
      const r = rarityMeta(it.rarity);
      const badge = document.createElement('span');
      badge.className = 'shop-card__rarity';
      badge.style.color = r.color;
      badge.textContent = r.label;
      body.appendChild(badge);
    }
    body.appendChild(price);

    card.appendChild(thumb);
    card.appendChild(body);
    listEl.appendChild(card);
  });
}

function renderCart() {
  const entries = cartEntries();
  cartListEl.innerHTML = '';

  if (entries.length === 0) {
    cartEmptyEl.classList.remove('hidden');
    cartCountEl.textContent = '0 món';
    cartTotalEl.textContent = fmtMoney(0);
    btnCheckout.disabled = true;
    return;
  }

  cartEmptyEl.classList.add('hidden');
  cartCountEl.textContent = `${entries.length} món`;
  cartTotalEl.textContent = fmtMoney(cartTotal());
  btnCheckout.disabled = false;

  entries.forEach((it) => {
    const row = document.createElement('div');
    row.className = 'shop-cart__row';

    const thumb = document.createElement('div');
    thumb.className = 'shop-cart__thumb';
    const img = document.createElement('img');
    img.className = 'shop-cart__thumbImg';
    const fb = document.createElement('span');
    fb.className = 'shop-cart__thumbFb';
    fb.textContent = '•';
    bindItemImage(img, it, (ok) => {
      fb.hidden = ok;
    });
    thumb.appendChild(img);
    thumb.appendChild(fb);

    const main = document.createElement('div');
    main.className = 'shop-cart__rowMain';
    const title = document.createElement('div');
    title.className = 'shop-cart__rowTitle';
    title.textContent = it.title || `Style #${it.style}`;
    const sub = document.createElement('div');
    sub.className = 'shop-cart__rowSub';
    sub.textContent = it.tabLabel || it.tab;
    main.appendChild(title);
    main.appendChild(sub);

    const price = document.createElement('div');
    price.className = 'shop-cart__rowPrice';
    price.textContent = fmtMoney(it.price || 0);

    const actions = document.createElement('div');
    actions.className = 'shop-cart__rowActions';

    const btnRemove = document.createElement('button');
    btnRemove.className = 'shop-cart__iconBtn shop-cart__iconBtn--remove';
    btnRemove.title = 'Xoá';
    btnRemove.textContent = '×';
    btnRemove.onclick = (e) => {
      e.stopPropagation();
      removeFromCart(it.tab);
    };

    actions.appendChild(btnRemove);

    row.appendChild(thumb);
    row.appendChild(main);
    row.appendChild(price);
    row.appendChild(actions);
    cartListEl.appendChild(row);
  });
}

function getSelected() {
  return getItemById(state.selectedId);
}

function renderDetail() {
  const it = getSelected();
  if (!it) {
    detailTitle.textContent = '—';
    detailBadge.textContent = '—';
    detailPrice.textContent = fmtMoney(0);
    detailImg.hidden = true;
    detailImgFallback.hidden = false;
    return;
  }
  detailTitle.textContent = it.title || `Style #${it.style}`;
  detailBadge.textContent = it.tabLabel || it.tab;
  detailPrice.textContent = fmtMoney(it.price || 0);
  const existingRarity = document.getElementById('detailRarity');
  if (existingRarity) existingRarity.remove();
  if (it.rarity && it.rarity !== 'common') {
    const r = rarityMeta(it.rarity);
    const badge = document.createElement('span');
    badge.id = 'detailRarity';
    badge.className = 'shop-detail__rarity';
    badge.style.color = r.color;
    badge.textContent = r.label;
    detailPrice.parentElement.appendChild(badge);
  }
  bindItemImage(detailImg, it, (ok) => {
    detailImgFallback.hidden = ok;
  });
}

function render() {
  renderTabs();
  renderList();
  renderCart();
  renderDetail();
}

function post(name, data) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

btnClose.onclick = () => post('close', {});
btnCancel.onclick = () => post('cancel', {});
btnCheckout.onclick = () => {
  const ids = cartEntries().map((it) => it.id);
  if (!ids.length) return;
  post('buyCart', { ids });
};
btnRotL.onclick = () => post('rotate', { dir: -1 });
btnRotR.onclick = () => post('rotate', { dir: 1 });

searchEl.addEventListener('input', () => {
  state.query = searchEl.value || '';
  renderList();
});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') post('close', {});
});

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') {
    state.open = true;
    state.shopTitle = d.title || 'Cửa hàng';
    state.gender = d.gender === 'female' ? 'female' : 'male';
    state.currency = d.currency === 'v_medal' ? 'v_medal' : 'cash';
    state.imageBase = (d.imageBase || 'https://minio1.webtui.vn:9000/bucket-renkunji123/images/').replace(/\/?$/, '/');
    state.tabs = Array.isArray(d.tabs) ? d.tabs : [];
    state.items = Array.isArray(d.items) ? d.items : [];
    state.rarities = Array.isArray(d.rarities) ? d.rarities : [];
    const tabIds = state.tabs.map((t) => t.id);
    const requestedTab = d.activeTab;
    state.activeTab = tabIds.includes(requestedTab)
      ? requestedTab
      : (tabIds[0] || 'jacket');
    state.selectedId = null;
    state.query = '';
    state.cart = {};
    titleEl.textContent = state.shopTitle;
    if (genderBadgeEl) {
      genderBadgeEl.textContent = state.gender === 'female' ? 'Đồ nữ' : 'Đồ nam';
    }
    searchEl.value = '';
    setAccent(d.accent);
    app.classList.remove('hidden');
    render();
  } else if (d.action === 'close') {
    state.open = false;
    state.cart = {};
    app.classList.add('hidden');
  } else if (d.action === 'select') {
    state.selectedId = d.id ?? null;
    render();
  }
});
