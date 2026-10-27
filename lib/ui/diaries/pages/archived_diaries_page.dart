import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../notebooks/controllers/diary_notebook_pick_flow.dart';
import '../../settings/providers/app_features_provider.dart';
import '../controllers/diary_card_menu_flows.dart';
import '../controllers/diary_open_flow.dart';
import '../controllers/diary_preview_edit_flow.dart';
import '../providers/diary_card_style_provider.dart';
import '../widgets/diary_preview/diary_preview_dialogs.dart';
import '../sections/diary_head_section.dart';
import '../../widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import '../../widgets/form_width.dart';

part '../controllers/archived_diaries_controller.dart';

/// 归档日记页面。
///
/// 支持：
/// - 点击进入预览页；
/// - 长按进入选择模式；
/// - 批量取消归档与删除；
/// - 列表左滑单条取消归档。
class ArchivedDiariesPage extends ConsumerStatefulWidget {
  const ArchivedDiariesPage({super.key});

  @override
  ConsumerState<ArchivedDiariesPage> createState() =>
      _ArchivedDiariesPageState();
}

class _ArchivedDiariesPageState extends ConsumerState<ArchivedDiariesPage> {
  /// 撤销提示展示时长。
  static const Duration _undoSnackDuration = Duration(seconds: 4);

  /// 操作完成后的轻提示时长。
  static const Duration _restoreHintDuration = Duration(seconds: 2);

  /// 当前多选集合（仅归档页内维护）。
  final Set<String> _selectedDiaryIds = <String>{};

  /// 多选取消归档/删除时正在播放收起动画、等待提交的条目。数据流确认移除后
  /// 在 build 中清理。
  final Set<String> _pendingHideDiaryIds = <String>{};

  /// 滑动取消归档后同步隐藏的条目：Dismissible 离场后必须立即移出列表，
  /// 不能等待异步写库后的数据流更新。
  final Set<String> _sweptAwayDiaryIds = <String>{};

  /// 撤销或失败回滚后重新出现、需要播放展开动画的条目。
  final Set<String> _appearingDiaryIds = <String>{};
  Timer? _appearingClearTimer;

  /// 桌面上 Shift + 点按选范围的起点（见 [DiarySelectionAnchor]）。
  final DiarySelectionAnchor _selectionAnchor = DiarySelectionAnchor();

