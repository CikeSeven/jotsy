// 官网入口脚本（index / privacy / 404 共用）。
//
// 负责：语言与明暗初始化、顶栏与移动端菜单、导航与目录高亮、进场动画、功能选项卡、
// 常见问题展开动画、复制与提示条。主题色面板（palette.js）与下载区（download.js）
// 只在页面上有对应区块时按需加载。
//
// 所有动画都尊重系统“减少动态效果”：开启时直接呈现终态。

import { initI18n, onLangChange, setLang, currentLang, t } from './i18n.js';
import { initTheme, cycleMode, getMode, onThemeChange } from './theme.js';
import { toast, copyText } from './ui.js';

const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

// 模块真正跑起来才打上 js 标记：进场动画、选项卡、文档单语显示都以它为前提，
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

// 滚过 8px 后顶栏换成半透明底；用 rAF 合并滚动事件，每帧最多算一次
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
// 与 CSS 断点一致：宽到显示顶栏导航时菜单按钮隐藏，展开着的菜单一并收起
matchMedia('(min-width: 900px)').addEventListener?.('change', (e) => e.matches && setMenu(false));

/* ---------- 导航高亮（滚动到哪个区块就点亮哪个链接） ---------- */
const navLinks = $$('.nav a[href^="#"]');
if (navLinks.length && 'IntersectionObserver' in window) {
  const byId = new Map();
  navLinks.forEach((a) => {
    const target = document.getElementById(a.getAttribute('href').slice(1));
    if (target) byId.set(target, [...(byId.get(target) || []), a]);
  });
  const visible = new Set();
  const spy = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => (e.isIntersecting ? visible.add(e.target) : visible.delete(e.target)));
      // 取文档顺序里第一个穿过视口中线附近的区块
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

/* ---------- 进场动画：进入视口一次即定格，不随滚动反复 ---------- */
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

/*
 * ---------- 功能选项卡 ----------
 * 结构：[data-tabs] 里一组 role=tab（aria-controls 指向文字面板），面板为 role=tabpanel，
 * 截图为 img[data-shot=<tab id>]，叠在同一台手机里，当前一张加 .is-active 淡入。
 * 只在用户点按或用方向键时切换，不自动轮播（自动轮播会打断阅读）。
 * 没有脚本时 HTML 里全部面板都可见、截图只显示第一张，内容不缺。
 */
$$('[data-tabs]').forEach((root) => {
  const tabs = $$('[role="tab"]', root);
  const shots = $$('[data-shot]', root);
  if (!tabs.length) return;

  const select = (tab, focus = false) => {
    tabs.forEach((x) => {
      const on = x === tab;
      x.setAttribute('aria-selected', String(on));
      x.tabIndex = on ? 0 : -1;
      const panel = document.getElementById(x.getAttribute('aria-controls'));
      if (panel) panel.hidden = !on;
    });
    shots.forEach((img) => {
      const on = img.dataset.shot === tab.id;
      img.classList.toggle('is-active', on);
      // 叠放的截图都带 loading=lazy；切到哪张就确保哪张开始加载
      if (on) img.loading = 'eager';
    });
    if (focus) tab.focus();
  };

  tabs.forEach((tab) => tab.addEventListener('click', () => select(tab)));
  $('[role="tablist"]', root)?.addEventListener('keydown', (event) => {
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
      select(target, true);
    }
  });

  select(tabs.find((x) => x.getAttribute('aria-selected') === 'true') || tabs[0]);
});

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
    // 先展开才量得到终点高度；收起时等动画结束再真正合上，内容不会提前消失
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

/* ---------- 按需加载：主题色面板与下载区 ---------- */
if ($('[data-palette]')) import('./palette.js').catch((e) => console.error(e));
if ($('[data-download]') || $('[data-stars]')) import('./download.js').catch((e) => console.error(e));
