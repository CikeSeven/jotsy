import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_editing.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 选区是否触及代码块（折叠选区看光标所在行）。工具栏据此决定点按代码块
/// 工具是“转为代码块”还是打开代码块面板，面板开着时据此判断是否该收起。
/// 悬浮工具栏上的「代码块」按钮。
///
/// - 输入：正文控制器、面板是否正为它打开（[panelOpen]）、点按回调；
/// - 输出：只有 [onPressed]，转为代码块还是打开面板由工具栏决定；
/// - 外观与颜色按钮一致（32dp 可见、40dp 触控区、14dp 图标）：光标在代码块
///   里或面板为它打开时，经 [ExpressiveStateBlend] 过渡到已选中工具的
///   primaryContainer 小圆角方形。
///
/// 只在按钮内监听正文控制器：光标进出代码块时只有按钮自己重建，不牵动
/// 整条工具栏。
class DiaryToolbarCodeBlockButton extends StatelessWidget {
  const DiaryToolbarCodeBlockButton({
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
        final selected = panelOpen || diarySelectionInCodeBlock(controller);
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
      onPressed: onPressed,
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
          child: FaIcon(FontAwesomeIcons.fileCode, size: 14, color: foreground),
        ),
      ),
    );
  }
}
