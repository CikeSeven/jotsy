import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/floating_top_bar/floating_action_island.dart';
import '../../../widgets/floating_top_bar/floating_island.dart';
import '../../../widgets/floating_top_bar/floating_top_bar.dart';
import '../../../widgets/floating_top_bar/floating_top_bar_host.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import 'diary_preview_host.dart';
import 'diary_preview_neighbors.dart';
import 'diary_preview_overlays.dart';

/// 预览页顶栏的动作。
class DiaryPreviewActions {
  const DiaryPreviewActions({
    required this.onEdit,
    required this.onShare,
    this.moreItems = const <Widget>[],
    this.onBack,
    this.onEditAt,
  });

  final VoidCallback onEdit;

  /// 双击正文进入编辑，光标放在 [Position] 处；null 时双击不进入编辑（设置页
  /// 预览）。是否识别双击还看阅读行为 `doubleTapToEdit` 与平台，见
  /// `DiaryPreviewContent`。
  final ValueChanged<Position>? onEditAt;
  final VoidCallback onShare;

  /// “更多”弹出菜单的条目；为空时（设置页预览）按钮照常画出、点了没反应，
  /// 与真实页面长得一样。
  final List<Widget> moreItems;

  /// 返回按钮；null 时返回上一页。
  final VoidCallback? onBack;
}

/// 预览页浮岛顶栏这一篇要显示的东西：标题胶囊、动作与显隐方式。
@immutable
class DiaryPreviewChrome {
  const DiaryPreviewChrome({
    required this.actions,
    this.title,
    this.titleSemantics,
    this.titleAnchor,
    this.hideOnScroll = false,
  });

  /// 按预览页样式得出这一篇的浮岛内容（标题胶囊见 [diaryPreviewTitleChip]）。
  factory DiaryPreviewChrome.of(
    AppLocalizations l10n, {
    required Diary diary,
    required DiaryPreviewPageStyle style,
    required DiaryPreviewActions actions,
    DiaryPreviewPaging? paging,
    GlobalKey? titleAnchor,
  }) {
    final chip = diaryPreviewTitleChip(
      l10n,
      diary: diary,
      mode: style.topBarTitle,
      paging: paging,
    );
    return DiaryPreviewChrome(
      actions: actions,
      title: chip?.text,
      titleSemantics: chip?.semantics,
      titleAnchor: chip != null && chip.afterScroll ? titleAnchor : null,
      hideOnScroll: style.topBar == DiaryPreviewTopBarMode.floating,
    );
  }

  final DiaryPreviewActions actions;

  /// 标题胶囊的文字；null 时没有标题胶囊。
  final String? title;
  final String? titleSemantics;

  /// 给出时标题胶囊在它滚过浮岛之后才出现（见 `FloatingTopBarHost`）。
  final GlobalKey? titleAnchor;
  final bool hideOnScroll;
}

/// 浮岛标题胶囊的内容：文字、读屏文字，以及是否等页头滚过才浮出。
typedef DiaryPreviewTitleChip = ({
  String text,
  String? semantics,
  bool afterScroll,
});

/// 按预览页样式的“顶栏标题”（[mode]）得出这一篇的标题胶囊；预览页与阅读式
/// 编辑页共用：
/// - 标题（[DiaryPreviewTopBarTitle.label]）：页头滚过后浮出这篇的标题（没写
///   标题时为日期）；
/// - 日期 / 位置：一直显示；没有位置（单篇打开、编辑页）时按“标题”处理；
/// - 不显示：null。
DiaryPreviewTitleChip? diaryPreviewTitleChip(
  AppLocalizations l10n, {
  required Diary diary,
  required DiaryPreviewTopBarTitle mode,
  DiaryPreviewPaging? paging,
}) {
  final date = l10n.formatFullDate(diary.createdAt.toLocal());
  DiaryPreviewTitleChip scrolledTitle() {
    final title = diary.title.trim();
    return (
      text: title.isEmpty ? date : title,
      semantics: null,
      afterScroll: true,
    );
  }

  return switch (mode) {
    DiaryPreviewTopBarTitle.label => scrolledTitle(),
    DiaryPreviewTopBarTitle.date => (
      text: date,
      semantics: null,
      afterScroll: false,
    ),
    DiaryPreviewTopBarTitle.position when paging != null => (
      text: paging.position,
      semantics: paging.positionSemantics,
      afterScroll: false,
    ),
    DiaryPreviewTopBarTitle.position => scrolledTitle(),
    DiaryPreviewTopBarTitle.none => null,
  };
}

/// 右侧动作胶囊：分享、编辑与“更多”。阅读式编辑页的胶囊另有一份（编辑
/// 中变形为 [更多 | 完成]）。
class DiaryPreviewActionsIsland extends StatelessWidget {
  const DiaryPreviewActionsIsland({super.key, required this.actions});

