/// 颜色面板跨日记记住的“最近用过的自定义颜色”：文字色与背景色各一组，
/// 最新的在前。
///
/// - 存于单个 JSON 设置键 `app.settings.diary_recent_colors`（随备份导出与
///   失败回滚），格式 `{"text":["#FF3A7BD5"],"background":["#4D5B9BFF"]}`；
/// - 解码逐项容错：不是字符串或读不懂的项跳过，重复的去重，超出 [maxCount]
///   的截掉；整体不是 JSON 对象时当作没有记录；
/// - 预设颜色不记录：色板里始终有它们，记下来只会挤掉真正的自定义颜色。
library;

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

@immutable
class DiaryRecentColors {
  const DiaryRecentColors({
    this.text = const <Color>[],
    this.background = const <Color>[],
  });

  factory DiaryRecentColors.fromJson(Map<String, dynamic> json) =>
      DiaryRecentColors(
        text: _decodeList(json[_textKey]),
        background: _decodeList(json[_backgroundKey]),
      );

  /// 解码设置原文；空值、坏 JSON 或类型不符一律视为没有记录。
  factory DiaryRecentColors.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return DiaryRecentColors.fromJson(json);
    } on FormatException {
      // 坏 JSON 按没有记录处理，下次记录时整份覆盖。
    }
    return empty;
  }

  static const DiaryRecentColors empty = DiaryRecentColors();

  /// 每组最多记几个：色板两行放得下的自定义颜色不会超过这个数。
  static const int maxCount = 12;

  static const String _textKey = 'text';
  static const String _backgroundKey = 'background';

  final List<Color> text;
  final List<Color> background;

  bool get isEmpty => text.isEmpty && background.isEmpty;

  List<Color> forTarget(DiaryColorTarget target) => switch (target) {
    DiaryColorTarget.text => text,
    DiaryColorTarget.background => background,
  };

  /// 把 [color] 记为 [target] 最近用过的颜色（移到最前，超出上限的丢掉）；
  /// 预设颜色或已经排在最前时原样返回。
  DiaryRecentColors record(DiaryColorTarget target, Color color) {
    if (DiaryColorPreset.match(color, target) != null) return this;
    final current = forTarget(target);
    if (current.isNotEmpty && sameDiaryColor(current.first, color)) {
      return this;
    }
    final next = List<Color>.unmodifiable(
      <Color>[
        color,
        ...current.where((Color other) => !sameDiaryColor(other, color)),
      ].take(maxCount),
    );
    return switch (target) {
      DiaryColorTarget.text => DiaryRecentColors(
        text: next,
        background: background,
      ),
      DiaryColorTarget.background => DiaryRecentColors(
        text: text,
        background: next,
      ),
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    _textKey: text.map(encodeDiaryColor).toList(),
    _backgroundKey: background.map(encodeDiaryColor).toList(),
  };

  /// 写回设置的原文；没有记录时为 null（移除设置键）。
  String? encode() => isEmpty ? null : jsonEncode(toJson());

  static List<Color> _decodeList(Object? value) {
    if (value is! List) return const <Color>[];
    final seen = <int>{};
    final result = <Color>[];
    for (final item in value) {
      final color = item is String ? parseDiaryColorValue(item) : null;
      if (color == null || !seen.add(color.toARGB32())) continue;
      result.add(color);
      if (result.length == maxCount) break;
    }
    return List<Color>.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryRecentColors &&
      _sameList(other.text, text) &&
      _sameList(other.background, background);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(text.map((Color color) => color.toARGB32())),
    Object.hashAll(background.map((Color color) => color.toARGB32())),
  );

  static bool _sameList(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!sameDiaryColor(a[i], b[i])) return false;
    }
    return true;
  }
}
