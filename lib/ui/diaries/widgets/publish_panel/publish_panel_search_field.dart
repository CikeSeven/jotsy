import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/search_pill_field.dart';

import 'publish_panel_tile.dart';

/// 面板子页顶部的胶囊形搜索框（标签子页、用过的地点子页共用，DESIGN.md
/// §5.17）：外观见 [SearchPillField]，静止时取面板格子的填充与描边色。
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
  static const double height = SearchPillField.height;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SearchPillField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      hintText: hintText,
      fill: PublishPanelTile.surfaceColor(colorScheme),
      idleOutline: PublishPanelTile.outlineColor(colorScheme),
    );
  }
}
