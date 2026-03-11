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

part '../controllers/archived_diaries_controller.dart';

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
  late final ArchivedDiariesController _controller;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = ArchivedDiariesController(this);
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
        _controller.clearSelection();
      },
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        appBar: AppBar(
          title: Text(_isSelectionMode ? '已选择 ${_selectedDiaryIds.length} 项' : '归档日记'),
          leading:
              _isSelectionMode
                  ? IconButton(
                    tooltip: '取消',
                    onPressed: _controller.clearSelection,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                  )
                  : null,
          actions:
              _isSelectionMode
                  ? <Widget>[
                    IconButton(
                      tooltip: '取消归档',
                      onPressed:
                          () => unawaited(_controller.unarchiveSelectedDiaries()),
                      icon: const FaIcon(FontAwesomeIcons.boxOpen, size: 18),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => unawaited(_controller.deleteSelectedDiaries()),
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
                    onCreate: _controller.noopCreate,
                    onOpenEditor: _controller.openEditor,
                    onToggleSelection: _controller.toggleSelection,
                    onArchiveDiary:
                        (diaryId) =>
                            unawaited(_controller.unarchiveDiaryBySwipe(diaryId)),
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
