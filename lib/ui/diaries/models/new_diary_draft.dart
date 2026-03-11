/// 新建日记草稿模型。
///
/// 作用：
/// - 作为“编辑页 <-> 发布页”之间的状态载体；
/// - 作为本地自动草稿持久化的数据结构；
/// - 统一承载发布上下文（封面、标签、位置、天气、心情、精力等）。
class NewDiaryDraft {
  static const Object _fieldNotChanged = Object();

  const NewDiaryDraft({
    required this.title,
    required this.contentDocJson,
    required this.contentText,
    this.cover,
    this.metadataJson = '{}',
    this.selectedTagIds = const <int>{},
    this.location,
    this.locationAddressComponent,
    this.locationLatitude,
    this.locationLongitude,
    this.locationFromAuto = false,
    this.weather,
    this.moodEmoji,
    this.energyLevel,
  });

  final String title;
  final String contentDocJson;
  final String contentText;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;
  final String? location;
  final Map<String, Object?>? locationAddressComponent;
  final double? locationLatitude;
  final double? locationLongitude;
  final bool locationFromAuto;
  final String? weather;
  final String? moodEmoji;
  final int? energyLevel;

  /// 标题和正文是否存在可见内容。
  ///
  /// 该判定用于：
  /// - 决定是否写入自动草稿；
  /// - 决定新建入口是否提示“继续编辑”。
  bool get hasContent {
    return title.trim().isNotEmpty || contentText.trim().isNotEmpty;
  }

  /// 反序列化：从本地 JSON 恢复草稿对象。
  factory NewDiaryDraft.fromJson(Map<String, Object?> json) {
    final rawTagIds = json['selectedTagIds'];
    final tagIds =
        rawTagIds is List<Object?>
            ? rawTagIds
                .whereType<num>()
                .map((num value) => value.toInt())
                .toSet()
            : const <int>{};

    return NewDiaryDraft(
      title: (json['title'] as String?) ?? '',
      contentDocJson: (json['contentDocJson'] as String?) ?? '',
      contentText: (json['contentText'] as String?) ?? '',
      cover: json['cover'] as String?,
      metadataJson: (json['metadataJson'] as String?) ?? '{}',
      selectedTagIds: tagIds,
      location: json['location'] as String?,
      locationAddressComponent: _parseObjectMap(json['locationAddressComponent']),
      locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
      locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
      locationFromAuto: (json['locationFromAuto'] as bool?) ?? false,
      weather: json['weather'] as String?,
      moodEmoji: json['moodEmoji'] as String?,
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
    );
  }

  /// 序列化：用于写入 SettingsService 的原始草稿字符串。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'contentDocJson': contentDocJson,
      'contentText': contentText,
      'cover': cover,
      'metadataJson': metadataJson,
      'selectedTagIds': selectedTagIds.toList()..sort(),
      'location': location,
      'locationAddressComponent': locationAddressComponent,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'locationFromAuto': locationFromAuto,
      'weather': weather,
      'moodEmoji': moodEmoji,
      'energyLevel': energyLevel,
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
    Object? cover = _fieldNotChanged,
    String? metadataJson,
    Set<int>? selectedTagIds,
    Object? location = _fieldNotChanged,
    Object? locationAddressComponent = _fieldNotChanged,
    Object? locationLatitude = _fieldNotChanged,
    Object? locationLongitude = _fieldNotChanged,
    bool? locationFromAuto,
    Object? weather = _fieldNotChanged,
    Object? moodEmoji = _fieldNotChanged,
    Object? energyLevel = _fieldNotChanged,
  }) {
    return NewDiaryDraft(
      title: title ?? this.title,
      contentDocJson: contentDocJson ?? this.contentDocJson,
      contentText: contentText ?? this.contentText,
      // `cover` 需要支持“显式置空”，因此不能用 `??` 合并。
      cover: identical(cover, _fieldNotChanged) ? this.cover : cover as String?,
      metadataJson: metadataJson ?? this.metadataJson,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      location:
          identical(location, _fieldNotChanged) ? this.location : location as String?,
      locationAddressComponent:
          identical(locationAddressComponent, _fieldNotChanged)
              ? this.locationAddressComponent
              : locationAddressComponent as Map<String, Object?>?,
      locationLatitude:
          identical(locationLatitude, _fieldNotChanged)
              ? this.locationLatitude
              : locationLatitude as double?,
      locationLongitude:
          identical(locationLongitude, _fieldNotChanged)
              ? this.locationLongitude
              : locationLongitude as double?,
      locationFromAuto: locationFromAuto ?? this.locationFromAuto,
      weather: identical(weather, _fieldNotChanged) ? this.weather : weather as String?,
      moodEmoji:
          identical(moodEmoji, _fieldNotChanged) ? this.moodEmoji : moodEmoji as String?,
      energyLevel:
          identical(energyLevel, _fieldNotChanged)
              ? this.energyLevel
              : energyLevel as int?,
    );
  }

  /// 归一化 Map 结构，确保只包含可 JSON 化的 value。
  static Map<String, Object?>? _parseObjectMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      normalized[key] = _normalizeJsonValue(entry.value);
    }
    return normalized;
  }

  /// 递归清洗动态值，防止运行时对象进入草稿 JSON 导致编码失败。
  static Object? _normalizeJsonValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      final nested = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null || key.isEmpty) {
          continue;
        }
        nested[key] = _normalizeJsonValue(entry.value);
      }
      return nested;
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value.toString();
  }
}
