// 小工具：提示条与复制到剪贴板（site.js / lab.js / download.js 共用）。

let toastTimer = 0;

/** 底部提示条，2.2 秒后自动收起；连续调用会刷新文案并重新计时。 */
export function toast(message) {
  const el = document.querySelector('[data-toast]');
  if (!el) return;
  el.querySelector('[data-toast-text]').textContent = message;
  el.classList.add('is-shown');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('is-shown'), 2200);
}

/** 复制文本；剪贴板 API 不可用（非 https、权限被拒）时退回选区复制。 */
export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (e) {
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.cssText = 'position:fixed;opacity:0;pointer-events:none';
    document.body.appendChild(area);
    area.select();
    let ok = false;
    try {
      ok = document.execCommand('copy');
    } catch (err) {
      ok = false;
    }
    area.remove();
    return ok;
  }
}
