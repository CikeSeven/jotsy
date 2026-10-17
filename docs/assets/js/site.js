// 官网入口脚本（index / privacy / 404 共用）。
//
// 负责：语言与明暗初始化、顶栏与移动端菜单、导航高亮、进场动画、数字递增、功能章节的
// 滚动叙事、首屏形状变形与视差、常见问题展开动画、复制与提示条。外观实验室（lab.js）
// 与下载区（download.js）只在页面上有对应区块时按需加载。
//
// 所有动画都尊重系统“减少动态效果”：开启时不变形、不视差、不递增，直接呈现终态。

import { initI18n, onLangChange, setLang, currentLang, t } from './i18n.js';
import { initTheme, cycleMode, getMode, onThemeChange } from './theme.js';
import { SHAPES, toPath, lerpShape, SAMPLES } from './shapes.js';
import { toast, copyText } from './ui.js';

const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

// 模块真正跑起来才打上 js 标记：进场动画、步骤调暗、文档单语显示都以它为前提，
// 不支持模块或脚本加载失败的浏览器看到的是完整的静态页面。
document.documentElement.classList.add('js');
initI18n();
initTheme();

/* ---------- 复制（QQ 群号等） ---------- */
document.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-copy]');
  if (!button) return;
  const ok = await copyText(button.getAttribute('data-copy'));
  toast(ok ? button.getAttribute('data-copied') || t('copied') : t('copyFailed'));
});

/* ---------- 语言与明暗按钮 ---------- */
function originOf(el) {
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

$$('[data-lang-toggle]').forEach((button) => {
  button.addEventListener('click', () => setLang(currentLang() === 'en' ? 'zh' : 'en'));
});

$$('[data-lang-seg]').forEach((seg) => {
  const sync = () =>
    $$('button', seg).forEach((b) => b.setAttribute('aria-checked', String(b.dataset.value === currentLang())));
  seg.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-value]');
    if (button) setLang(button.dataset.value);
  });
  onLangChange(sync);
  sync();
});

function syncThemeButton() {
  const label = { system: t('themeSystem'), light: t('themeLight'), dark: t('themeDark') }[getMode()];
  $$('[data-theme-toggle]').forEach((b) => {
    b.setAttribute('aria-label', label);
    b.setAttribute('title', label);
  });
}

$$('[data-theme-toggle]').forEach((button) => {
  button.addEventListener('click', () => cycleMode(originOf(button)));
});
onThemeChange(syncThemeButton);
onLangChange(syncThemeButton);
syncThemeButton();

/* ---------- 顶栏与移动端菜单 ---------- */
const header = $('.site-header');
const menu = $('#mobile-menu');
const menuButton = $('.menu-btn');

if (header) {
  let ticking = false;
  const update = () => {
    header.dataset.elevated = String(scrollY > 8);
    ticking = false;
  };
  addEventListener(
    'scroll',
    () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    },
    { passive: true },
  );
  update();
}

function setMenu(open) {
  if (!menu || !menuButton) return;
  menu.hidden = !open;
  menuButton.setAttribute('aria-expanded', String(open));
  header?.classList.toggle('is-menu-open', open);
}

menuButton?.addEventListener('click', () => setMenu(menu.hidden));
menu?.addEventListener('click', (event) => {
  if (event.target.closest('a')) setMenu(false);
});
addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && menu && !menu.hidden) {
    setMenu(false);
    menuButton.focus();
  }
});
matchMedia('(min-width: 1021px)').addEventListener?.('change', (e) => e.matches && setMenu(false));

