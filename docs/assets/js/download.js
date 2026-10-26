// 下载区：读取最新版本、生成各架构安装包（Android APK）与桌面安装包（Windows 安装
// 程序 / 便携版、Linux 压缩包）的下载地址，并为国内网络挑选镜像线路。
//
// 版本信息（先到先用，结果在 sessionStorage 里缓存 1 小时）：
//   1. GitHub 接口 releases 列表（带下载次数与 SHA-256；api.github.com 允许跨域，
//      但国内常连不上或被限流）；
//   2. Release 附件 jotsy-update.json（app 内更新用的清单），经允许跨域的镜像读取；
//   3. 都失败时保留 HTML 里写死的版本（发布时不必改它，只是兜底）。
//   刚发布、签名构建还没传完安装包的版本会被跳过，继续用上一个有安装包的版本。
//   两路结果版本相同时合并：下载次数、SHA-256 取自接口，英文更新说明取自清单。
//   桌面安装包与 APK 同在 Release 附件与清单的 assets 里（data-dl-pkg 按文件名后缀
//   认领）；该版本没有桌面安装包（桌面版之前的版本）或还没读到版本信息时，桌面按钮
//   停在发布页，不拼一个可能 404 的地址。
//
// 累计下载只统计 .apk：jotsy-update.json 每台装了 app 的手机每 2 小时会自动拉一次，
// SHA256SUMS.txt 也会被更新流程读取，算进去会让数字越来越虚高。数字优先取接口的实时值；
// 接口连不上或被限流（未登录每个 IP 每小时 60 次）时，取 download-stats.yml 每小时写进
// 最新 Release 的 jotsy-downloads.json（同样经允许跨域的镜像读取），国内访客也看得到。
//
// 更新说明：最新版本比“更新”一节里写死的最新一条还新时，从更新说明的
// “## 版本要点 / ## Highlights”一节（没有就取第一组列表）生成一张新卡片放在最前，
// 首屏版本标签也换成该版本的第一条要点；当前语言没有说明时只显示一行“已发布”提示。
//
// 主按钮：三个平台按钮里，访客系统对应的那个用 filled 并排到最前（Windows → 安装
// 程序，Linux 桌面 → 压缩包，其余含 Android、ChromeOS、macOS、iOS → APK），其余为
// tonal；没有脚本时保持 HTML 里的 Android 在前。
//
// 线路：与 app 内更新的 AppUpdateSource.builtInSources 保持一致
// （lib/core/services/app_update_sources.dart，改那边时同步这里）。镜像是第三方公共
// 服务：“自动”只对中文访客启用镜像（与 app 一样以镜像为主、直连为辅，国内直连附件
// 常被限速），在下载区接近视口时用 no-cors 请求同时探测各镜像的响应时间（只量连通与
// 延迟，读不到内容），取最快的一条，全都不通再直连；其他语言默认直连。
// SHA-256 只展示来自 GitHub 接口的值——经镜像读到的清单可能被篡改，不拿来做“校验”。

import { currentLang, formatNumber, onLangChange, t } from './i18n.js';
import { copyText, toast } from './ui.js';

const REPO = 'CikeSeven/jotsy';
const GH = `https://github.com/${REPO}`;
const API = `https://api.github.com/repos/${REPO}`;
const ROUTES = [
  { id: 'ghfast', name: 'ghfast.top', prefix: 'https://ghfast.top/' },
  { id: 'gh-proxy', name: 'gh-proxy.com', prefix: 'https://gh-proxy.com/' },
  { id: 'llkk', name: 'gh.llkk.cc', prefix: 'https://gh.llkk.cc/' },
  { id: 'ghproxy-net', name: 'ghproxy.net', prefix: 'https://ghproxy.net/' },
];
// 这两条镜像的响应带 Access-Control-Allow-Origin: *，可以直接读清单内容。
const CORS_PREFIXES = ['https://gh-proxy.com/', 'https://gh.llkk.cc/'];
const ABIS = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
// 桌面安装包的文件名后缀（jotsy-<tag><后缀>），与 release-apk.yml 的命名一致。
const DESKTOP = {
  'windows-setup': '-windows-x64-setup.exe',
  'windows-zip': '-windows-x64.zip',
  linux: '-linux-x64.tar.gz',
};
const isDesktopPackage = (name) => Object.values(DESKTOP).some((suffix) => name.endsWith(suffix));
const CACHE_KEY = 'jotsy.release.v3'; // v3：assets 里加入了桌面安装包
const STARS_KEY = 'jotsy.stars.v1';
const STATS_KEY = 'jotsy.downloads.v1';
const ROUTE_KEY = 'jotsy.route';
const CACHE_MS = 60 * 60 * 1000;

