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
import '../../../core/services/settings_service.dart';
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
  final GlobalKey _fabKey = GlobalKey();
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
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;
  bool get _showTopSearchField => _isSearchMode && !_isSearchAnimating;
  bool get _showHeaderSection => !_isSearchMode && !_isSearchAnimating;

  void _clearSelection() {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    setState(_selectedDiaryIds.clear);
  }

  // 打开编辑页，并根据来源位置执行展开动画。
  void _openEditor({
    String? diaryId,
    Rect? sourceGlobalRect,
    bool fromFab = false,
  }) {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final beginRect =
        sourceGlobalRect ?? (fromFab ? _globalRectOf(_fabKey) : null);

    unawaited(
      Navigator.of(context)
          .push(
            _buildEditRoute(
              diaryId: diaryId,
              sourceGlobalRect: beginRect,
              fromFab: fromFab,
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

  Route<void> _buildEditRoute({
    required String? diaryId,
    required Rect? sourceGlobalRect,
    required bool fromFab,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder:
          (BuildContext context, Animation<double> animation, _) =>
              EditDiaryPage(diaryId: diaryId),
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.34, 1.56, 0.64, 1.0),
          reverseCurve: Curves.easeInCubic,
        );
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final endRect = Offset.zero & constraints.biggest;
            final beginRect = _resolveBeginRect(
              sourceGlobalRect,
              endRect,
              fromFab: fromFab,
            );
            final revealRectAnimation = RectTween(
              begin: beginRect,
              end: endRect,
            ).animate(curved);
            final radiusAnimation = Tween<double>(
              begin: fromFab ? 24 : 12,
              end: 0,
            ).animate(curved);
            final scrimAnimation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(curved);

            return AnimatedBuilder(
              animation: curved,
              builder: (BuildContext context, Widget? _) {
                final currentRect = revealRectAnimation.value ?? endRect;
                final currentRadius = radiusAnimation.value ?? 0;
                final scrimAlpha =
                    (0.05 * (scrimAnimation.value ?? 1))
                        .clamp(0.0, 1.0)
                        .toDouble();

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: scrimAlpha),
                    ),
                    ClipPath(
                      clipper: _RectRevealClipper(
                        rect: currentRect,
                        radius: currentRadius,
                      ),
                      child: child,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Rect? _globalRectOf(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Rect _resolveBeginRect(Rect? rawRect, Rect endRect, {required bool fromFab}) {
    if (rawRect == null || rawRect.width <= 1 || rawRect.height <= 1) {
      final fallbackSize = fromFab ? const Size(56, 56) : const Size(220, 96);
      final fallbackCenter =
          fromFab
              ? Offset(endRect.right - 36, endRect.bottom - 36)
              : endRect.center;
      return Rect.fromCenter(
        center: fallbackCenter,
        width: fallbackSize.width,
        height: fallbackSize.height,
      );
    }

    final left = rawRect.left.clamp(0.0, endRect.right).toDouble();
    final top = rawRect.top.clamp(0.0, endRect.bottom).toDouble();
    final right = rawRect.right.clamp(0.0, endRect.right).toDouble();
    final bottom = rawRect.bottom.clamp(0.0, endRect.bottom).toDouble();
    if (right - left <= 1 || bottom - top <= 1) {
      return Rect.fromCenter(
        center: rawRect.center,
        width: fromFab ? 56 : 220,
        height: fromFab ? 56 : 96,
      );
    }
    return Rect.fromLTRB(left, top, right, bottom);
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

  void _onMenuSelected(DiaryMenuAction action) {
    setState(() {
      switch (action) {
        case DiaryMenuAction.sortUpdatedDesc:
          _sortMode = DiarySortMode.updatedDesc;
          break;
        case DiaryMenuAction.sortUpdatedAsc:
          _sortMode = DiarySortMode.updatedAsc;
          break;
        case DiaryMenuAction.sortTitleAsc:
          _sortMode = DiarySortMode.titleAsc;
          break;
        case DiaryMenuAction.layoutList:
          _layoutMode = DiaryLayoutMode.list;
          break;
        case DiaryMenuAction.layoutWaterfall:
          _layoutMode = DiaryLayoutMode.waterfall;
          break;
      }
    });
    _persistViewPreferences();
  }

  void _persistViewPreferences() {
    final settingsService = ref.read(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      return;
    }
    unawaited(settingsService.setDiarySortModeRaw(_sortMode.name));
    unawaited(settingsService.setDiaryLayoutModeRaw(_layoutMode.name));
  }

  void _loadViewPreferencesIfNeeded(SettingsService settingsService) {
    if (_viewPreferencesLoaded) {
      return;
    }
    _sortMode = _sortModeFromRaw(settingsService.diarySortModeRaw);
    _layoutMode = _layoutModeFromRaw(settingsService.diaryLayoutModeRaw);
    _viewPreferencesLoaded = true;
  }

  DiarySortMode _sortModeFromRaw(String raw) {
    switch (raw) {
      case 'updatedAsc':
        return DiarySortMode.updatedAsc;
      case 'titleAsc':
        return DiarySortMode.titleAsc;
      case 'updatedDesc':
      default:
        return DiarySortMode.updatedDesc;
    }
  }

  DiaryLayoutMode _layoutModeFromRaw(String raw) {
    switch (raw) {
      case 'waterfall':
        return DiaryLayoutMode.waterfall;
      case 'list':
      default:
        return DiaryLayoutMode.list;
    }
  }

  void _sortDiaries(List<DiaryWithTags> items) {
    switch (_sortMode) {
      case DiarySortMode.updatedDesc:
        items.sort((a, b) => b.diary.updatedAt.compareTo(a.diary.updatedAt));
        break;
      case DiarySortMode.updatedAsc:
        items.sort((a, b) => a.diary.updatedAt.compareTo(b.diary.updatedAt));
        break;
      case DiarySortMode.titleAsc:
        items.sort(
          (a, b) => a.diary.title.toLowerCase().compareTo(
            b.diary.title.toLowerCase(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 标签与日记列表分别独立监听，避免相互阻塞。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final diariesAsync = ref.watch(filteredDiariesProvider);

    final fabBottomOffset = 80 + MediaQuery.paddingOf(context).bottom;
    final listBottomOffset = 112 + MediaQuery.paddingOf(context).bottom;

    return settingsAsync.when(
      loading:
          () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) =>
              Scaffold(body: Center(child: Text('设置加载失败: $error'))),
      data: (settingsService) {
        _loadViewPreferencesIfNeeded(settingsService);
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              PopScope(
                canPop: !_isSelectionMode,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  if (_isSelectionMode) {
                    _clearSelection();
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
                              onArchiveSelected: () {},
                              onDeleteSelected: () {},
                              onOpenArchived: () {},
                              sortMode: _sortMode,
                              layoutMode: _layoutMode,
                              onMenuSelected: _onMenuSelected,
                              searchFieldKey: _topSearchFieldKey,
                              searchPreviewText: _searchInput,
                              searchEnabled: true,
                            ),
                          ),
                        ),
                        // 带阴影的细分割线
                        Container(
                          height: 1.0, // 分割线本身的高度
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).dividerColor.withAlpha(100), // 分割线的颜色
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20), // 阴影颜色，保持低透明度
                                offset: const Offset(0, 4), // 阴影向下偏移 4px
                                blurRadius: 8, // 模糊半径，让阴影更柔和扩散
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
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
                                _sortDiaries(visibleItems);

                                return DiariesListSection(
                                  key: ValueKey<String>(
                                    'diaries_list_${brightness.name}',
                                  ),
                                  themeBrightness: brightness,
                                  tags: tags,
                                  diaries: visibleItems,
                                  layoutMode: _layoutMode,
                                  isSelectionMode: _isSelectionMode,
                                  selectedDiaryIds: _selectedDiaryIds,
                                  listBottomOffset: listBottomOffset,
                                  onCreate: () => _openEditor(fromFab: true),
                                  onOpenEditor: (diaryId, sourceGlobalRect) {
                                    _openEditor(
                                      diaryId: diaryId,
                                      sourceGlobalRect: sourceGlobalRect,
                                      fromFab: false,
                                    );
                                  },
                                  onToggleSelection:
                                      (noteId, forceSelect) => _toggleSelection(
                                        noteId,
                                        forceSelect: forceSelect,
                                      ),
                                );
                              },
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              error:
                                  (Object error, StackTrace stackTrace) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text('标签加载失败: $error'),
                                  ),
                            );
                          },
                          loading:
                              () =>
                                  const Center(child: CircularProgressIndicator()),
                          error:
                              (Object error, StackTrace stackTrace) =>
                                  Center(child: Text('日记加载失败: $error')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isSelectionMode)
                Positioned(
                  right: AppSpacing.xl,
                  bottom: fabBottomOffset,
                  child: FloatingActionButton(
                    key: _fabKey,
                    onPressed: () => _openEditor(fromFab: true),
                    child: FaIcon(FontAwesomeIcons.plus),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RectRevealClipper extends CustomClipper<Path> {
  const _RectRevealClipper({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  Path getClip(Size size) {
    final clippedRect = Rect.fromLTRB(
      rect.left.clamp(0.0, size.width).toDouble(),
      rect.top.clamp(0.0, size.height).toDouble(),
      rect.right.clamp(0.0, size.width).toDouble(),
      rect.bottom.clamp(0.0, size.height).toDouble(),
    );
    if (clippedRect.width <= 0 || clippedRect.height <= 0) {
      return Path();
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        clippedRect,
        Radius.circular(radius.clamp(0.0, 32.0).toDouble()),
      ),
    );
  }

  @override
  bool shouldReclip(covariant _RectRevealClipper oldClipper) {
    return rect != oldClipper.rect || radius != oldClipper.radius;
  }
}

