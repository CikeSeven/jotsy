import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 日记正文排版偏好：字体来源 + 字号 / 行距 / 字间距 / 段间距 / 首行缩进。
///
/// 编辑页、预览页与发布页共用同一份偏好（单个 JSON 设置键，随备份导出）。
/// 本类只描述“用户选了什么”，不关心字体是否已加载：导入字体按 [fontId]
/// 记录，文件缺失或加载失败时由界面层回落到内置字体，偏好原样保留，
/// 重新导入或换回已有字体后即恢复。
///
/// 数值在解析与赋值时统一吸附到步进并夹在范围内：滑块只会产出步进上的值，
/// 损坏或越界的存档（手改、旧版本、跨设备备份）也不会把正文排成无法阅读的样子。
@immutable
class DiaryTypography {
  const DiaryTypography({
    this.fontId = bundledFontId,
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.letterSpacing = defaultLetterSpacing,
    this.paragraphSpacing = defaultParagraphSpacing,
    this.firstLineIndent = defaultFirstLineIndent,
  });

  /// 应用内置的 HarmonyOS Sans SC（与全局主题同一字体）。
  static const String bundledFontId = 'bundled';

  /// 设备系统字体（各厂商 ROM 的系统字体，iOS 上为苹方 / SF）。
  static const String systemFontId = 'system';

  // 默认值与旧版“中号字 + 标准行距”一致，升级后编辑页观感不变。
  static const double defaultFontSize = 16;
  static const double defaultLineHeight = 1.55;
  static const double defaultLetterSpacing = 0;
  static const double defaultParagraphSpacing = 0;

  /// 默认不缩进：升级后已有日记的观感不变。
  static const double defaultFirstLineIndent = 0;

  static const double minFontSize = 10;
  static const double maxFontSize = 32;
  static const double fontSizeStep = 1;

  static const double minLineHeight = 1.0;
  static const double maxLineHeight = 3.0;
  static const double lineHeightStep = 0.05;

  // 允许少量负值：部分导入字体自带字距偏松，收紧一点更易读。
  static const double minLetterSpacing = -1;
  static const double maxLetterSpacing = 8;
  static const double letterSpacingStep = 0.25;

  static const double minParagraphSpacing = 0;
  static const double maxParagraphSpacing = 48;
  static const double paragraphSpacingStep = 1;

  // 中文习惯“首行空两字”；半字步进照顾西文常见的 1–1.5em 缩进。
  static const double minFirstLineIndent = 0;
  static const double maxFirstLineIndent = 4;
  static const double firstLineIndentStep = 0.5;

  /// [bundledFontId]、[systemFontId] 或导入字体的 id。
  final String fontId;
  final double fontSize;
  final double lineHeight;

  /// 逻辑像素，直接作为 `TextStyle.letterSpacing`。
  final double letterSpacing;

  /// 段落（每次换行）之后追加的垂直间距，逻辑像素。
  final double paragraphSpacing;

  /// 普通段落首行缩进的字数，0 为不缩进；宽度见 [firstLineIndentExtent]。
  final double firstLineIndent;

  /// 首行缩进的宽度（逻辑像素）：每个字按字号加字间距计，正好是中文全角字
  /// 的步进，缩进两字时首行与下面各行的第三个字对齐。
  double get firstLineIndentExtent =>
      firstLineIndent * math.max(0.0, fontSize + letterSpacing);

  bool get usesImportedFont =>
      fontId != bundledFontId && fontId != systemFontId;

  DiaryTypography copyWith({
    String? fontId,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? firstLineIndent,
  }) {
    return DiaryTypography(
      fontId: _normalizeFontId(fontId ?? this.fontId),
      fontSize: normalizeFontSize(fontSize ?? this.fontSize),
      lineHeight: normalizeLineHeight(lineHeight ?? this.lineHeight),
      letterSpacing: normalizeLetterSpacing(
        letterSpacing ?? this.letterSpacing,
      ),
      paragraphSpacing: normalizeParagraphSpacing(
        paragraphSpacing ?? this.paragraphSpacing,
      ),
      firstLineIndent: normalizeFirstLineIndent(
        firstLineIndent ?? this.firstLineIndent,
      ),
    );
  }

  /// 只把排版数值恢复默认，保留字体选择：用户换了字体后多半只想重调数值。
  DiaryTypography withDefaultMetrics() => DiaryTypography(fontId: fontId);

