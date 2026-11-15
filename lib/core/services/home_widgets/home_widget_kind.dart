// 桌面小组件的种类（docs/rules/home_widgets.md）。
//
// 每个种类对应 Android 上的一个 `AppWidgetProvider`（Glance 接收器，
// `android/app/src/main/kotlin/com/jotsy/diary/widgets/kinds/`），在启动器的
// 小组件列表里是独立的一项。[id] 是持久化值：写进小组件设置
// （`app.settings.home_widgets`）与发给原生的快照，改名等同于改存储格式。

/// 组件库里的分组，决定小组件页画廊的分区顺序。
enum HomeWidgetGroup { capture, time, todos, stats }

/// 一种小组件需要的功能开关；对应功能关闭时组件库隐藏它，已放在桌面上的
/// 显示“功能已关闭”占位（见 `HomeWidgetFeatureGate`）。
enum HomeWidgetRequirement { none, calendar, todos, anniversaries, explore }

enum HomeWidgetKind {
  /// 快速记录：一到四个自选的快捷动作。
  quickCapture(
    id: 'quick_capture',
    receiverName: 'QuickCaptureWidgetReceiver',
    group: HomeWidgetGroup.capture,
    requirement: HomeWidgetRequirement.none,
  ),

  /// 那年今日：往年这一天（或前后几天、同月）写下的日记，照片优先，多篇时
  /// 在桌面上翻看。
  onThisDay(
    id: 'on_this_day',
    receiverName: 'OnThisDayWidgetReceiver',
    group: HomeWidgetGroup.capture,
    requirement: HomeWidgetRequirement.none,
  ),

  /// 最近日记：全部、某个日记本、某个标签或置顶的最近几篇。
  recentDiaries(
    id: 'recent_diaries',
    receiverName: 'RecentDiariesWidgetReceiver',
    group: HomeWidgetGroup.capture,
    requirement: HomeWidgetRequirement.none,
  ),

  /// 今日：日期、农历、节气与法定节假日，今天写了多少、还有几项待办，点脸
  /// 记下今天的心情。
  today(
    id: 'today',
    receiverName: 'TodayWidgetReceiver',
    group: HomeWidgetGroup.time,
    requirement: HomeWidgetRequirement.none,
  ),

  /// 纪念日：一个纪念日的大号倒数，或接下来几个纪念日的列表。
  anniversary(
    id: 'anniversary',
    receiverName: 'AnniversaryWidgetReceiver',
    group: HomeWidgetGroup.time,
    requirement: HomeWidgetRequirement.anniversaries,
  ),

  /// 心情月历：这个月每天的心情与写过的日子。
  moodCalendar(
    id: 'mood_calendar',
    receiverName: 'MoodCalendarWidgetReceiver',
    group: HomeWidgetGroup.time,
    requirement: HomeWidgetRequirement.calendar,
  ),

  /// 待办清单：今天 / 计划 / 全部 / 某个清单的待办，在桌面上直接勾选完成。
  todos(
    id: 'todos',
    receiverName: 'TodosWidgetReceiver',
    group: HomeWidgetGroup.todos,
    requirement: HomeWidgetRequirement.todos,
  ),

  /// 写作统计：连续记录天数、本月与今年写了多少，以及最近几周的热力图。
  writingStats(
    id: 'writing_stats',
    receiverName: 'WritingStatsWidgetReceiver',
    group: HomeWidgetGroup.stats,
    requirement: HomeWidgetRequirement.explore,
  ),

  /// 照片回忆：日记里的照片满幅显示，每天换一张，也可以在桌面上换。
  photoMemories(
    id: 'photo_memories',
    receiverName: 'PhotoMemoriesWidgetReceiver',
    group: HomeWidgetGroup.stats,
    requirement: HomeWidgetRequirement.none,
  );

  const HomeWidgetKind({
    required this.id,
    required this.receiverName,
    required this.group,
    required this.requirement,
  });

  /// 持久化 id（设置与快照里的 `kind`）。
  final String id;

  /// 原生接收器的类名（不含包名）。
  final String receiverName;

  final HomeWidgetGroup group;

  final HomeWidgetRequirement requirement;

  /// 原生接收器所在的包；与 `AndroidManifest.xml` 里登记的保持一致。
  static const String androidPackage = 'com.jotsy.diary.widgets';

  /// 刷新与固定到桌面时交给 home_widget 的完整类名。
  String get qualifiedAndroidName => '$androidPackage.$receiverName';

  /// 按持久化 id 查找；认不出（更新版本写入的新种类）时返回 null。
  static HomeWidgetKind? byId(String? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// 按 `getInstalledWidgets` 报告的类名查找；接收器改名或来自旧版本时
  /// 返回 null，调用方跳过这个实例。
  static HomeWidgetKind? byAndroidClassName(String? className) {
    if (className == null) return null;
    for (final kind in values) {
      if (className == kind.qualifiedAndroidName ||
          className.endsWith('.${kind.receiverName}')) {
        return kind;
      }
    }
    return null;
  }
}
