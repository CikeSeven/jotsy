import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';

/// 一个悬停快捷按钮。
@immutable
class TodoHoverAction {
  const TodoHoverAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// 桌面上鼠标停在待办行上时，行尾浮出一组快捷按钮（`surfaceContainerHigh`
/// 胶囊底上的 32dp 图标按钮），移开后淡出；[endInset] 为行尾已有控件
/// （拖动手柄）占的宽度，按钮停在它左边。只在 `AppPlatform.isDesktop` 时由
/// 调用方包上；淡入淡出只作用在按钮上，行本身（可能是玻璃）不动。
class TodoHoverActions extends StatefulWidget {
  const TodoHoverActions({
    super.key,
    required this.actions,
    required this.child,
    this.endInset = 0,
  });

  final List<TodoHoverAction> actions;
  final Widget child;
  final double endInset;

  @override
  State<TodoHoverActions> createState() => _TodoHoverActionsState();
}

class _TodoHoverActionsState extends State<TodoHoverActions> {
  bool _hovered = false;

  void _set(bool value) {
    if (value != _hovered) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: Stack(
        children: <Widget>[
          widget.child,
          PositionedDirectional(
            top: 0,
            bottom: 0,
            end: widget.endInset + AppSpacing.s,
            child: Center(
              child: IgnorePointer(
                ignoring: !_hovered,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final action in widget.actions)
                          IconButton(
                            tooltip: action.tooltip,
                            visualDensity: VisualDensity.compact,
                            iconSize: 14,
                            onPressed: action.onPressed,
                            icon: FaIcon(action.icon, size: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