  /// 业务控制器：处理删除/取消归档/撤销等流程。
  late final ArchivedDiariesController _controller;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = ArchivedDiariesController(this);
  }

  @override
  void dispose() {
    _appearingClearTimer?.cancel();
    super.dispose();
  }

  /// 数据流已不含的条目无需再隐藏/收起，返回本次应展示的列表。
  List<DiaryWithTags> _resolveVisibleDiaries(List<DiaryWithTags> diaries) {
    final currentIds = <String>{
      for (final diary in diaries) diary.diary.diaryId,
    };
    _pendingHideDiaryIds.removeWhere((id) => !currentIds.contains(id));
    _sweptAwayDiaryIds.removeWhere((id) => !currentIds.contains(id));
    if (_sweptAwayDiaryIds.isEmpty) {
      return diaries;
    }
    return diaries
        .where((diary) => !_sweptAwayDiaryIds.contains(diary.diary.diaryId))
        .toList(growable: false);
  }

  /// 桌面右键菜单：取消归档与删除带本页的收起 / 出现动画（见控制器）。
  DiaryCardMenuActions _menuActions() {
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    return DiaryCardMenuActions(
      onEdit: (diary) =>
          unawaited(_controller.editDiaryFromMenu(diary.diary.diaryId)),
      onTogglePin: (diary) => unawaited(
        setDiaryPinned(
          context,
          ref,
          diary.diary.diaryId,
          pinned: !diary.diary.isPinned,
        ),
      ),
      onNotebooks: notebooksEnabled
          ? (diary) => unawaited(
              pickNotebooksForDiary(context, ref, diaryId: diary.diary.diaryId),
            )
          : null,
      onToggleArchive: (diary) =>
          unawaited(_controller.unarchiveDiaryFromMenu(diary.diary.diaryId)),
      onDelete: (diary) =>
          unawaited(_controller.deleteDiaryFromMenu(diary.diary.diaryId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archivedAsync = ref.watch(archivedDiariesProvider);
    final diaryCardTagLimit =
        ref.watch(diaryCardTagLimitProvider).asData?.value ??
        SettingsService.defaultDiaryCardTagLimit;
    final colorScheme = Theme.of(context).colorScheme;
    final pageBackgroundColor = colorScheme.surface;

    // 返回键优先退出选择模式，避免误退出页面。
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _controller.clearSelection();
      },
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        // 进入/退出多选时标题、返回键与操作按钮缩放淡入切换，而不是整条
        // 标题栏硬换。
        appBar: AppTopBar(
          contentMaxWidth: FormWidth.maxWidth,
          title: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: Text(
              _isSelectionMode
                  ? context.l10n.autoT0099(_selectedDiaryIds.length.toString())
                  : context.l10n.autoT0100,
              key: ValueKey<int>(
                _isSelectionMode ? _selectedDiaryIds.length : -1,
              ),
            ),
          ),
          leading: ExpressiveIconSwap(
            switchKey: _isSelectionMode,
            child: _isSelectionMode
                ? IconButton(
                    tooltip: context.l10n.commonCancel,
                    onPressed: _controller.clearSelection,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                  )
                : IconButton(
                    tooltip: context.l10n.commonBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                  ),
          ),
          actions: <Widget>[
            ExpressiveIconSwap(
              switchKey: _isSelectionMode,
              child: _isSelectionMode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: context.l10n.autoT0101,
                          onPressed: () =>
                              unawaited(_controller.unarchiveSelectedDiaries()),
                          icon: const FaIcon(
                            FontAwesomeIcons.boxOpen,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.commonDelete,
                          onPressed: () =>
                              unawaited(_controller.deleteSelectedDiaries()),
                          icon: FaIcon(
                            FontAwesomeIcons.trashCan,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        // 归档页使用独立 provider，不与主页筛选逻辑共享状态。
        body: archivedAsync.when(
          loading: () => const DelayedLoadingIndicator(),
          error: (Object error, StackTrace stackTrace) =>
              Center(child: Text(context.l10n.autoT0102(error.toString()))),
          data: (List<DiaryWithTags> diaries) {
            final visibleDiaries = _resolveVisibleDiaries(diaries);
            // 最后一条被移走后与空态交叉淡入，而不是硬切成一行文字。
            return AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              child: visibleDiaries.isEmpty
                  ? EmptyHint(
                      key: const ValueKey<String>('archived_empty'),
                      icon: FontAwesomeIcons.boxArchive,
                      message: context.l10n.autoT0103,
                    )
                  : LayoutBuilder(
                      key: const ValueKey<String>('archived_list'),
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final side = FormWidth.extra(
                              constraints.maxWidth,
                              childInset: ref
                                  .watch(diaryCardStyleProvider)
                                  .list
                                  .sideMargin,
                            );
                            return CustomScrollView(
                              slivers: <Widget>[
                                // 列表组件与主页复用，行为通过回调注入实现“归档页语义”。
                                // 宽窗口：卡片列最宽 720 并居中（卡片自带左右边距
                                // sideMargin，这里只补其余留白；手机上为 0）。
                                SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: side,
                                  ),
                                  sliver: DiariesListSection(
                                    // 卡片样式按这一列实际的宽度解析。
                                    availableWidth:
                                        constraints.maxWidth - side * 2,
                                    diaries: visibleDiaries,
                                    pendingHideDiaryIds: _pendingHideDiaryIds,
                                    appearingDiaryIds: _appearingDiaryIds,
                                    layoutMode: DiaryLayoutMode.list,
                                    selectedDiaryIds: _selectedDiaryIds,
                                    isSelectionMode: _isSelectionMode,
                                    maxVisibleTags: diaryCardTagLimit,
                                    cardStyle: ref.watch(
                                      diaryCardStyleProvider,
                                    ),
                                    moodOptions: ref.watch(
                                      diaryCardMoodOptionsProvider,
                                    ),
                                    onCreate: _controller.noopCreate,
                                    onOpenEditor: (diary, coverHero) =>
                                        _controller.openPreview(
                                          diary.diary.diaryId,
                                          initialDetail: diary,
                                          coverHero: coverHero,
                                          // 正在取消归档而淡出的条目不参与翻页。
                                          sequence:
                                              DiaryPreviewSequence.fromItems(
                                                visibleDiaries.where(
                                                  (DiaryWithTags item) =>
                                                      !_pendingHideDiaryIds
                                                          .contains(
                                                            item.diary.diaryId,
                                                          ),
                                                ),
                                              ),
                                        ),
                                    onToggleSelection:
                                        _controller.toggleSelection,
                                    onArchiveDiary: (diaryId) => unawaited(
                                      _controller.unarchiveDiaryBySwipe(
                                        diaryId,
                                      ),
                                    ),
                                    swipeActionIcon: FontAwesomeIcons.boxOpen,
                                    menuActions: _menuActions(),
                                    selectionAnchor: _selectionAnchor,
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
            );
          },
        ),
      ),
    );
  }
}
