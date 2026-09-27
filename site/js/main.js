const CARD_API = 'https://api-production-bf3c9.up.railway.app/v1/site/cards';
const MAIL = 'omeryenigun@gmail.com';
const ACCENTS = [
  ['#7c5cff', '#a78bfa'],
  ['#ff4d94', '#ff8ab5'],
  ['#22d3ee', '#67e8f9'],
  ['#ff8a3d', '#ffb37a'],
  ['#34d399', '#6ee7b7'],
  ['#facc15', '#fde68a'],
];
const PLAY_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#4285F4" d="M3.2 20.6V3.4c0-.4.2-.8.6-.9l.1 10.5L3.8 21.5c-.4-.1-.6-.5-.6-.9z"/><path fill="#34A853" d="M16.7 15.2 13.2 12 3.9 21.5c.3.2.7.2 1.1 0l11.7-6.3z"/><path fill="#FBBC04" d="M16.7 8.8 5 2.5c-.4-.2-.8-.2-1.1 0L3.8 2.6 13.2 12l3.5-3.2z"/><path fill="#EA4335" d="M20.4 10.6 16.7 8.8 13.2 12l3.5 3.2 3.7-2c.6-.4.6-1.2 0-1.6z"/></svg>';
const APPLE_ICON = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.7c0-2.2 1.8-3.3 1.9-3.4-1-1.5-2.6-1.7-3.2-1.7-1.4-.1-2.6.8-3.3.8-.7 0-1.7-.8-2.8-.8-1.5 0-2.8.9-3.6 2.2-1.5 2.6-.4 6.5 1.1 8.6.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7 1.3 0 1.7.7 2.8.7 1.2 0 1.9-1.1 2.6-2.1.8-1.2 1.2-2.4 1.2-2.4s-2.2-.9-2.2-3.3zM14.3 5.9c.6-.7 1-1.7.9-2.7-.9 0-2 .6-2.6 1.3-.6.6-1.1 1.7-.9 2.6 1 .1 2-.5 2.6-1.2z"/></svg>';

let cards = [];

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[ch]));
}

function cardName(card) {
  return currentLang() === 'en' && card.nameEn ? card.nameEn : card.name;
}

function cardText(card) {
  return currentLang() === 'en' && card.descriptionEn ? card.descriptionEn : card.description;
}

function safeUrl(href) {
  if (!href) return '';
  try {
    const url = new URL(href);
    return url.protocol === 'https:' ? url.href : '';
  } catch (_) {
    return '';
  }
}

function storeButton(kind, href, label, enabled) {
  const cls = kind === 'play' ? 'play' : 'apple';
  const icon = kind === 'play' ? PLAY_ICON : APPLE_ICON;
  const url = safeUrl(href);
  const inner = `${icon}<span>${label}</span>`;
  if (enabled && url) {
    return `<a class="store-btn ${cls}" href="${esc(url)}" rel="noopener" target="_blank">${inner}</a>`;
  }
  return `<span class="store-btn ${cls} is-off" aria-disabled="true">${inner}</span>`;
}

function storeRow(card) {
  const live = card.status === 'live';
  return `${storeButton('play', card.playUrl, t('play'), live)}${storeButton('apple', card.iosUrl, t('apple'), live)}`;
}

function cardHtml(card, index) {
  const [a, b] = ACCENTS[index % ACCENTS.length];
  const live = card.status === 'live';
  const name = esc(cardName(card));
  const thumb = card.iconUrl
    ? `<img src="${esc(card.iconUrl)}" alt="">`
    : name.slice(0, 1);
  return `<article class="card${live ? '' : ' soon'}" data-status="${live ? 'live' : 'soon'}" style="--accent:${a};--accent-2:${b}">
    <span class="tag ${live ? 'live' : 'soon'}"><span class="dot"></span>${live ? t('live') : t('soon')}</span>
    <div class="thumb">${thumb}</div>
    <h3>${name}</h3>
    <p>${esc(cardText(card))}</p>
    <a class="detail-btn" href="/oyun/${encodeURIComponent(card.id)}">${t('detail')}</a>
    <div class="stores">${storeRow(card)}</div>
  </article>`;
}

