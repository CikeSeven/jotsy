import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/notebook_icon.dart';
import 'notebook_cover_parts.dart';

/// 日记本图标选择：44dp 圆形格子，选中的格子底色与图标补间到强调色容器色、
/// 描边补间到 primary（[ExpressiveStateBlend]）。编辑页与快速新建弹窗共用。
class NotebookIconGrid extends StatelessWidget {
  const NotebookIconGrid({
    super.key,
    required this.selected,
    required this.color,
    required this.onSelected,
    this.icons = NotebookIcon.values,
  });

  final NotebookIcon selected;

  /// 强调色种子，决定选中格子的容器色。
  final int? color;
  final ValueChanged<NotebookIcon> onSelected;
  final List<NotebookIcon> icons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(color, scheme);
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (final icon in icons)
          Semantics(
            button: true,
            selected: icon == selected,
            label: icon.name,
            child: InkResponse(
              onTap: () => onSelected(icon),
              radius: 24,
              child: ExpressiveStateBlend(
                active: icon == selected,
                builder: (BuildContext context, double t, Widget? child) {
                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        scheme.surfaceContainerHigh,
                        accent.container,
                        t,
                      ),
                      border: Border.all(
                        color: Color.lerp(
                          scheme.primary.withValues(alpha: 0),
                          scheme.primary,
                          t,
                        )!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: FaIcon(
                        icon.data,
                        size: 18,
                        color: Color.lerp(
                          scheme.onSurfaceVariant,
                          accent.onContainer,
                          t,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
