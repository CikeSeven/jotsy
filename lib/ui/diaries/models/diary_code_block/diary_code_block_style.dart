import 'dart:convert';

import 'package:flutter/foundation.dart';

// 正文代码块的外观设置：配色主题、明暗、行号、标题栏、自动识别、边框、
// 字体与字号 / 行距 / 圆角。
//
// 存于单个 JSON 设置键（`SettingsService.diaryCodeBlockStyleRaw`，随备份
// 导出与失败回滚）；服务层只保存原文，解析与默认值都在这里。
//
// 解析逐字段容错：缺失或类型不符的字段取默认值，其余字段照常生效；数值
// 夹在范围内并吸附到步进（滑块只产出步进上的值，手改或跨版本的存档也不会
// 排出无法阅读的代码块）；整段 JSON 损坏时回到默认样式。

/// 代码块字体：系统等宽字体。
const String kDiaryCodeFontMono = 'mono';

/// 代码块字体：跟随正文字体（`DiaryTypography`）。
const String kDiaryCodeFontBody = 'body';

/// 代码块配色主题。[app] 由应用配色推出，其余为常见编辑器主题。
enum DiaryCodeThemeId {
  app('app', null),
  github('github', 'GitHub'),
  one('one', 'One'),
  solarized('solarized', 'Solarized'),
  gruvbox('gruvbox', 'Gruvbox'),
  catppuccin('catppuccin', 'Catppuccin'),
  tokyoNight('tokyo_night', 'Tokyo Night'),
  nord('nord', 'Nord'),
  dracula('dracula', 'Dracula'),
  rosePine('rose_pine', 'Rosé Pine');

  const DiaryCodeThemeId(this.storageId, this.displayName);

  /// 写入 JSON 的标识；与枚举名解耦，重命名枚举不影响已有存档。
  final String storageId;

  /// 主题的专有名；[app] 为 null，由界面按语言显示“跟随应用”。
  final String? displayName;

  /// 认不出的值（未来版本的新主题、手改存档）回落 [app]。
  static DiaryCodeThemeId fromStorageId(Object? raw) {
    if (raw is String) {
      final id = raw.trim();
      for (final value in values) {
        if (value.storageId == id) {
          return value;
        }
      }
    }
    return app;
  }
}

/// 代码块明暗：跟随应用主题，或固定浅色 / 深色。
enum DiaryCodeBrightness {
  system,
  light,
  dark;

  /// 按枚举名容错解析；认不出的值回落 [system]。
  static DiaryCodeBrightness fromName(Object? raw) {
    if (raw is String) {
      final name = raw.trim();
      for (final value in values) {
        if (value.name == name) {
          return value;
        }
      }
    }
    return system;
  }
}

@immutable
class DiaryCodeBlockStyle {
  const DiaryCodeBlockStyle({
    this.theme = DiaryCodeThemeId.app,
    this.brightness = DiaryCodeBrightness.system,
    this.lineNumbers = true,
    this.header = true,
    this.autoDetect = true,
    this.border = false,
    this.fontId = kDiaryCodeFontMono,
    this.fontScale = defaultFontScale,
    this.lineHeight = defaultLineHeight,
    this.radius = defaultRadius,
  });

  static const DiaryCodeBlockStyle defaults = DiaryCodeBlockStyle();

  static const double defaultFontScale = 0.9;
  static const double minFontScale = 0.7;
  static const double maxFontScale = 1.3;
  static const double fontScaleStep = 0.05;

  static const double defaultLineHeight = 1.5;
  static const double minLineHeight = 1.0;
  static const double maxLineHeight = 2.4;
  static const double lineHeightStep = 0.05;

  static const double defaultRadius = 12;
  static const double minRadius = 0;
  static const double maxRadius = 24;
  static const double radiusStep = 2;

  final DiaryCodeThemeId theme;
  final DiaryCodeBrightness brightness;
  final bool lineNumbers;

  /// 顶部标题栏（语言名 + 复制按钮）。
  final bool header;

  /// 未指定语言的代码块是否自动判断语言并高亮。
  final bool autoDetect;
  final bool border;

  /// [kDiaryCodeFontMono]、[kDiaryCodeFontBody] 或导入字体的 id（与
  /// `DiaryTypography.fontId` 同一套 id，即 `DiaryImportedFont.id`）。
  final String fontId;

  /// 相对正文字号的倍数。
  final double fontScale;
  final double lineHeight;

  /// 圆角半径，逻辑像素。
  final double radius;

  bool get isDefault => this == defaults;