/* ---------- 导航高亮（滚动到哪个区块就点亮哪个链接） ---------- */
const navLinks = $$('.nav a[href^="#"]');
if (navLinks.length && 'IntersectionObserver' in window) {
  const byId = new Map();
  navLinks.forEach((a) => {
    const id = a.getAttribute('href').slice(1);
    const target = document.getElementById(id);
    if (target) byId.set(target, [...(byId.get(target) || []), a]);
  });
  const visible = new Set();
  const spy = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => (e.isIntersecting ? visible.add(e.target) : visible.delete(e.target)));
      // 取文档顺序里第一个可见区块
      const first = [...byId.keys()].find((el) => visible.has(el));
      navLinks.forEach((a) => a.removeAttribute('aria-current'));
      if (first) byId.get(first).forEach((a) => a.setAttribute('aria-current', 'true'));
    },
    { rootMargin: '-40% 0px -55% 0px' },
  );
  byId.forEach((_, el) => spy.observe(el));
}

/* ---------- 文档目录高亮：最后一个越过视口 35% 线的标题 ---------- */
const tocLinks = $$('.toc a[href^="#"]');
if (tocLinks.length) {
  const pairs = tocLinks
    .map((a) => [a, document.getElementById(a.getAttribute('href').slice(1))])
    .filter(([, el]) => el);
  let ticking = false;
  const update = () => {
    ticking = false;
    const line = innerHeight * 0.35;
    let current = null;
    for (const [a, el] of pairs) {
      if (el.offsetParent === null) continue; // 另一种语言的正文被隐藏了
      if (el.getBoundingClientRect().top <= line) current = a;
    }
    tocLinks.forEach((a) => (a === current ? a.setAttribute('aria-current', 'true') : a.removeAttribute('aria-current')));
  };
  addEventListener(
    'scroll',
    () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    },
    { passive: true },
  );
  onLangChange(update);
  update();
}

/* ---------- 进场动画 ---------- */
const reveals = $$('.reveal');
if ('IntersectionObserver' in window && !reducedMotion.matches) {
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add('is-in');
          io.unobserve(e.target);
        }
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
  );
  reveals.forEach((el) => io.observe(el));
} else {
  reveals.forEach((el) => el.classList.add('is-in'));
}

/* ---------- 数字递增（首次进入视口时从 0 数到目标值） ---------- */
const counters = $$('[data-count]');
if (counters.length && 'IntersectionObserver' in window && !reducedMotion.matches) {
  const run = (el) => {
    const target = Number(el.dataset.count);
    const start = performance.now();
    const duration = 1100;
    const frame = (now) => {
      const p = Math.min(1, (now - start) / duration);
      el.textContent = String(Math.round(target * (1 - (1 - p) ** 3)));
      if (p < 1) requestAnimationFrame(frame);
    };
    el.textContent = '0';
    requestAnimationFrame(frame);
  };
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          run(e.target);
          io.unobserve(e.target);
        }
      });
    },
    { threshold: 0.6 },
  );
  counters.forEach((el) => io.observe(el));
}

/* ---------- 功能章节：文字滚到视口中部时，左侧手机切到对应截图 ---------- */
$$('[data-story]').forEach((chapter) => {
  const steps = $$('.story-step', chapter);
  const shots = $$('.story-shot', chapter);
  const dots = $$('.story-dots li', chapter);
  if (!('IntersectionObserver' in window) || !steps.length) return;
  const activate = (index) => {
    steps.forEach((s, i) => s.classList.toggle('is-active', i === index));
    shots.forEach((s, i) => s.classList.toggle('is-active', i === index));
    dots.forEach((d, i) => d.classList.toggle('is-active', i === index));
  };
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) activate(steps.indexOf(e.target));
      });
    },
    { rootMargin: '-45% 0px -45% 0px' },
  );
  steps.forEach((s) => io.observe(s));
});

