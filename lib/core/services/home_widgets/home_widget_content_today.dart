part of 'home_widget_content.dart';

// 今日小组件的内容选项（见 home_widget_content.dart 文件头）。

/// 点今日小组件打开哪里。
enum TodayTapAction { calendar, write, app }

class TodayContent extends HomeWidgetContent {
  const TodayContent({
    this.lunar = HomeWidgetAlmanacMode.locale,
    this.holiday = HomeWidgetAlmanacMode.locale,
    this.showWriting = true,
    this.showTodos = true,
    this.showYearProgress = false,
    this.showMood = true,
    this.tapAction = TodayTapAction.calendar,
  });

  static const TodayContent defaults = TodayContent();

  /// 农历日期、节气与传统节日。
  final HomeWidgetAlmanacMode lunar;

  /// 法定节假日的“休 / 班”。
  final HomeWidgetAlmanacMode holiday;

  /// 今天写了多少字。
  final bool showWriting;

  /// 今天（含逾期）还有几项待办；待办功能关闭时不显示。
  final bool showTodos;

  /// 今年已经过去了多少。
  final bool showYearProgress;

  /// 一排五张心情脸，点一下记下今天的心情（再点一下取消）；放得下时才显示
  /// （横幅与更高的方块）。
  final bool showMood;

  final TodayTapAction tapAction;

  TodayContent copyWith({
    HomeWidgetAlmanacMode? lunar,
    HomeWidgetAlmanacMode? holiday,
    bool? showWriting,
    bool? showTodos,
    bool? showYearProgress,
    bool? showMood,
    TodayTapAction? tapAction,
  }) {
    return TodayContent(
      lunar: lunar ?? this.lunar,
      holiday: holiday ?? this.holiday,
      showWriting: showWriting ?? this.showWriting,
      showTodos: showTodos ?? this.showTodos,
      showYearProgress: showYearProgress ?? this.showYearProgress,
      showMood: showMood ?? this.showMood,
      tapAction: tapAction ?? this.tapAction,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'lunar': lunar.name,
    'holiday': holiday.name,
    'writing': showWriting,
    'todos': showTodos,
    'yearProgress': showYearProgress,
    'mood': showMood,
    'tap': tapAction.name,
  };

  static TodayContent _fromJson(Map<Object?, Object?> json) => TodayContent(
    lunar: _pick(HomeWidgetAlmanacMode.values, json['lunar'], defaults.lunar),
    holiday: _pick(
      HomeWidgetAlmanacMode.values,
      json['holiday'],
      defaults.holiday,
    ),
    showWriting: _bool(json['writing'], defaults.showWriting),
    showTodos: _bool(json['todos'], defaults.showTodos),
    showYearProgress: _bool(json['yearProgress'], defaults.showYearProgress),
    showMood: _bool(json['mood'], defaults.showMood),
    tapAction: _pick(TodayTapAction.values, json['tap'], defaults.tapAction),
  );

  @override
  bool operator ==(Object other) =>
      other is TodayContent &&
      other.lunar == lunar &&
      other.holiday == holiday &&
      other.showWriting == showWriting &&
      other.showTodos == showTodos &&
      other.showYearProgress == showYearProgress &&
      other.showMood == showMood &&
      other.tapAction == tapAction;

  @override
  int get hashCode => Object.hash(
    lunar,
    holiday,
    showWriting,
    showTodos,
    showYearProgress,
    showMood,
    tapAction,
  );
}
