import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../style_library/saved_style.dart';
import 'diary_preview_behavior.dart';
import 'diary_preview_style.dart';

/// 用户保存的一套预览页样式（“我的样式”）。
typedef DiaryPreviewSavedStyle = SavedStyle<DiaryPreviewStyle>;

/// 预览页设置的整体：当前样式、已保存的样式与阅读行为。
///
/// 持久化为单个 JSON 键（`diaryPreviewStyleRaw`）：
/// `{"v":1,"current":{…},"saved":[…],"behavior":{…}}`。放在一个键里，备份
/// 恢复与失败回滚都是原子的，也只需一个通知源。全为默认时编码为 null，由
/// 设置服务删除该键。保存项的增删改与上限见 [SavedStyles]；所有修改都原样
/// 保留 [behavior]。
@immutable
class DiaryPreviewSettings
    implements StyleLibrary<DiaryPreviewStyle, DiaryPreviewSettings> {
  const DiaryPreviewSettings({
    this.current = DiaryPreviewStyle.defaults,
    this.saved = const <DiaryPreviewSavedStyle>[],
    this.behavior = DiaryPreviewBehavior.defaults,
  });

  static const DiaryPreviewSettings defaults = DiaryPreviewSettings();
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。各部分逐项容错。
  factory DiaryPreviewSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    return DiaryPreviewSettings(
      current: DiaryPreviewStyle.fromJson(decoded['current']),
      saved: SavedStyles.decode(decoded['saved'], DiaryPreviewStyle.fromJson),
      behavior: DiaryPreviewBehavior.fromJson(decoded['behavior']),
    );
  }

  @override
  final DiaryPreviewStyle current;
  @override
  final List<DiaryPreviewSavedStyle> saved;
  final DiaryPreviewBehavior behavior;

  bool get isDefault =>
      current.isDefault && saved.isEmpty && behavior.isDefault;

  @override
  bool get canSaveMore => saved.length < SavedStyles.maxItems;

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) {
      return null;
    }
    final behaviorJson = behavior.toJson();
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'current': current.toJson(),
      if (saved.isNotEmpty)
        'saved': SavedStyles.encode(saved, (style) => style.toJson()),
      if (behaviorJson.isNotEmpty) 'behavior': behaviorJson,
    });
  }

  DiaryPreviewSettings withBehavior(DiaryPreviewBehavior value) =>
      DiaryPreviewSettings(current: current, saved: saved, behavior: value);

  @override
  DiaryPreviewSettings withCurrent(DiaryPreviewStyle style) =>
      DiaryPreviewSettings(current: style, saved: saved, behavior: behavior);

  @override
  DiaryPreviewSettings addSaved(
    String name,
    DiaryPreviewStyle style, {
    DateTime? now,
  }) => _withSaved(SavedStyles.add(saved, name, style, now: now));

  @override
  DiaryPreviewSettings renameSaved(String id, String name) =>
      _withSaved(SavedStyles.rename(saved, id, name));

  @override
  DiaryPreviewSettings removeSaved(String id) =>
      _withSaved(SavedStyles.remove(saved, id));

  @override
  DiaryPreviewSettings restoreSaved(DiaryPreviewSavedStyle item, int index) =>
      _withSaved(SavedStyles.restore(saved, item, index));

  DiaryPreviewSettings _withSaved(List<DiaryPreviewSavedStyle>? next) =>
      next == null
      ? this
      : DiaryPreviewSettings(current: current, saved: next, behavior: behavior);

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewSettings &&
        other.current == current &&
        listEquals(other.saved, saved) &&
        other.behavior == behavior;
  }

  @override
  int get hashCode => Object.hash(current, Object.hashAll(saved), behavior);
}
