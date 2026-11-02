import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import '../../models/tag_picker_sort.dart';
import '../../providers/tag_picker_sort_provider.dart';
import '../../viewmodels/tag_picker_view.dart';
import 'publish_tag_list.dart';
import 'publish_tag_row.dart';
import 'publish_tag_search_bar.dart';

/// 面板的标签子页：顶部固定的搜索框 + 排序按钮，下面是“新建”行与全部
/// 标签的勾选列表（[PublishTagPickerPane]），勾选直接写进草稿。
class PublishTagPickerPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return PublishTagPickerPane(
      tags: tags,
      onCreateTag: onCreateTag,
      // 只在草稿的标签变化时重建各行（草稿其他字段的变化不牵动标签行）。
      rowsScope: (context, buildRows) =>
          ValueListenableSelector<DiaryMetaDraft, Set<int>>(
            valueListenable: draft,
            selector: (value) => value.tagIds,
            builder: (context, _, _) => buildRows(context),
          ),
      rowBuilder: (context, tag) => PublishTagRow(
        tag: tag,
        selected: draft.value.tagIds.contains(tag.id),
        onToggle: (selected) => draft.setTagSelected(tag.id, selected),
      ),
    );
  }
}

/// 标签挑选区：顶部固定的搜索框 + 排序按钮，下面是“新建”行与全部标签的
/// 列表。发布面板的标签子页与多选日记的标签面板共用，行的样子与选中状态
/// 由调用方经 [rowBuilder] / [rowsScope] 给出（见 [PublishTagList]）。
///
/// - 三态：加载中 / 加载失败 / 列表（空时提示先创建）。
/// - 检索：按名称或拼音实时筛选（[TagPickerView]）；检索词还没有同名标签
///   时，“新建”行变成“新建「检索词」”，点按以它预填新建弹窗。
/// - 排序：默认排序（标签管理里的顺序）或按字母（分组 + 索引条），选择经
///   [tagPickerSortProvider] 记住；切换时新旧列表交叉淡入。
/// - 检索词只在本组件内存里：离开（返回、收起面板）后销毁，下次打开是
///   完整列表。
///
/// 高度取父级给的约束（列表在其中滚动），父级须给出有界高度。
class PublishTagPickerPane extends ConsumerStatefulWidget {
  const PublishTagPickerPane({
    super.key,
    required this.tags,
    required this.rowBuilder,
    required this.onCreateTag,
    this.rowsScope,
    this.searchPadding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  final AsyncValue<List<Tag>> tags;

  /// 见 [PublishTagList.rowBuilder]。
  final Widget Function(BuildContext context, Tag tag) rowBuilder;

  /// 见 [PublishTagList.rowsScope]。
  final Widget Function(BuildContext context, WidgetBuilder buildRows)?
  rowsScope;

  /// 打开新建标签弹窗；参数为预填的名称（来自检索词），可为 null。
  final ValueChanged<String?> onCreateTag;

  /// 搜索框一行的外边距（发布面板子页顶部没有标题，多留 12）。
  final EdgeInsetsGeometry searchPadding;

  @override
  ConsumerState<PublishTagPickerPane> createState() =>
      _PublishTagPickerPaneState();
}

class _PublishTagPickerPaneState extends ConsumerState<PublishTagPickerPane> {
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
          padding: widget.searchPadding,
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
                  rowsScope: widget.rowsScope,
                  rowBuilder: widget.rowBuilder,
                  indexed: sort == TagPickerSort.alphabetical,
                  header: PublishTagListHeader(
                    view: view,
                    hasTags: list.isNotEmpty,
                    onCreate: _createTag,
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
