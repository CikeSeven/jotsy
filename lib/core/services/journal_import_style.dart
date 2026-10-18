/// 把第三方正文里的颜色、字号与对齐换算成本应用正文（Quill Delta）能渲染
/// 的值；各导入来源（HTML、Markdown 行内 HTML、手机笔记的私有标记）共用。
///
/// - 颜色一律输出 `#AARRGGBB`：Quill 只认 `#RRGGBB` / `#AARRGGBB` 与少数颜色
///   名，`rgb()`、CSS 的 `#RRGGBBAA` 等写法会让正文渲染时抛异常；PDF 导出把
///   6 位十六进制当作全透明，所以始终带上 alpha。
/// - 来源应用的默认配色不导入：接近黑 / 白的无彩色文字是对方主题的默认墨色，
///   白色、透明背景是对方的纸色，原样导入会在本应用的暗色（或亮色）主题下
///   看不清；只保留用户主动设置的彩色与中间灰。
/// - 字号换算成 Quill 的 small / large / huge 三档（相对正文字号，跟随用户
///   的正文排版设置），不写绝对像素。
/// - 对齐只保留 center / right / justify，左对齐即默认。
///
/// 纯函数，无 IO。
library;

/// 导入的“高亮”（荧光笔、`<mark>` 等没有具体颜色的标记）统一使用的背景色：
/// 40% 不透明的琥珀色，亮暗主题下都能看清上面的文字。
const String journalHighlightColor = '#66FFC107';

/// 文字颜色：解析失败、几乎透明或属于默认墨色（接近黑 / 白的无彩色）时返回
/// null。
String? journalTextColor(String? css) {
  final color = _JournalColor.parse(css);
  if (color == null || color.a < 0.2) return null;
  if (color.isNeutral && (color.lightness < 0.3 || color.lightness > 0.85)) {
    return null;
  }
  return color.hex;
}

/// 背景（高亮）颜色：透明、白色 / 近白、黑色 / 近黑的无彩色背景返回 null。
String? journalBackgroundColor(String? css) {
  final color = _JournalColor.parse(css);
  if (color == null || color.a < 0.05) return null;
  if (color.isNeutral && (color.lightness < 0.12 || color.lightness > 0.9)) {
    return null;
  }
  return color.hex;
}

/// 是否是能识别的颜色值（`inherit`、`currentColor`、CSS 变量等返回 false）。
/// 转换器据此区分“改回默认色”（应去掉继承的颜色）与“看不懂”（保持继承）。
bool journalIsColor(String? css) => _JournalColor.parse(css) != null;

/// CSS `font-size`（关键字、px、pt、em、rem、%）与来源正文字号 [base]（px）
/// 之比；无法识别（`inherit`、`calc()` 等）时返回 null。再经
/// [journalFontSizeForRatio] 换算成档位。
double? journalFontSizeRatio(String? css, {double base = 16}) {
  final value = css?.trim().toLowerCase();
  if (value == null || value.isEmpty || base <= 0) return null;
  final keyword = switch (value) {
    'xx-small' => 0.6,
    'x-small' => 0.75,
    'small' || 'smaller' => 0.82,
    'medium' => 1.0,
    'large' || 'larger' => 1.2,
    'x-large' => 1.5,
    'xx-large' => 2.0,
    'xxx-large' => 3.0,
    _ => null,
  };
  if (keyword != null) return keyword;
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(px|pt|em|rem|%)?$',
  ).firstMatch(value);
  final number = match == null ? null : double.tryParse(match.group(1)!);
  if (number == null || number <= 0) return null;
  return switch (match!.group(2)) {
    'pt' => number * 4 / 3 / base,
    'em' || 'rem' => number,
    '%' => number / 100,
    _ => number / base,
  };
}

/// 字号与正文字号之比换算成档位：小于等于 0.85 为 small，1.1 起为 large，
/// 1.4 起为 huge；本应用对应的倍数见 `buildDiaryQuillStyles`。
String? journalFontSizeForRatio(double ratio) {
  if (!ratio.isFinite || ratio <= 0) return null;
  if (ratio <= 0.85) return 'small';
  if (ratio >= 1.4) return 'huge';
  if (ratio >= 1.1) return 'large';
  return null;
}

/// HTML `<font size="1~7">`（3 为正文字号）换算成档位。
String? journalFontSizeForLegacyLevel(String? level) {
  final raw = level?.trim() ?? '';
  final number = int.tryParse(raw.replaceFirst('+', ''));
  if (number == null) return null;
  final absolute = raw.startsWith('+') || raw.startsWith('-')
      ? 3 + number
      : number;
  if (absolute <= 2) return 'small';
  if (absolute >= 6) return 'huge';
  if (absolute >= 4) return 'large';
  return null;
}

/// CSS `text-align` / HTML `align` 换算成 Quill 的行对齐；左对齐与无法识别
/// 时返回 null。
String? journalAlign(String? css) => switch (css?.trim().toLowerCase()) {
  'center' || 'middle' || '-webkit-center' => 'center',
  'right' || 'end' || '-webkit-right' => 'right',
  'justify' => 'justify',
  _ => null,
};

