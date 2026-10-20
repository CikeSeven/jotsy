/// 正文文字色 / 背景色的纯数据模型：预设色板、属性值的读写与十六进制输入。
///
/// - 输入：Quill 选区样式、文档 Delta、用户输入的颜色代码；
/// - 输出：可比较的 [Color] 与写回正文的属性值；
/// - 无副作用，不依赖 BuildContext。
///
/// 写回正文的值一律是大写 8 位 `#AARRGGBB`：PDF 导出把 6 位十六进制当作全
/// 透明，导入链路（`journal_import_style.dart`）也写 `#AARRGGBB`，两边同一种
/// 写法，比较与去重才不会因大小写或位数不同而失效。
library;

import 'dart:ui' show Color;

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/services/journal_import_style.dart';

/// 颜色面板正在编辑的是文字色还是背景色。
enum DiaryColorTarget {
  text,
  background;

  /// 对应的 Quill 行内属性键（`color` / `background`）。
  String get attributeKey => switch (this) {
    DiaryColorTarget.text => quill.Attribute.color.key,
    DiaryColorTarget.background => quill.Attribute.background.key,
  };

  /// 写入 [color] 的属性；[color] 为 null 时是清除该属性。
  quill.Attribute<String?> attributeFor(Color? color) {
    final value = color == null ? null : encodeDiaryColor(color);
    return switch (this) {
      DiaryColorTarget.text => quill.ColorAttribute(value),
      DiaryColorTarget.background => quill.BackgroundAttribute(value),
    };
  }
}

/// 预设颜色：两种目标同序同下标，切换目标时色块原地变色而不重排。
enum DiaryColorPreset {
  red(Color(0xFFE5484D), Color(0x4DFF6369)),
  orange(Color(0xFFDA6A10), Color(0x4DFF9F43)),
  // 黄色高亮与导入的“高亮”同色（见 [journalHighlightColor]），在 [colorFor]
  // 中取自那个常量；这里的背景值只是占位，不会被读到。
  yellow(Color(0xFFB07F00), Color(0x00000000)),
  green(Color(0xFF2B9455), Color(0x4D4CC38A)),
  teal(Color(0xFF0E8F83), Color(0x4D2CC4B4)),
  blue(Color(0xFF3B7BE8), Color(0x4D5B9BFF)),
  indigo(Color(0xFF5B63D6), Color(0x4D7C83F5)),
  purple(Color(0xFF9150C8), Color(0x4DB57EE6)),
  pink(Color(0xFFD6409F), Color(0x4DF472B6)),
  brown(Color(0xFFA27250), Color(0x4DB98B6E)),
  gray(Color(0xFF7E848E), Color(0x4D9AA0A6));

  const DiaryColorPreset(this._text, this._background);

  /// 文字色：不透明的中间调，在白纸与暗色卡片上都有 3:1 以上的对比度。
  final Color _text;

  /// 背景色：半透明，叠在纸面上后正文的 onSurface 墨色在亮暗主题下都清楚。
  final Color _background;

  Color colorFor(DiaryColorTarget target) => switch (target) {
    DiaryColorTarget.text => _text,
    DiaryColorTarget.background =>
      this == DiaryColorPreset.yellow ? _journalHighlight : _background,
  };

  /// [color] 恰好是某个预设（按 ARGB 比较）时返回它。
  static DiaryColorPreset? match(Color color, DiaryColorTarget target) {
    for (final preset in values) {
      if (sameDiaryColor(preset.colorFor(target), color)) return preset;
    }
    return null;
  }
}

final Color _journalHighlight = parseDiaryColorValue(journalHighlightColor)!;

/// 选区在某个目标上的颜色状态。
///
/// - [raw] 为 null：没有设置颜色（默认墨色 / 无背景）；
/// - [raw] 有值但 [color] 为 null：设了颜色但读不懂（如 Quill 的颜色名），
///   面板不选中任何色块，颜色代码显示“自定义”；
/// - 两者都有：可以比较与显示的颜色。
class DiaryColorValue {
  const DiaryColorValue._(this.raw, this.color);

  static const DiaryColorValue none = DiaryColorValue._(null, null);

  factory DiaryColorValue.parse(String? raw) {
    if (raw == null || raw.isEmpty) return none;
    return DiaryColorValue._(raw, parseDiaryColorValue(raw));
  }

  /// 从选区样式（`controller.getSelectionStyle().attributes`）里读取。
  factory DiaryColorValue.of(
    Map<String, quill.Attribute> attributes,
    DiaryColorTarget target,
  ) {
    final value = attributes[target.attributeKey]?.value;
    return DiaryColorValue.parse(value is String ? value : null);
  }

  final String? raw;
  final Color? color;

