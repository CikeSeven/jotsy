// 外观实验室：主题色 / 卡片样式 / 正文排版三个面板，驱动右侧（窄屏在上方）手机里的
// app 复刻。主题色改的是整个网站（theme.js），卡片样式与排版只改复刻本身。
//
// 色板与 app 的 kColorPaletteFamilies 一致（lib/ui/widgets/color_palette_families.dart）：
// 色系按钮显示第 3 个色（colors[2]），点按选中该色系的第 1 个色（colors[0]），与
// PaletteColorPicker 的行为相同；下面一排是该色系的 8 个色。

import { DEFAULT_SEED, getMode, getSeed, onThemeChange, setMode, setSeed } from './theme.js';
import { onLangChange, t } from './i18n.js';

const FAMILIES = [
  ['ffebee', 'ffcdd2', 'e57373', 'ef5350', 'e53935', 'd32f2f', 'c62828', 'b71c1c'],
  ['fce4ec', 'f8bbd0', 'f48fb1', 'f06292', 'ec407a', 'd81b60', 'c2185b', '880e4f'],
  ['fff3e0', 'ffe0b2', 'ffb74d', 'ffa726', 'fb8c00', 'f57c00', 'ef6c00', 'e65100'],
  ['fffde7', 'fff9c4', 'fff176', 'ffee58', 'fdd835', 'fbc02d', 'f9a825', 'f57f17'],
  ['e8f5e9', 'c8e6c9', 'a5d6a7', '81c784', '66bb6a', '43a047', '2e7d32', '1b5e20'],
  ['e0f7fa', 'b2ebf2', '80deea', '4dd0e1', '26c6da', '00acc1', '00838f', '006064'],
  ['e3f2fd', 'bbdefb', '90caf9', '64b5f6', '42a5f5', '1e6586', '1565c0', '0d47a1'],
  ['f3e5f5', 'e1bee7', 'ce93d8', 'ba68c8', 'ab47bc', '8e24aa', '6a1b9a', '4a148c'],
  ['efebe9', 'd7ccc8', 'bcaaa4', 'a1887f', '8d6e63', '6d4c41', '5d4037', '3e2723'],
  ['fafafa', 'f5f5f5', 'eeeeee', 'e0e0e0', 'bdbdbd', '9e9e9e', '757575', '616161'],
];
const DEFAULT_FAMILY = 6;
const TYPE_DEFAULTS = { fs: 16, lh: 1.55, ls: 0, ps: 0 };
const FONTS = {
  harmony: '',
  system: 'system-ui, -apple-system, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif',
  serif: 'var(--font-serif)',
};

const lab = document.querySelector('[data-lab]');
const $ = (sel, root = lab) => root.querySelector(sel);
const $$ = (sel, root = lab) => [...root.querySelectorAll(sel)];
const app = $('[data-app]');
const feed = $('[data-feed]');
const readText = $('[data-read-text]');

function originOf(el) {
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

function familyOf(seed) {
  const i = FAMILIES.findIndex((f) => f.includes(seed));
  return i < 0 ? DEFAULT_FAMILY : i;
}

/** 色块上勾选图标的颜色：浅色块用深色勾，深色块用白色勾。 */
function inkFor(hex) {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return lum > 0.62 ? '#1b1f22' : '#ffffff';
}

const checkIcon =
  '<svg class="i" aria-hidden="true"><use href="assets/img/icons.svg#i-check"></use></svg>';

/* ---------- 单选组（role=radiogroup）的通用键盘行为 ---------- */
function radioGroup(group, onSelect) {
  group.addEventListener('click', (event) => {
    const button = event.target.closest('[role="radio"]');
    if (button && group.contains(button)) onSelect(button, event);
  });
  group.addEventListener('keydown', (event) => {
    const keys = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };
    if (!(event.key in keys)) return;
    const items = [...group.querySelectorAll('[role="radio"]')];
    const index = items.indexOf(document.activeElement);
    if (index < 0) return;
    event.preventDefault();
    const next = items[(index + keys[event.key] + items.length) % items.length];
    next.focus();
    onSelect(next, event);
  });
}

function check(group, predicate) {
  [...group.querySelectorAll('[role="radio"]')].forEach((b) => {
    const on = predicate(b);
    b.setAttribute('aria-checked', String(on));
    b.tabIndex = on ? 0 : -1;
  });
}

/* ---------- 标签页 ---------- */
const tabs = $$('[role="tab"]');
function selectTab(tab, focus = false) {
  tabs.forEach((x) => {
    const on = x === tab;
    x.setAttribute('aria-selected', String(on));
    x.tabIndex = on ? 0 : -1;
    document.getElementById(x.getAttribute('aria-controls')).hidden = !on;
  });
  if (focus) tab.focus();
  showView(tab.id === 'tab-type' ? 'read' : 'home');
}
tabs.forEach((tab) => tab.addEventListener('click', () => selectTab(tab)));
$('[role="tablist"]').addEventListener('keydown', (event) => {
  const index = tabs.indexOf(document.activeElement);
  if (index < 0) return;
  const target = {
    ArrowRight: tabs[(index + 1) % tabs.length],
    ArrowLeft: tabs[(index - 1 + tabs.length) % tabs.length],
    Home: tabs[0],
    End: tabs[tabs.length - 1],
  }[event.key];
  if (target) {
    event.preventDefault();
    selectTab(target, true);
  }
});

