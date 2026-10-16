import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../style_library/saved_style.dart';
import 'diary_card_style.dart';

/// 用户保存的一套卡片样式（“我的样式”）。
typedef DiaryCardSavedStyle = SavedStyle<DiaryCardStyle>;

/// 卡片样式设置的整体：当前样式 + 已保存的样式。
///
/// 持久化为单个 JSON 键（`diaryCardStyleRaw`）：
/// `{"v":1,"current":{…},"saved":[{"id":…,"name":…,"style":{…}}]}`。
/// 放在一个键里，备份恢复与失败回滚都是原子的，也只需一个通知源。
/// 与默认完全相同（默认样式且没有保存项）时编码为 null，由设置服务删除
/// 该键，备份里不留冗余配置。保存项的增删改与上限见 [SavedStyles]。
@immutable
class DiaryCardStyleSettings
    implements StyleLibrary<DiaryCardStyle, DiaryCardStyleSettings> {
  const DiaryCardStyleSettings({
    this.current = DiaryCardStyle.defaults,
    this.saved = const <DiaryCardSavedStyle>[],
  });

  static const DiaryCardStyleSettings defaults = DiaryCardStyleSettings();

  static const int maxSaved = SavedStyles.maxItems;
  static const int maxNameLength = SavedStyles.maxNameLength;
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。保存项逐条容错。
  factory DiaryCardStyleSettings.decode(String? raw) {
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
    return DiaryCardStyleSettings(
      current: DiaryCardStyle.fromJson(decoded['current']),
      saved: SavedStyles.decode(decoded['saved'], DiaryCardStyle.fromJson),
    );
  }

  @override
  final DiaryCardStyle current;
  @override
  final List<DiaryCardSavedStyle> saved;

  bool get isDefault => current.isDefault && saved.isEmpty;

  @override
  bool get canSaveMore => saved.length < maxSaved;

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) {
      return null;
    }
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'current': current.toJson(),
      if (saved.isNotEmpty)
        'saved': SavedStyles.encode(saved, (style) => style.toJson()),
    });
  }

  static String normalizeName(String raw) => SavedStyles.normalizeName(raw);

  @override
  DiaryCardStyleSettings withCurrent(DiaryCardStyle style) =>
      DiaryCardStyleSettings(current: style, saved: saved);

  @override
  DiaryCardStyleSettings addSaved(
    String name,
    DiaryCardStyle style, {
    DateTime? now,
  }) => _withSaved(SavedStyles.add(saved, name, style, now: now));

  @override
  DiaryCardStyleSettings renameSaved(String id, String name) =>
      _withSaved(SavedStyles.rename(saved, id, name));

  @override
  DiaryCardStyleSettings removeSaved(String id) =>
      _withSaved(SavedStyles.remove(saved, id));

  @override
  DiaryCardStyleSettings restoreSaved(DiaryCardSavedStyle item, int index) =>
      _withSaved(SavedStyles.restore(saved, item, index));

  DiaryCardSavedStyle? savedById(String id) => SavedStyles.byId(saved, id);

  DiaryCardStyleSettings _withSaved(List<DiaryCardSavedStyle>? next) =>
      next == null ? this : DiaryCardStyleSettings(current: current, saved: next);

  @override
  bool operator ==(Object other) {
    return other is DiaryCardStyleSettings &&
        other.current == current &&
        listEquals(other.saved, saved);
  }

  @override
  int get hashCode => Object.hash(current, Object.hashAll(saved));
}
