part of 'diary_preview_style.dart';

/// 信息栏：位置、版式、各项显隐、时间格式与胶囊样式。
///
/// 时间格式沿用卡片眉线的取值（相对 / 月日·星期 / 完整日期 / 数字，可附星期与
/// 时刻，按创建或更新时间），由 `DiaryCardDateFormatter` 统一格式化；默认的
/// “相对 + 创建时间 + 发表于前缀”即改版前的“发表于 3 天前”。
@immutable
class DiaryPreviewMetaStyle {
  const DiaryPreviewMetaStyle({
    this.position = DiaryPreviewMetaPosition.belowTitle,
    this.layout = DiaryPreviewMetaLayout.stacked,
    this.showDate = true,
    this.showLocation = true,
    this.showWeather = true,
    this.showMood = true,
    this.showEnergy = true,
    this.showTags = true,
    this.showWordCount = true,
    this.showReadingTime = true,
    this.dateFormat = DiaryCardDateFormat.relative,
    this.showWeekday = false,
    this.showTime = false,
    this.dateSource = DiaryCardDateSource.created,
    this.datePrefix = true,
    this.tagStyle = DiaryCardTagStyle.chip,
    this.chipStyle = DiaryPreviewChipStyle.chip,
  });

  final DiaryPreviewMetaPosition position;
  final DiaryPreviewMetaLayout layout;
  final bool showDate;
  final bool showLocation;
  final bool showWeather;
  final bool showMood;
  final bool showEnergy;
  final bool showTags;
  final bool showWordCount;

  /// 字数后附“约 N 分钟”（只在显示字数时生效）。
  final bool showReadingTime;
  final DiaryCardDateFormat dateFormat;
  final bool showWeekday;
  final bool showTime;
  final DiaryCardDateSource dateSource;

  /// 时间前加“发表于”（按更新时间时为“更新于”）。
  final bool datePrefix;
  final DiaryCardTagStyle tagStyle;
  final DiaryPreviewChipStyle chipStyle;

  /// 是否有任何一项可能显示（全部关闭时整个信息栏不占位）。
  bool get showsAnything =>
      showDate ||
      showLocation ||
      showWeather ||
      showMood ||
      showEnergy ||
      showTags ||
      showWordCount;

  DiaryPreviewMetaStyle copyWith({
    DiaryPreviewMetaPosition? position,
    DiaryPreviewMetaLayout? layout,
    bool? showDate,
    bool? showLocation,
    bool? showWeather,
    bool? showMood,
    bool? showEnergy,
    bool? showTags,
    bool? showWordCount,
    bool? showReadingTime,
    DiaryCardDateFormat? dateFormat,
    bool? showWeekday,
    bool? showTime,
    DiaryCardDateSource? dateSource,
    bool? datePrefix,
    DiaryCardTagStyle? tagStyle,
    DiaryPreviewChipStyle? chipStyle,
  }) {
    return DiaryPreviewMetaStyle(
      position: position ?? this.position,
      layout: layout ?? this.layout,
      showDate: showDate ?? this.showDate,
      showLocation: showLocation ?? this.showLocation,
      showWeather: showWeather ?? this.showWeather,
      showMood: showMood ?? this.showMood,
      showEnergy: showEnergy ?? this.showEnergy,
      showTags: showTags ?? this.showTags,
      showWordCount: showWordCount ?? this.showWordCount,
      showReadingTime: showReadingTime ?? this.showReadingTime,
      dateFormat: dateFormat ?? this.dateFormat,
      showWeekday: showWeekday ?? this.showWeekday,
      showTime: showTime ?? this.showTime,
      dateSource: dateSource ?? this.dateSource,
      datePrefix: datePrefix ?? this.datePrefix,
      tagStyle: tagStyle ?? this.tagStyle,
      chipStyle: chipStyle ?? this.chipStyle,
    );
  }

