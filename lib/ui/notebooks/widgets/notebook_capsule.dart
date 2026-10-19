import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../viewmodels/notebook_view.dart';
import 'notebook_cover_parts.dart';

/// 日记本微胶囊：日记本图标 + 名称（发布面板的日记本行、预览页信息栏）。
///
/// 与标签微胶囊（DESIGN.md §5.2）同一排布：无描边、w600 小字，只是前缀
/// 换成日记本图标。颜色取日记本强调色经主题换算的容器色 / 容器上的文字色
/// （[notebookAccentColors]），明暗主题下对比度都有保证，与头部卡片的状态
/// 胶囊同一套。名称最宽 [maxNameWidth]，超出省略。
///
/// [onTap] 非空时可点（预览页：打开这本），读屏读作“打开「名称」”。
class NotebookCapsule extends StatelessWidget {
  const NotebookCapsule({
    super.key,
    required this.notebook,
    this.onTap,
    this.maxNameWidth = 140,
  });

  final NotebookView notebook;
  final VoidCallback? onTap;
  final double maxNameWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = notebookAccentColors(notebook.color, theme.colorScheme);
    final radius = BorderRadius.circular(8);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(notebook.icon.data, size: 10, color: accent.onContainer),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxNameWidth),
            child: Text(
              notebook.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent.onContainer,
              ),
            ),
          ),
        ],
      ),
    );
    final onTap = this.onTap;
    return Material(
      color: accent.container,
      borderRadius: radius,
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              label: context.l10n.notebookOpenNotebook(notebook.name),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}
