// 明暗模式与主题色。
//
// 明暗：'system'（不写 data-theme，跟随系统）/ 'light' / 'dark'，存 jotsy.theme。
// 主题色：app 的 80 个种子色之一，配色数据见 assets/data/themes.json（由
// ColorScheme.fromSeed(tonalSpot) 生成，与 app 一致）。换色时生成与 site.css 同结构的
// 三段规则注入 <style id="seed-theme">，并把这段 CSS 存进 jotsy.seedCss，下次访问由
// <head> 引导脚本在首帧前注入，不闪烁。默认种子色不注入任何覆盖。
//
// 切换动画：支持 View Transitions 时从点按处圆形展开新配色；否则给 <html> 临时加
// theme-anim 让颜色补间；系统开启“减少动态效果”时直接切换。

const THEME_KEY = 'jotsy.theme';
const SEED_KEY = 'jotsy.seed';
const SEED_CSS_KEY = 'jotsy.seedCss';
export const DEFAULT_SEED = '1e6586';

const root = document.documentElement;
const listeners = new Set();
const darkQuery = matchMedia('(prefers-color-scheme: dark)');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let themesPromise = null;

function read(key) {
  try {
    return localStorage.getItem(key);
  } catch (e) {
    return null;
  }
}

function write(key, value) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch (e) {
    /* 存不了只影响下次访问 */
  }
}

/** 懒加载 80 套配色（约 27 KB），只在访客第一次动主题色时请求。 */
export function loadThemes() {
  themesPromise ??= fetch(new URL('../data/themes.json', import.meta.url)).then((r) => {
    if (!r.ok) throw new Error(`themes.json ${r.status}`);
    return r.json();
  });
  return themesPromise;
}

export function getMode() {
  return root.getAttribute('data-theme') || 'system';
}

export function isDark() {
  const mode = getMode();
  return mode === 'dark' || (mode === 'system' && darkQuery.matches);
}

export function getSeed() {
  return read(SEED_KEY) || DEFAULT_SEED;
}

export function onThemeChange(fn) {
  listeners.add(fn);
}

function notify() {
  syncDocument();
  listeners.forEach((fn) => fn({ mode: getMode(), seed: getSeed(), dark: isDark() }));
}

/** 地址栏颜色与首屏暗色截图跟随当前明暗。 */
function syncDocument() {
  // 页面底色是 --c-page（亮色为最浅表面），地址栏颜色跟它一致
  const surface = getComputedStyle(root).getPropertyValue('--c-surface-lowest').trim();
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta && surface) meta.setAttribute('content', `rgb(${surface.split(/\s+/).join(',')})`);
  const mode = getMode();
  document.querySelectorAll('[data-dark-source]').forEach((source) => {
    source.media = mode === 'dark' ? 'all' : mode === 'light' ? 'not all' : '(prefers-color-scheme: dark)';
  });
}

/**
 * 执行一次配色变更。origin 为点按位置（{x, y}，视口坐标），有就从那里圆形展开。
 */
function transition(origin, change) {
  if (reducedMotion.matches) {
    change();
    return;
  }
  if (document.startViewTransition && origin) {
    const vt = document.startViewTransition(change);
    vt.ready
      .then(() => {
        const r = Math.hypot(
          Math.max(origin.x, innerWidth - origin.x),
          Math.max(origin.y, innerHeight - origin.y),
        );
        root.animate(
          { clipPath: [`circle(0px at ${origin.x}px ${origin.y}px)`, `circle(${r}px at ${origin.x}px ${origin.y}px)`] },
          { duration: 560, easing: 'cubic-bezier(.2, 0, 0, 1)', pseudoElement: '::view-transition-new(root)' },
        );
      })
      .catch(() => {});
    return;
  }
  root.classList.add('theme-anim');
  change();
  setTimeout(() => root.classList.remove('theme-anim'), 420);
}

export function setMode(mode, origin) {
  if (mode === getMode()) return;
  transition(origin, () => {
    if (mode === 'light' || mode === 'dark') root.setAttribute('data-theme', mode);
    else root.removeAttribute('data-theme');
    write(THEME_KEY, mode === 'system' ? null : mode);
    notify();
  });
}

/** 依次切换：跟随系统 → 浅色 → 深色 → 跟随系统。 */
export function cycleMode(origin) {
  const next = { system: 'light', light: 'dark', dark: 'system' }[getMode()];
  setMode(next, origin);
}

function triplet(hex) {
  return `${parseInt(hex.slice(0, 2), 16)} ${parseInt(hex.slice(2, 4), 16)} ${parseInt(hex.slice(4, 6), 16)}`;
}

function buildCss(data, seed) {
  const entry = data.schemes[seed];
  if (!entry || seed === DEFAULT_SEED) return '';
  const decl = (packed) => data.roles.map((role, i) => `--c-${role}:${triplet(packed.slice(i * 6, i * 6 + 6))};`).join('');
  const light = decl(entry[0]);
  const dark = decl(entry[1]);
  return `:root{${light}}@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){${dark}}}:root[data-theme="dark"]{${dark}}`;
}

function injectCss(css) {
  let style = document.getElementById('seed-theme');
  if (!css) {
    style?.remove();
    return;
  }
  if (!style) {
    style = document.createElement('style');
    style.id = 'seed-theme';
    document.head.appendChild(style);
  }
  style.textContent = css;
}

export async function setSeed(seed, origin) {
  seed = String(seed).replace('#', '').toLowerCase();
  if (seed === getSeed() && document.getElementById('seed-theme')) return;
  const data = await loadThemes();
  if (!data.schemes[seed]) return;
  const css = buildCss(data, seed);
  transition(origin, () => {
    injectCss(css);
    write(SEED_KEY, seed === DEFAULT_SEED ? null : seed);
    write(SEED_CSS_KEY, css || null);
    notify();
  });
}

export function initTheme() {
  const onSystemChange = () => {
    if (getMode() === 'system') notify();
  };
  darkQuery.addEventListener?.('change', onSystemChange);
  syncDocument();
}
