import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
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
  const DiarySearchPage({super.key});

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const double _headerContentHeight = 48;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';

  @override
  void initState() {
    super.initState();
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
    final diariesAsync = ref.watch(searchDiariesProvider(_effectiveSearchKeyword));
    final hasKeyword = _effectiveSearchKeyword.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            child: ColoredBox(
              color: pageBackgroundColor,
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(child: SizedBox(height: headerOverlayHeight + 6)),
                  diariesAsync.when(
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
                    data: (diaries) => DiariesListSection(
                      themeBrightness: brightness,
                      diaries: diaries,
                      layoutMode: DiaryLayoutMode.list,
                      selectedDiaryIds: const <String>{},
                      isSelectionMode: false,
                      onCreate: () {},
                      onOpenEditor: _openPreview,
                      onToggleSelection: (_, __) {},
                      isSearchResultEmpty: hasKeyword,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
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
                            onExitSearch: _closePage,
                            onClearSearch: _clearSearchInPlace,
                            onSearchChanged: _onSearchChanged,
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
}

/// 搜索页顶部输入条。
///
/// 保持与主页搜索态同风格：左侧返回、中央输入、右侧按需清空按钮。
class _SearchInputBar extends StatelessWidget {
  const _SearchInputBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.hasSearchText,
    required this.onExitSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool hasSearchText;
  final VoidCallback onExitSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;

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
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: hasSearchText
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

