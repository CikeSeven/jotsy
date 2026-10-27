import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../core/database/app_database.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../models/notebook_icon.dart';
import 'notebook_cover_mini.dart';
import 'notebook_cover_texture.dart';

String notebookCoverLayoutLabel(
  AppLocalizations l10n,
  NotebookCoverLayout layout,
) => switch (layout) {
  NotebookCoverLayout.classic => l10n.notebookCoverLayoutClassic,
  NotebookCoverLayout.fullBleed => l10n.notebookCoverLayoutFullBleed,
  NotebookCoverLayout.spine => l10n.notebookCoverLayoutSpine,
  NotebookCoverLayout.label => l10n.notebookCoverLayoutPlate,
  NotebookCoverLayout.minimal => l10n.notebookCoverLayoutMinimal,
};

String notebookCoverTextureLabel(
  AppLocalizations l10n,
  NotebookCoverTexture texture,
) => switch (texture) {
  NotebookCoverTexture.none => l10n.notebookCoverTextureNone,
  NotebookCoverTexture.dots => l10n.notebookCoverTextureDots,
  NotebookCoverTexture.lines => l10n.notebookCoverTextureLines,
  NotebookCoverTexture.grid => l10n.notebookCoverTextureGrid,
  NotebookCoverTexture.diagonal => l10n.notebookCoverTextureDiagonal,
};

/// 选中描边：2dp，从透明补间到 primary（与图标格子同一种选中态）。
Color _selectionBorder(ColorScheme scheme, double t) =>
    Color.lerp(scheme.primary.withValues(alpha: 0), scheme.primary, t)!;

/// 选项下方的名称：选中时 primary、w700。
class _OptionLabel extends StatelessWidget {
  const _OptionLabel({required this.text, required this.t});

  final String text;
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500,
        color: Color.lerp(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.primary,
          t,
        ),
      ),
    );
  }
}

/// 版式选择：五个小预览卡横向排开（放不下时横向滚动，桌面可拖动与
/// Shift + 滚轮）。每张卡用当前的图标、颜色、封面图、纹理与取景画出该版式
/// 的小封面（[NotebookCoverMini]），下方写版式名。
class NotebookCoverLayoutPicker extends StatelessWidget {
  const NotebookCoverLayoutPicker({
    super.key,
    required this.style,
    required this.icon,
    required this.accent,
    required this.onSelected,
    this.coverPath,
  });

  final NotebookCoverStyle style;
  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final String? coverPath;
  final ValueChanged<NotebookCoverLayout> onSelected;

  static const double previewWidth = 56;
  static const double _border = 2;
  static const double _inset = 3;

  /// 整行高度：预览（3:4）+ 选中描边与间隙 + 名称。
  static const double height =
      previewWidth / 0.75 + (_border + _inset) * 2 + AppSpacing.xs + 18;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    const outer = previewWidth + (_border + _inset) * 2;
    return SizedBox(
      height: height,
      child: DesktopHorizontalScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          itemCount: NotebookCoverLayout.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (BuildContext context, int index) {
            final layout = NotebookCoverLayout.values[index];
            final label = notebookCoverLayoutLabel(l10n, layout);
            final selected = layout == style.layout;
            return Semantics(
              button: true,
              selected: selected,
              label: label,
              excludeSemantics: true,
              onTap: () => onSelected(layout),
              child: InkWell(
                onTap: () => onSelected(layout),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: outer,
                  child: ExpressiveStateBlend(
                    active: selected,
                    builder: (BuildContext context, double t, Widget? child) =>
                        Column(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(_inset),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectionBorder(scheme, t),
                                  width: _border,
                                ),
                              ),
                              child: child,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _OptionLabel(text: label, t: t),
                          ],
                        ),
                    child: _MiniFrame(
                      accent: accent,
                      child: NotebookCoverMini(
                        icon: icon,
                        accent: accent,
                        coverPath: coverPath,
                        style: style.copyWith(layout: layout),
                        width: previewWidth,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 小预览的外框：容器色底、10dp 圆角、卡片微边框。
class _MiniFrame extends StatelessWidget {
  const _MiniFrame({required this.accent, required this.child});

  final DiaryTemplateAccentColors accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);
    return Container(
      width: NotebookCoverLayoutPicker.previewWidth,
      height: NotebookCoverLayoutPicker.previewWidth / 0.75,
      decoration: BoxDecoration(color: accent.container, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(scheme),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 纹理选择：五个 40dp 圆角方块，以当前强调容器色为底画出纹理样例，
/// 下方写纹理名；选中描边同版式选择。
class NotebookCoverTexturePicker extends StatelessWidget {
  const NotebookCoverTexturePicker({
    super.key,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final NotebookCoverTexture selected;
  final DiaryTemplateAccentColors accent;
  final ValueChanged<NotebookCoverTexture> onSelected;

  static const double _swatch = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (final texture in NotebookCoverTexture.values)
          Semantics(
            button: true,
            selected: texture == selected,
            label: notebookCoverTextureLabel(l10n, texture),
            excludeSemantics: true,
            onTap: () => onSelected(texture),
            child: InkWell(
              onTap: () => onSelected(texture),
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: _swatch + 10,
                child: ExpressiveStateBlend(
                  active: texture == selected,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectionBorder(scheme, t),
                                width: 2,
                              ),
                            ),
                            child: child,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _OptionLabel(
                            text: notebookCoverTextureLabel(l10n, texture),
                            t: t,
                          ),
                        ],
                      ),
                  child: Container(
                    width: _swatch,
                    height: _swatch,
                    decoration: BoxDecoration(
                      color: accent.container,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: NotebookCoverTextureLayer(
                      texture: texture,
                      color: notebookCoverTextureColor(accent.onContainer),
                      scale: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
