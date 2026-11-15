// 桌面小组件的内容选项（每个实例各自一份，按种类不同）。
//
// 与外观（`HomeWidgetStyle`）分开：外观各种类通用，内容只对自己的种类有
// 意义。每个种类一个子类，JSON 逐字段容错解析，认不出的种类回到该种类的
// 默认内容。哪些动作 / 字段在当前功能开关下可用，由快照构建时判断
// （`HomeWidgetFeatureGate`），这里只存用户的选择——功能重新开启时选择原样恢复。

import 'home_widget_kind.dart';

part 'home_widget_content_today.dart';
part 'home_widget_content_diaries.dart';
part 'home_widget_content_stats.dart';
part 'home_widget_content_time.dart';
part 'home_widget_content_todos.dart';

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
    HomeWidgetKind.anniversary => AnniversaryContent.defaults,
    HomeWidgetKind.moodCalendar => MoodCalendarContent.defaults,
    HomeWidgetKind.todos => TodoListContent.defaults,
    HomeWidgetKind.onThisDay => OnThisDayContent.defaults,
    HomeWidgetKind.recentDiaries => RecentDiariesContent.defaults,
    HomeWidgetKind.writingStats => WritingStatsContent.defaults,
    HomeWidgetKind.photoMemories => PhotoMemoriesContent.defaults,
  };

  static HomeWidgetContent fromJson(HomeWidgetKind kind, Object? json) {
    final map = json is Map ? json : const <Object?, Object?>{};
    return switch (kind) {
      HomeWidgetKind.quickCapture => QuickCaptureContent._fromJson(map),
      HomeWidgetKind.today => TodayContent._fromJson(map),
      HomeWidgetKind.anniversary => AnniversaryContent._fromJson(map),
      HomeWidgetKind.moodCalendar => MoodCalendarContent._fromJson(map),
      HomeWidgetKind.todos => TodoListContent._fromJson(map),
      HomeWidgetKind.onThisDay => OnThisDayContent._fromJson(map),
      HomeWidgetKind.recentDiaries => RecentDiariesContent._fromJson(map),
      HomeWidgetKind.writingStats => WritingStatsContent._fromJson(map),
      HomeWidgetKind.photoMemories => PhotoMemoriesContent._fromJson(map),
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

  /// 拍照记：新建日记并直接打开相机，拍到的照片插进正文（能拍摄的平台）。
  camera,

  /// 录音记：新建日记并直接开始录音（能录音的平台）。
  voice,

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

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
