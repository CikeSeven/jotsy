import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/diary_drafts_controller.dart';
import '../controllers/diary_pointer_selection.dart';
import '../providers/diary_draft_providers.dart';
import '../sections/diary_drafts_top_bar.dart';
import '../viewmodels/diary_draft_list_item.dart';
import '../widgets/diary_draft_context_menu.dart';
import '../widgets/diary_draft_tile.dart';
import '../widgets/diary_swipe_action_item.dart';
import 'edit_diary_page.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 草稿箱：还没发布的新建日记，最近编辑的在前。
///
/// - 点按续写（打开新建模式的编辑页，发布后这一份自动删除）；
/// - 左滑删除单份，长按进入多选（顶栏可全选）、批量删除（先确认）；两种
///   删除都带撤销；
/// - 桌面上鼠标很少长按、也不该拖动卡片（会误删），改为：顶栏“多选”按钮
///   直接进入多选、Ctrl / Shift + 点按多选、右键菜单继续写或删除单份（与
///   左滑一样不确认、带撤销），不提供左滑（#350）；
/// - 多选时系统返回先退出多选。
///
/// 页面只做装配与选择、收起等界面状态；删除与撤销经 [DiaryDraftsController]。
class DiaryDraftsPage extends ConsumerStatefulWidget {
  const DiaryDraftsPage({super.key});

  @override
  ConsumerState<DiaryDraftsPage> createState() => _DiaryDraftsPageState();
}

class _DiaryDraftsPageState extends ConsumerState<DiaryDraftsPage> {
  static const Duration _undoSnackDuration = Duration(seconds: 4);

  late final DiaryDraftsController _controller = DiaryDraftsController(
    database: ref.read(appDatabaseProvider),
    mediaCleanup: ref.read(diaryMediaCleanupServiceProvider),
  );

  final Set<String> _selectedIds = <String>{};

  /// 批量删除时先收起、再写库的条目；数据流确认移除后在 build 中清理，
  /// 写库失败的重新展开。
  final Set<String> _pendingHideIds = <String>{};

  /// 左滑删掉的条目：侧滑组件已播完滑出与收起，必须在同一帧移出列表。
  final Set<String> _sweptAwayIds = <String>{};

  /// 撤销后重新出现的条目，从 0 展开而不是直接冒出。
  final Set<String> _appearingIds = <String>{};

  /// 本次构建列出、可以勾选的草稿（不含滑走与正在收起的），供“全选”使用；
  /// 在 build 开头随数据流更新。
  List<String> _selectableIds = const <String>[];

  bool _operating = false;

  /// 桌面顶栏“多选”按钮进入的多选：一份都没勾也停在多选里，直到 ✕、返回或
  /// 删除。长按 / 修饰键点按进入的多选仍由“有选中项”推出（取消最后一份
  /// 即退出），手机上行为不变。
  bool _selectionPinned = false;

  /// 桌面上 Shift + 点按选范围的起点（最近一次点按、勾选或长按的那份）。
  final DiarySelectionAnchor _anchor = DiarySelectionAnchor();

  bool get _isSelectionMode => _selectionPinned || _selectedIds.isNotEmpty;

  bool get _allSelected =>
      _selectableIds.isNotEmpty && _selectedIds.containsAll(_selectableIds);

