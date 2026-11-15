// 快照构建的输入（`HomeWidgetSnapshotBuilder.build`）：构建时刻、界面语言、配色、
// 功能开关、应用锁、小组件设置与桌面上的实例。由同步控制器从设置与插件读出，测试
// 直接构造。

import 'package:flutter/painting.dart' show Color;

import '../../../core/services/app_features.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';

class HomeWidgetSnapshotInput {
  const HomeWidgetSnapshotInput({
    required this.now,
    required this.l10n,
    required this.appSeed,
    required this.features,
    required this.appLocked,
    required this.settings,
    required this.installed,
    required this.kinds,
    this.moodOptions = const <String>[],
    this.weekStart = CalendarWeekStart.locale,
    this.previewContents = const <HomeWidgetContent>[],
  });

  final DateTime now;
  final AppLocalizations l10n;
  final Color appSeed;
  final AppFeatures features;

  /// 开启了应用锁：涉及日记标题、正文与照片的内容不进快照，原生显示锁定
  /// 占位（docs/rules/home_widgets.md「隐私」）。
  final bool appLocked;

  final HomeWidgetSettings settings;
  final List<InstalledHomeWidget> installed;

  /// 要计算数据节的种类。
  final Set<HomeWidgetKind> kinds;

  /// 日记心情的十档符号（心情月历把当天日记的平均心情折成五段）。
  final List<String> moodOptions;

  /// 日历设置里一周从哪天开始（心情月历与日历页一致）。
  final CalendarWeekStart weekStart;

  /// 工作室里正在编辑、还没放到桌面上的内容：预览要画出它选的来源与口径
  /// （最近日记的某个日记本、那年今日的同月等），数据节一并算上。
  final List<HomeWidgetContent> previewContents;

  /// 桌面上的实例、待领取的设计与工作室草稿的全部内容。
  Iterable<HomeWidgetContent> get usedContents sync* {
    for (final widget in installed) {
      yield settings.instanceFor(widget.widgetId, widget.kind).content;
    }
    for (final pin in settings.pending) {
      yield pin.instance.content;
    }
    yield* previewContents;
  }
}