function paint(list, element, filter) {
  if (!element) return;
  const shown = filter && filter !== 'all' ? list.filter((card) => (card.status === 'live' ? 'live' : 'soon') === filter) : list;
  element.innerHTML = shown.map((card, i) => cardHtml(card, list.indexOf(card) < 0 ? i : list.indexOf(card))).join('');
  const empty = document.getElementById('emptyState');
  if (empty && element.id === 'gameGrid') empty.style.display = shown.length ? 'none' : 'block';
}

function paintAll() {
  const live = cards.filter((card) => card.status === 'live');
  const featured = document.getElementById('featuredGrid');
  if (featured) paint(live.length ? live.slice(0, 3) : cards.slice(0, 1), featured);
  const grid = document.getElementById('gameGrid');
  const active = document.querySelector('.filter-btn.active');
  paint(cards, grid, active ? active.dataset.filter : null);
  const liveStat = document.querySelector('[data-stat="live"]');
  const soonStat = document.querySelector('[data-stat="soon"]');
  if (liveStat) liveStat.textContent = String(live.length);
  if (soonStat) soonStat.textContent = String(cards.length - live.length);
  paintLanding();
}

function gameId() {
  const parts = location.pathname.replace(/\/+$/, '').split('/');
  const last = decodeURIComponent(parts[parts.length - 1] || '');
  if (!last || last === 'oyun' || last === 'oyun.html') return '';
  return last;
}

function paintLanding() {
  const root = document.getElementById('landing');
  if (!root) return;
  const card = cards.find((item) => item.id === gameId());
  if (!card) {
    root.innerHTML = `<p class="soon-note">${t('missing')}</p>`;
    return;
  }
  const index = Math.max(0, cards.indexOf(card));
  const [a, b] = ACCENTS[index % ACCENTS.length];
  const live = card.status === 'live';
  const name = esc(cardName(card));
  const thumb = card.iconUrl
    ? `<img src="${esc(card.iconUrl)}" alt="">`
    : name.slice(0, 1);
  const images = card.images || [];
  const cover = images[0];
  const shots = images.slice(1)
    .map((image) => `<img src="${esc(image.url)}" alt="${name}">`)
    .join('');
  const coverHtml = cover
    ? `<section class="vitrin"><h2>${t('vitrin')}</h2><img class="vitrin-cover" src="${esc(cover.url)}" alt="${name}"></section>`
    : '';
  const shotsHtml = shots
    ? `<section class="vitrin shots"><h2>${t('shots')}</h2><div class="vitrin-row">${shots}</div></section>`
    : '';
  document.title = `${cardName(card)} — Onyapp`;
  root.innerHTML = `<a class="back-link" href="/oyunlar">${t('backGames')}</a>
    <div class="landing-hero" style="--accent:${a};--accent-2:${b}">
      <div class="landing-copy">
        <div class="thumb">${thumb}</div>
        <div>
          <span class="tag ${live ? 'live' : 'soon'}"><span class="dot"></span>${live ? t('live') : t('soon')}</span>
          <h1>${name}</h1>
          <p class="lead">${esc(cardText(card))}</p>
        </div>
      </div>
      <div class="stores">${storeRow(card)}</div>
    </div>
    ${storyHtml(card)}
    ${coverHtml}
    ${shotsHtml}`;
}

function pageStory(card) {
  if (typeof GAME_PAGES === 'undefined' || !GAME_PAGES[card.id]) return null;
  const pack = GAME_PAGES[card.id];
  return pack[currentLang()] || pack.tr;
}

function flagLabel(kind) {
  if (kind === 'yes') return t('flagYes');
  if (kind === 'no') return t('flagNo');
  return t('flagLater');
}

