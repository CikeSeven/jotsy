import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_surfaces.dart';

/// 工具栏排序页里的分界线：线上方的工具常驻在编辑器工具栏一排，线下方的
/// 收进「更多」面板。分界位置由当前屏宽决定，本身不可拖动。
class DiaryToolbarOverflowDivider extends StatelessWidget {
  const DiaryToolbarOverflowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(
        height: 1,
        thickness: 0.8,
        color: ExpressiveSurfaces.cardBorderColor(colors),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: <Widget>[
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.ellipsis,
                  size: 12,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.diaryToolbarOverflowDivider,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          line,
        ],
      ),
    );
  }
}
