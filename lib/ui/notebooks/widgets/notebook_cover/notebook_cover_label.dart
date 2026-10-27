import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import 'notebook_cover_classic.dart';
import 'notebook_cover_layouts.dart';
import 'notebook_cover_texture.dart';

/// 贴签的底色：亮色主题近白的纸色，暗色主题提亮一档的表面色（最暗的
/// 表面色在深色封面上像一个黑洞）。
Color notebookLabelPlateColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light
    ? scheme.surfaceContainerLowest
    : scheme.surfaceContainerHigh;

/// 贴签上小图标的颜色：在强调色的容器色与 onContainer 里取与贴签底色对比
/// 更强的一个——不同种子色 / 主题变体下，容器色可能深也可能浅。
Color notebookLabelIconColor(DiaryTemplateAccentColors accent, Color plate) {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  return contrast(accent.onContainer, plate) >=
          contrast(accent.container, plate)
      ? accent.onContainer
      : accent.container;
}

/// 贴签版式上方为角标（22dp，距边 8）留出的高度。
const double _labelTopReserve = 8 + 22 + AppSpacing.xs;

/// 贴签版式（[NotebookCoverLayoutBody] 的一种）：底色（或封面图）铺满，
/// 中央一块纸色、细描边的圆角贴签，小图标、名称与篇数居中写在贴签上。
class NotebookCoverLabelBody extends StatelessWidget {
  const NotebookCoverLabelBody(this.data, {super.key});

  final NotebookCoverLayoutBody data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = data.accent;
    final cover = data.coverPath;
    final plateColor = notebookLabelPlateColor(scheme);
    final plate = DecoratedBox(
      decoration: BoxDecoration(
        color: plateColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(
              data.icon.data,
              size: 14,
              color: notebookLabelIconColor(accent, plateColor),
            ),
            const SizedBox(height: 6),
            NotebookCoverText(
              name: data.name,
              countLabel: data.countLabel,
              color: scheme.onSurface,
              countColor: scheme.onSurfaceVariant,
              center: true,
            ),
          ],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (cover != null)
          NotebookCoverFilledImage(path: cover, style: data.style)
        else
          NotebookCoverTextureLayer(
            texture: data.style.texture,
            color: notebookCoverTextureColor(accent.onContainer),
          ),
        // 上方让出右上角角标的高度（不论有没有角标都一样，书架上各本的
        // 贴签高度一致），贴签在剩余区域里略高于正中，像贴在本子上半部。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            _labelTopReserve,
            AppSpacing.m,
            AppSpacing.xl,
          ),
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: SizedBox(width: double.infinity, child: plate),
          ),
        ),
      ],
    );
  }
}