function storyHtml(card) {
  const story = pageStory(card);
  if (!story) return '';
  const about = story.about.map((line) => `<p>${esc(line)}</p>`).join('');
  const steps = story.steps.map((line, i) => `<div class="step"><b>${i + 1}</b><span>${esc(line)}</span></div>`).join('');
  const modes = story.modes.map((mode) => `<article class="mode"><h3>${esc(mode.t)}</h3><p>${esc(mode.p)}</p></article>`).join('');
  const fact = (kind, title, note) => `<article class="fact"><span class="flag ${kind}">${flagLabel(kind)}</span><h3>${title}</h3><p>${esc(note)}</p></article>`;
  return `<div class="story">
    <section><h2>${t('secAbout')}</h2>${about}</section>
    <section><h2>${t('secHow')}</h2><div class="steps">${steps}</div></section>
    <section><h2>${t('secModes')}</h2><div class="modes">${modes}</div></section>
    <section class="facts">
      <article class="fact"><span class="flag age">${esc(story.age)}</span><h3>${t('secAge')}</h3><p>${esc(story.ageNote)}</p></article>
      ${fact(story.ads, t('secAds'), story.adsNote)}
      ${fact(story.iap, t('secIap'), story.iapNote)}
    </section>
  </div>`;
}

async function loadCards() {
  const grid = document.getElementById('gameGrid') || document.getElementById('featuredGrid');
  const landing = document.getElementById('landing');
  if (!grid && !landing && !document.querySelector('[data-stat="live"]')) return;
  try {
    const response = await fetch(CARD_API);
    if (!response.ok) throw new Error(String(response.status));
    const body = await response.json();
    cards = Array.isArray(body.cards) ? body.cards : [];
    paintAll();
  } catch (_) {
    const note = `<p class="soon-note">${t('gamesError')}</p>`;
    if (landing) landing.innerHTML = note;
    else if (grid) grid.innerHTML = note;
  }
}

function bindMenu() {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.querySelector('.menu');
  if (toggle && menu) toggle.addEventListener('click', () => menu.classList.toggle('open'));
}

function bindLang() {
  document.querySelectorAll('.langs button').forEach((btn) => {
    btn.addEventListener('click', () => setLang(btn.dataset.lang));
  });
  document.addEventListener('ony-lang', paintAll);
}

function bindFilters() {
  const buttons = document.querySelectorAll('.filter-btn');
  buttons.forEach((btn) => {
    btn.addEventListener('click', () => {
      buttons.forEach((item) => item.classList.remove('active'));
      btn.classList.add('active');
      paint(cards, document.getElementById('gameGrid'), btn.dataset.filter);
    });
  });
}

function bindFaq() {
  document.querySelectorAll('.faq-q').forEach((q) => {
    q.addEventListener('click', () => {
      const item = q.parentElement;
      const wasOpen = item.classList.contains('open');
      document.querySelectorAll('.faq-item').forEach((row) => row.classList.remove('open'));
      if (!wasOpen) item.classList.add('open');
    });
  });
}

function bindMail() {
  const form = document.querySelector('.contact-form');
  if (!form) return;
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    const data = new FormData(form);
    const subject = `${data.get('subject') || ''} — ${data.get('name') || ''}`;
    const body = `${data.get('message') || ''}\n\n${data.get('email') || ''}`;
    window.location.href = `mailto:${MAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  });
  const news = document.querySelector('.subscribe');
  if (!news) return;
  news.addEventListener('submit', (event) => {
    event.preventDefault();
    const email = new FormData(news).get('email') || '';
    const subject = currentLang() === 'en' ? 'News' : 'Duyuru';
    window.location.href = `mailto:${MAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(email)}`;
  });
}

applyI18n();
bindMenu();
bindLang();
bindFilters();
bindFaq();
bindMail();
loadCards();
