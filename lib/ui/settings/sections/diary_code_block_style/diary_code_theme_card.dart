import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../../diaries/models/diary_code_block/diary_code_theme.dart';
import '../../../widgets/expressive_state_blend.dart';

/// 配色主题网格里的一格：上方色条左右两半分别是该主题浅色与深色的代码块
/// 底色，各放关键字、字符串、函数三个记号色点；下方是主题名。
///
/// 两种明暗都画出来：代码块明暗可单独固定，用户挑主题时要同时看到两面。
/// 配色经 [DiaryCodeThemes.palette] 取（与正文渲染同一来源，已过对比度
/// 兜底），“跟随应用”按当前应用配色推出。选中格的 2dp 主色描边与对勾经
/// [ExpressiveStateBlend] 过渡。
class DiaryCodeThemeCard extends StatelessWidget {
  const DiaryCodeThemeCard({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final DiaryCodeThemeId theme;
  final bool selected;
  final VoidCallback onTap;

  static const List<DiaryCodeTokenRole> _sampleRoles = <DiaryCodeTokenRole>[
    DiaryCodeTokenRole.keyword,
    DiaryCodeTokenRole.string,
    DiaryCodeTokenRole.function,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = theme.displayName ?? context.l10n.codeBlockThemeFollowApp;
    final swatch = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant, width: 0.8),
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            children: <Widget>[
              for (final brightness in Brightness.values.reversed)
                Expanded(
                  child: _SwatchHalf(
                    palette: DiaryCodeThemes.palette(theme, brightness, scheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: name,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        child: swatch,
        builder: (BuildContext context, double t, Widget? swatch) {
          final shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Color.lerp(scheme.outlineVariant, scheme.primary, t)!,
              width: lerpDouble(1, 2, t)!,
            ),
          );
          return Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    swatch!,
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Opacity(
                          opacity: t,
                          child: FaIcon(
                            FontAwesomeIcons.solidCircleCheck,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 色条的一半：代码块底色上三个记号色点。
class _SwatchHalf extends StatelessWidget {
  const _SwatchHalf({required this.palette});

  final DiaryCodePalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.background,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final role in DiaryCodeThemeCard._sampleRoles)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.tokens[role] ?? palette.foreground,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
