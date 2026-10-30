import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../diary_templates/viewmodels/diary_template_accent.dart';
import '../models/notebook_icon.dart';
import '../viewmodels/notebook_labels.dart';

export 'notebook_cover/notebook_cover_classic.dart'
    show NotebookCoverBody, NotebookCoverText;
export 'notebook_cover/notebook_cover_image.dart';

/// 日记本强调色在当前明暗主题下的容器色与前景色。
///
/// 与模板强调色同一套换算（`ColorScheme.fromSeed` 后取 primaryContainer /
/// onPrimaryContainer，灰色这类无彩色种子换成同深浅的中性灰，带缓存），这里
/// 只是按日记本的语义起个名字。
DiaryTemplateAccentColors notebookAccentColors(int? seed, ColorScheme scheme) =>
    diaryTemplateAccentColors(seed, scheme);

/// 封面上的 40dp 图标圆：onContainer 12% 叠在容器色上。叠成不透明色而不是
/// 直接用半透明：圆放在封面图上时，半透明底会透出照片、图标就看不清了。
class NotebookIconCircle extends StatelessWidget {
  const NotebookIconCircle({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
  });

  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.onContainer.withValues(alpha: 0.12),
            accent.container,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: FaIcon(
            icon.data,
            size: size * 0.42,
            color: accent.onContainer,
          ),
        ),
      ),
    );
  }
}

/// 右上角的状态角标：22dp 半透明 surface 圆 + 12px 图标。
class NotebookStateBadge extends StatelessWidget {
  const NotebookStateBadge({super.key, required this.badge});

  final NotebookBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: FaIcon(
            switch (badge) {
              NotebookBadge.locked => FontAwesomeIcons.lock,
              NotebookBadge.hidden => FontAwesomeIcons.eyeSlash,
              NotebookBadge.smart => FontAwesomeIcons.wandMagicSparkles,
            },
            size: 12,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// 网格末尾的“＋ 新建日记本”：描边、无底色。
class NotebookCreateTile extends StatelessWidget {
  const NotebookCreateTile({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = context.l10n.notebookNew;
    final borderRadius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.plus,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
