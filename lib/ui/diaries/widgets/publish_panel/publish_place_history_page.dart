import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import '../../providers/diary_place_history_provider.dart';
import '../../viewmodels/place_history_view.dart';
import 'publish_panel_search_field.dart';
import 'publish_place_row.dart';

/// 面板的“用过的地点”子页：顶部固定的搜索框，下面是用过的地点（最近使用
/// 在前，口径见 `AppDatabase.watchPlaceHistory`）。点一行即选用它
/// （[onSelect]，由面板写进草稿并回到主页）；当前地点所在的一行标为选中。
///
/// 四态：加载中 / 加载失败 / 还没有用过的地点（说明，不显示搜索框）/ 列表
/// （检索没有结果时一行提示）。检索按名称或拼音（[filterPlaces]），检索词只
/// 在本页内存里：子页只在打开时构建，返回或收起面板后清空。
class PublishPlaceHistoryPage extends ConsumerStatefulWidget {
  const PublishPlaceHistoryPage({
    super.key,
    required this.draft,
    required this.enabled,
    required this.onSelect,
  });

  final DiaryMetaDraftController draft;

  /// 正在定位时为 false（见 `PublishPlaceHistoryStrip.enabled`）。
  final bool enabled;
  final ValueChanged<DiaryPlaceUsage> onSelect;

  @override
  ConsumerState<PublishPlaceHistoryPage> createState() =>
      _PublishPlaceHistoryPageState();
}

class _PublishPlaceHistoryPageState
    extends ConsumerState<PublishPlaceHistoryPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'PlaceHistorySearch');
  final ScrollController _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    // 换检索词回到顶部，结果总是从第一条看起。
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(DiaryPlaceUsage place) {
    _searchFocus.unfocus();
    widget.onSelect(place);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ref
        .watch(diaryPlaceHistoryProvider)
        .when(
          loading: () => const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SizedBox(
                height: 20,
                width: 20,
                child: ExpressiveLoadingIndicator(),
              ),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text('$error', style: theme.textTheme.bodySmall),
          ),
          data: (places) {
            if (places.isEmpty) return const _PlaceHistoryEmpty();
            final matches = filterPlaces(places, _query);
            final now = DateTime.now();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: PublishPanelSearchField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: _onQueryChanged,
                    hintText: l10n.placeHistorySearchHint,
                  ),
                ),
                Expanded(
                  child: matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            l10n.placeHistorySearchEmpty(_query.trim()),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      // 只在草稿的地点变化时重建各行的选中态。
                      : ValueListenableSelector<DiaryMetaDraft, String?>(
                          valueListenable: widget.draft,
                          selector: (value) => value.location,
                          builder: (context, current, _) => ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final place = matches[index];
                              return PublishPlaceRow(
                                key: ValueKey<String>(
                                  'place_row_${place.label}',
                                ),
                                place: place,
                                selected: place.label == current,
                                now: now,
                                onTap: widget.enabled
                                    ? () => _select(place)
                                    : null,
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
  }
}

/// 还没有用过的地点：居中的时钟徽章 + 标题 + 一句说明。
class _PlaceHistoryEmpty extends StatelessWidget {
  const _PlaceHistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: FaIcon(
              FontAwesomeIcons.clockRotateLeft,
              size: 22,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.placeHistoryEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.placeHistoryEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