  bool get isNone => raw == null;

  /// 是否正好是 [other]（按 ARGB 比较，读不懂的值不等于任何颜色）。
  bool matches(Color other) {
    final own = color;
    return own != null && sameDiaryColor(own, other);
  }
}

/// 两个颜色的 ARGB 是否完全相同（不受色彩空间与浮点误差影响）。
bool sameDiaryColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

/// 写回正文的属性值：大写 `#AARRGGBB`。
String encodeDiaryColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// 显示用的 `#RRGGBB`（省略透明度）。
String diaryColorRgbHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

final RegExp _attributeHex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// 解析正文里的颜色属性值：`#RRGGBB`（视为不透明）或 `#AARRGGBB`，大小写
/// 不限；其他写法返回 null。
Color? parseDiaryColorValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (!_attributeHex.hasMatch(trimmed)) return null;
  final digits = trimmed.substring(1);
  final argb = int.parse(digits, radix: 16);
  return Color(digits.length == 6 ? 0xFF000000 | argb : argb);
}

final RegExp _whitespace = RegExp(r'\s');
final RegExp _inputPrefix = RegExp(r'^(#|0[xX])');
final RegExp _hexDigits = RegExp(r'^[0-9a-fA-F]+$');

/// 解析用户输入的颜色代码：去掉空白与开头的 `#` / `0x`，只接受 3 位（逐位
/// 展开）或 6 位十六进制，得到不透明颜色；其余一律无效（null）。
Color? parseDiaryHexInput(String input) {
  var digits = input.replaceAll(_whitespace, '').replaceFirst(_inputPrefix, '');
  if (!_hexDigits.hasMatch(digits)) return null;
  if (digits.length == 3) {
    digits = digits.split('').map((String digit) => '$digit$digit').join();
  }
  if (digits.length != 6) return null;
  return Color(0xFF000000 | int.parse(digits, radix: 16));
}

/// 输入框能接受的字符：去掉空白、`#` 与粘贴进来的 `0x` 前缀，只留十六进制
/// 数字并转成大写。
String sanitizeDiaryHexInput(String input) => input
    .replaceAll(_whitespace, '')
    .replaceAll('#', '')
    .replaceAll(RegExp(r'0[xX](?=[0-9a-fA-F])'), '')
    .replaceAll(RegExp('[^0-9a-fA-F]'), '')
    .toUpperCase();

/// 这篇日记里用过、但不是预设的颜色（按文档顺序去重，读不懂的值跳过）。
///
/// 遍历整篇 Delta，只在面板打开、切换目标与回到色板时调用一次，不在每次
/// 构建或按键时计算。
List<Color> collectDiaryDocumentColors(
  quill.Document document,
  DiaryColorTarget target,
) {
  final seen = <int>{};
  final result = <Color>[];
  for (final operation in document.toDelta().toList()) {
    final value = operation.attributes?[target.attributeKey];
    final color = value is String ? parseDiaryColorValue(value) : null;
    if (color == null || DiaryColorPreset.match(color, target) != null) {
      continue;
    }
    if (seen.add(color.toARGB32())) result.add(color);
  }
  return result;
}

/// 色板页的排布：列数、预设占几行，以及下方“我的颜色”一行。
///
/// 规则：列数按 40dp 一格取整并夹在 [minColumns, maxColumns]；第一格是默认 /
/// 无背景，随后 11 个预设，按列数折行；预设之下隔 [stripGap] 是固定一行的
/// “我的颜色”（首格新建、末格管理，中间横向滚动），存多少都不改变高度。纯
/// 计算，面板高度由此直接得出，不必等测量；与保存了几个颜色无关，切换目标
/// 时面板不会跳动。
class DiaryColorGridLayout {
  const DiaryColorGridLayout._({
    required this.columns,
    required this.presetRows,
  });

  factory DiaryColorGridLayout.resolve({required double innerWidth}) {
    final columns = (innerWidth / cellHeight).floor().clamp(
      minColumns,
      maxColumns,
    );
    return DiaryColorGridLayout._(
      columns: columns,
      presetRows: (presetCellCount / columns).ceil(),
    );
  }

  static const double cellHeight = 40;
  static const int minColumns = 6;
  static const int maxColumns = 16;

  /// 预设与“我的颜色”之间的间距（中间画一道细分隔线）。
  static const double stripGap = 8;

  /// 默认 / 无背景 + 11 个预设。
  static final int presetCellCount = 1 + DiaryColorPreset.values.length;

  final int columns;
  final int presetRows;

  double get presetHeight => presetRows * cellHeight;

  /// 色板页总高：预设 + 间距 + 我的颜色一行。
  double get height => presetHeight + stripGap + cellHeight;
}
