import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

import '../../../app/theme/app_spacing.dart';
import '../sections/diaries_list_section.dart';

/// 日记列表页。
///
/// 提供关键词搜索、标签筛选、列表展示与进入编辑页能力。

class DiariesPage extends ConsumerStatefulWidget {
  const DiariesPage({super.key});

  @override
  ConsumerState<DiariesPage> createState() => _DiariesPage();
  
}
class _DiariesPage extends ConsumerState<DiariesPage>
    with SingleTickerProviderStateMixin {

  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration _searchMorphDuration = Duration(milliseconds: 280);

  final Set<String> _selectedDiaryIds = <String>{};
  final Set<String> _optimisticHiddenDiaryIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _listSearchFieldKey = GlobalKey();
  final GlobalKey _topSearchFieldKey = GlobalKey();
  Timer? _searchDebounceTimer;
  OverlayEntry? _searchMorphOverlay;
  Rect? _cachedListSearchRect;
  late final AnimationController _searchMorphController;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  bool _isSearchMode = false;
  bool _isSearchAnimating = false;
  bool _isSearchMorphEntering = false;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;
  bool get _showTopSearchField => _isSearchMode && !_isSearchAnimating;
  bool get _showHeaderSection => !_isSearchMode && !_isSearchAnimating;


  void _clearSelection() {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    setState(_selectedDiaryIds.clear);
  }


  //打开一个新的日记
  void _openEditor([String? diaryId]) {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => EditDiaryPage(
                diaryId: diaryId,
              ),
            ),
          )
          .then((_) {
            if (!mounted) {
              return;
            }
            _searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }),
    );
  }

  
  void _toggleSelection(String noteId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect && _isSearchMode) {
        _isSearchMode = false;
        _isSearchAnimating = false;
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
      if (forceSelect) {
        _selectedDiaryIds.add(noteId);
        return;
      }
      if (_selectedDiaryIds.contains(noteId)) {
        _selectedDiaryIds.remove(noteId);
      } else {
        _selectedDiaryIds.add(noteId);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    // 标签与日记列表分别独立监听，避免相互阻塞。
    final tagsAsync = ref.watch(tagListProvider);
    final diariesAsync = ref.watch(filteredDiariesProvider);
    final selectedTagIds = ref.watch(diaryFilterProvider).selectedTagIds;

    final fabBottomOffset = 84 + MediaQuery.paddingOf(context).bottom;
    final listBottomOffset = 112 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                return KeyEventResult.ignored;
              },
              child: SafeArea(
                child: Column(
                  children: <Widget>[

                    // 顶部标题栏
                    AnimatedOpacity(
                      duration: _searchMorphDuration,
                      curve: Curves.easeOutCubic,
                      opacity: _showHeaderSection ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_showHeaderSection,
                        child: DiaryHeadSection(
                          isSelectionMode: _isSelectionMode,
                          selectedCount: _selectedDiaryIds.length,
                          onCancelSelection: _clearSelection,
                          onArchiveSelected: (){},
                          onDeleteSelected: (){}, 
                          onOpenArchived: (){}
                        )
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    // 主列表区域
                    tagsAsync.when(
                      data: (tags) {
                        return diariesAsync.when(
                          data: (items) {
                            final visibleItems =
                                items.where((DiaryWithTags item) {
                                  return !_optimisticHiddenDiaryIds.contains(
                                    item.diary.diaryId,
                                  );
                                }).toList();

                            return DiariesListSection(
                              tags: tags,
                              searchFieldKey: _listSearchFieldKey,
                              searchPreviewText: _searchInput,
                              animateSearchRow: true,
                              searchEnabled: true,
                              diaries: visibleItems,
                              isSelectionMode: _isSelectionMode,
                              selectedDiaryIds: _selectedDiaryIds,
                              listBottomOffset: listBottomOffset,
                              onCreate: _openEditor,
                              onOpenEditor: _openEditor,
                              onToggleSelection:
                                (noteId, forceSelect) =>
                                  _toggleSelection(
                                    noteId,
                                    forceSelect: forceSelect,
                                  ),
                              onArchiveBySwipe: (note) async {
                                final diaryId = note.diary.diaryId;
                                setState(() {
                                  _optimisticHiddenDiaryIds.add(diaryId);
                                  _selectedDiaryIds.remove(diaryId);
                                });
                                try {
                                  await ref
                                      .read(appDatabaseProvider)
                                      .archiveDiary(diaryId);
                                } catch (_) {
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _optimisticHiddenDiaryIds.remove(diaryId);
                                  });
                                }
                              },
                            );
                          },
                             loading:
                              () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                          error:
                              (Object error, StackTrace stackTrace) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('标签加载失败: $error'),
                              ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error:
                          (Object error, StackTrace stackTrace) =>
                              Center(child: Text('日记加载失败: $error')),
                    )
                  ],
                ),
              ),
            ),
          ),
          if (!_isSelectionMode)
            Positioned(
              right: AppSpacing.l,
              bottom: fabBottomOffset,
              child: FloatingActionButton(
                onPressed: _openEditor,
                child: FaIcon(FontAwesomeIcons.plus),
              ),
            ),
        ]
      ),
    );
  }
}

/// 统一时间展示格式。
String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd $hh:$min';
}
