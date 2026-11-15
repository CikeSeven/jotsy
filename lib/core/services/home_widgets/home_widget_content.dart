// 桌面小组件的内容选项（每个实例各自一份，按种类不同）。
//
// 与外观（`HomeWidgetStyle`）分开：外观各种类通用，内容只对自己的种类有
// 意义。每个种类一个子类，JSON 逐字段容错解析，认不出的种类回到该种类的
// 默认内容。哪些动作 / 字段在当前功能开关下可用，由快照构建时判断
// （`HomeWidgetFeatureGate`），这里只存用户的选择——功能重新开启时选择原样恢复。

import 'home_widget_kind.dart';

/// 农历、节气与法定节假日的显示口径：与日历页的同名选项一致，`locale`
/// 只在中文界面显示（只与中国相关的能力不随界面语言改变内容，只决定默认
/// 是否显示）。
enum HomeWidgetAlmanacMode { locale, always, never }

sealed class HomeWidgetContent {
  const HomeWidgetContent();

  Map<String, Object?> toJson();

  static HomeWidgetContent defaultsFor(HomeWidgetKind kind) => switch (kind) {
    HomeWidgetKind.quickCapture => QuickCaptureContent.defaults,
    HomeWidgetKind.today => TodayContent.defaults,
  };

  static HomeWidgetContent fromJson(HomeWidgetKind kind, Object? json) {
    final map = json is Map ? json : const <Object?, Object?>{};
    return switch (kind) {
      HomeWidgetKind.quickCapture => QuickCaptureContent._fromJson(map),
      HomeWidgetKind.today => TodayContent._fromJson(map),
    };
  }
}

T _pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

/// 快速记录上的一个动作。枚举名即持久化值。
enum QuickCaptureAction {
  /// 写日记（可指定写进哪个日记本）。
  write,

  /// 新待办（待办功能开启时）。
  todo,

  /// 打开日历的今天（日历开启时）。
  calendar,

  /// 搜索日记。
  search,
}

class QuickCaptureContent extends HomeWidgetContent {
  const QuickCaptureContent({
    this.actions = const <QuickCaptureAction>[
      QuickCaptureAction.write,
      QuickCaptureAction.todo,
      QuickCaptureAction.calendar,
    ],
    this.notebookId,
    this.showLabels = true,
    this.showGreeting = true,
  });

  static const QuickCaptureContent defaults = QuickCaptureContent();

  /// 一个小组件最多放几个动作：再多 1×1 到 4×1 的格子里就挤不下了。
  static const int maxActions = 4;

  /// 有序、不重复，1 到 [maxActions] 个；第一个是主动作（强调色、最大）。
  final List<QuickCaptureAction> actions;

  /// “写日记”写进的日记本（业务 id）；null 为不指定。只能选普通日记本，
  /// 本子后来变成私密或被删除时按不指定处理（见快照构建）。
  final String? notebookId;

  /// 动作下方显示文字；关掉只留图标。
  final bool showLabels;

  /// 2×2 及以上的尺寸显示日期与问候语。
  final bool showGreeting;

  QuickCaptureContent copyWith({
    List<QuickCaptureAction>? actions,
    String? Function()? notebookId,
    bool? showLabels,
    bool? showGreeting,
  }) {
    return QuickCaptureContent(
      actions: actions ?? this.actions,
      notebookId: notebookId == null ? this.notebookId : notebookId(),
      showLabels: showLabels ?? this.showLabels,
      showGreeting: showGreeting ?? this.showGreeting,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'actions': <String>[for (final action in actions) action.name],
    if (notebookId != null) 'notebook': notebookId,
    'labels': showLabels,
    'greeting': showGreeting,
  };

  static QuickCaptureContent _fromJson(Map<Object?, Object?> json) {
    final rawActions = json['actions'];
    final actions = <QuickCaptureAction>[];
    if (rawActions is List) {
      for (final raw in rawActions) {
        for (final action in QuickCaptureAction.values) {
          if (action.name == raw && !actions.contains(action)) {
            actions.add(action);
          }
        }
      }
    }
    final notebook = json['notebook'];
    return QuickCaptureContent(
      actions: actions.isEmpty
          ? defaults.actions
          : actions.take(maxActions).toList(growable: false),
      notebookId: notebook is String && notebook.isNotEmpty ? notebook : null,
      showLabels: _bool(json['labels'], defaults.showLabels),
      showGreeting: _bool(json['greeting'], defaults.showGreeting),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuickCaptureContent &&
      _sameList(other.actions, actions) &&
      other.notebookId == notebookId &&
      other.showLabels == showLabels &&
      other.showGreeting == showGreeting;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(actions),
    notebookId,
    showLabels,
    showGreeting,
  );
}

/// 点今日小组件打开哪里。
enum TodayTapAction { calendar, write, app }

class TodayContent extends HomeWidgetContent {
  const TodayContent({
    this.lunar = HomeWidgetAlmanacMode.locale,
    this.holiday = HomeWidgetAlmanacMode.locale,
    this.showWriting = true,
    this.showTodos = true,
    this.showYearProgress = false,
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

  final TodayTapAction tapAction;

  TodayContent copyWith({
    HomeWidgetAlmanacMode? lunar,
    HomeWidgetAlmanacMode? holiday,
    bool? showWriting,
    bool? showTodos,
    bool? showYearProgress,
    TodayTapAction? tapAction,
  }) {
    return TodayContent(
      lunar: lunar ?? this.lunar,
      holiday: holiday ?? this.holiday,
      showWriting: showWriting ?? this.showWriting,
      showTodos: showTodos ?? this.showTodos,
      showYearProgress: showYearProgress ?? this.showYearProgress,
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
      other.tapAction == tapAction;

  @override
  int get hashCode => Object.hash(
    lunar,
    holiday,
    showWriting,
    showTodos,
    showYearProgress,
    tapAction,
  );
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
