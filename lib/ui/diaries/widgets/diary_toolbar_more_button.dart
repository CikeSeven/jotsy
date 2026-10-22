import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 悬浮工具栏最后一格的「更多」开关。
///
/// - 收起时显示 ⋯；展开时换成向下箭头，并过渡到与已选中工具相同的容器色和
///   小圆角，表明面板正开着、再点一下收起；
/// - 面板收起时，若收进面板的某个工具正在生效（光标在引用、列表里，或正在
///   录音），右上角亮一个小圆点，状态不会因为工具被收起来而看不见。圆点只
///   监听正文控制器，随选区变化局部重建，不牵动整条工具栏。
class DiaryToolbarMoreButton extends StatelessWidget {
  const DiaryToolbarMoreButton({
    super.key,
    required this.controller,
    required this.overflow,
    required this.expanded,
    required this.onPressed,
    this.recordingOpen = false,
  });

  final editor.DiaryEditorController controller;

  /// 收在面板里的工具，用于判断要不要亮圆点。
  final List<DiaryToolbarItem> overflow;
  final bool expanded;
  final bool recordingOpen;
  final VoidCallback onPressed;

  bool _hasActiveOverflow() {
    final attributes = controller.activeAttributes;
    return overflow.any(
      (DiaryToolbarItem item) =>
          isDiaryToolbarItemActive(item, attributes) ||
          (item == DiaryToolbarItem.recording && recordingOpen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final button = ExpressiveStateBlend(
      active: expanded,
      child: ExpressiveIconSwap(
        switchKey: expanded,
        child: FaIcon(
          expanded ? FontAwesomeIcons.angleDown : FontAwesomeIcons.ellipsis,
          size: 14,
        ),
      ),
      builder: (BuildContext context, double t, Widget? icon) {
        final foreground = Color.lerp(
          colors.onSurface,
          colors.onPrimaryContainer,
          t,
        )!;
        return IconButton(
          tooltip: expanded
              ? l10n.diaryToolbarHideMoreTools
              : l10n.diaryToolbarMoreTools,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: kDiaryToolbarButtonConstraints,
          style: ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.padded,
            // 收起时与其他工具同为胶囊，展开时过渡到已选中工具的小圆角方形。
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
          icon: icon!,
        );
      },
    );
    return ListenableBuilder(
      listenable: controller,
      child: button,
      builder: (BuildContext context, Widget? button) {
        final showDot = !expanded && _hasActiveOverflow();
        return Semantics(
          value: showDot ? l10n.diaryToolbarMoreToolsActive : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              button!,
              // 40dp 触控区里可见按钮占 4~36，圆点落在 ⋯ 图标的右上方。
              Positioned(
                top: 6,
                right: 6,
                child: IgnorePointer(
                  child: AnimatedScale(
                    key: const ValueKey<String>('diary-toolbar-more-dot'),
                    scale: showDot ? 1 : 0,
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    curve: showDot
                        ? ExpressiveMotion.spatial
                        : ExpressiveMotion.exit,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
