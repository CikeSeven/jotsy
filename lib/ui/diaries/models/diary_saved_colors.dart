/// 颜色面板的“我的颜色”：在自定义页调出的颜色跨日记保留，文字色与背景色
/// 各一组，新的在前。
///
/// - 存于单个 JSON 设置键 `app.settings.diary_recent_colors`（随备份导出与
///   失败回滚），格式 `{"text":["#FF3A7BD5"],"background":["#4D5B9BFF"]}`。
///   键名沿用早先“最近颜色”的叫法：已有设置与备份里记下的颜色原样成为我的
///   颜色，不必迁移；
/// - 解码逐项容错：不是字符串或读不懂的项跳过，重复的去重，超出 [maxCount]
///   的截掉；整体不是 JSON 对象时当作没有保存；
/// - 预设颜色不保存：色板里始终有它们；
/// - 位置稳定：再次调出已保存的颜色不会把它挪到最前，手边的色块不换位置；
///   新颜色插在最前，超出上限时丢掉最旧的。同一次调色的中间色经
///   [save] 的 `replacing` 原地替换，不会一个个堆进来。
library;

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 对我的颜色的一次改写：拿到最新的记录、返回改写后的记录。由 provider 在
/// 自己的最新状态上执行，界面不必持有可能过期的副本。
typedef DiarySavedColorsEdit =
    DiarySavedColors Function(DiarySavedColors current);

@immutable
class DiarySavedColors {
  const DiarySavedColors({
    this.text = const <Color>[],
    this.background = const <Color>[],
  });

  factory DiarySavedColors.fromJson(Map<String, dynamic> json) =>
      DiarySavedColors(
        text: _decodeList(json[_textKey]),
        background: _decodeList(json[_backgroundKey]),
      );

  /// 解码设置原文；空值、坏 JSON 或类型不符一律视为没有保存。
  factory DiarySavedColors.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return DiarySavedColors.fromJson(json);
    } on FormatException {
      // 坏 JSON 按没有保存处理，下次保存时整份覆盖。
    }
    return empty;
  }

  static const DiarySavedColors empty = DiarySavedColors();

  /// 每组最多存几个：色板那一行横向滚动，再多就不好找了。
  static const int maxCount = 24;

  static const String _textKey = 'text';
  static const String _backgroundKey = 'background';

  final List<Color> text;
  final List<Color> background;

  bool get isEmpty => text.isEmpty && background.isEmpty;

  List<Color> forTarget(DiaryColorTarget target) => switch (target) {
    DiaryColorTarget.text => text,
    DiaryColorTarget.background => background,
  };

  bool contains(DiaryColorTarget target, Color color) =>
      forTarget(target).any((Color saved) => sameDiaryColor(saved, color));

  /// 保存 [color]：不是预设、也还没存过时插在最前。
  ///
  /// [replacing] 是同一次调色先前存下的颜色：它还在时先拿掉，新颜色占它的
  /// 位置（新颜色已存过或是预设时只拿掉它）。没有任何变化时原样返回。
  DiarySavedColors save(
    DiaryColorTarget target,
    Color color, {
    Color? replacing,
  }) {
    final current = forTarget(target);
    final index = replacing == null
        ? -1
        : current.indexWhere((Color saved) => sameDiaryColor(saved, replacing));
    final next = <Color>[...current];
    if (index >= 0) next.removeAt(index);
    final skip =
        DiaryColorPreset.match(color, target) != null ||
        next.any((Color saved) => sameDiaryColor(saved, color));
    if (!skip) next.insert(index >= 0 ? index : 0, color);
    final result = _with(target, next);
    return result == this ? this : result;
  }

  /// 从我的颜色里移除 [color]；没存过时原样返回。
  DiarySavedColors remove(DiaryColorTarget target, Color color) {
    if (!contains(target, color)) return this;
    return _with(target, <Color>[
      for (final saved in forTarget(target))
        if (!sameDiaryColor(saved, color)) saved,
    ]);
  }

  DiarySavedColors _with(DiaryColorTarget target, List<Color> colors) {
    final next = List<Color>.unmodifiable(colors.take(maxCount));
    return switch (target) {
      DiaryColorTarget.text => DiarySavedColors(
        text: next,
        background: background,
      ),
      DiaryColorTarget.background => DiarySavedColors(
        text: text,
        background: next,
      ),
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    _textKey: text.map(encodeDiaryColor).toList(),
    _backgroundKey: background.map(encodeDiaryColor).toList(),
  };

  /// 写回设置的原文；什么都没存时为 null（移除设置键）。
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
      other is DiarySavedColors &&
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
