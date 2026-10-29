import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/controllers/diary_table_editing.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 悬浮工具栏上的「表格」按钮，与代码块按钮同一规格（32dp 可见、40dp 触控
/// 区、14dp 图标）：光标在表格里或面板为它打开时，经 [ExpressiveStateBlend]
/// 过渡到已选中工具的 primaryContainer 小圆角方形。
///
/// 只有 [onPressed]：插入表格还是打开面板由工具栏决定。只在按钮内监听正文
/// 控制器，光标进出表格时只有按钮自己重建。
class DiaryToolbarTableButton extends StatelessWidget {
  const DiaryToolbarTableButton({
    super.key,
    required this.controller,
    required this.panelOpen,
    required this.tooltip,
    required this.onPressed,
  });

  final editor.DiaryEditorController controller;
  final bool panelOpen;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final selected = panelOpen || diarySelectionInTable(controller);
        return Semantics(
          selected: selected,
          child: ExpressiveStateBlend(
            active: selected,
            builder: (BuildContext context, double t, Widget? child) =>
                _buildButton(context, t),
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, double t) {
    final colors = Theme.of(context).colorScheme;
    final foreground = Color.lerp(
      colors.onSurface,
      colors.onPrimaryContainer,
      t,
    )!;
    return IconButton(
      tooltip: tooltip,
      onPressed: controller.readOnly ? null : onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: kDiaryToolbarButtonConstraints,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
          final pressed = states.contains(WidgetState.pressed);
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              pressed ? lerpDouble(12, 8, t)! : lerpDouble(16, 12, t)!,
            ),
          );
        }),
        backgroundColor: WidgetStatePropertyAll<Color>(
          colors.primaryContainer.withValues(alpha: t),
        ),
        foregroundColor: WidgetStatePropertyAll<Color>(foreground),
        iconColor: WidgetStatePropertyAll<Color>(foreground),
      ),
      icon: SizedBox.square(
        dimension: 32,
        child: Center(
          child: FaIcon(FontAwesomeIcons.table, size: 14, color: foreground),
        ),
      ),
    );
  }
}
