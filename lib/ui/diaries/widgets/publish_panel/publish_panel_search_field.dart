import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import 'publish_panel_tile.dart';

/// 面板子页顶部的胶囊形搜索框（标签子页、用过的地点子页共用，DESIGN.md
/// §5.17）：48 高、输入框填充色，14px 放大镜 + 提示语，有字时行尾出现清空
/// 按钮；聚焦时 1.5dp 描边补间到 `primary`。
///
/// 文字与焦点由子页持有（[controller] / [focusNode]），结果随输入实时
/// 筛选，回车只收起键盘；不自动聚焦，打开子页不弹键盘。
class PublishPanelSearchField extends StatelessWidget {
  const PublishPanelSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hintText,
  });

  /// 与主题图标按钮的最小尺寸、模板面板的搜索框同高。
  static const double height = 48;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;
    // 玻璃时（“控件”为玻璃，或面板本身是玻璃）换成半透明填充，不模糊；
    // “控件”为玻璃时静止描边取玻璃描边，聚焦补间照旧。
    final glassField = AppGlassField.of(context);
    final fill = glassField?.fill ?? PublishPanelTile.surfaceColor(colorScheme);
    final idleOutline =
        glassField?.border?.color ?? PublishPanelTile.outlineColor(colorScheme);
    // 聚焦时描边补间到 primary（与主题输入框的聚焦描边同色），提示正在输入。
    return ListenableBuilder(
      listenable: focusNode,
      builder: (BuildContext context, Widget? child) => ExpressiveStateBlend(
        active: focusNode.hasFocus,
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: fill,
          shape: StadiumBorder(
            side: BorderSide(
              color: Color.lerp(idleOutline, colorScheme.primary, t)!,
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
          height: height,
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
                    hintText: hintText,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: iconColor.withValues(alpha: 0.75),
                    ),
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => focusNode.unfocus(),
                  contextMenuBuilder: appTextContextMenuBuilder,
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
