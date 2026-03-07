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

      
  final Set<String> _selectedDiariesIds = <String>{};

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
                            return DiariesListSection(
                              tags: tags,
                              searchFieldKey: _listSearchFieldKey,
                              searchPreviewText: _searchInput,
                              animateSearchRow: true,
                              searchEnabled: true,
                              diaries: items,
                              isSelectionMode: _isSelectionMode,
                              selectedDiaryIds: _selectedDiariesIds,
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
                    
                    // tagsAsync.when(
                    //   data: (List<Tag> tags) {
                    //     if (tags.isEmpty) {
                    //       return const SizedBox.shrink();
                    //     }
                    //     return SizedBox(
                    //       height: 46,
                    //       child: ListView(
                    //         scrollDirection: Axis.horizontal,
                    //         padding: const EdgeInsets.symmetric(horizontal: 12),
                    //         children:
                    //             tags.map((Tag tag) {
                    //               final selected = selectedTagIds.contains(tag.id);
                    //               return Padding(
                    //                 padding: const EdgeInsets.symmetric(horizontal: 4),
                    //                 child: FilterChip(
                    //                   selected: selected,
                    //                   avatar: CircleAvatar(
                    //                     radius: 8,
                    //                     backgroundColor: Color(tag.color),
                    //                   ),
                    //                   label: Text(tag.name),
                    //                   onSelected: (bool value) {
                    //                     // 标签筛选采用可叠加的 AND 语义。
                    //                     ref
                    //                         .read(diaryFilterProvider.notifier)
                    //                         .toggleTag(tag.id, value);
                    //                   },
                    //                 ),
                    //               );
                    //             }).toList(),
                    //       ),
                    //     );
                    //   },
                    //   loading:
                    //       () => const Padding(
                    //         padding: EdgeInsets.symmetric(vertical: 8),
                    //         child: SizedBox(
                    //           height: 22,
                    //           width: 22,
                    //           child: CircularProgressIndicator(strokeWidth: 2),
                    //         ),
                    //       ),
                    //   error:
                    //       (Object error, StackTrace stackTrace) => Padding(
                    //         padding: const EdgeInsets.only(bottom: 8),
                    //         child: Text('标签加载失败: $error'),
                    //       ),
                    // ),
                    // Expanded(
                    //   child: diariesAsync.when(
                    //     data: (List<DiaryWithTags> items) {
                    //       if (items.isEmpty) {
                    //         return const Center(child: Text('暂无日记'));
                    //       }
                
                    //       return ListView.separated(
                    //         itemCount: items.length,
                    //         separatorBuilder: (_, __) => const Divider(height: 1),
                    //         itemBuilder: (BuildContext context, int index) {
                    //           final item = items[index];
                    //           final title =
                    //               item.diary.title.trim().isEmpty
                    //                   ? '未命名日记'
                    //                   : item.diary.title;
                    //           final preview = item.diary.contentText.replaceAll('\n', ' ');
                    //           final updatedAt = _formatDateTime(item.diary.updatedAt);
                
                    //           return ListTile(
                    //             title: Text(
                    //               title,
                    //               maxLines: 1,
                    //               overflow: TextOverflow.ellipsis,
                    //             ),
                    //             subtitle: Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: <Widget>[
                    //                 Text(
                    //                   preview,
                    //                   maxLines: 2,
                    //                   overflow: TextOverflow.ellipsis,
                    //                 ),
                    //                 const SizedBox(height: 4),
                    //                 Text(
                    //                   updatedAt,
                    //                   style: Theme.of(context).textTheme.bodySmall,
                    //                 ),
                    //                 if (item.tags.isNotEmpty) ...<Widget>[
                    //                   const SizedBox(height: 4),
                    //                   Wrap(
                    //                     spacing: 6,
                    //                     runSpacing: -8,
                    //                     children:
                    //                         item.tags.map((Tag tag) {
                    //                           return Chip(
                    //                             avatar: CircleAvatar(
                    //                               radius: 7,
                    //                               backgroundColor: Color(tag.color),
                    //                             ),
                    //                             label: Text(tag.name),
                    //                           );
                    //                         }).toList(),
                    //                   ),
                    //                 ],
                    //               ],
                    //             ),
                    //             onTap: () async {
                    //               // 点击条目进入编辑页，返回后列表会自动流式刷新。
                    //               await Navigator.of(context).push(
                    //                 MaterialPageRoute<void>(
                    //                   builder: (_) => EditDiaryPage(
                    //                     diaryId: item.diary.diaryId,
                    //                   ),
                    //                 ),
                    //               );
                    //             },
                    //           );
                    //         },
                    //       );
                    //     },
                    //     loading: () => const Center(child: CircularProgressIndicator()),
                    //     error:
                    //         (Object error, StackTrace stackTrace) =>
                    //             Center(child: Text('日记加载失败: $error')),
                    //   ),
                    // ),
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
