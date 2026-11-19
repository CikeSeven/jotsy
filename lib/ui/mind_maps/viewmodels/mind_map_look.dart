import 'package:flutter/material.dart';

import '../../../app/theme/app_fonts.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../l10n/app_localizations.dart';
import '../layout/mind_map_layout.dart';
import '../layout/mind_map_text_cache.dart';
import '../models/mind_map_options.dart';
import '../models/mind_map_themes.dart';
import 'mind_map_palette.dart';
import 'mind_map_visuals.dart';

/// 一张导图在当前界面下的“外观输入”：文档里的结构 / 主题 / 连线 / 间距 /
/// 彩虹 / 点阵设置，加上应用配色、日记字体与占位文字。
///
/// 值相等即布局结果相同：画布据此判断要不要重新布局（文档没变、外观没变时
/// 直接复用上一次的布局）。
@immutable
final class MindMapLook {
  const MindMapLook({
    required this.theme,
    required this.structure,
    required this.spacing,
    required this.line,
    required this.rainbow,
    required this.grid,
    required this.scheme,
    required this.baseText,
    required this.rootPlaceholder,
    required this.nodePlaceholder,
  });

  /// 按文档设置与 [context] 的主题解析。
  factory MindMapLook.of(BuildContext context, MindMapDocument document) {
    final theme = Theme.of(context);
    final spec = MindMapThemeSpec.of(MindMapThemeId.resolve(document.theme));
    final structure = MindMapStructure.resolve(document.structure);
    return MindMapLook(
      theme: spec.id,
      structure: structure,
      spacing: MindMapSpacing.resolve(document.spacing),
      line:
          MindMapLineStyle.tryResolve(document.line) ??
          defaultLineFor(structure, spec.line),
      rainbow: document.rainbow ?? spec.rainbow,
      grid: document.grid ?? false,
      scheme: theme.colorScheme,
      // 字体随日记字体（“正文字体与排版”，与日记卡片相同；没选时为主题
      // 字体），字号由导图主题按层级定。
      baseText: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: theme.colorScheme.onSurface,
        fontFamily: AppFonts.of(theme).diary,
      ),
      rootPlaceholder: context.l10n.mindMapRootPlaceholder,
      nodePlaceholder: context.l10n.mindMapNodePlaceholder,
    );
  }

  /// 还没有布局结果时占位用的结构与连线。
  static const MindMapStructure fallbackStructure = MindMapStructure.fallback;
  static const MindMapLineStyle fallbackLine = MindMapLineStyle.curve;

  final MindMapThemeId theme;
  final MindMapStructure structure;
  final MindMapSpacing spacing;
  final MindMapLineStyle line;
  final bool rainbow;
  final bool grid;
  final ColorScheme scheme;
  final TextStyle baseText;
  final String rootPlaceholder;
  final String nodePlaceholder;

  MindMapThemeSpec get spec => MindMapThemeSpec.of(theme);

  MindMapPalette get palette => MindMapPalette.of(spec, scheme);

  MindMapStyleResolver get styles => MindMapStyleResolver(
    spec: spec,
    palette: palette,
    rainbow: rainbow,
    baseText: baseText,
  );

  MindMapLayoutConfig config(MindMapTextCache texts) => MindMapLayoutConfig(
    structure: structure,
    spacing: spacing,
    line: line,
    styles: styles,
    texts: texts,
    rootPlaceholder: rootPlaceholder,
    nodePlaceholder: nodePlaceholder,
  );

  @override
  bool operator ==(Object other) =>
      other is MindMapLook &&
      other.theme == theme &&
      other.structure == structure &&
      other.spacing == spacing &&
      other.line == line &&
      other.rainbow == rainbow &&
      other.grid == grid &&
      other.scheme == scheme &&
      other.baseText == baseText &&
      other.rootPlaceholder == rootPlaceholder &&
      other.nodePlaceholder == nodePlaceholder;

  @override
  int get hashCode => Object.hash(
    theme,
    structure,
    spacing,
    line,
    rainbow,
    grid,
    scheme,
    baseText,
    rootPlaceholder,
    nodePlaceholder,
  );
}