/// Android 风格的 `#AARRGGBB`（小米笔记等）改写成 CSS 的 `#RRGGBBAA`，再交给
/// [journalTextColor] / [journalBackgroundColor]；6 位值原样返回，其他写法
/// 返回 null。8 位十六进制在两种约定下无法区分，只能由来源决定用哪个。
String? journalArgbToCss(String? hex) {
  final value = hex?.trim() ?? '';
  final match = RegExp(
    r'^#?([0-9a-fA-F]{2})([0-9a-fA-F]{6})$',
  ).firstMatch(value);
  if (match != null) return '#${match.group(2)}${match.group(1)}';
  return RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(value)
      ? '#${value.replaceFirst('#', '')}'
      : null;
}

/// 读取内联 `style` 中某个属性的值（最后一次声明生效）；没有时返回 null。
String? journalStyleValue(String? style, String property) {
  if (style == null || style.isEmpty) return null;
  String? result;
  for (final declaration in style.split(';')) {
    final colon = declaration.indexOf(':');
    if (colon <= 0) continue;
    if (declaration.substring(0, colon).trim().toLowerCase() == property) {
      result = declaration
          .substring(colon + 1)
          .replaceFirst(RegExp(r'!important\s*$', caseSensitive: false), '')
          .trim();
    }
  }
  return result;
}

/// 解析后的 sRGB 颜色，各分量 0~255，[a] 为 0~1。
class _JournalColor {
  const _JournalColor(this.r, this.g, this.b, this.a);

  final int r;
  final int g;
  final int b;
  final double a;

  String get hex {
    String two(int value) =>
        value.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two((a * 255).round())}${two(r)}${two(g)}${two(b)}'
        .toUpperCase();
  }

  /// HSL 亮度，0~1。
  double get lightness {
    final values = [r, g, b];
    final max = values.reduce((x, y) => x > y ? x : y);
    final min = values.reduce((x, y) => x < y ? x : y);
    return (max + min) / 2 / 255;
  }

  /// 近乎无彩色（灰阶）：最大与最小分量相差不到 24。
  bool get isNeutral {
    final values = [r, g, b];
    final max = values.reduce((x, y) => x > y ? x : y);
    final min = values.reduce((x, y) => x < y ? x : y);
    return max - min < 24;
  }

  static _JournalColor? parse(String? css) {
    final value = css?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('#')) return _hex(value.substring(1));
    final function = RegExp(r'^rgba?\((.*)\)$').firstMatch(value);
    if (function != null) return _rgb(function.group(1)!);
    final named = _named[value];
    return named == null
        ? null
        : value == 'transparent'
        ? const _JournalColor(0, 0, 0, 0)
        : _hex(named);
  }

  /// CSS 十六进制：`rgb`、`rgba`、`rrggbb`、`rrggbbaa`（alpha 在最后）。
  static _JournalColor? _hex(String digits) {
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(digits)) return null;
    final full = switch (digits.length) {
      3 || 4 => digits.split('').map((digit) => '$digit$digit').join(),
      6 || 8 => digits,
      _ => null,
    };
    if (full == null) return null;
    int at(int index) =>
        int.parse(full.substring(index * 2, index * 2 + 2), radix: 16);
    return _JournalColor(
      at(0),
      at(1),
      at(2),
      full.length == 8 ? at(3) / 255 : 1,
    );
  }

  /// `rgb(r, g, b)`、`rgba(r, g, b, a)` 与 `rgb(r g b / a)`，分量可为百分比。
  static _JournalColor? _rgb(String arguments) {
    final parts = arguments
        .replaceAll('/', ' ')
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length != 3 && parts.length != 4) return null;
    int? channel(String part) {
      final percent = part.endsWith('%');
      final number = double.tryParse(percent ? part.replaceAll('%', '') : part);
      if (number == null) return null;
      return (percent ? number * 2.55 : number).round().clamp(0, 255);
    }

    final r = channel(parts[0]);
    final g = channel(parts[1]);
    final b = channel(parts[2]);
    if (r == null || g == null || b == null) return null;
    var alpha = 1.0;
    if (parts.length == 4) {
      final raw = parts[3];
      final number = double.tryParse(raw.replaceAll('%', ''));
      if (number == null) return null;
      alpha = (raw.endsWith('%') ? number / 100 : number).clamp(0, 1);
    }
    return _JournalColor(r, g, b, alpha);
  }

  /// 导出正文里常见的 CSS 颜色名。
  static const Map<String, String> _named = {
    'transparent': '00000000',
    'black': '000000',
    'white': 'ffffff',
    'gray': '808080',
    'grey': '808080',
    'silver': 'c0c0c0',
    'red': 'ff0000',
    'maroon': '800000',
    'orange': 'ffa500',
    'yellow': 'ffff00',
    'olive': '808000',
    'lime': '00ff00',
    'green': '008000',
    'aqua': '00ffff',
    'cyan': '00ffff',
    'teal': '008080',
    'blue': '0000ff',
    'navy': '000080',
    'fuchsia': 'ff00ff',
    'magenta': 'ff00ff',
    'purple': '800080',
    'pink': 'ffc0cb',
    'brown': 'a52a2a',
    'gold': 'ffd700',
    'violet': 'ee82ee',
    'indigo': '4b0082',
    'orchid': 'da70d6',
    'coral': 'ff7f50',
    'tomato': 'ff6347',
    'crimson': 'dc143c',
    'darkred': '8b0000',
    'darkgreen': '006400',
    'darkblue': '00008b',
    'darkorange': 'ff8c00',
    'skyblue': '87ceeb',
    'lightblue': 'add8e6',
    'lightgreen': '90ee90',
    'lightyellow': 'ffffe0',
    'lightpink': 'ffb6c1',
  };
}
