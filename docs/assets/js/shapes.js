// Material 3 Expressive 风格的形状：饼干形、四叶草、太阳形、圆角多边形、胶囊……
//
// 每个形状都表示成围绕中心的径向采样（N 个角度上的半径），并归一化到相同面积。
// 两个形状之间逐个插值半径即可平滑变形，不会扭结；转成路径时用二次曲线连接相邻
// 采样的中点，得到闭合平滑轮廓。site.js 用它做首屏的变形背景，tool 脚本用它
// 生成 site.css 里的静态遮罩（--shape-*），两边共用同一份几何。

export const SAMPLES = 72;
const TAU = Math.PI * 2;

/** 按 r(θ) 采样并把面积归一化到半径 0.82 的圆。 */
function radial(fn) {
  const r = new Float64Array(SAMPLES);
  for (let i = 0; i < SAMPLES; i++) r[i] = fn((i / SAMPLES) * TAU);
  let area = 0;
  for (let i = 0; i < SAMPLES; i++) area += r[i] * r[i];
  area *= Math.PI / SAMPLES; // Σ ½r²Δθ
  const k = Math.sqrt((Math.PI * 0.82 * 0.82) / area);
  for (let i = 0; i < SAMPLES; i++) r[i] *= k;
  return r;
}

/** 沿每条射线二分查找 sdf 的零点，得到星形区域的径向采样。 */
function fromSdf(sdf) {
  return radial((t) => {
    const c = Math.cos(t);
    const s = Math.sin(t);
    let lo = 0;
    let hi = 2;
    for (let k = 0; k < 28; k++) {
      const m = (lo + hi) / 2;
      if (sdf(m * c, m * s) < 0) lo = m;
      else hi = m;
    }
    return (lo + hi) / 2;
  });
}

/** 正多边形（外接圆半径 1）的精确有符号距离，再整体外扩 k 得到圆角。 */
function roundedPolygon(sides, k, rotation = -Math.PI / 2, scaleY = 1) {
  const pts = [];
  const shrink = 1 - k / Math.cos(Math.PI / sides);
  for (let i = 0; i < sides; i++) {
    const a = rotation + (i / sides) * TAU;
    pts.push([Math.cos(a) * shrink, Math.sin(a) * shrink * scaleY]);
  }
  return (x, y) => {
    let d = Infinity;
    let inside = false;
    for (let i = 0, j = sides - 1; i < sides; j = i++) {
      const [xi, yi] = pts[i];
      const [xj, yj] = pts[j];
      const ex = xj - xi;
      const ey = yj - yi;
      const wx = x - xi;
      const wy = y - yi;
      const h = Math.max(0, Math.min(1, (wx * ex + wy * ey) / (ex * ex + ey * ey)));
      const dx = wx - ex * h;
      const dy = wy - ey * h;
      d = Math.min(d, dx * dx + dy * dy);
      if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    }
    return (inside ? -Math.sqrt(d) : Math.sqrt(d)) - k;
  };
}

/** 斜放的胶囊。 */
function pill(angle = -Math.PI / 4) {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  return (x, y) => {
    const u = x * c + y * s;
    const v = -x * s + y * c;
    const cu = Math.max(-0.42, Math.min(0.42, u));
    return Math.hypot(u - cu, v) - 0.5;
  };
}

/** 爱心（Inigo Quilez 的 sdHeart，零点集精确即可）。 */
function heart(x, y) {
  const px = Math.abs(x) / 1.05;
  const py = (-y + 0.92) / 1.05;
  if (py + px > 1) return Math.hypot(px - 0.25, py - 0.75) - Math.SQRT2 / 4;
  const a = Math.hypot(px, py - 1);
  const m = 0.5 * Math.max(px + py, 0);
  const b = Math.hypot(px - m, py - m);
  return Math.sqrt(Math.min(a * a, b * b)) * Math.sign(px - py);
}

/** n 片圆叶围成的四叶草 / 八叶草：圆形平滑并集，叶片饱满、叶间凹口深。 */
function lobes(n, dist, radius, rotation = Math.PI / 4, smooth = 0.12) {
  const centers = [];
  for (let i = 0; i < n; i++) {
    const a = rotation + (i / n) * TAU;
    centers.push([Math.cos(a) * dist, Math.sin(a) * dist]);
  }
  return (x, y) => {
    let d = Math.hypot(x, y) - dist * 0.9; // 中心填实，射线只穿出一次
    for (const [cx, cy] of centers) {
      const e = Math.hypot(x - cx, y - cy) - radius;
      const h = Math.max(0, Math.min(1, 0.5 + (0.5 * (e - d)) / smooth));
      d = e * (1 - h) + d * h - smooth * h * (1 - h);
    }
    return d;
  };
}

const cookie = (n, a) => radial((t) => 1 + a * Math.cos(n * t));
const burst = (n, a, b) => radial((t) => 1 + a * Math.cos(n * t) + b * Math.cos(2 * n * t));

export const SHAPES = {
  circle: radial(() => 1),
  cookie4: cookie(4, 0.1),
  cookie6: cookie(6, 0.075),
  cookie9: cookie(9, 0.065),
  cookie12: cookie(12, 0.05),
  clover4: fromSdf(lobes(4, 0.42, 0.5)),
  clover8: fromSdf(lobes(8, 0.6, 0.32, 0, 0.08)),
  sunny: burst(8, 0.1, 0.035),
  softBurst: burst(10, 0.075, 0.03),
  pentagon: fromSdf(roundedPolygon(5, 0.2)),
  triangle: fromSdf(roundedPolygon(3, 0.28, -Math.PI / 2)),
  gem: fromSdf(roundedPolygon(6, 0.16, 0, 0.86)),
  square: fromSdf(roundedPolygon(4, 0.3, Math.PI / 4)),
  pill: fromSdf(pill()),
  heart: fromSdf(heart),
};

/** 半径数组 → SVG 路径；坐标映射到 0..size 的方形画布，旋转 rotation 弧度。 */
export function toPath(r, size = 100, rotation = 0, precision = 1) {
  const n = r.length;
  const half = size / 2;
  // 留 4% 边距：太阳形、四叶草的尖角会略超出面积等效圆。
  const scale = half * 0.96 / 1.12;
  const f = 10 ** precision;
  const px = new Array(n);
  const py = new Array(n);
  for (let i = 0; i < n; i++) {
    const t = (i / n) * TAU + rotation;
    px[i] = half + Math.cos(t) * r[i] * scale;
    py[i] = half + Math.sin(t) * r[i] * scale;
  }
  const q = (v) => Math.round(v * f) / f;
  const mid = (i) => {
    const j = (i + 1) % n;
    return [q((px[i] + px[j]) / 2), q((py[i] + py[j]) / 2)];
  };
  const start = mid(n - 1);
  let d = `M${start[0]} ${start[1]}`;
  for (let i = 0; i < n; i++) {
    const m = mid(i);
    d += `Q${q(px[i])} ${q(py[i])} ${m[0]} ${m[1]}`;
  }
  return `${d}Z`;
}

/** 两组半径按 t（0..1）插值，结果写进 out 以免逐帧分配。 */
export function lerpShape(a, b, t, out) {
  for (let i = 0; i < a.length; i++) out[i] = a[i] + (b[i] - a[i]) * t;
  return out;
}
