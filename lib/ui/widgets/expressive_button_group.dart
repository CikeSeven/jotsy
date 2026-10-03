import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

/// 单选连接按钮组：输入选项/当前值，输出用户选择，不保存业务状态。
/// 利用原生按钮保留键盘、焦点与 disabled 行为；窄屏和大字体时改为纵向连接，
/// 避免 SegmentedButton 固定横排挤掉标签。方向圆角同时适配 RTL。
class ExpressiveButtonGroup<T> extends StatelessWidget {
  const ExpressiveButtonGroup({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  }) : assert(segments.length > 0),
       assert(selected.length == 1);

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < segments.length * 104 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final children = <Widget>[];
        for (var index = 0; index < segments.length; index++) {
          final segment = segments[index];
          final isSelected = selected.contains(segment.value);
          final button = Semantics(
            selected: isSelected,
            inMutuallyExclusiveGroup: true,
            child: FilledButton.tonal(
              onPressed: onSelectionChanged != null && segment.enabled
                  ? () => onSelectionChanged!({segment.value})
                  : null,
              style: ButtonStyle(
                animationDuration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  return isSelected
                      ? colors.primary
                      : colors.surfaceContainerHighest;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  return isSelected ? colors.onPrimary : colors.onSurface;
                }),
                shape: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed) || isSelected) {
                    return RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isSelected ? 24 : 12),
                    );
                  }
                  const inner = Radius.circular(4);
                  const outer = Radius.circular(24);
                  final first = index == 0;
                  final last = index == segments.length - 1;
                  final radius = stacked
                      ? BorderRadius.vertical(
                          top: first ? outer : inner,
                          bottom: last ? outer : inner,
                        )
                      : BorderRadiusDirectional.horizontal(
                          start: first ? outer : inner,
                          end: last ? outer : inner,
                        );
                  return RoundedRectangleBorder(borderRadius: radius);
                }),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    segment.icon!,
                    const SizedBox(width: 8),
                  ],
                  if (segment.label != null) Flexible(child: segment.label!),
                ],
              ),
            ),
          );
          if (index > 0) {
            children.add(
              SizedBox(width: stacked ? 0 : 4, height: stacked ? 4 : 0),
            );
          }
          children.add(stacked ? button : Expanded(child: button));
        }
        return FocusTraversalGroup(
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                )
              : Row(children: children),
        );
      },
    );
  }
}
