import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

import '../../models/tag_picker_sort.dart';
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

  /// 与主题图标按钮的最小尺寸、模板面板的搜索框同高。
  static const double height = 48;

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
          child: _SearchField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        _SortMenuButton(sort: sort, onSortChanged: onSortChanged),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;
    // 聚焦时描边补间到 primary（与主题输入框的聚焦描边同色），提示正在输入。
    return ListenableBuilder(
      listenable: focusNode,
      builder: (BuildContext context, Widget? child) => ExpressiveStateBlend(
        active: focusNode.hasFocus,
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: PublishPanelTile.surfaceColor(colorScheme),
          shape: StadiumBorder(
            side: BorderSide(
              color: Color.lerp(
                PublishPanelTile.outlineColor(colorScheme),
                colorScheme.primary,
                t,
              )!,
              width: 1.5,
            ),
          ),
          child: child,
        ),
        child: child,
      ),
      child: InkWell(
        // 点在放大镜或空白处也进入输入。
        customBorder: const StadiumBorder(),
        onTap: focusNode.requestFocus,
        child: SizedBox(
          height: PublishTagSearchBar.height,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 16),
              FaIcon(
                FontAwesomeIcons.magnifyingGlass,
                size: 14,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 1,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    // 外层已是输入框填充色与描边，不再叠主题的底色与边框
                    // （主题给了聚焦描边，只清 border 仍会画在胶囊里面）。
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: context.l10n.tagPickerSearchHint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: iconColor.withValues(alpha: 0.75),
                    ),
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => focusNode.unfocus(),
                ),
              ),
              // 有字时才出现清空按钮；交叉缩放淡入，不推动输入框宽度以外的布局。
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder:
                    (BuildContext context, TextEditingValue value, Widget? _) =>
                        ExpressiveIconSwap(
                          switchKey: value.text.isNotEmpty,
                          child: value.text.isEmpty
                              ? const SizedBox(width: 12)
                              : IconButton(
                                  tooltip: context.l10n.autoT0130,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    controller.clear();
                                    onChanged('');
                                  },
                                  icon: FaIcon(
                                    FontAwesomeIcons.circleXmark,
                                    size: 16,
                                    color: iconColor,
                                  ),
                                ),
                        ),
              ),
            ],
          ),
        ),
      ),
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
      final selected = value == widget.sort;
      return ExpressiveMenuItem(
        // 当前方式用 primary 文字与行尾对勾标出。
        style: selected
            ? ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
                iconColor: WidgetStatePropertyAll(colorScheme.primary),
              )
            : null,
        leadingIcon: FaIcon(_iconOf(value)),
        trailingIcon: selected
            ? const FaIcon(FontAwesomeIcons.check, size: 14)
            : null,
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
