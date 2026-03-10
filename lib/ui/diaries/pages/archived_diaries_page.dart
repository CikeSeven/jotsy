import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../core/database/app_database.dart';
import '../sections/diary_head_section.dart';

/// 归档日记页面。
///
/// 支持：
/// - 点击进入编辑页；
/// - 长按进入选择模式；
/// - 批量取消归档与删除；
/// - 列表左滑单条取消归档。
class ArchivedDiariesPage extends ConsumerStatefulWidget {
  const ArchivedDiariesPage({super.key});

  @override
  ConsumerState<ArchivedDiariesPage> createState() => _ArchivedDiariesPageState();
}

class _ArchivedDiariesPageState extends ConsumerState<ArchivedDiariesPage> {
  static const Duration _undoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);

  final Set<String> _selectedDiaryIds = <String>{};

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;

  // 归档页不提供新建入口，传空实现用于复用列表组件。
  void _noopCreate() {}

  Future<void> _showInfoSnackBar(
    String message, {
    Duration duration = _restoreHintDuration,
  }) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  Future<bool> _showUndoSnackBar({
    required String message,
    required Duration duration,
  }) async {
    var undoRequested = false;
    final closedReason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            undoRequested = true;
          },
        ),
      ),
      forceCloseAfter: duration,
    );

    return undoRequested || closedReason == SnackBarClosedReason.action;
  }

  void _clearSelection() {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    setState(_selectedDiaryIds.clear);
  }

  void _toggleSelection(String diaryId, bool forceSelect) {
    setState(() {
      if (forceSelect) {
        _selectedDiaryIds.add(diaryId);
        return;
      }
      if (_selectedDiaryIds.contains(diaryId)) {
        _selectedDiaryIds.remove(diaryId);
      } else {
        _selectedDiaryIds.add(diaryId);
      }
    });
  }

  Future<bool> _showDeleteSelectedConfirmDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: Text('确认删除已选择的 $count 条归档日记吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _unarchiveDiaries(
    List<String> diaryIds, {
    required bool clearSelection,
    required bool showUndoSnack,
  }) async {
    final targetIds =
        diaryIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false);
    if (targetIds.isEmpty) {
      return;
    }

    if (clearSelection) {
      setState(() {
        _selectedDiaryIds.removeAll(targetIds);
      });
    }

    final db = ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!mounted) {
      return;
    }

    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      if (clearSelection) {
        setState(() {
          _selectedDiaryIds.addAll(targetIds);
        });
      }
      await _showInfoSnackBar('取消归档失败，请重试');
      return;
    }

    if (!showUndoSnack) {
      return;
    }

    final undoRequested = await _showUndoSnackBar(
      message: '已取消归档 ${targetIds.length} 条日记',
      duration: _undoSnackDuration,
    );
    if (!mounted || !undoRequested) {
      return;
    }

    for (final diaryId in targetIds) {
      await db.archiveDiary(diaryId, touchUpdatedAt: false);
    }
    if (!mounted) {
      return;
    }
    await _showInfoSnackBar('已恢复归档状态');
  }

  Future<void> _unarchiveSelectedDiaries() async {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    await _unarchiveDiaries(
      _selectedDiaryIds.toList(growable: false),
      clearSelection: true,
      showUndoSnack: true,
    );
  }

  Future<void> _unarchiveDiaryBySwipe(String diaryId) async {
    await _unarchiveDiaries(
      <String>[diaryId],
      clearSelection: false,
      showUndoSnack: true,
    );
  }

  Future<void> _deleteSelectedDiaries() async {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }

    final targetIds = _selectedDiaryIds.toList(growable: false);
    final confirmed = await _showDeleteSelectedConfirmDialog(targetIds.length);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _selectedDiaryIds.clear();
    });

    final db = ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.softDeleteDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!mounted) {
      return;
    }

    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDiaryIds.addAll(targetIds);
      });
      await _showInfoSnackBar('删除失败，请重试');
      return;
    }

    await _showInfoSnackBar('已删除 ${targetIds.length} 条日记');
  }

  @override
  Widget build(BuildContext context) {
    final archivedAsync = ref.watch(archivedDiariesProvider);
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final pageBackgroundColor =
        brightness == Brightness.light ? Colors.white : colorScheme.surface;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _clearSelection();
      },
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        appBar: AppBar(
          title: Text(_isSelectionMode ? '已选择 ${_selectedDiaryIds.length} 项' : '归档日记'),
          leading:
              _isSelectionMode
                  ? IconButton(
                    tooltip: '取消',
                    onPressed: _clearSelection,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                  )
                  : null,
          actions:
              _isSelectionMode
                  ? <Widget>[
                    IconButton(
                      tooltip: '取消归档',
                      onPressed: () => unawaited(_unarchiveSelectedDiaries()),
                      icon: const FaIcon(FontAwesomeIcons.boxOpen, size: 18),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => unawaited(_deleteSelectedDiaries()),
                      icon: FaIcon(
                        FontAwesomeIcons.trashCan,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ]
                  : null,
        ),
        body: archivedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (Object error, StackTrace stackTrace) =>
                  Center(child: Text('归档加载失败: $error')),
          data: (List<DiaryWithTags> diaries) {
            if (diaries.isEmpty) {
              return const Center(child: Text('暂无归档日记'));
            }

            return ColoredBox(
              color: pageBackgroundColor,
              child: CustomScrollView(
                slivers: <Widget>[
                  DiariesListSection(
                    themeBrightness: brightness,
                    diaries: diaries,
                    layoutMode: DiaryLayoutMode.list,
                    selectedDiaryIds: _selectedDiaryIds,
                    isSelectionMode: _isSelectionMode,
                    onCreate: _noopCreate,
                    onOpenEditor: (diaryId) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (BuildContext context) => EditDiaryPage(
                                diaryId: diaryId,
                                entryMode: EditDiaryEntryMode.edit,
                              ),
                        ),
                      );
                    },
                    onToggleSelection: _toggleSelection,
                    onArchiveDiary:
                        (diaryId) => unawaited(_unarchiveDiaryBySwipe(diaryId)),
                    swipeActionIcon: FontAwesomeIcons.boxOpen,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
