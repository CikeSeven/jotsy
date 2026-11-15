// 把一个实例的配置换成原生绘制用的口径：用户的选择按当前功能开关、界面
// 语言与数据过一遍，原生只管画，不再判断功能开关或隐私规则。
//
// - 快速记录：功能已关闭的动作剔除（待办、日历），剔完为空时只留“写日记”；
//   “写进日记本”指向的本子已不能写（删除、合上、变成私密）或日记本功能
//   关闭时按不指定处理。
// - 今日：农历 / 节假日的“跟随语言”按界面语言落成显示与否；待办关闭时不显示
//   待办数；日历关闭时点按改为打开应用。
// - 最近日记：来源落成快照「最近日记」一节的键（[homeWidgetRecentSourceKey]），
//   日记本已不能看（删除、变成私密）、日记本功能关闭或标签已不存在时按全部日记；
//   表头的“写一篇”只在来源是能写进去的日记本时预先选好这本。
//
// [disabled] 为 true 时原生显示“功能已关闭”占位（所需功能整体关闭）。

import '../../../core/services/app_features.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';

/// 原生口径需要的上下文。
class HomeWidgetNativeContext {
  const HomeWidgetNativeContext({
    required this.features,
    required this.languageCode,
    required this.writableNotebooks,
    this.readableNotebooks = const <String, String>{},
    this.tagNames = const <String>{},
  });

  final AppFeatures features;
  final String languageCode;

  /// 能写进去的日记本 id → 名字（见 `HomeWidgetDataSource`）。
  final Map<String, String> writableNotebooks;

  /// 能看的日记本（非私密）id → 名字，最近日记的来源只认这些。
  final Map<String, String> readableNotebooks;

  /// 现有标签的名字。
  final Set<String> tagNames;

  bool get isZh => languageCode.startsWith('zh');
}

/// 某种类的小组件所需的功能整体是否开启。
bool homeWidgetKindAvailable(HomeWidgetKind kind, AppFeatures features) =>
    switch (kind.requirement) {
      HomeWidgetRequirement.none => true,
      HomeWidgetRequirement.calendar => features.calendar,
      HomeWidgetRequirement.todos => features.todos,
      HomeWidgetRequirement.anniversaries => features.anniversariesEnabled,
      HomeWidgetRequirement.explore => features.explore,
    };

/// 快速记录在当前功能开关下可用的动作。
bool quickCaptureActionAvailable(
  QuickCaptureAction action,
  AppFeatures features,
) => switch (action) {
  QuickCaptureAction.write || QuickCaptureAction.search => true,
  QuickCaptureAction.camera => AppPlatform.supportsCameraCapture,
  QuickCaptureAction.voice => AppPlatform.supportsAudioRecording,
  QuickCaptureAction.todo => features.todos,
  QuickCaptureAction.calendar => features.calendar,
};

/// 最近日记一个实例实际取数的来源键：`all`、`pinned`、`notebook:<id>` 或
/// `tag:<名字>`；失效的来源落回 `all`。快照「最近日记」一节按这个键存。
String homeWidgetRecentSourceKey(
  RecentDiariesContent content,
  HomeWidgetNativeContext context,
) => switch (content.source) {
  RecentDiariesSource.all => 'all',
  RecentDiariesSource.pinned => 'pinned',
  RecentDiariesSource.notebook =>
    context.features.notebooks &&
            context.readableNotebooks.containsKey(content.notebookId)
        ? 'notebook:${content.notebookId}'
        : 'all',
  RecentDiariesSource.tag =>
    context.tagNames.contains(content.tagName)
        ? 'tag:${content.tagName}'
        : 'all',
};

Map<String, Object?> homeWidgetNativeConfig(
  HomeWidgetInstance instance,
  HomeWidgetNativeContext context,
) {
  return <String, Object?>{
    'kind': instance.kind.id,
    'disabled': !homeWidgetKindAvailable(instance.kind, context.features),
    'style': instance.style.toNative(),
    'content': switch (instance.content) {
      final QuickCaptureContent content => _quickCapture(content, context),
      final TodayContent content => _today(content, context),
      final AnniversaryContent content => <String, Object?>{
        'display': content.display.name,
        'id': ?content.anniversaryId,
        'date': content.showDate,
      },
      final TodoListContent content => <String, Object?>{
        'view': content.view.name,
        'list': ?content.listId,
        'completed': content.showCompleted,
        'due': content.showDue,
      },
      final MoodCalendarContent content => <String, Object?>{
        'moods': content.showMoods,
        'written': content.showWritten,
        'holiday': _almanac(content.holiday, context),
      },
      final OnThisDayContent content => <String, Object?>{
        'match': content.match.name,
        'photo': content.showPhoto,
        'excerpt': content.showExcerpt,
      },
      final RecentDiariesContent content => _recent(content, context),
    },
  };
}

Map<String, Object?> _quickCapture(
  QuickCaptureContent content,
  HomeWidgetNativeContext context,
) {
  final actions = <String>[
    for (final action in content.actions)
      if (quickCaptureActionAvailable(action, context.features)) action.name,
  ];
  final notebook = content.notebookId;
  return <String, Object?>{
    'actions': actions.isEmpty
        ? <String>[QuickCaptureAction.write.name]
        : actions,
    if (notebook != null &&
        context.features.notebooks &&
        context.writableNotebooks.containsKey(notebook))
      'notebook': notebook,
    'labels': content.showLabels,
    'greeting': content.showGreeting,
  };
}

Map<String, Object?> _today(
  TodayContent content,
  HomeWidgetNativeContext context,
) {
  bool resolve(HomeWidgetAlmanacMode mode) => _almanac(mode, context);
  final tap = switch (content.tapAction) {
    TodayTapAction.calendar when !context.features.calendar =>
      TodayTapAction.app,
    final action => action,
  };
  return <String, Object?>{
    'lunar': resolve(content.lunar),
    'holiday': resolve(content.holiday),
    'writing': content.showWriting,
    'todos': content.showTodos && context.features.todos,
    'yearProgress': content.showYearProgress,
    'mood': content.showMood,
    'tap': tap.name,
  };
}

Map<String, Object?> _recent(
  RecentDiariesContent content,
  HomeWidgetNativeContext context,
) {
  final key = homeWidgetRecentSourceKey(content, context);
  final notebook = key.startsWith('notebook:') ? content.notebookId : null;
  return <String, Object?>{
    'source': key,
    // 表头：日记本名、“#标签”；全部与置顶由原生取快照里的文案。
    if (notebook != null) 'title': context.readableNotebooks[notebook],
    if (key.startsWith('tag:')) 'title': '#${content.tagName}',
    if (notebook != null && context.writableNotebooks.containsKey(notebook))
      'notebook': notebook,
    'photos': content.showPhotos,
    'excerpt': content.showExcerpt,
  };
}

/// 农历 / 节假日的“跟随语言”按界面语言落成显示与否（与日历页同一规则）。
bool _almanac(HomeWidgetAlmanacMode mode, HomeWidgetNativeContext context) =>
    switch (mode) {
      HomeWidgetAlmanacMode.locale => context.isZh,
      HomeWidgetAlmanacMode.always => true,
      HomeWidgetAlmanacMode.never => false,
    };