function showView(name) {
  $$('[data-app-view]', app).forEach((view) => {
    const on = view.dataset.appView === name;
    view.hidden = !on;
    view.inert = !on;
  });
}

/* ---------- 主题色 ---------- */
const familiesEl = $('[data-families]');
const shadesEl = $('[data-shades]');
const hexEl = $('[data-seed-hex]');
const dotsEl = document.querySelector('[data-family-dots]');
let shownFamily = familyOf(getSeed());

function renderFamilies() {
  const names = t('familyNames');
  familiesEl.innerHTML = FAMILIES.map(
    (f, i) =>
      `<button class="swatch" type="button" role="radio" data-family="${i}" style="--sw:#${f[2]};--ink:${inkFor(f[2])}" aria-label="${t('familyLabel', { name: names[i] })}">${checkIcon}</button>`,
  ).join('');
  if (dotsEl) {
    dotsEl.innerHTML = FAMILIES.map(
      (f, i) =>
        `<button class="dot-btn" type="button" data-seed="${f[5]}" style="--sw:#${f[5]}" aria-label="${t('seedLabel', { hex: `#${f[5].toUpperCase()}` })} · ${names[i]}"></button>`,
    ).join('');
  }
}

function renderShades() {
  shadesEl.innerHTML = FAMILIES[shownFamily]
    .map(
      (c) =>
        `<button class="swatch" type="button" role="radio" data-seed="${c}" style="--sw:#${c};--ink:${inkFor(c)}" aria-label="${t('seedLabel', { hex: `#${c.toUpperCase()}` })}">${checkIcon}</button>`,
    )
    .join('');
}

function syncTheme() {
  const seed = getSeed();
  check($('[data-theme-seg]'), (b) => b.dataset.value === getMode());
  check(familiesEl, (b) => Number(b.dataset.family) === familyOf(seed));
  check(shadesEl, (b) => b.dataset.seed === seed);
  hexEl.textContent = `#${seed.toUpperCase()}`;
  dotsEl?.querySelectorAll('.dot-btn').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.seed === seed)));
}

radioGroup($('[data-theme-seg]'), (button) => setMode(button.dataset.value, originOf(button)));
radioGroup(familiesEl, (button) => {
  shownFamily = Number(button.dataset.family);
  renderShades();
  setSeed(FAMILIES[shownFamily][0], originOf(button));
  syncTheme();
});
radioGroup(shadesEl, (button) => setSeed(button.dataset.seed, originOf(button)));
dotsEl?.addEventListener('click', (event) => {
  const button = event.target.closest('[data-seed]');
  if (!button) return;
  shownFamily = familyOf(button.dataset.seed);
  renderShades();
  setSeed(button.dataset.seed, originOf(button));
});
$('[data-seed-reset]').addEventListener('click', (event) => {
  shownFamily = DEFAULT_FAMILY;
  renderShades();
  setSeed(DEFAULT_SEED, originOf(event.currentTarget));
});

/* ---------- 卡片样式 ---------- */
const layoutSeg = $('[data-layout-seg]');
const presetsEl = $('[data-presets]');
radioGroup(layoutSeg, (button) => {
  feed.dataset.layout = button.dataset.value;
  check(layoutSeg, (b) => b === button);
});
radioGroup(presetsEl, (button) => {
  feed.dataset.preset = button.dataset.value;
  check(presetsEl, (b) => b === button);
});

/* ---------- 正文排版（取值范围与 app 的 DiaryTypography 一致） ---------- */
const fontSeg = $('[data-font-seg]');
radioGroup(fontSeg, (button) => {
  const font = FONTS[button.dataset.value];
  if (font) app.style.setProperty('--read-font', font);
  else app.style.removeProperty('--read-font');
  check(fontSeg, (b) => b === button);
});

const sliders = $$('[data-type-prop]');
function formatValue(prop, value) {
  if (prop === 'lh') return value.toFixed(2);
  if (prop === 'ls') return String(Math.round(value * 100) / 100);
  return String(value);
}
function applySlider(input) {
  const prop = input.dataset.typeProp;
  const value = Number(input.value);
  const min = Number(input.min);
  const max = Number(input.max);
  input.closest('.slider-ctl').style.setProperty('--t', String((value - min) / (max - min)));
  readText.style.setProperty(`--${prop}`, String(value));
  $(`[data-out="${prop}"]`).textContent = formatValue(prop, value);
}
sliders.forEach((input) => {
  input.addEventListener('input', () => applySlider(input));
  applySlider(input);
});
$('[data-type-reset]').addEventListener('click', () => {
  sliders.forEach((input) => {
    input.value = String(TYPE_DEFAULTS[input.dataset.typeProp]);
    applySlider(input);
  });
  app.style.removeProperty('--read-font');
  check(fontSeg, (b) => b.dataset.value === 'harmony');
});

/* ---------- 初始化 ---------- */
renderFamilies();
renderShades();
syncTheme();
showView('home');
onThemeChange(() => {
  shownFamily = familyOf(getSeed());
  renderShades();
  syncTheme();
});
onLangChange(() => {
  renderFamilies();
  renderShades();
  syncTheme();
});
