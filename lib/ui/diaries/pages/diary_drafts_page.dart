import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/diary_drafts_controller.dart';
import '../providers/diary_draft_providers.dart';
import '../viewmodels/diary_draft_list_item.dart';
import '../widgets/diary_draft_tile.dart';
import '../widgets/diary_swipe_action_item.dart';
import 'edit_diary_page.dart';

/// 草稿箱：还没发布的新建日记，最近编辑的在前。
///
/// - 点按续写（打开新建模式的编辑页，发布后这一份自动删除）；
/// - 左滑删除单份，长按进入多选、批量删除（先确认）；两种删除都带撤销；
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

  /// 左滑删掉的条目：Dismissible 已播完离场，必须在同一帧移出列表。
  final Set<String> _sweptAwayIds = <String>{};

  /// 撤销后重新出现的条目，从 0 展开而不是直接冒出。
  final Set<String> _appearingIds = <String>{};

  bool _operating = false;

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
    if (_isSelectionMode) {
      _toggleSelection(draftId);
      return;
    }
    _open(draftId);
  }

  void _toggleSelection(String draftId) {
    if (_operating) return;
    setState(() {
      if (!_selectedIds.remove(draftId)) _selectedIds.add(draftId);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _deleteSelected() async {
    if (!_isSelectionMode || _operating) return;
    final ids = _selectedIds.toList(growable: false);
    if (!await _confirmDelete(ids.length) || !mounted) return;

    setState(() {
      _operating = true;
      _selectedIds.clear();
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
    final confirmed = await showDialog<bool>(
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

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: AppTopBar(
          leading: _isSelectionMode
              ? IconButton(
                  tooltip: l10n.commonCancel,
                  onPressed: _clearSelection,
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                )
              : IconButton(
                  tooltip: l10n.commonBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                ),
          // 进入/退出多选、选择数量变化时标题淡入淡出，而不是硬切。
          title: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: Text(
              _isSelectionMode
                  ? l10n.autoT0099(_selectedIds.length.toString())
                  : l10n.diaryDraftsTitle,
              key: ValueKey<int>(_isSelectionMode ? _selectedIds.length : -1),
            ),
          ),
          actions: <Widget>[
            if (_isSelectionMode)
              IconButton(
                tooltip: l10n.commonDelete,
                onPressed: _operating ? null : _deleteSelected,
                icon: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        body: draftsAsync.when(
          loading: () => const DelayedLoadingIndicator(),
          error: (error, _) =>
              Center(child: Text(l10n.autoT0121(error.toString()))),
          data: _buildList,
        ),
      ),
    );
  }

  Widget _buildList(List<DiaryDraftListItem> drafts) {
    final currentIds = <String>{for (final item in drafts) item.draftId};
    // 数据流确认移除后清理界面状态；撤销写回的条目重新出现时不再算作滑走。
    _pendingHideIds.removeWhere((id) => !currentIds.contains(id));
    _sweptAwayIds.removeWhere((id) => !currentIds.contains(id));
    _selectedIds.removeWhere((id) => !currentIds.contains(id));
    final visible = drafts
        .where((item) => !_sweptAwayIds.contains(item.draftId))
        .toList(growable: false);
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
          : ListView.builder(
              key: const ValueKey<String>('drafts_list'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int index) {
                final item = visible[index];
                final id = item.draftId;
                // 间距放在收起容器内（收起时连同间距一起收掉），滑动背景只
                // 覆盖卡片本身。
                return ListItemPresence(
                  key: ValueKey<String>('draft_$id'),
                  visible: !_pendingHideIds.contains(id),
                  appearing: _appearingIds.contains(id),
                  duration: itemDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    child: DiarySwipeActionItem(
                      diaryId: id,
                      enabled: !_isSelectionMode && !_operating,
                      icon: FontAwesomeIcons.trashCan,
                      actionColor: colorScheme.errorContainer,
                      actionIconColor: colorScheme.onErrorContainer,
                      borderRadius: AppRadii.input,
                      onSwiped: () => unawaited(_deleteBySwipe(id)),
                      child: DiaryDraftTile(
                        item: item,
                        selectionMode: _isSelectionMode,
                        selected: _selectedIds.contains(id),
                        onTap: () => _onTap(id),
                        onLongPress: () => _toggleSelection(id),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