/* ---------- 首屏：形状变形与指针视差 ---------- */
const hero = $('[data-hero]');
if (hero && !reducedMotion.matches) {
  const big = $('[data-morph]', hero);
  const small = $('[data-morph-small]', hero);
  const sequences = [
    [big, ['cookie9', 'clover4', 'sunny', 'pentagon', 'cookie12', 'softBurst', 'gem'], 0.08],
    [small, ['sunny', 'clover8', 'heart', 'softBurst', 'triangle'], -0.14],
  ].filter(([el]) => el);
  const buffers = sequences.map(() => new Float64Array(SAMPLES));
  const MORPH = 1400;
  const HOLD = 1600;
  const ease = (x) => (x < 0.5 ? 4 * x * x * x : 1 - (-2 * x + 2) ** 3 / 2);
  let visible = true;
  let raf = 0;
  const begin = performance.now();

  const frame = (now) => {
    // rAF 的时间戳是帧开始时刻，可能早于上面记下的 begin，取 0 以免算出负的序号
    const elapsed = Math.max(0, now - begin);
    sequences.forEach(([el, names, spin], i) => {
      const cycle = MORPH + HOLD;
      const step = Math.floor(elapsed / cycle);
      const local = elapsed - step * cycle;
      const from = SHAPES[names[step % names.length]];
      const to = SHAPES[names[(step + 1) % names.length]];
      const p = local < HOLD ? 0 : ease((local - HOLD) / MORPH);
      lerpShape(from, to, p, buffers[i]);
      el.setAttribute('d', toPath(buffers[i], 100, (elapsed / 1000) * spin, 1));
    });
    raf = visible && !document.hidden ? requestAnimationFrame(frame) : 0;
  };
  const resume = () => {
    if (!raf && visible && !document.hidden) raf = requestAnimationFrame(frame);
  };
  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    resume();
  }).observe(hero);
  document.addEventListener('visibilitychange', resume);
  resume();

  // 视差：只在有精确指针（鼠标、触控板）的设备上跟随
  if (matchMedia('(hover: hover) and (pointer: fine)').matches) {
    let tx = 0;
    let ty = 0;
    let cx = 0;
    let cy = 0;
    let moving = 0;
    const tick = () => {
      cx += (tx - cx) * 0.08;
      cy += (ty - cy) * 0.08;
      hero.style.setProperty('--px', cx.toFixed(3));
      hero.style.setProperty('--py', cy.toFixed(3));
      moving = Math.abs(tx - cx) + Math.abs(ty - cy) > 0.001 ? requestAnimationFrame(tick) : 0;
    };
    $('.hero')?.addEventListener('pointermove', (event) => {
      const r = hero.getBoundingClientRect();
      tx = Math.max(-1, Math.min(1, ((event.clientX - r.left) / r.width) * 2 - 1));
      ty = Math.max(-1, Math.min(1, ((event.clientY - r.top) / r.height) * 2 - 1));
      if (!moving) moving = requestAnimationFrame(tick);
    });
    $('.hero')?.addEventListener('pointerleave', () => {
      tx = 0;
      ty = 0;
      if (!moving) moving = requestAnimationFrame(tick);
    });
  }
}

/* ---------- 常见问题：展开 / 收起时高度补间 ---------- */
$$('details.faq').forEach((details) => {
  const summary = $('summary', details);
  const body = $('.faq-body', details);
  if (!summary || !body || !details.animate) return;
  let animation = null;
  summary.addEventListener('click', (event) => {
    if (reducedMotion.matches) return;
    event.preventDefault();
    animation?.cancel();
    const startHeight = details.offsetHeight;
    const borders = details.offsetHeight - details.clientHeight;
    const opening = !details.open;
    if (opening) details.open = true;
    const endHeight = opening ? details.offsetHeight : summary.offsetHeight + borders;
    details.style.overflow = 'hidden';
    animation = details.animate(
      { height: [`${startHeight}px`, `${endHeight}px`] },
      { duration: 320, easing: 'cubic-bezier(.2, 0, 0, 1)' },
    );
    animation.onfinish = () => {
      details.open = opening;
      details.style.overflow = '';
      animation = null;
    };
    animation.oncancel = () => {
      details.style.overflow = '';
    };
  });
});

/* ---------- 按需加载：外观实验室与下载区 ---------- */
if ($('[data-lab]')) import('./lab.js').catch((e) => console.error(e));
if ($('[data-download]') || $('[data-stars]')) import('./download.js').catch((e) => console.error(e));
