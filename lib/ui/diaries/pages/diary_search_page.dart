import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../providers/diary_filters.dart';
import '../sections/diaries_list_section.dart';
import '../sections/diary_head_section.dart';
import 'diary_preview_page.dart';

/// 日记搜索页（独立覆盖层）。
///
/// 设计目标：
/// - 点击主页搜索预览后，通过淡入过渡进入该页面；
/// - 页面内部自行维护搜索关键词，不污染主页筛选状态；
/// - 结构固定为“顶部搜索框 + 下方日记列表”。
class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({
    super.key,
    this.initialKeyword = '',
    this.initialTagIds = const <int>{},
  });

  final String initialKeyword;
  final Set<int> initialTagIds;

  /// 构建覆盖式搜索页路由，保持与日记列表入口一致的体感。
  static Route<void> buildRoute({
    String initialKeyword = '',
    Set<int> initialTagIds = const <int>{},
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DiarySearchPage(
          initialKeyword: initialKeyword,
          initialTagIds: initialTagIds,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final easedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInOutCubic,
        );
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(easedAnimation);
        final scaleAnimation = Tween<double>(
          begin: 0.992,
          end: 1,
        ).animate(easedAnimation);
        return FadeTransition(
          opacity: easedAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const double _headerContentHeight = 48;
  static const int _diaryPageSize = 20;
  static const double _loadMoreTriggerExtent = 420;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  Timer? _pagingCooldownTimer;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  late final Set<int> _selectedTagIds;
  int _visibleDiaryLimit = _diaryPageSize;
  int _lastPageableCount = 0;
  bool _isPagingCooldown = false;
  String _pagingSignature = '';

  @override
  void initState() {
    super.initState();
    final normalizedInitialKeyword = widget.initialKeyword.trim();
    _selectedTagIds = <int>{...widget.initialTagIds};
    _searchInput = normalizedInitialKeyword;
    _effectiveSearchKeyword = normalizedInitialKeyword;
    _searchController.text = normalizedInitialKeyword;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _pagingCooldownTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final pageBackgroundColor =
        brightness == Brightness.light ? Colors.white : colorScheme.surface;
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final headerOverlayHeight = topSafeInset + _headerContentHeight;
    final query = SearchDiaryQuery(
      keyword: _effectiveSearchKeyword,
      requiredTagIds: _selectedTagIds,
    );
    _syncPagingStateWithQuery(query);
    if (!query.hasAnyCondition) {
      _lastPageableCount = 0;
    }
    final diariesAsync =
        query.hasAnyCondition ? ref.watch(searchDiariesProvider(query)) : null;
    final tagListAsync = ref.watch(tagListProvider);
    final selectedTags = tagListAsync.maybeWhen(
      data:
          (tags) =>
              tags.where((tag) => _selectedTagIds.contains(tag.id)).toList(growable: false),
      orElse: () {
        final fallbackTagIds = _selectedTagIds.toList(growable: false)..sort();
        return fallbackTagIds
            .map(
              (id) => Tag(
                id: id,
                name: '标签$id',
                color: colorScheme.primary.value,
              ),
            )
            .toList(growable: false);
      },
    );

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            child: ColoredBox(
              color: pageBackgroundColor,
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(child: SizedBox(height: headerOverlayHeight + 6)),
                    if (!query.hasAnyCondition)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox.shrink(),
                      )
                    else
                      diariesAsync!.when(
                        loading: () => const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (error, stackTrace) => SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('日记加载失败: $error')),
                        ),
                        data: (diaries) {
                          final pagedDiaries = diaries.take(_visibleDiaryLimit).toList();
                          _lastPageableCount = diaries.length;
                          final hasMoreDiaries = pagedDiaries.length < diaries.length;
                          return SliverMainAxisGroup(
                            slivers: <Widget>[
                              DiariesListSection(
                                themeBrightness: brightness,
                                diaries: pagedDiaries,
                                layoutMode: DiaryLayoutMode.list,
                                selectedDiaryIds: const <String>{},
                                isSelectionMode: false,
                                onCreate: () {},
                                onOpenEditor: _openPreview,
                                onToggleSelection: (_, __) {},
                                isSearchResultEmpty: true,
                              ),
                              if (hasMoreDiaries || _isPagingCooldown)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Center(
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(boxShadow: AppEffects.softShadow),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 20,
                    sigmaY: 20,
                    tileMode: TileMode.mirror,
                  ),
                  child: Container(
                    width: double.infinity,
                    color: colorScheme.surface.withAlpha(10),
                    child: Column(
                      children: <Widget>[
                        SizedBox(height: topSafeInset),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.l,
                            AppSpacing.xs,
                            AppSpacing.l,
                            0,
                          ),
                          child: _SearchInputBar(
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            hasSearchText: _searchInput.trim().isNotEmpty,
                            selectedTags: selectedTags,
                            onExitSearch: _closePage,
                            onClearSearch: _clearSearchInPlace,
                            onSearchChanged: _onSearchChanged,
                            onRemoveTagCondition: _removeTagCondition,
                          ),
                        ),
                        Container(height: 1, margin: const EdgeInsets.only(top: AppSpacing.xs)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    if (_searchInput != value) {
      setState(() {
        _searchInput = value;
      });
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      final normalized = value.trim();
      if (normalized == _effectiveSearchKeyword) {
        return;
      }
      setState(() {
        _effectiveSearchKeyword = normalized;
      });
    });
  }

  void _clearSearchInPlace() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchInput = '';
      _effectiveSearchKeyword = '';
    });
    _searchFocusNode.requestFocus();
  }

  /// 移除单个标签搜索条件（仅影响搜索页本地状态，不回写主页筛选）。
  void _removeTagCondition(int tagId) {
    if (!_selectedTagIds.contains(tagId)) {
      return;
    }
    setState(() {
      _selectedTagIds.remove(tagId);
      _visibleDiaryLimit = _diaryPageSize;
      _isPagingCooldown = false;
    });
  }

  void _closePage() {
    _searchDebounceTimer?.cancel();
    Navigator.of(context).maybePop();
  }

  void _openPreview(String diaryId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
      ),
    );
  }

  /// 滚动接近底部时追加下一批结果（+20）。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter < _loadMoreTriggerExtent) {
      _requestLoadMoreDiaries();
    }
    return false;
  }

  /// 条件变更时重置分页窗口，避免沿用旧查询的加载进度。
  void _syncPagingStateWithQuery(SearchDiaryQuery query) {
    final signature = '${query.keyword}|${query.requiredTagIds.join(",")}';
    if (_pagingSignature == signature) {
      return;
    }
    _pagingSignature = signature;
    _visibleDiaryLimit = _diaryPageSize;
    _isPagingCooldown = false;
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = null;
  }

  /// 追加一页搜索结果，使用短冷却避免高频滚动瞬间连跳多页。
  void _requestLoadMoreDiaries() {
    if (_isPagingCooldown || _visibleDiaryLimit >= _lastPageableCount) {
      return;
    }
    setState(() {
      _visibleDiaryLimit = math.min(
        _visibleDiaryLimit + _diaryPageSize,
        _lastPageableCount,
      );
      _isPagingCooldown = true;
    });
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPagingCooldown = false;
      });
    });
  }
}