  void _open(String draftId) {
    unawaited(
      Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            createDraftId: draftId,
          ),
        ),
      ),
    );
  }

  void _onTap(String draftId) {
    // 桌面：Ctrl / ⌘ + 点按切换勾选、Shift + 点按勾上一段（按列表顺序），
    // 不在多选时即进入多选；不带修饰键时只记下范围起点，照常往下走。
    if (AppPlatform.isDesktop &&
        handleDiaryModifierTap(
          order: _selectableIds,
          diaryId: draftId,
          anchor: _anchor,
          toggle: _setSelected,
        )) {
      return;
    }
    if (_isSelectionMode) {
      _setSelected(draftId, false);
      return;
    }
    _open(draftId);
  }

  void _onLongPress(String draftId) {
    _anchor.id = draftId;
    _setSelected(draftId, false);
  }

  /// 切换 [draftId] 的勾选；[force] 为 true 时只勾上不取消（Shift 选范围）。
  void _setSelected(String draftId, bool force) {
    if (_operating) return;
    setState(() {
      if (force) {
        _selectedIds.add(draftId);
      } else if (!_selectedIds.remove(draftId)) {
        _selectedIds.add(draftId);
      }
    });
  }

  /// 桌面顶栏“多选”：直接进入多选，每行出现勾选框，一份都还没勾。
  void _enterSelection() {
    if (_operating) return;
    setState(() => _selectionPinned = true);
  }

  void _clearSelection() => setState(() {
    _selectedIds.clear();
    _selectionPinned = false;
  });

  /// 全选 / 取消全选。多选态由“有选中项”推出，取消全选即退出多选（从桌面
  /// 顶栏“多选”进入的除外，见 [_selectionPinned]）。
  void _toggleSelectAll() {
    if (_operating) return;
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_selectableIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _operating) return;
    final ids = _selectedIds.toList(growable: false);
    if (!await _confirmDelete(ids.length) || !mounted) return;

    setState(() {
      _operating = true;
      _selectedIds.clear();
      _selectionPinned = false;
      _pendingHideIds.addAll(ids);
    });
    // 先收起再写库：数据流随后移除条目时它已收成 0 高度，列表不会硬跳；
    // 减少动画时时长为 0，立即提交。
    await Future<void>.delayed(
      ExpressiveMotion.duration(context, ExpressiveMotion.medium),
    );
    if (!mounted) return;
    try {
      await _deleteWithUndo(
        ids,
        message: context.l10n.diaryDraftsDeleted(ids.length),
      );
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  Future<void> _deleteBySwipe(String draftId) async {
    setState(() => _sweptAwayIds.add(draftId));
    await _deleteWithUndo([draftId], message: context.l10n.diaryDraftDeleted);
  }

  /// 桌面右键菜单删除单份：与左滑一样不确认、带撤销。没有侧滑组件替它播
  /// 收起，先收起再写库（同批量删除）；不占用 [_operating]，撤销窗口里照样
  /// 可以接着删别的。
  Future<void> _deleteFromMenu(String draftId) async {
    if (_operating || _pendingHideIds.contains(draftId)) return;
    final message = context.l10n.diaryDraftDeleted;
    setState(() => _pendingHideIds.add(draftId));
    await Future<void>.delayed(
      ExpressiveMotion.duration(context, ExpressiveMotion.medium),
    );
    if (!mounted) return;
    await _deleteWithUndo([draftId], message: message);
  }

  /// 删除并给出撤销提示；未撤销时提示条关闭后才回收媒体。
  Future<void> _deleteWithUndo(
    List<String> ids, {
    required String message,
  }) async {
    final l10n = context.l10n;
    final List<DiaryDraftRow> deleted;
    try {
      deleted = await _controller.delete(ids);
    } catch (error) {
      debugPrint('Deleting drafts failed: $error');
      if (!mounted) return;
      // 草稿仍在数据里，取消收起与滑走，让它们重新出现。
      setState(() {
        _pendingHideIds.removeAll(ids);
        _sweptAwayIds.removeAll(ids);
      });
      _showHint(l10n.diaryDraftsDeleteFailed);
      return;
    }
    if (!mounted) {
      _controller.releaseMedia();
      return;
    }
    final undo = await _showUndoSnackBar(message);
    if (!undo) {
      _controller.releaseMedia();
      return;
    }
    try {
      await _controller.restore(deleted);
      if (!mounted) return;
      setState(() {
        _appearingIds.addAll(ids);
        _sweptAwayIds.removeAll(ids);
      });
    } catch (error) {
      debugPrint('Restoring drafts failed: $error');
      // 没写回去：删除已成定局，照常回收媒体。
      _controller.releaseMedia();
      if (mounted) _showHint(l10n.diaryDraftsRestoreFailed);
    }
  }

  Future<bool> _confirmDelete(int count) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.diaryDraftsDeleteTitle),
          content: Text(l10n.diaryDraftsDeleteMessage(count)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<bool> _showUndoSnackBar(String message) async {
    var undoRequested = false;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        duration: _undoSnackDuration,
        persist: false,
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => undoRequested = true,
        ),
      ),
    );
    return undoRequested || reason == SnackBarClosedReason.action;
  }

  void _showHint(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draftsAsync = ref.watch(diaryDraftsProvider);
    // 先按最新数据整理界面状态，顶栏的全选与列表看到的是同一份。
    final drafts = draftsAsync.value;
    final visible = drafts == null
        ? const <DiaryDraftListItem>[]
        : _resolveVisible(drafts);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: AppPageBackground(
        area: AppBackgroundArea.other,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: DiaryDraftsTopBar(
              selectionMode: _isSelectionMode,
              selectedCount: _selectedIds.length,
              allSelected: _allSelected,
              onCancelSelection: _clearSelection,
              onEnterSelection: _selectableIds.isEmpty || _operating
                  ? null
                  : _enterSelection,
              onToggleSelectAll: _operating ? null : _toggleSelectAll,
              // 一份都没勾（桌面从“多选”进入）时停用。
              onDelete: _operating || _selectedIds.isEmpty
                  ? null
                  : _deleteSelected,
            ),
            body: draftsAsync.when(
              loading: () => const DelayedLoadingIndicator(),
              error: (error, _) =>
                  Center(child: Text(l10n.autoT0121(error.toString()))),
              data: (_) => _buildList(visible),
            ),
          ),
        ),
      ),
    );
  }

  /// 数据流确认移除后清理界面状态，返回本次要列出的草稿（不含滑走的），
  /// 并记下可勾选的 id；撤销写回的条目重新出现时不再算作滑走。
  List<DiaryDraftListItem> _resolveVisible(List<DiaryDraftListItem> drafts) {
    final currentIds = <String>{for (final item in drafts) item.draftId};
    _pendingHideIds.removeWhere((id) => !currentIds.contains(id));
    _sweptAwayIds.removeWhere((id) => !currentIds.contains(id));
    _selectedIds.removeWhere((id) => !currentIds.contains(id));
    final visible = drafts
        .where((item) => !_sweptAwayIds.contains(item.draftId))
        .toList(growable: false);
    _selectableIds = <String>[
      for (final item in visible)
        if (!_pendingHideIds.contains(item.draftId)) item.draftId,
    ];
    // 从“多选”进入后草稿都没了（在别处发表、同步删除）：没什么可选，退出。
    if (_selectableIds.isEmpty) _selectionPinned = false;
    return visible;
  }

  Widget _buildList(List<DiaryDraftListItem> visible) {
    final itemDuration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final colorScheme = Theme.of(context).colorScheme;

    // 最后一份移走后与空态交叉淡入。
    return AnimatedSwitcher(
      duration: itemDuration,
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: visible.isEmpty
          ? EmptyHint(
              key: const ValueKey<String>('drafts_empty'),
              icon: FontAwesomeIcons.filePen,
              message: context.l10n.diaryDraftsEmpty,
            )
          : LayoutBuilder(
              key: const ValueKey<String>('drafts_list'),
              builder: (BuildContext context, BoxConstraints constraints) {
                final side = FormWidth.gutter(constraints.maxWidth);
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    side,
                    AppSpacing.s,
                    side,
                    AppSpacing.xxl,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = visible[index];
                    final id = item.draftId;
                    final interactive = !_isSelectionMode && !_operating;
                    final tile = DiaryDraftTile(
                      item: item,
                      selectionMode: _isSelectionMode,
                      selected: _selectedIds.contains(id),
                      onTap: () => _onTap(id),
                      onLongPress: () => _onLongPress(id),
                    );
                    // 桌面用右键菜单代替左滑：鼠标拖动卡片会误删（与日记卡片、
                    // 待办一致）。两种包装都在多选时只停用、结构不变。
                    final Widget row = AppPlatform.isDesktop
                        ? DiaryDraftContextMenu(
                            enabled: interactive,
                            onContinue: () => _open(id),
                            onDelete: () => unawaited(_deleteFromMenu(id)),
                            child: tile,
                          )
                        : DiarySwipeActionItem(
                            diaryId: id,
                            enabled: interactive,
                            icon: FontAwesomeIcons.trashCan,
                            actionColor: colorScheme.errorContainer,
                            actionIconColor: colorScheme.onErrorContainer,
                            borderRadius: AppRadii.input,
                            onSwiped: () => unawaited(_deleteBySwipe(id)),
                            child: tile,
                          );
                    // 间距放在收起容器内（收起时连同间距一起收掉），滑动背景只
                    // 覆盖卡片本身。
                    return ListItemPresence(
                      key: ValueKey<String>('draft_$id'),
                      visible: !_pendingHideIds.contains(id),
                      appearing: _appearingIds.contains(id),
                      duration: itemDuration,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: row,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