  static DiaryPreviewMetaStyle _fromJson(Object? raw) {
    const d = DiaryPreviewMetaStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    bool flag(String key, bool fallback) =>
        StyleJson.boolean(json[key], fallback);
    return DiaryPreviewMetaStyle(
      position: StyleJson.enumByName(
        DiaryPreviewMetaPosition.values,
        json['position'],
        d.position,
      ),
      layout: StyleJson.enumByName(
        DiaryPreviewMetaLayout.values,
        json['layout'],
        d.layout,
      ),
      showDate: flag('showDate', d.showDate),
      showLocation: flag('showLocation', d.showLocation),
      showWeather: flag('showWeather', d.showWeather),
      showMood: flag('showMood', d.showMood),
      showEnergy: flag('showEnergy', d.showEnergy),
      showTags: flag('showTags', d.showTags),
      showWordCount: flag('showWordCount', d.showWordCount),
      showReadingTime: flag('showReadingTime', d.showReadingTime),
      dateFormat: StyleJson.enumByName(
        DiaryCardDateFormat.values,
        json['dateFormat'],
        d.dateFormat,
      ),
      showWeekday: flag('showWeekday', d.showWeekday),
      showTime: flag('showTime', d.showTime),
      dateSource: StyleJson.enumByName(
        DiaryCardDateSource.values,
        json['dateSource'],
        d.dateSource,
      ),
      datePrefix: flag('datePrefix', d.datePrefix),
      tagStyle: StyleJson.enumByName(
        DiaryCardTagStyle.values,
        json['tagStyle'],
        d.tagStyle,
      ),
      chipStyle: StyleJson.enumByName(
        DiaryPreviewChipStyle.values,
        json['chipStyle'],
        d.chipStyle,
      ),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewMetaStyle();
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'position', position, d.position);
    StyleJson.putEnum(json, 'layout', layout, d.layout);
    StyleJson.put(json, 'showDate', showDate, d.showDate);
    StyleJson.put(json, 'showLocation', showLocation, d.showLocation);
    StyleJson.put(json, 'showWeather', showWeather, d.showWeather);
    StyleJson.put(json, 'showMood', showMood, d.showMood);
    StyleJson.put(json, 'showEnergy', showEnergy, d.showEnergy);
    StyleJson.put(json, 'showTags', showTags, d.showTags);
    StyleJson.put(json, 'showWordCount', showWordCount, d.showWordCount);
    StyleJson.put(json, 'showReadingTime', showReadingTime, d.showReadingTime);
    StyleJson.putEnum(json, 'dateFormat', dateFormat, d.dateFormat);
    StyleJson.put(json, 'showWeekday', showWeekday, d.showWeekday);
    StyleJson.put(json, 'showTime', showTime, d.showTime);
    StyleJson.putEnum(json, 'dateSource', dateSource, d.dateSource);
    StyleJson.put(json, 'datePrefix', datePrefix, d.datePrefix);
    StyleJson.putEnum(json, 'tagStyle', tagStyle, d.tagStyle);
    StyleJson.putEnum(json, 'chipStyle', chipStyle, d.chipStyle);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewMetaStyle &&
        other.position == position &&
        other.layout == layout &&
        other.showDate == showDate &&
        other.showLocation == showLocation &&
        other.showWeather == showWeather &&
        other.showMood == showMood &&
        other.showEnergy == showEnergy &&
        other.showTags == showTags &&
        other.showWordCount == showWordCount &&
        other.showReadingTime == showReadingTime &&
        other.dateFormat == dateFormat &&
        other.showWeekday == showWeekday &&
        other.showTime == showTime &&
        other.dateSource == dateSource &&
        other.datePrefix == datePrefix &&
        other.tagStyle == tagStyle &&
        other.chipStyle == chipStyle;
  }

  @override
  int get hashCode => Object.hash(
    position,
    layout,
    showDate,
    showLocation,
    showWeather,
    showMood,
    showEnergy,
    showTags,
    showWordCount,
    showReadingTime,
    dateFormat,
    showWeekday,
    showTime,
    dateSource,
    datePrefix,
    tagStyle,
    chipStyle,
  );
}
