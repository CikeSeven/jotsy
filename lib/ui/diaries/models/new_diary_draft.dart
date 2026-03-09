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
  final double? locationLatitude;
  final double? locationLongitude;
  final bool locationFromAuto;
  final String? weather;
  final String? moodEmoji;
  final int? energyLevel;

  bool get hasContent {
    return title.trim().isNotEmpty || contentText.trim().isNotEmpty;
  }

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
      locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
      locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
      locationFromAuto: (json['locationFromAuto'] as bool?) ?? false,
      weather: json['weather'] as String?,
      moodEmoji: json['moodEmoji'] as String?,
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'contentDocJson': contentDocJson,
      'contentText': contentText,
      'cover': cover,
      'metadataJson': metadataJson,
      'selectedTagIds': selectedTagIds.toList()..sort(),
      'location': location,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'locationFromAuto': locationFromAuto,
      'weather': weather,
      'moodEmoji': moodEmoji,
      'energyLevel': energyLevel,
    };
  }

  NewDiaryDraft copyWith({
    String? title,
    String? contentDocJson,
    String? contentText,
    Object? cover = _fieldNotChanged,
    String? metadataJson,
    Set<int>? selectedTagIds,
    Object? location = _fieldNotChanged,
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
}