  /// 排版数值是否都是默认值（不看字体），决定“恢复默认排版”是否可点。
  bool get hasDefaultMetrics => this == withDefaultMetrics();

  Map<String, Object?> toJson() => <String, Object?>{
    'fontId': fontId,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'paragraphSpacing': paragraphSpacing,
    'firstLineIndent': firstLineIndent,
  };

  String toRaw() => jsonEncode(toJson());

  /// 逐字段容错：缺失、类型不符的字段取默认值，其余字段照常生效。
  factory DiaryTypography.fromJson(Map<String, Object?> json) {
    double read(String key, double fallback) => switch (json[key]) {
      num value => value.toDouble(),
      String value => double.tryParse(value) ?? fallback,
      _ => fallback,
    };
    final fontIdRaw = json['fontId'];
    return const DiaryTypography().copyWith(
      fontId: fontIdRaw is String ? fontIdRaw : bundledFontId,
      fontSize: read('fontSize', defaultFontSize),
      lineHeight: read('lineHeight', defaultLineHeight),
      letterSpacing: read('letterSpacing', defaultLetterSpacing),
      paragraphSpacing: read('paragraphSpacing', defaultParagraphSpacing),
      firstLineIndent: read('firstLineIndent', defaultFirstLineIndent),
    );
  }

  /// 解析设置原文；空值或损坏的 JSON 回到默认排版。
  factory DiaryTypography.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const DiaryTypography();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return DiaryTypography.fromJson(decoded);
      }
    } on FormatException {
      // 损坏的配置回退默认值，不能让一条坏设置挡住日记的打开与编辑。
    }
    return const DiaryTypography();
  }

  /// 旧版“编辑器字号 / 行距”三档预设（small/medium/large、
  /// compact/normal/relaxed）迁移为连续值；本机设置与旧备份共用。
  factory DiaryTypography.fromLegacyPresets({
    String? fontSizePreset,
    String? lineHeightPreset,
  }) {
    return DiaryTypography(
      fontSize: switch (fontSizePreset) {
        'small' => 14,
        'large' => 18,
        _ => defaultFontSize,
      },
      lineHeight: switch (lineHeightPreset) {
        'compact' => 1.35,
        'relaxed' => 1.75,
        _ => defaultLineHeight,
      },
    );
  }

  static double normalizeFontSize(double value) =>
      _snap(value, minFontSize, maxFontSize, fontSizeStep, defaultFontSize);

  static double normalizeLineHeight(double value) => _snap(
    value,
    minLineHeight,
    maxLineHeight,
    lineHeightStep,
    defaultLineHeight,
  );

  static double normalizeLetterSpacing(double value) => _snap(
    value,
    minLetterSpacing,
    maxLetterSpacing,
    letterSpacingStep,
    defaultLetterSpacing,
  );

  static double normalizeParagraphSpacing(double value) => _snap(
    value,
    minParagraphSpacing,
    maxParagraphSpacing,
    paragraphSpacingStep,
    defaultParagraphSpacing,
  );

  static double normalizeFirstLineIndent(double value) => _snap(
    value,
    minFirstLineIndent,
    maxFirstLineIndent,
    firstLineIndentStep,
    defaultFirstLineIndent,
  );

  static String _normalizeFontId(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? bundledFontId : trimmed;
  }

  /// 以 [min] 为原点吸附到步进再夹取范围；结果按两位小数取整，消除
  /// `0.05 * 31` 这类浮点误差，保证存档与界面显示的值一致、可比较。
  static double _snap(
    double value,
    double min,
    double max,
    double step,
    double fallback,
  ) {
    if (!value.isFinite) {
      return fallback;
    }
    final steps = ((value.clamp(min, max) - min) / step).round();
    final snapped = (min + steps * step).clamp(min, max).toDouble();
    return double.parse(snapped.toStringAsFixed(2));
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryTypography &&
        other.fontId == fontId &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.letterSpacing == letterSpacing &&
        other.paragraphSpacing == paragraphSpacing &&
        other.firstLineIndent == firstLineIndent;
  }

  @override
  int get hashCode => Object.hash(
    fontId,
    fontSize,
    lineHeight,
    letterSpacing,
    paragraphSpacing,
    firstLineIndent,
  );

  @override
  String toString() => 'DiaryTypography(${toRaw()})';
}
