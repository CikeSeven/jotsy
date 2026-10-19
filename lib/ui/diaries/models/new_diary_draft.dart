import 'dart:convert';

import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/json_object_map.dart';

/// 草稿箱自动保存的快照：要写进草稿表的整份 JSON 与列表用的镜像字段。
///
/// 用 record 是为了结构相等——自动保存控制器靠 `==` 判断“已存过”，内容
/// 没变时不写库，打开一份草稿什么也不改就不会刷新它的编辑时间。
typedef NewDiaryDraftSnapshot = ({
  String payload,
  String title,
  String contentText,
  bool hasContent,
});

/// 新建日记草稿模型。
///
/// 作用：
/// - 作为“编辑页 <-> 发布页”之间的状态载体；
/// - 作为草稿箱（`diary_drafts` 表 `payload` 列）持久化的数据结构；
/// - 统一承载发布上下文（封面、标签、所在日记本、位置、天气、心情、精力等）。
///
/// 日记本：[notebookIds] 为要收进的日记本（业务 id，按勾选先后）；
/// [notebookChapterIds] 为在日记本里按章节新建时的章节（日记本 id → 章节
/// id），发布时只对仍勾选的本子生效。两者都随草稿保存，旧草稿没有这两项时
/// 为空。
class NewDiaryDraft {
  static const Object _fieldNotChanged = Object();

  const NewDiaryDraft({
    required this.title,
    required this.contentDocJson,
    required this.contentText,
    this.createdAtOverride,
    this.cover,
    this.metadataJson = '{}',
    this.selectedTagIds = const <int>{},
    this.notebookIds = const <String>[],
    this.notebookChapterIds = const <String, String>{},
    this.location,
    this.locationAddressComponent,
    this.locationLatitude,
    this.locationLongitude,
    this.locationFromAuto = false,
    this.locationPrecision = DiaryLocationPrecision.township,
    this.weather,
    this.weatherIconCode,
    this.moodEmoji,
    this.energyLevel,
    this.capsuleUnlockAt,
    this.capsulePrecision,
  });

  final String title;
  final String contentDocJson;
  final String contentText;
  final DateTime? createdAtOverride;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;
  final List<String> notebookIds;
  final Map<String, String> notebookChapterIds;
  final String? location;
  final Map<String, Object?>? locationAddressComponent;
  final double? locationLatitude;
  final double? locationLongitude;
  final bool locationFromAuto;
  final DiaryLocationPrecision locationPrecision;
  final String? weather;
  final String? weatherIconCode;
  final String? moodEmoji;
  final double? energyLevel;
  final DateTime? capsuleUnlockAt;
  final String? capsulePrecision;

  /// 标题和正文是否存在可见内容。
  ///
  /// 该判定用于：
  /// - 决定是否写入自动草稿；
  /// - 决定新建入口是否提示“继续编辑”。
  bool get hasContent {
    return title.trim().isNotEmpty ||
        contentText.trim().isNotEmpty ||
        diaryContentHasEmbeddedContent(contentDocJson);
  }

  /// 草稿箱写入用的快照，`payload` 即 [toJson] 的编码结果。
  NewDiaryDraftSnapshot toSnapshot() => (
    payload: jsonEncode(toJson()),
    title: title,
    contentText: contentText,
    hasContent: hasContent,
  );

  /// 反序列化：从本地 JSON 恢复草稿对象。
  factory NewDiaryDraft.fromJson(Map<String, Object?> json) {
    final rawTagIds = json['selectedTagIds'];
    final tagIds = rawTagIds is List<Object?>
        ? rawTagIds.whereType<num>().map((num value) => value.toInt()).toSet()
        : const <int>{};
    final rawNotebookIds = json['notebookIds'];
    final notebookIds = rawNotebookIds is List<Object?>
        ? rawNotebookIds
              .whereType<String>()
              .where((String id) => id.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    final rawChapters = json['notebookChapterIds'];
    final notebookChapterIds = rawChapters is Map
        ? <String, String>{
            for (final entry in rawChapters.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          }
        : const <String, String>{};

    return NewDiaryDraft(
      title: (json['title'] as String?) ?? '',
      contentDocJson: (json['contentDocJson'] as String?) ?? '',
      contentText: (json['contentText'] as String?) ?? '',
      createdAtOverride: _parseDateTime(json['createdAtOverride']),
      cover: json['cover'] as String?,
      metadataJson: (json['metadataJson'] as String?) ?? '{}',
      selectedTagIds: tagIds,
      notebookIds: notebookIds,
      notebookChapterIds: notebookChapterIds,
      location: json['location'] as String?,
      locationAddressComponent: parseJsonObjectMap(
        json['locationAddressComponent'],
      ),
      locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
      locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
      locationFromAuto: (json['locationFromAuto'] as bool?) ?? false,
      locationPrecision: DiaryLocationPrecision.parse(
        json['locationPrecision'],
      ),
      weather: json['weather'] as String?,
      weatherIconCode: json['weatherIconCode'] as String?,
      moodEmoji: json['moodEmoji'] as String?,
      energyLevel: (json['energyLevel'] as num?)?.toDouble(),
      capsuleUnlockAt: _parseDateTime(json['capsuleUnlockAt']),
      capsulePrecision: json['capsulePrecision'] as String?,
    );
  }

  /// 序列化：草稿表 `payload` 列与备份中的草稿内容。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'contentDocJson': contentDocJson,
      'contentText': contentText,
      'createdAtOverride': createdAtOverride?.toIso8601String(),
      'cover': cover,
      'metadataJson': metadataJson,
      'selectedTagIds': selectedTagIds.toList()..sort(),
      'notebookIds': notebookIds,
      'notebookChapterIds': notebookChapterIds,
      'location': location,
      'locationAddressComponent': locationAddressComponent,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'locationFromAuto': locationFromAuto,
      'locationPrecision': locationPrecision.name,
      'weather': weather,
      'weatherIconCode': weatherIconCode,
      'moodEmoji': moodEmoji,
      'energyLevel': energyLevel,
      'capsuleUnlockAt': capsuleUnlockAt?.toIso8601String(),
      'capsulePrecision': capsulePrecision,
    };
  }

