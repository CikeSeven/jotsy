part of 'home_widget_content.dart';

// 纪念日与心情月历的内容选项（见 home_widget_content.dart 文件头）。

/// 纪念日小组件显示一个还是一列。
enum AnniversaryDisplay {
  /// 一个纪念日的大号倒数（[AnniversaryContent.anniversaryId]，未指定时取
  /// 列表里的第一个：置顶的、最近要到的）。
  single,

  /// 接下来的几个纪念日（置顶在前，再按日子远近），行数随高度。
  list,
}

class AnniversaryContent extends HomeWidgetContent {
  const AnniversaryContent({
    this.display = AnniversaryDisplay.single,
    this.anniversaryId,
    this.showDate = true,
  });

  static const AnniversaryContent defaults = AnniversaryContent();

  final AnniversaryDisplay display;

  /// 单个模式显示哪一个（业务 id）；null 或已被删除时取列表里的第一个。
  final String? anniversaryId;

  /// 显示日期（与第几周年）。
  final bool showDate;

  AnniversaryContent copyWith({
    AnniversaryDisplay? display,
    String? Function()? anniversaryId,
    bool? showDate,
  }) => AnniversaryContent(
    display: display ?? this.display,
    anniversaryId: anniversaryId == null ? this.anniversaryId : anniversaryId(),
    showDate: showDate ?? this.showDate,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'display': display.name,
    if (anniversaryId != null) 'id': anniversaryId,
    'date': showDate,
  };

  static AnniversaryContent _fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    return AnniversaryContent(
      display: _pick(
        AnniversaryDisplay.values,
        json['display'],
        defaults.display,
      ),
      anniversaryId: id is String && id.isNotEmpty ? id : null,
      showDate: _bool(json['date'], defaults.showDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnniversaryContent &&
      other.display == display &&
      other.anniversaryId == anniversaryId &&
      other.showDate == showDate;

  @override
  int get hashCode => Object.hash(display, anniversaryId, showDate);
}

class MoodCalendarContent extends HomeWidgetContent {
  const MoodCalendarContent({
    this.showMoods = true,
    this.showWritten = true,
    this.holiday = HomeWidgetAlmanacMode.locale,
  });

  static const MoodCalendarContent defaults = MoodCalendarContent();

  /// 按心情给日期格着色：这天的心情优先，其次是当天日记心情的平均（与
  /// 日历年视图同一口径）。
  final bool showMoods;

  /// 写过日记的日子在数字下方打点。
  final bool showWritten;

  /// 法定节假日的“休 / 班”。
  final HomeWidgetAlmanacMode holiday;

  MoodCalendarContent copyWith({
    bool? showMoods,
    bool? showWritten,
    HomeWidgetAlmanacMode? holiday,
  }) => MoodCalendarContent(
    showMoods: showMoods ?? this.showMoods,
    showWritten: showWritten ?? this.showWritten,
    holiday: holiday ?? this.holiday,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'moods': showMoods,
    'written': showWritten,
    'holiday': holiday.name,
  };

  static MoodCalendarContent _fromJson(Map<Object?, Object?> json) =>
      MoodCalendarContent(
        showMoods: _bool(json['moods'], defaults.showMoods),
        showWritten: _bool(json['written'], defaults.showWritten),
        holiday: _pick(
          HomeWidgetAlmanacMode.values,
          json['holiday'],
          defaults.holiday,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is MoodCalendarContent &&
      other.showMoods == showMoods &&
      other.showWritten == showWritten &&
      other.holiday == holiday;

  @override
  int get hashCode => Object.hash(showMoods, showWritten, holiday);
}
