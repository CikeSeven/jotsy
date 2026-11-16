import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';

/// 格式条上的一格（导图的格式条与写留言面板的格式条共用）：开着的开关
/// （或展开着面板的颜色按钮）铺次要容器色；颜色按钮在图标下画一条当前
/// 颜色 [indicator]。点按区域铺满父级给的大小，图标块 36×32 居中。
class InlineFormatButton extends StatelessWidget {
  const InlineFormatButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.indicator,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Color? indicator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final ink = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: indicator == null ? selected : null,
        selected: indicator == null ? null : selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: AnimatedContainer(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              width: 36,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FaIcon(icon, size: 15, color: ink),
                  if (indicator case final color?) ...<Widget>[
                    const SizedBox(height: 3),
                    Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: enabled ? color : color.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