  final DiaryPreviewActions actions;

  @override
  Widget build(BuildContext context) {
    return FloatingActionIsland(
      children: <Widget>[
        IconButton(
          tooltip: context.l10n.previewShare,
          onPressed: actions.onShare,
          icon: const FaIcon(FontAwesomeIcons.shareFromSquare, size: 16),
        ),
        IconButton(
          tooltip: context.l10n.commonEdit,
          onPressed: actions.onEdit,
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
        ),
        DiaryMoreMenuIslandButton(items: actions.moreItems),
      ],
    );
  }
}

/// 动作胶囊里的“更多”：弹出菜单从这颗按钮的圆长出。条目为空时（设置页
/// 预览）照常画出、点了没反应。
class DiaryMoreMenuIslandButton extends StatelessWidget {
  const DiaryMoreMenuIslandButton({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    const icon = FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16);
    final tooltip = context.l10n.autoT0125;
    if (items.isEmpty) {
      return IconButton(tooltip: tooltip, onPressed: () {}, icon: icon);
    }
    return ExpressiveMenuButton(tooltip: tooltip, icon: icon, items: items);
  }
}

/// 一篇预览画浮岛要用的全部东西：要显示的标题与动作，以及整页样式、
/// 状态栏底色与这一篇的滚动控制器（点标题胶囊回到顶部）。翻页时由各篇
/// 登记给翻页器（见 `DiaryPreviewChromeBoard`）。
@immutable
class DiaryPreviewChromeEntry {
  const DiaryPreviewChromeEntry({
    required this.chrome,
    required this.resolved,
    required this.barColor,
    required this.scrollController,
  });

  final DiaryPreviewChrome chrome;
  final DiaryPreviewResolvedStyle resolved;

  /// 状态栏底条在经典材质下的颜色（纸色，或让位给背景时的实色栏底色）。
  final Color barColor;
  final ScrollController scrollController;
}

/// 预览的浮岛顶栏：把 [child]（一篇的整页内容，或翻页器）放在浮岛下面。
///
/// - 独立页面：左侧返回岛，状态栏那一条垫 [DiaryPreviewChromeEntry.barColor]
///   （玻璃时为玻璃），状态栏图标按这一篇的整页主题；
/// - 嵌在宽窗口右栏（[DiaryPreviewHostScope]）：只有右侧动作岛，不画状态栏
///   底条（右栏上方没有状态栏），也没有标题胶囊（右栏本就是阅读区）；
/// - [entry] 为 null（翻页器里当前这篇还没登记）：暂不画浮岛，结构不变，
///   [child] 不会因为浮岛出现而重新挂载。
///
/// 岛与正文列对齐（[DiaryPreviewResolvedStyle.maxContentWidth]）。翻页器在
/// 所有页之上画浮岛时传 [themed]：浮岛按当前这篇的整页主题着色，换篇时
/// 过渡（各篇自己画时已在这篇的主题之下）。
class DiaryPreviewTopBarHost extends StatelessWidget {
  const DiaryPreviewTopBarHost({
    super.key,
    required this.entry,
    required this.child,
    this.resetKey,
    this.themed = false,
  });

  final DiaryPreviewChromeEntry? entry;
  final Widget child;

  /// 见 `FloatingTopBarHost.resetKey`。
  final Object? resetKey;
  final bool themed;

  @override
  Widget build(BuildContext context) {
    final embedded = DiaryPreviewHostScope.isEmbedded(context);
    final entry = this.entry;
    final chrome = entry?.chrome;
    final actions = chrome?.actions;
    return FloatingTopBarHost(
      resetKey: resetKey,
      theme: themed ? entry?.resolved.theme : null,
      hideOnScroll: chrome?.hideOnScroll ?? false,
      contentMaxWidth: entry?.resolved.maxContentWidth,
      statusBarColor: embedded ? null : entry?.barColor,
      leading: embedded || actions == null
          ? null
          : FloatingBackIsland(onPressed: actions.onBack),
      trailing: actions == null
          ? null
          : DiaryPreviewActionsIsland(actions: actions),
      title: embedded ? null : chrome?.title,
      titleSemantics: chrome?.titleSemantics,
      titleAnchor: chrome?.titleAnchor,
      titleTooltip: context.l10n.diaryPreviewBackToTop,
      onTitleTap: entry == null
          ? null
          : () => scrollDiaryPreviewToTop(context, entry.scrollController),
      child: child,
    );
  }
}

/// 页面顶端在静止时给浮岛让出的高度（状态栏之下）：头图通栏贴顶时为 0，
/// 让岛直接压在头图上；其余情况（没有头图、内嵌头图、宽窗口的列内头图）
/// 让出整行，标题与卡片式头图不被岛盖住。
double diaryPreviewIslandClearance({required bool bannerOnTop}) =>
    bannerOnTop ? 0 : FloatingTopBar.extent;
