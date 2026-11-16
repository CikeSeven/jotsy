import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../models/mind_map_templates.dart';
import 'mind_map_thumbnail.dart';

/// 还只有中心主题的导图上浮出的起步卡：一排带预览的内置模板（套用时保留
/// 已写的中心主题），右上可选“转回文字日记”。一加主题就由宿主收起。
class MindMapStarterCard extends StatelessWidget {
  const MindMapStarterCard({
    super.key,
    required this.onTemplate,
    this.onConvertBack,
    this.onImport,
    this.onAiGenerate,
  });

  final ValueChanged<MindMapTemplate> onTemplate;

  /// 导图日记才有：把这篇转回普通的文字日记。
  final VoidCallback? onConvertBack;

  /// 从文件导入（XMind、OPML、FreeMind、Markdown）。
  final VoidCallback? onImport;

  /// AI 生成整张导图（AI 写作可用时才有，排在模板之前）。
  final VoidCallback? onAiGenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DiaryFloatingToolbarSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.mindMapStarterTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onImport != null)
                    IconButton(
                      tooltip: l10n.mindMapImport,
                      onPressed: onImport,
                      visualDensity: VisualDensity.compact,
                      icon: FaIcon(
                        FontAwesomeIcons.fileImport,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (onConvertBack != null)
                    TextButton(
                      onPressed: onConvertBack,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        textStyle: theme.textTheme.labelMedium,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.mindMapConvertBack),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 104,
              child: DesktopHorizontalScroll(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount:
                      MindMapTemplate.values.length +
                      (onAiGenerate == null ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final ai = onAiGenerate;
                    if (ai != null) {
                      if (index == 0) return _AiTile(onTap: ai);
                      index -= 1;
                    }
                    final template = MindMapTemplate.values[index];
                    return _TemplateTile(
                      template: template,
                      onTap: () => onTemplate(template),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final MindMapTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = template.name(l10n);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 116,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExcludeSemantics(
                  child: MindMapThumbnail(
                    document: template.preview(l10n),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 模板前的“AI 生成”格：同模板格的尺寸，预览处是 `primaryContainer` 底上的
/// 魔杖，表明它不是现成的模板。
class _AiTile extends StatelessWidget {
  const _AiTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = l10n.mindMapAiTile;
    return Semantics(
      button: true,
      label: l10n.mindMapAiGenerate,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 116,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
