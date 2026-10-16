part of 'diary_card_style.dart';

/// 卡片上的日期、时间与附加信息（心情、天气、地点、精力、字数、媒体）。
/// 两种布局共用；心情与天气放在哪由各模式的 `metaPosition` 决定。
@immutable
class DiaryCardMetaStyle {
  const DiaryCardMetaStyle({
    this.showDate = true,
    this.dateFormat = DiaryCardDateFormat.eyebrow,
    this.showWeekday = true,
    this.showTime = false,
    this.dateSource = DiaryCardDateSource.created,
    this.footerTime = DiaryCardFooterTime.relativeUpdated,
    this.showMood = true,
    this.showWeather = true,
    this.indicatorStyle = DiaryCardIndicatorStyle.stamp,
    this.showLocation = false,
    this.showEnergy = false,
    this.showWordCount = false,
    this.showMedia = false,
  });

  /// 眉线日期；关闭后眉线只剩置顶徽章与（位于眉线时的）心情天气。
  final bool showDate;
  final DiaryCardDateFormat dateFormat;

  /// 日期后附星期；相对时间格式下不适用。
  final bool showWeekday;

  /// 日期后附 HH:mm；相对时间格式下不适用。
  final bool showTime;
  final DiaryCardDateSource dateSource;
  final DiaryCardFooterTime footerTime;
  final bool showMood;
  final bool showWeather;
  final DiaryCardIndicatorStyle indicatorStyle;
  final bool showLocation;
  final bool showEnergy;
  final bool showWordCount;

  /// 正文中的图片数量、录音、视频与附件标记。
  final bool showMedia;

  /// 底栏是否有附加信息（地点、精力、字数、媒体）。
  bool get hasFooterExtras =>
      showLocation || showEnergy || showWordCount || showMedia;

  DiaryCardMetaStyle copyWith({
    bool? showDate,
    DiaryCardDateFormat? dateFormat,
    bool? showWeekday,
    bool? showTime,
    DiaryCardDateSource? dateSource,
    DiaryCardFooterTime? footerTime,
    bool? showMood,
    bool? showWeather,
    DiaryCardIndicatorStyle? indicatorStyle,
    bool? showLocation,
    bool? showEnergy,
    bool? showWordCount,
    bool? showMedia,
  }) {
    return DiaryCardMetaStyle(
      showDate: showDate ?? this.showDate,
      dateFormat: dateFormat ?? this.dateFormat,
      showWeekday: showWeekday ?? this.showWeekday,
      showTime: showTime ?? this.showTime,
      dateSource: dateSource ?? this.dateSource,
      footerTime: footerTime ?? this.footerTime,
      showMood: showMood ?? this.showMood,
      showWeather: showWeather ?? this.showWeather,
      indicatorStyle: indicatorStyle ?? this.indicatorStyle,
      showLocation: showLocation ?? this.showLocation,
      showEnergy: showEnergy ?? this.showEnergy,
      showWordCount: showWordCount ?? this.showWordCount,
      showMedia: showMedia ?? this.showMedia,
    );
  }

  static DiaryCardMetaStyle _fromJson(Object? raw) {
    const d = DiaryCardMetaStyle();
    final json = _map(raw);
    if (json == null) {
      return d;
    }
    return DiaryCardMetaStyle(
      showDate: _bool(json['showDate'], d.showDate),
      dateFormat: _enumByName(
        DiaryCardDateFormat.values,
        json['dateFormat'],
        d.dateFormat,
      ),
      showWeekday: _bool(json['showWeekday'], d.showWeekday),
      showTime: _bool(json['showTime'], d.showTime),
      dateSource: _enumByName(
        DiaryCardDateSource.values,
        json['dateSource'],
        d.dateSource,
      ),
      footerTime: _enumByName(
        DiaryCardFooterTime.values,
        json['footerTime'],
        d.footerTime,
      ),
      showMood: _bool(json['showMood'], d.showMood),
      showWeather: _bool(json['showWeather'], d.showWeather),
      indicatorStyle: _enumByName(
        DiaryCardIndicatorStyle.values,
        json['indicatorStyle'],
        d.indicatorStyle,
      ),
      showLocation: _bool(json['showLocation'], d.showLocation),
      showEnergy: _bool(json['showEnergy'], d.showEnergy),
      showWordCount: _bool(json['showWordCount'], d.showWordCount),
      showMedia: _bool(json['showMedia'], d.showMedia),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryCardMetaStyle();
    final json = <String, Object>{};
    _put(json, 'showDate', showDate, d.showDate);
    _putEnum(json, 'dateFormat', dateFormat, d.dateFormat);
    _put(json, 'showWeekday', showWeekday, d.showWeekday);
    _put(json, 'showTime', showTime, d.showTime);
    _putEnum(json, 'dateSource', dateSource, d.dateSource);
    _putEnum(json, 'footerTime', footerTime, d.footerTime);
    _put(json, 'showMood', showMood, d.showMood);
    _put(json, 'showWeather', showWeather, d.showWeather);
    _putEnum(json, 'indicatorStyle', indicatorStyle, d.indicatorStyle);
    _put(json, 'showLocation', showLocation, d.showLocation);
    _put(json, 'showEnergy', showEnergy, d.showEnergy);
    _put(json, 'showWordCount', showWordCount, d.showWordCount);
    _put(json, 'showMedia', showMedia, d.showMedia);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardMetaStyle &&
        other.showDate == showDate &&
        other.dateFormat == dateFormat &&
        other.showWeekday == showWeekday &&
        other.showTime == showTime &&
        other.dateSource == dateSource &&
        other.footerTime == footerTime &&
        other.showMood == showMood &&
        other.showWeather == showWeather &&
        other.indicatorStyle == indicatorStyle &&
        other.showLocation == showLocation &&
        other.showEnergy == showEnergy &&
        other.showWordCount == showWordCount &&
        other.showMedia == showMedia;
  }

  @override
  int get hashCode => Object.hash(
    showDate,
    dateFormat,
    showWeekday,
    showTime,
    dateSource,
    footerTime,
    showMood,
    showWeather,
    indicatorStyle,
    showLocation,
    showEnergy,
    showWordCount,
    showMedia,
  );
}
