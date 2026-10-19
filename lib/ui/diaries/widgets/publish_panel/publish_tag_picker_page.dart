import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../models/tag_picker_sort.dart';
import '../../providers/tag_picker_sort_provider.dart';
import '../../viewmodels/tag_picker_view.dart';
import 'publish_panel_tile.dart';
import 'publish_tag_list.dart';
import 'publish_tag_search_bar.dart';

/// 面板的标签子页：顶部固定的搜索框 + 排序按钮，下面是“新建”行与全部
/// 标签的勾选列表。
///
/// - 三态：加载中 / 加载失败 / 列表（空时提示先创建）。勾选直接写进草稿。
/// - 检索：按名称或拼音实时筛选（[TagPickerView]）；检索词还没有同名标签
///   时，“新建”行变成“新建「检索词」”，点按以它预填新建弹窗。
/// - 排序：默认排序（标签管理里的顺序）或按字母（分组 + 索引条），选择经
///   [tagPickerSortProvider] 记住；切换时新旧列表交叉淡入。
/// - 检索词只在本页内存里：离开子页（返回、收起面板）后本页销毁，下次
///   打开是完整列表。
class PublishTagPickerPage extends ConsumerStatefulWidget {
  const PublishTagPickerPage({
    super.key,
    required this.draft,
    required this.tags,
    required this.onCreateTag,
  });

  final DiaryMetaDraftController draft;
  final AsyncValue<List<Tag>> tags;

  /// 打开新建标签弹窗；参数为预填的名称（来自检索词），可为 null。
  final ValueChanged<String?> onCreateTag;

  @override
  ConsumerState<PublishTagPickerPage> createState() =>
      _PublishTagPickerPageState();
}

class _PublishTagPickerPageState extends ConsumerState<PublishTagPickerPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'TagPickerSearch');
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _createTag(String? name) {
    // 先收起键盘：弹窗关闭后焦点不会回到搜索框、再把键盘弹出来。
    _searchFocus.unfocus();
    widget.onCreateTag(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sort = ref.watch(tagPickerSortProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: PublishTagSearchBar(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (value) => setState(() => _query = value),
            sort: sort,
            onSortChanged: ref.read(tagPickerSortProvider.notifier).select,
          ),
        ),
        Expanded(
          child: widget.tags.when(
            loading: () => const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: ExpressiveLoadingIndicator(),
                ),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.autoT0165('$error'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            data: (list) {
              final view = TagPickerView.of(list, sort: sort, query: _query);
              // 排序切换时新旧两份列表叠放交叉淡入；各自持有滚动控制器，
              // 互不干扰。
              return AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[...previous, ?current],
                ),
                child: PublishTagList(
                  key: ValueKey<TagPickerSort>(sort),
                  view: view,
                  selection: widget.draft,
                  onToggle: widget.draft.setTagSelected,
                  indexed: sort == TagPickerSort.alphabetical,
                  header: _TagListHeader(
                    view: view,
                    hasTags: list.isNotEmpty,
                    onCreate: () => _createTag(view.createName),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 列表最前的“新建”行与空态提示。
class _TagListHeader extends StatelessWidget {
  const _TagListHeader({
    required this.view,
    required this.hasTags,
    required this.onCreate,
  });

  final TagPickerView view;
  final bool hasTags;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final createName = view.createName;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final String? hint;
    if (view.isSearching && view.isEmpty) {
      hint = l10n.tagPickerSearchEmpty(view.query);
    } else if (!hasTags) {
      hint = l10n.autoT0166;
    } else {
      hint = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 与面板其他行同一表面；检索时带上检索词。
          PublishPanelTile(
            onTap: onCreate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const FaIcon(FontAwesomeIcons.plus, size: 12),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    createName == null
                        ? l10n.autoT0157
                        : l10n.tagPickerCreateNamed(createName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(hint, textAlign: TextAlign.center, style: hintStyle),
            ),
        ],
      ),
    );
  }
}