  /// copyWith 支持“显式置空”字段。
  ///
  /// 某些可空字段需要区分：
  /// - 未传入（保持旧值）；
  /// - 显式传入 null（清空该值）。
  NewDiaryDraft copyWith({
    String? title,
    String? contentDocJson,
    String? contentText,
    Object? createdAtOverride = _fieldNotChanged,
    Object? cover = _fieldNotChanged,
    String? metadataJson,
    Set<int>? selectedTagIds,
    List<String>? notebookIds,
    Map<String, String>? notebookChapterIds,
    Object? location = _fieldNotChanged,
    Object? locationAddressComponent = _fieldNotChanged,
    Object? locationLatitude = _fieldNotChanged,
    Object? locationLongitude = _fieldNotChanged,
    bool? locationFromAuto,
    DiaryLocationPrecision? locationPrecision,
    Object? weather = _fieldNotChanged,
    Object? weatherIconCode = _fieldNotChanged,
    Object? moodEmoji = _fieldNotChanged,
    Object? energyLevel = _fieldNotChanged,
    Object? capsuleUnlockAt = _fieldNotChanged,
    Object? capsulePrecision = _fieldNotChanged,
  }) {
    return NewDiaryDraft(
      title: title ?? this.title,
      contentDocJson: contentDocJson ?? this.contentDocJson,
      contentText: contentText ?? this.contentText,
      createdAtOverride: identical(createdAtOverride, _fieldNotChanged)
          ? this.createdAtOverride
          : createdAtOverride as DateTime?,
      // `cover` 需要支持“显式置空”，因此不能用 `??` 合并。
      cover: identical(cover, _fieldNotChanged) ? this.cover : cover as String?,
      metadataJson: metadataJson ?? this.metadataJson,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      notebookIds: notebookIds ?? this.notebookIds,
      notebookChapterIds: notebookChapterIds ?? this.notebookChapterIds,
      location: identical(location, _fieldNotChanged)
          ? this.location
          : location as String?,
      locationAddressComponent:
          identical(locationAddressComponent, _fieldNotChanged)
          ? this.locationAddressComponent
          : locationAddressComponent as Map<String, Object?>?,
      locationLatitude: identical(locationLatitude, _fieldNotChanged)
          ? this.locationLatitude
          : locationLatitude as double?,
      locationLongitude: identical(locationLongitude, _fieldNotChanged)
          ? this.locationLongitude
          : locationLongitude as double?,
      locationFromAuto: locationFromAuto ?? this.locationFromAuto,
      locationPrecision: locationPrecision ?? this.locationPrecision,
      weather: identical(weather, _fieldNotChanged)
          ? this.weather
          : weather as String?,
      weatherIconCode: identical(weatherIconCode, _fieldNotChanged)
          ? this.weatherIconCode
          : weatherIconCode as String?,
      moodEmoji: identical(moodEmoji, _fieldNotChanged)
          ? this.moodEmoji
          : moodEmoji as String?,
      energyLevel: identical(energyLevel, _fieldNotChanged)
          ? this.energyLevel
          : energyLevel as double?,
      capsuleUnlockAt: identical(capsuleUnlockAt, _fieldNotChanged)
          ? this.capsuleUnlockAt
          : capsuleUnlockAt as DateTime?,
      capsulePrecision: identical(capsulePrecision, _fieldNotChanged)
          ? this.capsulePrecision
          : capsulePrecision as String?,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    if (raw is int) {
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    return null;
  }
}
