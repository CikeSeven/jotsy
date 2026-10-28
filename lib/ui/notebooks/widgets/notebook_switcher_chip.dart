import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_field.dart';

import '../../widgets/expressive_state_blend.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_parts.dart';

/// 首页标签栏最前面的日记本切换胶囊：“全部日记”“未收录”或当前日记本的
/// 名称，点按打开书架面板。
///
/// 高度由标签栏给定（与标签胶囊同高）；宽度取内容固有宽度，展开成多行时
/// 标签栏按 [measureWidth] 预留同样的宽度。全部日记用 `secondaryContainer`，
/// 未收录用 `tertiaryContainer`，日记本用它强调色换算出的容器色，与全部日记
/// 之间经 [ExpressiveStateBlend] 补间。
class NotebookSwitcherChip extends StatelessWidget {
  const NotebookSwitcherChip({
    super.key,
    required this.notebook,
    required this.onTap,
    this.unfiled = false,
  });

  /// “未收录”的图标（书架那一行、胶囊与搜索页共用）。
  static const FaIconData unfiledIcon = FontAwesomeIcons.inbox;

  /// 当前日记本；null 为全部日记或未收录（[unfiled]）。
  final NotebookView? notebook;

  /// 在“未收录”里。
  final bool unfiled;
  final VoidCallback onTap;

  /// 名称最多显示的字符数，超出截断加“…”。
  static const int maxLabelCharacters = 8;
  static const double _horizontalPadding = 10;
  static const double _iconSize = 14;
  static const double _iconGap = 6;
  static const double _caretGap = 4;
  static const double _caretSize = 10;
  static const double _radius = 12;

  /// 胶囊上显示的名称（截断后）。
  static String labelFor(
    BuildContext context,
    NotebookView? notebook, {
    bool unfiled = false,
  }) {
    if (notebook == null) {
      return unfiled
          ? context.l10n.notebookUnfiled
          : context.l10n.notebookAllDiaries;
    }
    final characters = notebook.name.characters;
    if (characters.length <= maxLabelCharacters) {
      return notebook.name;
    }
    return '${characters.take(maxLabelCharacters)}…';
  }

  static TextStyle _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
        fontWeight: MediaQuery.boldTextOf(context)
            ? FontWeight.w700
            : FontWeight.w600,
      );

  /// 胶囊在当前字号下的固有宽度（标签栏展开排版用）。
  static double measureWidth(
    BuildContext context,
    NotebookView? notebook, {
    bool unfiled = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: labelFor(context, notebook, unfiled: unfiled),
        style: _labelStyle(context),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    // 向上取整：避免排版宽度比实际绘制窄零点几像素而截断文字。
    return (_horizontalPadding * 2 +
            _iconSize +
            _iconGap +
            width +
            _caretGap +
            _caretSize)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = notebook;
    final inUnfiled = current == null && unfiled;
    final accent = current == null
        ? null
        : notebookAccentColors(current.color, scheme);
    final targetBackground =
        accent?.container ??
        (inUnfiled ? scheme.tertiaryContainer : scheme.secondaryContainer);
    final targetForeground =
        accent?.onContainer ??
        (inUnfiled ? scheme.onTertiaryContainer : scheme.onSecondaryContainer);
    final label = labelFor(context, current, unfiled: unfiled);
    final borderRadius = BorderRadius.circular(_radius);
    // “控件”为玻璃时，停在全部日记的静止态与旁边的标签胶囊一样换成玻璃
    // 底色 + 玻璃描边；在某本 / 未收录时仍是强调色容器（表示“正在范围里”），
    // 描边随补间淡出。
    final glassField = AppGlassField.of(context);
    final restingBackground = glassField?.fill ?? scheme.secondaryContainer;
    final restingSide = glassField?.border;
    return Semantics(
      button: true,
      label: context.l10n.notebookSwitcherSemantics(
        current?.name ??
            (inUnfiled
                ? context.l10n.notebookUnfiled
                : context.l10n.notebookAllDiaries),
      ),
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: current != null || inUnfiled,
        builder: (BuildContext context, double t, Widget? _) {
          // 全部日记 ↔ 日记本之间补间；两本之间切换时直接换成新本子的颜色。
          final background = Color.lerp(
            restingBackground,
            targetBackground,
            t,
          )!;
          final foreground = Color.lerp(
            scheme.onSecondaryContainer,
            targetForeground,
            t,
          )!;
          final side = restingSide;
          return Material(
            color: background,
            borderRadius: side == null ? borderRadius : null,
            shape: side == null
                ? null
                : RoundedRectangleBorder(
                    borderRadius: borderRadius,
                    side: side.copyWith(
                      color: side.color.withValues(
                        alpha: side.color.a * (1 - t).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FaIcon(
                      current?.icon.data ??
                          (inUnfiled
                              ? unfiledIcon
                              : FontAwesomeIcons.layerGroup),
                      size: _iconSize,
                      color: foreground,
                    ),
                    const SizedBox(width: _iconGap),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(context).copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: _caretGap),
                    SizedBox(
                      width: _caretSize,
                      child: FaIcon(
                        FontAwesomeIcons.caretDown,
                        size: _caretSize,
                        color: foreground,
                      ),
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
