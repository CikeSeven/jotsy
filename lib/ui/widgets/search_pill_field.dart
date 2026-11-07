import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

/// 胶囊形搜索框（DESIGN.md §5.17 / §5.33）：48 高、`StadiumBorder`，14px 放大镜
/// + 提示语，有字时行尾出现清空按钮（交叉缩放淡入）；聚焦时 1.5dp 描边经
/// [ExpressiveStateBlend] 补间到 `primary`。
///
/// 发布面板子页（标签、用过的地点）与日记搜索页共用同一套外观，只有静止时
/// 的填充 / 描边色由调用方给出（[fill] / [idleOutline]）。玻璃时（“控件”为
/// 玻璃，或画在玻璃表面上）一律换成 [AppGlassField] 的半透明填充与玻璃描边，
/// 不模糊：搜索框所在的顶栏 / 面板已经是一层材质，同一区域不叠两层模糊。
///
/// 文字与焦点由调用方持有（[controller] / [focusNode]）。
class SearchPillField extends StatelessWidget {
  const SearchPillField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hintText,
    required this.fill,
    required this.idleOutline,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  /// 与主题图标按钮的最小尺寸、模板面板的搜索框同高。
  static const double height = 48;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;

  /// 经典材质下的填充与静止描边色。
  final Color fill;
  final Color idleOutline;

  /// 键盘“搜索”键；null 时只收起键盘。
  final ValueChanged<String>? onSubmitted;

  /// 清空按钮；null 时清掉文字并以空串回调 [onChanged]。
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;
    final glassField = AppGlassField.of(context);
    final surface = glassField?.fill ?? fill;
    final outline = glassField?.border?.color ?? idleOutline;
    // 聚焦时描边补间到 primary（与主题输入框的聚焦描边同色），提示正在输入。
    return ListenableBuilder(
      listenable: focusNode,
      builder: (BuildContext context, Widget? child) => ExpressiveStateBlend(
        active: focusNode.hasFocus,
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: Color.lerp(outline, colorScheme.primary, t)!,
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
                  autofocus: autofocus,
                  maxLines: 1,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    // 外层已是填充色与描边，不再叠主题的底色与边框（主题给了
                    // 聚焦描边，只清 border 仍会画在胶囊里面）。
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
                  onSubmitted: onSubmitted ?? (_) => focusNode.unfocus(),
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
                                  onPressed:
                                      onClear ??
                                      () {
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
