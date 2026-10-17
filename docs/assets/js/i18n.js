// 中英切换。
//
// 中文直接写在标签里；英文写在同一元素的 data-en（替换文本）、data-en-html（替换
// 带标记的内容）与 data-en-<属性>（替换该属性，如 alt、aria-label、src）里。第一次
// 切到英文时把中文原值存进 WeakMap，切回中文时原样恢复，所以中文永远以 HTML 为准。
// 脚本动态生成的文案（下载区、提示条等）不写在标签里，统一走 t()，并在
// onLangChange 回调里重新渲染。
//
// 偏好：?lang=en|zh 优先，其次 localStorage（jotsy.lang），首帧前由 <head> 里的
// 引导脚本先设好 <html lang>，这里只负责替换文案并去掉 lang-pending 遮挡。

const STORE_KEY = 'jotsy.lang';
const ATTRS = ['alt', 'aria-label', 'title', 'content', 'src', 'srcset', 'href', 'data-copied'];
const SELECTOR = ['[data-en]', '[data-en-html]', ...ATTRS.map((a) => `[data-en-${a}]`)].join(',');

const originals = new WeakMap();
const listeners = new Set();
let current = 'zh';

const STRINGS = {
  zh: {
    copied: '已复制',
    copyFailed: '复制失败，请手动选择',
    copySha: '复制 {name} 的 SHA-256',
    newRelease: '{tag} 已发布 · 看看更新了什么',
    releaseHeadline: '{tag} · {lead}',
    latest: '最新',
    fullNotes: '完整更新说明 →',
    newerRelease: '最新的 {tag} 已于 {date} 发布，',
    newerReleaseLink: '查看更新说明 →',
    downloads: '累计下载 {n} 次',
    stars: '{n}',
    routeAutoPending: '正在测试哪条线路最快…',
    routeAuto: '已自动选择 {name}（{ms} ms）',
    routeAutoFailed: '镜像都没有响应，已改用 GitHub 直连',
    routeManual: '使用 {name}',
    routeHint: '国内网络一般走镜像更快。',
    direct: 'GitHub 直连',
    themeSystem: '主题：跟随系统（点按切换）',
    themeLight: '主题：浅色（点按切换）',
    themeDark: '主题：深色（点按切换）',
    familyNames: ['红', '粉', '橙', '黄', '绿', '青', '蓝', '紫', '棕', '灰'],
    seedLabel: '主题色 {hex}',
    familyLabel: '{name}色系',
  },
  en: {
    copied: 'Copied',
    copyFailed: "Couldn't copy, please select it by hand",
    copySha: 'Copy the SHA-256 of {name}',
    newRelease: "{tag} is out · see what's new",
    releaseHeadline: '{tag} · {lead}',
    latest: 'Latest',
    fullNotes: 'Full release notes →',
    newerRelease: '{tag} came out on {date}. ',
    newerReleaseLink: 'Read the release notes →',
    downloads: '{n} downloads',
    stars: '{n}',
    routeAutoPending: 'Testing which route is fastest…',
    routeAuto: 'Using {name} automatically ({ms} ms)',
    routeAutoFailed: 'No mirror answered, so GitHub direct is used',
    routeManual: 'Using {name}',
    routeHint: 'Mirrors are usually faster in mainland China.',
    direct: 'GitHub direct',
    themeSystem: 'Theme: system (tap to switch)',
    themeLight: 'Theme: light (tap to switch)',
    themeDark: 'Theme: dark (tap to switch)',
    familyNames: ['Red', 'Pink', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple', 'Brown', 'Grey'],
    seedLabel: 'Theme color {hex}',
    familyLabel: '{name}',
  },
};

function store(value) {
  try {
    localStorage.setItem(STORE_KEY, value);
  } catch (e) {
    /* 隐私模式等情况下存不了，只影响下次访问 */
  }
}

/** 当前语言：'zh' | 'en'。 */
export function currentLang() {
  return current;
}

/** 取脚本文案；{name} 形式的占位由 vars 替换。 */
export function t(key, vars = {}) {
  const value = STRINGS[current][key] ?? STRINGS.zh[key] ?? key;
  if (typeof value !== 'string') return value;
  return value.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? vars[k] : `{${k}}`));
}

/** 按当前语言格式化数字（千分位）。 */
export function formatNumber(n) {
  return new Intl.NumberFormat(current === 'en' ? 'en-US' : 'zh-CN').format(n);
}

export function onLangChange(fn) {
  listeners.add(fn);
}

function snapshot(el) {
  let snap = originals.get(el);
  if (snap) return snap;
  snap = {};
  if (el.hasAttribute('data-en')) snap.text = el.textContent;
  if (el.hasAttribute('data-en-html')) snap.html = el.innerHTML;
  for (const a of ATTRS) {
    if (el.hasAttribute(`data-en-${a}`)) snap[a] = el.getAttribute(a);
  }
  originals.set(el, snap);
  return snap;
}

function apply(lang) {
  const en = lang === 'en';
  document.querySelectorAll(SELECTOR).forEach((el) => {
    const snap = snapshot(el);
    if ('text' in snap) el.textContent = en ? el.getAttribute('data-en') : snap.text;
    if ('html' in snap) el.innerHTML = en ? el.getAttribute('data-en-html') : snap.html;
    for (const a of ATTRS) {
      if (!(a in snap)) continue;
      const v = en ? el.getAttribute(`data-en-${a}`) : snap[a];
      if (v == null) el.removeAttribute(a);
      else el.setAttribute(a, v);
    }
  });
  document.documentElement.lang = en ? 'en' : 'zh-CN';
}

/** 切换语言并记住；同步地址栏的 ?lang=，便于分享英文页。 */
export function setLang(lang, { persist = true } = {}) {
  lang = lang === 'en' ? 'en' : 'zh';
  if (lang === current && !document.documentElement.classList.contains('lang-pending')) return;
  current = lang;
  apply(lang);
  document.documentElement.classList.remove('lang-pending');
  if (persist) {
    store(lang);
    try {
      const url = new URL(location.href);
      if (url.searchParams.has('lang') || lang === 'en') {
        if (lang === 'en') url.searchParams.set('lang', 'en');
        else url.searchParams.delete('lang');
        history.replaceState(history.state, '', url);
      }
    } catch (e) {
      /* file:// 等环境下改不了地址栏，忽略 */
    }
  }
  listeners.forEach((fn) => fn(lang));
}

/** 读取引导脚本已决定的语言并替换文案。 */
export function initI18n() {
  const wanted = document.documentElement.lang === 'en' ? 'en' : 'zh';
  if (wanted === 'en') setLang('en', { persist: false });
  else document.documentElement.classList.remove('lang-pending');
  current = wanted;
  // 从带 ?lang= 的分享链接进来时记住这个选择，站内跳到隐私政策页也保持同一语言。
  if (/[?&]lang=(en|zh)\b/.test(location.search)) store(wanted);
}