const section = document.querySelector('[data-download]');
const $$ = (sel) => [...document.querySelectorAll(sel)];
const staticTag = document.querySelector('[data-dl-version]')?.textContent.trim() || 'v0.7.0';

let release = null; // { source, tag, date, assets: [{ name, abi, size, sha256, url }], downloads, notes: { zh, en } }
let statsTotal = null; // jotsy-downloads.json 里的累计下载（每小时统计一次）
let route = readRoute();
let autoPick = null; // { id, ms, lang } | { failed: true, lang } | null（还没测）
let probing = false;

function readRoute() {
  try {
    return localStorage.getItem(ROUTE_KEY) || 'auto';
  } catch (e) {
    return 'auto';
  }
}

function session(key, value) {
  try {
    if (value === undefined) {
      const raw = sessionStorage.getItem(key);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      return Date.now() - parsed.at < CACHE_MS ? parsed.data : null;
    }
    sessionStorage.setItem(key, JSON.stringify({ at: Date.now(), data: value }));
  } catch (e) {
    return null;
  }
  return null;
}

function withTimeout(ms) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  return { signal: controller.signal, done: () => clearTimeout(timer) };
}

async function fetchJson(url, ms = 8000) {
  const { signal, done } = withTimeout(ms);
  try {
    const res = await fetch(url, { signal, headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    return await res.json();
  } finally {
    done();
  }
}

function abiOf(name) {
  return ABIS.find((abi) => name.includes(abi)) || null;
}

const isApk = (asset) => asset.name.endsWith('.apk');
// 展示与下载的安装包：APK 与桌面安装包；累计下载仍只数 APK（见文件开头）。
const isPackage = (asset) => isApk(asset) || isDesktopPackage(asset.name);

/** GitHub 接口：取第一个正式发布且已上传安装包的版本；顺带累计各版本安装包的下载次数。 */
async function fromApi() {
  const list = await fetchJson(`${API}/releases?per_page=100`);
  let downloads = 0;
  for (const r of list) for (const a of r.assets || []) if (isApk(a)) downloads += a.download_count || 0;
  const picked = list.find((r) => !r.draft && !r.prerelease && (r.assets || []).some((a) => a.name.endsWith('.apk')));
  if (!picked) throw new Error('no release with APKs');
  return {
    source: 'api',
    tag: picked.tag_name,
    date: (picked.published_at || '').slice(0, 10),
    downloads,
    // Release 正文就是中文版更新说明（docs/releases/<tag>.md）
    notes: { zh: picked.body || '', en: '' },
    assets: picked.assets
      .filter(isPackage)
      .map((a) => ({
        name: a.name,
        abi: abiOf(a.name),
        size: a.size,
        sha256: (a.digest || '').replace(/^sha256:/, '') || null,
        url: a.browser_download_url,
      })),
  };
}

/** app 内更新清单（schema 见 AppUpdateManifest），经允许跨域的镜像读取。 */
async function fromManifest(prefix) {
  const m = await fetchJson(`${prefix}${GH}/releases/latest/download/jotsy-update.json`);
  if (!m || !m.tag || !Array.isArray(m.assets) || !m.assets.length) throw new Error('bad manifest');
  return {
    source: 'manifest',
    tag: m.tag,
    date: (m.publishedAt || '').slice(0, 10),
    downloads: null,
    notes: { zh: m.notes?.zh || '', en: m.notes?.en || '' },
    assets: m.assets.filter(isPackage).map((a) => ({
      name: a.name,
      abi: a.abi || abiOf(a.name),
      size: a.size ?? null,
      sha256: a.sha256 || null,
      url: `${GH}/releases/download/${m.tag}/${a.name}`,
    })),
  };
}

/** 定时统计的累计下载（download-stats.yml 写入最新 Release），经允许跨域的镜像读取。 */
async function fromStats(prefix) {
  const s = await fetchJson(`${prefix}${GH}/releases/latest/download/jotsy-downloads.json`);
  if (!s || !Number.isInteger(s.total) || s.total < 0) throw new Error('bad download stats');
  return s.total;
}

function assetUrl(abi) {
  const asset = release?.assets.find((a) => a.abi === abi);
  const tag = release?.tag || staticTag;
  return asset?.url || `${GH}/releases/download/${tag}/jotsy-${tag}-${abi}.apk`;
}

/** 桌面安装包的地址；该版本没有时（或还没读到版本信息）为 null。 */
function desktopAsset(kind) {
  const suffix = DESKTOP[kind];
  return (suffix && release?.assets.find((a) => a.name.endsWith(suffix))) || null;
}

function autoRouteId() {
  if (currentLang() !== 'zh') return 'direct';
  if (autoPick?.lang === 'zh') return autoPick.failed ? 'direct' : autoPick.id;
  return ROUTES[0].id; // 还没测出结果时先用第一条镜像
}

function currentPrefix() {
  const id = route === 'auto' ? autoRouteId() : route;
  return ROUTES.find((r) => r.id === id)?.prefix || '';
}

function formatSize(bytes) {
  if (!bytes) return '';
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/* ---------- 渲染 ---------- */
function renderLinks() {
  const prefix = currentPrefix();
  $$('[data-dl-abi]').forEach((link) => {
    const abi = link.dataset.dlAbi;
    link.href = prefix + assetUrl(abi);
    const size = release?.assets.find((a) => a.abi === abi)?.size;
    const sizeEl = link.querySelector('[data-dl-size]');
    if (sizeEl) sizeEl.textContent = size ? `· ${formatSize(size)}` : '';
  });
  $$('[data-dl-pkg]').forEach((link) => {
    const asset = desktopAsset(link.dataset.dlPkg);
    // 发布页是 HTML，不经镜像；只有安装包本身套线路前缀。
    link.href = asset ? prefix + asset.url : `${GH}/releases/latest`;
    const sizeEl = link.querySelector('[data-dl-size]');
    if (sizeEl) sizeEl.textContent = asset?.size ? `· ${formatSize(asset.size)}` : '';
  });
}

function renderRouteStatus() {
  const status = document.querySelector('[data-route-status]');
  if (!status) return;
  status.removeAttribute('data-en');
  if (route !== 'auto') {
    const r = ROUTES.find((x) => x.id === route);
    status.textContent = t('routeManual', { name: r ? r.name : t('direct') });
  } else if (currentLang() !== 'zh') {
    status.textContent = t('routeHint');
  } else if (probing) {
    status.textContent = t('routeAutoPending');
  } else if (autoPick?.failed) {
    status.textContent = t('routeAutoFailed');
  } else if (autoPick) {
    const r = ROUTES.find((x) => x.id === autoPick.id);
    status.textContent = t('routeAuto', { name: r.name, ms: autoPick.ms });
  } else {
    status.textContent = t('routeHint');
  }
}

function setDynamic(el, text) {
  if (!el) return;
  // 交给脚本渲染后不再参与 data-en 的整体替换
  el.removeAttribute('data-en');
  el.textContent = text;
}

/** 版本号比较：v0.6.10 > v0.6.9；构建号与预发布后缀忽略。 */
function compareTags(a, b) {
  const parse = (tag) => (String(tag).match(/\d+/g) || []).slice(0, 3).map(Number);
  const x = parse(a);
  const y = parse(b);
  for (let i = 0; i < 3; i++) {
    const d = (x[i] || 0) - (y[i] || 0);
    if (d) return d;
  }
  return 0;
}

/** 去掉 Markdown 记号（链接留文字、加粗与行内代码留内容），用于纯文本展示。 */
function plainMarkdown(text) {
  return text
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/(\*\*|__)(.+?)\1/g, '$2')
    .replace(/`([^`]+)`/g, '$1')
    .trim();
}

/** 更新说明里“版本要点 / Highlights”一节的条目；没有该节时取第一组列表。 */
function highlightsOf(markdown, max = 3) {
  if (!markdown) return [];
  const lines = markdown.split(/\r?\n/);
  const heading = lines.findIndex((line) => /^#{2,3}\s*(版本要点|Highlights)\s*$/i.test(line.trim()));
  const items = [];
  for (let i = heading >= 0 ? heading + 1 : 0; i < lines.length; i++) {
    const line = lines[i];
    if (heading >= 0 && /^#{1,3}\s/.test(line)) break;
    const bullet = /^\s*[-*]\s+(.+)$/.exec(line);
    if (bullet) items.push(plainMarkdown(bullet[1]));
    else if (heading < 0 && items.length && !line.trim()) break;
    if (items.length >= max) break;
  }
  return items.filter(Boolean);
}

/** 要点冒号前的短语当标题（“应用内更新全面重做：……”）；没有就返回 null。 */
function headlineOf(item) {
  const match = /^(.{2,32}?)[：:]/.exec(item || '');
  return match ? match[1].trim() : null;
}

function mergeRelease(a, b) {
  const api = [a, b].find((r) => r.source === 'api');
  const manifest = [a, b].find((r) => r.source === 'manifest');
  const base = api || a;
  return {
    ...base,
    downloads: api?.downloads ?? null,
    notes: {
      zh: manifest?.notes?.zh || api?.notes?.zh || '',
      en: manifest?.notes?.en || '',
    },
  };
}

function renderRelease() {
  if (!release) return;
  const newer = compareTags(release.tag, staticTag) > 0;
  $$('[data-dl-version], [data-latest-version]').forEach((el) => (el.textContent = release.tag));
  $$('[data-dl-date]').forEach((el) => release.date && (el.textContent = release.date));
  renderTotal();
  if (newer) {
    const pill = document.querySelector('[data-release-pill]');
    if (pill) {
      pill.href = '#updates';
      const lead = headlineOf(highlightsOf(release.notes?.[currentLang()])[0]);
      setDynamic(
        pill.querySelector('[data-release-text]'),
        lead ? t('releaseHeadline', { tag: release.tag, lead }) : t('newRelease', { tag: release.tag }),
      );
    }
  }
  renderTimeline();
  renderSha();
  renderLinks();
}

/** 累计下载：接口的实时值优先，没有时用每小时的统计文件；都没有就不显示。 */
function renderTotal() {
  const box = document.querySelector('[data-dl-total]');
  const total = release?.downloads ?? statsTotal;
  if (!box || !total) return;
  box.hidden = false;
  box.querySelector('[data-dl-total-value]').textContent = t('downloads', { n: formatNumber(total) });
}

/** “更新”一节：比写死的条目更新的版本，自动在最前补一条。 */
function renderTimeline() {
  const list = document.querySelector('[data-timeline]');
  if (!list || !release) return;
  list.querySelector('[data-auto-release]')?.remove();
  const cards = [...list.querySelectorAll('.release[data-tag]')];
  const note = document.querySelector('[data-newer-release]');
  if (note) note.hidden = true;
  cards.forEach((card, index) => {
    card.hidden = false;
    const badge = card.querySelector('[data-release-badge]');
    if (badge) badge.hidden = index !== 0;
  });
  if (!cards.length || compareTags(release.tag, cards[0].dataset.tag) <= 0) return;

  const releaseUrl = `${GH}/releases/tag/${release.tag}`;
  const items = highlightsOf(release.notes?.[currentLang()]);
  if (!items.length) {
    // 当前语言没有说明（例如国内连不上接口、镜像也读不到清单）：只提示已发布
    if (note) {
      note.hidden = false;
      note.textContent = t('newerRelease', { tag: release.tag, date: release.date });
      const link = document.createElement('a');
      link.href = releaseUrl;
      link.textContent = t('newerReleaseLink');
      note.appendChild(link);
    }
    return;
  }
  cards.forEach((card) => {
    const badge = card.querySelector('[data-release-badge]');
    if (badge) badge.hidden = true;
  });
  cards[cards.length - 1].hidden = true; // 始终只摆三张

  // 结构与 index.html 里写死的 li.release 一致：header（版本号、“最新”、日期）+ 要点 + 链接
  const card = document.createElement('li');
  card.className = 'release';
  card.dataset.autoRelease = '';
  const header = document.createElement('header');
  const title = document.createElement('h3');
  title.textContent = release.tag;
  const badge = document.createElement('span');
  badge.className = 'badge';
  badge.textContent = t('latest');
  const time = document.createElement('time');
  time.dateTime = release.date;
  time.textContent = release.date;
  header.append(title, badge, time);
  const ul = document.createElement('ul');
  for (const item of items) {
    const li = document.createElement('li');
    li.textContent = item;
    ul.appendChild(li);
  }
  const more = document.createElement('a');
  more.href = releaseUrl;
  more.textContent = t('fullNotes');
  card.append(header, ul, more);
  list.prepend(card);
}

function renderSha() {
  const box = document.querySelector('[data-sha]');
  const list = document.querySelector('[data-sha-list]');
  const items = release?.source === 'api' ? release.assets.filter((a) => a.sha256) : [];
  if (!box || !list) return;
  box.hidden = !items.length;
  if (!items.length) return;
  box.hidden = false;
  list.innerHTML = '';
  for (const a of items) {
    const li = document.createElement('li');
    li.innerHTML = `<b></b><code></code><button class="icon-btn" type="button"><svg class="i" aria-hidden="true"><use href="assets/img/icons.svg#i-copy"></use></svg></button>`;
    li.querySelector('b').textContent = a.abi || a.name;
    li.querySelector('code').textContent = a.sha256;
    const button = li.querySelector('button');
    button.setAttribute('aria-label', t('copySha', { name: a.name }));
    button.addEventListener('click', async () => toast((await copyText(a.sha256)) ? t('copied') : t('copyFailed')));
    list.appendChild(li);
  }
}

/* ---------- 版本信息 ---------- */
function loadRelease() {
  const cached = session(CACHE_KEY);
  if (cached) {
    release = cached;
    renderRelease();
    // 缓存里已经有接口的数据（下载次数、SHA-256）才算完整；只有镜像清单时仍去请求接口，
    // 否则接口一次没连上，这一小时里下载次数和校验值都补不回来
    if (cached.source === 'api') return;
  }
  // 各路结果先到先渲染；同版本的后到结果合并进来（补下载次数、SHA-256、英文说明）
  const accept = (next) => {
    if (release && compareTags(next.tag, release.tag) < 0) return;
    release = release && release.tag === next.tag ? mergeRelease(release, next) : next;
    session(CACHE_KEY, release);
    renderRelease();
  };
  const attempts = cached ? [fromApi()] : [fromApi(), ...CORS_PREFIXES.map((p) => fromManifest(p))];
  for (const attempt of attempts) {
    attempt.then(accept).catch(() => {
      /* 这一路失败不影响其他路；全部失败时保留 HTML 里的版本与直链 */
    });
  }
}

async function loadStats() {
  let total = session(STATS_KEY);
  if (total == null) {
    try {
      total = await Promise.any(CORS_PREFIXES.map((p) => fromStats(p)));
      session(STATS_KEY, total);
    } catch (e) {
      return; // 镜像都读不到（或统计文件还没生成）时只依赖接口
    }
  }
  statsTotal = total;
  renderTotal();
}

async function loadStars() {
  const box = document.querySelector('[data-stars]');
  if (!box) return;
  let stars = session(STARS_KEY);
  if (stars == null) {
    try {
      stars = (await fetchJson(API, 6000)).stargazers_count;
      session(STARS_KEY, stars);
    } catch (e) {
      return;
    }
  }
  if (typeof stars === 'number' && stars > 0) {
    box.querySelector('[data-stars-value]').textContent = formatNumber(stars);
    box.hidden = false;
  }
}

/* ---------- 线路探测 ---------- */
async function probe(url) {
  const { signal, done } = withTimeout(4500);
  const start = performance.now();
  try {
    await fetch(url, { mode: 'no-cors', cache: 'no-store', signal });
    return Math.round(performance.now() - start);
  } finally {
    done();
  }
}

async function pickRoute() {
  if (probing || route !== 'auto' || currentLang() !== 'zh' || autoPick?.lang === 'zh') return;
  probing = true;
  renderRouteStatus();
  const target = `${GH}/releases/latest/download/jotsy-update.json`;
  try {
    autoPick = await Promise.any(
      ROUTES.map((r) => probe(r.prefix + target).then((ms) => ({ id: r.id, ms, lang: 'zh' }))),
    );
  } catch (e) {
    autoPick = { failed: true, lang: 'zh' };
  }
  probing = false;
  renderRouteStatus();
  renderLinks();
}

/** 访客系统对应的平台按钮：Windows、Linux 桌面（排除 Android 与 ChromeOS），其余为 Android。 */
function visitorPlatform() {
  const ua = navigator.userAgent || '';
  if (/Windows/.test(ua)) return 'windows';
  if (/Linux/.test(ua) && !/Android|CrOS/.test(ua)) return 'linux';
  return 'android';
}

function renderPrimaryPlatform() {
  const row = document.querySelector('[data-dl-platforms]');
  if (!row) return;
  const platform = visitorPlatform();
  const buttons = [...row.querySelectorAll('[data-dl-platform]')];
  const primary = buttons.find((b) => b.dataset.dlPlatform === platform) || buttons[0];
  for (const button of buttons) {
    button.classList.toggle('btn--filled', button === primary);
    button.classList.toggle('btn--tonal', button !== primary);
  }
  if (primary && row.firstElementChild !== primary) row.prepend(primary);
}

/* ---------- 初始化 ---------- */
const select = document.querySelector('[data-route]');
if (select) {
  select.value = ROUTES.some((r) => r.id === route) || route === 'direct' ? route : 'auto';
  route = select.value;
  select.addEventListener('change', () => {
    route = select.value;
    try {
      localStorage.setItem(ROUTE_KEY, route);
    } catch (e) {
      /* 只影响下次访问 */
    }
    if (route === 'auto') pickRoute();
    renderRouteStatus();
    renderLinks();
  });
}

if (section) {
  renderPrimaryPlatform();
  renderLinks();
  renderRouteStatus();
  // 下载区接近视口、或用户把手放到下载按钮上时才开始探测线路
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          pickRoute();
          io.disconnect();
        }
      },
      { rootMargin: '600px 0px' },
    );
    io.observe(section);
  }
  section.addEventListener('pointerenter', pickRoute, { once: true });
}

const idle = window.requestIdleCallback || ((fn) => setTimeout(fn, 1200));
idle(() => {
  loadRelease();
  loadStats();
  loadStars();
});

onLangChange(() => {
  if (section && route === 'auto') pickRoute();
  renderRouteStatus();
  renderRelease();
  renderTotal(); // 版本信息还没到、只有统计文件时 renderRelease 不会重画下载次数
  renderLinks();
});