  /// 是否选了导入字体（需要按 id 加载字族）。
  bool get usesImportedFont =>
      fontId != kDiaryCodeFontMono && fontId != kDiaryCodeFontBody;

  DiaryCodeBlockStyle copyWith({
    DiaryCodeThemeId? theme,
    DiaryCodeBrightness? brightness,
    bool? lineNumbers,
    bool? header,
    bool? autoDetect,
    bool? border,
    String? fontId,
    double? fontScale,
    double? lineHeight,
    double? radius,
  }) {
    return DiaryCodeBlockStyle(
      theme: theme ?? this.theme,
      brightness: brightness ?? this.brightness,
      lineNumbers: lineNumbers ?? this.lineNumbers,
      header: header ?? this.header,
      autoDetect: autoDetect ?? this.autoDetect,
      border: border ?? this.border,
      fontId: _normalizeFontId(fontId ?? this.fontId),
      fontScale: normalizeFontScale(fontScale ?? this.fontScale),
      lineHeight: normalizeLineHeight(lineHeight ?? this.lineHeight),
      radius: normalizeRadius(radius ?? this.radius),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'theme': theme.storageId,
    'brightness': brightness.name,
    'lineNumbers': lineNumbers,
    'header': header,
    'autoDetect': autoDetect,
    'border': border,
    'fontId': fontId,
    'fontScale': fontScale,
    'lineHeight': lineHeight,
    'radius': radius,
  };

  /// 逐字段容错：缺失、类型不符的字段取默认值。布尔字段只认真正的 bool，
  /// 避免 `"false"` 这类字符串被误读为开启。
  factory DiaryCodeBlockStyle.fromJson(Map<String, Object?> json) {
    double readNum(String key, double fallback) => switch (json[key]) {
      num value => value.toDouble(),
      String value => double.tryParse(value.trim()) ?? fallback,
      _ => fallback,
    };
    bool readBool(String key, bool fallback) => switch (json[key]) {
      bool value => value,
      _ => fallback,
    };
    final fontIdRaw = json['fontId'];
    return defaults.copyWith(
      theme: DiaryCodeThemeId.fromStorageId(json['theme']),
      brightness: DiaryCodeBrightness.fromName(json['brightness']),
      lineNumbers: readBool('lineNumbers', defaults.lineNumbers),
      header: readBool('header', defaults.header),
      autoDetect: readBool('autoDetect', defaults.autoDetect),
      border: readBool('border', defaults.border),
      fontId: fontIdRaw is String ? fontIdRaw : kDiaryCodeFontMono,
      fontScale: readNum('fontScale', defaultFontScale),
      lineHeight: readNum('lineHeight', defaultLineHeight),
      radius: readNum('radius', defaultRadius),
    );
  }

  /// 解析设置原文；空值或损坏的 JSON 回到默认样式。
  static DiaryCodeBlockStyle decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return DiaryCodeBlockStyle.fromJson(decoded);
      }
    } on FormatException {
      // 损坏的配置回退默认值，不能让一条坏设置挡住日记的打开与编辑。
    }
    return defaults;
  }

  /// 编码为设置原文；与默认样式相同时返回 null，让设置键被移除，备份里
  /// 不留冗余配置。
  String? encode() => isDefault ? null : jsonEncode(toJson());

  static double normalizeFontScale(double value) =>
      _snap(value, minFontScale, maxFontScale, fontScaleStep, defaultFontScale);

  static double normalizeLineHeight(double value) => _snap(
    value,
    minLineHeight,
    maxLineHeight,
    lineHeightStep,
    defaultLineHeight,
  );

  static double normalizeRadius(double value) =>
      _snap(value, minRadius, maxRadius, radiusStep, defaultRadius);

  static String _normalizeFontId(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? kDiaryCodeFontMono : trimmed;
  }

  /// 以 [min] 为原点吸附到步进再夹取范围；按两位小数取整消除浮点误差，
  /// 保证存档与界面显示的值一致、可比较（与 `DiaryTypography` 同一口径）。
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
    return other is DiaryCodeBlockStyle &&
        other.theme == theme &&
        other.brightness == brightness &&
        other.lineNumbers == lineNumbers &&
        other.header == header &&
        other.autoDetect == autoDetect &&
        other.border == border &&
        other.fontId == fontId &&
        other.fontScale == fontScale &&
        other.lineHeight == lineHeight &&
        other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(
    theme,
    brightness,
    lineNumbers,
    header,
    autoDetect,
    border,
    fontId,
    fontScale,
    lineHeight,
    radius,
  );

  @override
  String toString() => 'DiaryCodeBlockStyle(${jsonEncode(toJson())})';
}