/// 搜索页顶部输入条。
///
/// 保持与主页搜索态同风格：左侧返回、中央输入、右侧按需清空按钮。
class _SearchInputBar extends StatelessWidget {
  const _SearchInputBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.hasSearchText,
    required this.selectedTags,
    required this.onExitSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
    required this.onRemoveTagCondition,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool hasSearchText;
  final List<Tag> selectedTags;
  final VoidCallback onExitSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onRemoveTagCondition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        boxShadow: AppEffects.softShadow,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.nav),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.nav),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 17,
                  sigmaY: 17,
                  tileMode: TileMode.mirror,
                ),
                child: Container(
                  color: colorScheme.primary.withAlpha(20),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: '取消搜索',
                        splashRadius: 18,
                        onPressed: onExitSearch,
                        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                      ),
                      Expanded(
                        child:
                            selectedTags.isEmpty
                                ? TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  onChanged: onSearchChanged,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: '搜索标题或内容',
                                    border: InputBorder.none,
                                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: <Widget>[
                                      for (final tag in selectedTags) ...[
                                        _TagConditionChip(
                                          tag: tag,
                                          onRemove: () => onRemoveTagCondition(tag.id),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      SizedBox(
                                        width: 220,
                                        child: Focus(
                                          onKeyEvent: (node, event) {
                                            final isBackspace =
                                                event is KeyDownEvent &&
                                                event.logicalKey == LogicalKeyboardKey.backspace;
                                            final isInputEmpty = searchController.text.trim().isEmpty;
                                            if (isBackspace && isInputEmpty && selectedTags.isNotEmpty) {
                                              onRemoveTagCondition(selectedTags.last.id);
                                              return KeyEventResult.handled;
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                          child: TextField(
                                            controller: searchController,
                                            focusNode: searchFocusNode,
                                            autofocus: true,
                                            textInputAction: TextInputAction.search,
                                            onChanged: onSearchChanged,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              hintText: '搜索标题或内容',
                                              border: InputBorder.none,
                                              hintStyle: Theme.of(context).textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child:
                            hasSearchText
                                ? IconButton(
                                  key: const ValueKey<String>('search_clear_button'),
                                  tooltip: '清空',
                                  splashRadius: 18,
                                  onPressed: onClearSearch,
                                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                                )
                                : const SizedBox(
                                  key: ValueKey<String>('search_clear_placeholder'),
                                  width: 40,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索页标签条件 chip：彩色 `#` + 标签名 + 移除按钮。
class _TagConditionChip extends StatelessWidget {
  const _TagConditionChip({
    required this.tag,
    required this.onRemove,
  });

  final Tag tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = Color(tag.color);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tagColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            tag.name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          InkResponse(
            onTap: onRemove,
            radius: 12,
            child: FaIcon(
              FontAwesomeIcons.xmark,
              size: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
