import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';

class TagFilterChip extends StatelessWidget {
  const TagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedForegroundColor,
    required this.unselectedColor,
    required this.unselectedForegroundColor,
    required this.onTap,
    this.colorDot,
    this.leading,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedForegroundColor;
  final Color unselectedColor;
  final Color unselectedForegroundColor;
  final VoidCallback onTap;
  final Color? colorDot;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? selectedColor : unselectedColor;
    final foregroundColor =
        selected ? selectedForegroundColor : unselectedForegroundColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.nav),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadii.nav),
            boxShadow:
                selected
                    ? <BoxShadow>[
                      BoxShadow(
                        color: backgroundColor.withAlpha(140),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: foregroundColor, size: 12),
                    child: leading!,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (colorDot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                ],
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
