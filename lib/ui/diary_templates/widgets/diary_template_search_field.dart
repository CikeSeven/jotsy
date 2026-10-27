import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';

/// 模板面板的搜索框：放大镜 + “搜索模板”占位，有字时右侧出现清空按钮。
///
/// 输入框的文字与焦点由面板（[controller] / [focusNode] 的持有者）管理，
/// 这样进入预览再返回时搜索词还在。外观取主题的 `searchBarTheme`
/// （`surfaceContainerHigh`、无阴影），经典时不覆盖颜色；玻璃时（“控件”为
/// 玻璃，或面板本身是玻璃）换成半透明填充与玻璃描边，不模糊（见
/// [AppGlassField]）。
/// 不自动聚焦：面板一打开就弹键盘会挡住大半列表。
class DiaryTemplateSearchField extends StatelessWidget {
  const DiaryTemplateSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final glassField = AppGlassField.of(context);
    final glassBorder = glassField?.border;
    return SearchBar(
      backgroundColor: glassField == null
          ? null
          : WidgetStatePropertyAll<Color>(glassField.fill),
      side: glassBorder == null
          ? null
          : WidgetStatePropertyAll<BorderSide>(glassBorder),
      controller: controller,
      focusNode: focusNode,
      hintText: l10n.diaryTemplatePickerSearchHint,
      // 默认约束带 360dp 最小宽度与 56dp 高度；面板里按可用宽度铺满、48dp 高。
      constraints: const BoxConstraints(minHeight: 48),
      textInputAction: TextInputAction.search,
      leading: FaIcon(
        FontAwesomeIcons.magnifyingGlass,
        size: 16,
        color: iconColor,
      ),
      trailing: <Widget>[
        if (controller.text.isNotEmpty)
          IconButton(
            tooltip: l10n.autoT0130,
            onPressed: () {
              controller.clear();
              onChanged('');
            },
            icon: FaIcon(FontAwesomeIcons.xmark, size: 16, color: iconColor),
          ),
      ],
      onChanged: onChanged,
      // 结果随输入实时筛选，提交只是收起键盘，便于浏览结果。
      onSubmitted: (_) => focusNode.unfocus(),
    );
  }
}
