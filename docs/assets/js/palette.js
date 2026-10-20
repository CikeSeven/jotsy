// 主题色面板：一排色系 + 当前色系的 8 个色阶 + 明暗三段切换。换的是整个网页
// （theme.js 注入配色），与 app 里“主题色”的效果一致。
//
// 色板与 app 的 kColorPaletteFamilies 一致（lib/ui/widgets/color_palette_families.dart，
// 也与 assets/data/themes.json 的 families 相同；这里留一份副本，免得为了画色块在首屏
// 就去请求 27 KB 的配色数据——配色只在第一次换色时才懒加载）。色系按钮显示第 3 个色
// （colors[2]），点按选中该色系的第 1 个色（colors[0]），与 PaletteColorPicker 的行为相同。

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

const root = document.querySelector('[data-palette]');
const familiesEl = root.querySelector('[data-families]');
const shadesEl = root.querySelector('[data-shades]');
const modeSeg = root.querySelector('[data-mode-seg]');
const resetButton = root.querySelector('[data-seed-reset]');

const checkIcon = '<svg class="i" aria-hidden="true"><use href="assets/img/icons.svg#i-check"></use></svg>';

function originOf(el) {
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

function familyOf(seed) {
  const i = FAMILIES.findIndex((f) => f.includes(seed));
  return i < 0 ? DEFAULT_FAMILY : i;
}

/** 色块上勾选图标的颜色：浅色块用深色勾，深色块用白色勾（颜色来自色块数据本身）。 */
function inkFor(hex) {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.62 ? '#1b1f22' : '#ffffff';
}

let shownFamily = familyOf(getSeed());

/* ---------- 单选组（role=radiogroup）的通用键盘行为：方向键移动并选中 ---------- */
function radioGroup(group, onSelect) {
  group.addEventListener('click', (event) => {
    const button = event.target.closest('[role="radio"]');
    if (button && group.contains(button)) onSelect(button);
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
    onSelect(next);
  });
}

function check(group, predicate) {
  group.querySelectorAll('[role="radio"]').forEach((b) => {
    const on = predicate(b);
    b.setAttribute('aria-checked', String(on));
    b.tabIndex = on ? 0 : -1;
  });
}

function renderFamilies() {
  const names = t('familyNames');
  familiesEl.innerHTML = FAMILIES.map(
    (f, i) =>
      `<button class="swatch" type="button" role="radio" data-family="${i}" style="--sw:#${f[2]};--ink:${inkFor(f[2])}" aria-label="${t('familyLabel', { name: names[i] })}" title="${names[i]}">${checkIcon}</button>`,
  ).join('');
}

function renderShades() {
  shadesEl.innerHTML = FAMILIES[shownFamily]
    .map(
      (c) =>
        `<button class="swatch" type="button" role="radio" data-seed="${c}" style="--sw:#${c};--ink:${inkFor(c)}" aria-label="${t('seedLabel', { hex: `#${c.toUpperCase()}` })}">${checkIcon}</button>`,
    )
    .join('');
}

function sync() {
  const seed = getSeed();
  check(modeSeg, (b) => b.dataset.value === getMode());
  // 色系按“正在看的那一组”高亮（点了色系还没等配色加载完时也立即有反馈）
  check(familiesEl, (b) => Number(b.dataset.family) === shownFamily);
  check(shadesEl, (b) => b.dataset.seed === seed);
  resetButton.hidden = seed === DEFAULT_SEED;
}

radioGroup(modeSeg, (button) => setMode(button.dataset.value, originOf(button)));
radioGroup(familiesEl, (button) => {
  shownFamily = Number(button.dataset.family);
  renderShades();
  sync();
  setSeed(FAMILIES[shownFamily][0], originOf(button));
});
radioGroup(shadesEl, (button) => setSeed(button.dataset.seed, originOf(button)));
resetButton.addEventListener('click', (event) => {
  shownFamily = DEFAULT_FAMILY;
  renderShades();
  setSeed(DEFAULT_SEED, originOf(event.currentTarget));
});

renderFamilies();
renderShades();
sync();
onThemeChange(() => {
  shownFamily = familyOf(getSeed());
  renderShades();
  sync();
});
onLangChange(() => {
  renderFamilies();
  renderShades();
  sync();
});
