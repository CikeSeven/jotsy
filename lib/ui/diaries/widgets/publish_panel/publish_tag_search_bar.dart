import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

import '../../models/tag_picker_sort.dart';
import 'publish_panel_search_field.dart';
import 'publish_panel_tile.dart';

/// 标签子页顶部一行：胶囊形搜索框 + 右侧圆形排序按钮（同高、同底色）。
///
/// 搜索框的文字与焦点由子页持有（[controller] / [focusNode]），结果随输入
/// 实时筛选，回车只收起键盘；不自动聚焦，打开子页不弹键盘。排序按钮弹出
/// 锚定菜单（默认排序 / 按字母排序），按字母时按钮底色补间到
/// `secondaryContainer`、图标换成 A–Z，一眼可见不是默认顺序。
class PublishTagSearchBar extends StatelessWidget {
  const PublishTagSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.sort,
    required this.onSortChanged,
  });

  /// 排序按钮与搜索框同高。
  static const double height = PublishPanelSearchField.height;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final TagPickerSort sort;
  final ValueChanged<TagPickerSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: PublishPanelSearchField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            hintText: context.l10n.tagPickerSearchHint,
          ),
        ),
        const SizedBox(width: 8),
        _SortMenuButton(sort: sort, onSortChanged: onSortChanged),
      ],
    );
  }
}

class _SortMenuButton extends StatefulWidget {
  const _SortMenuButton({required this.sort, required this.onSortChanged});

  final TagPickerSort sort;
  final ValueChanged<TagPickerSort> onSortChanged;

  @override
  State<_SortMenuButton> createState() => _SortMenuButtonState();
}

class _SortMenuButtonState extends State<_SortMenuButton> {
  final FocusNode _focus = FocusNode(debugLabel: 'TagPickerSortButton');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  static FaIconData _iconOf(TagPickerSort sort) => switch (sort) {
    TagPickerSort.custom => FontAwesomeIcons.arrowDownWideShort,
    TagPickerSort.alphabetical => FontAwesomeIcons.arrowDownAZ,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    Widget item(TagPickerSort value, String label) {
      return ExpressiveMenuItem(
        // 当前方式用菜单项的选中态（主色容器底 + 行尾对勾）标出。
        selected: value == widget.sort,
        leadingIcon: FaIcon(_iconOf(value)),
        onPressed: () => widget.onSortChanged(value),
        child: Text(label),
      );
    }

    final label = switch (widget.sort) {
      TagPickerSort.custom => l10n.tagPickerSortCustom,
      TagPickerSort.alphabetical => l10n.tagPickerSortAlphabetical,
    };
    return ExpressiveMenuAnchor(
      childFocusNode: _focus,
      menuChildren: <Widget>[
        item(TagPickerSort.custom, l10n.tagPickerSortCustom),
        item(TagPickerSort.alphabetical, l10n.tagPickerSortAlphabetical),
      ],
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? _) =>
              ExpressiveStateBlend(
                active: widget.sort != TagPickerSort.custom,
                builder: (BuildContext context, double t, Widget? _) =>
                    // 合并进按钮自己的语义节点：读屏读到“排序方式，按字母
                    // 排序，按钮，已展开”。
                    MergeSemantics(
                      child: Semantics(
                        expanded: menu.isExpanded,
                        value: label,
                        child: IconButton(
                          focusNode: _focus,
                          tooltip: l10n.tagPickerSortTooltip,
                          onPressed: menu.toggle,
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(
                              PublishTagSearchBar.height,
                            ),
                            backgroundColor: Color.lerp(
                              // 与搜索框同底色（玻璃时同为半透明）。
                              AppGlassField.of(context)?.fill ??
                                  PublishPanelTile.surfaceColor(colorScheme),
                              colorScheme.secondaryContainer,
                              t,
                            ),
                            foregroundColor: Color.lerp(
                              colorScheme.onSurfaceVariant,
                              colorScheme.onSecondaryContainer,
                              t,
                            ),
                          ),
                          icon: ExpressiveIconSwap(
                            switchKey: widget.sort,
                            child: FaIcon(_iconOf(widget.sort), size: 15),
                          ),
                        ),
                      ),
                    ),
              ),
    );
  }
}
