import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../models/mind_map_options.dart';
import '../models/mind_map_templates.dart';
import '../models/mind_map_themes.dart';
import '../viewmodels/mind_map_labels.dart';
import '../viewmodels/mind_map_look.dart';
import '../widgets/mind_map_thumbnail.dart';

/// 导图样式面板：结构、配色主题、连线、间距、彩虹分支与点阵背景。
///
/// 每一项点了立即生效（经 [MindMapEditingController.updateDocument]，各是一步
/// 撤销），面板留着可以接着换；结构与主题的格子是用样例图实时画出的预览。
Future<void> showMindMapStyleSheet(
  BuildContext context,
  MindMapEditingController controller,
) => showAppModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (BuildContext context) => _MindMapStyleSheet(controller: controller),
);

class _MindMapStyleSheet extends StatelessWidget {
  const _MindMapStyleSheet({required this.controller});

  final MindMapEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sample = MindMapTemplate.sample(l10n);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final document = controller.document;
        final look = MindMapLook.of(context, document);
        void update(MindMapDocument Function(MindMapDocument) change) =>
            controller.updateDocument(change);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.mindMapStyleSheetTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _SectionTitle(l10n.mindMapStructureTitle),
                _PreviewStrip(
                  children: <Widget>[
                    for (final structure in MindMapStructure.values)
                      _PreviewTile(
                        label: mindMapStructureLabel(l10n, structure),
                        selected: look.structure == structure,
                        onTap: () =>
                            update((d) => d.copyWith(structure: structure.id)),
                        preview: MindMapThumbnail(
                          document: sample,
                          overrideStructure: structure.id,
                          overrideTheme: look.theme.id,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
                _SectionTitle(l10n.mindMapThemeTitle),
                _PreviewStrip(
                  children: <Widget>[
                    for (final id in MindMapThemeId.values)
                      _PreviewTile(
                        label: mindMapThemeLabel(l10n, id),
                        selected: look.theme == id,
                        onTap: () => update(
                          // 换主题时彩虹跟随新主题的缺省，连线也回到缺省。
                          (d) => d.copyWith(
                            theme: id.id,
                            rainbow: null,
                            line: null,
                          ),
                        ),
                        preview: MindMapThumbnail(
                          document: sample,
                          overrideTheme: id.id,
                          overrideStructure: MindMapStructure.mindMap.id,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
                _SectionTitle(l10n.mindMapLineTitle),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExpressiveButtonGroup<MindMapLineStyle>(
                    // 标签只有两三个字：四段在窄屏上也排得下一行。
                    minSegmentWidth: 68,
                    segments: <ButtonSegment<MindMapLineStyle>>[
                      for (final line in MindMapLineStyle.values)
                        ButtonSegment<MindMapLineStyle>(
                          value: line,
                          label: Text(mindMapLineLabel(l10n, line)),
                        ),
                    ],
                    selected: <MindMapLineStyle>{look.line},
                    onSelectionChanged: (value) =>
                        update((d) => d.copyWith(line: value.first.id)),
                  ),
                ),
                _SectionTitle(l10n.mindMapSpacingTitle),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExpressiveButtonGroup<MindMapSpacing>(
                    minSegmentWidth: 68,
                    segments: <ButtonSegment<MindMapSpacing>>[
                      for (final spacing in MindMapSpacing.values)
                        ButtonSegment<MindMapSpacing>(
                          value: spacing,
                          label: Text(mindMapSpacingLabel(l10n, spacing)),
                        ),
                    ],
                    selected: <MindMapSpacing>{look.spacing},
                    onSelectionChanged: (value) =>
                        update((d) => d.copyWith(spacing: value.first.id)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: <Widget>[
                      SettingsSwitchTile(
                        title: l10n.mindMapRainbow,
                        value: look.rainbow,
                        onChanged: (value) =>
                            update((d) => d.copyWith(rainbow: value)),
                      ),
                      SettingsSwitchTile(
                        title: l10n.mindMapGrid,
                        value: look.grid,
                        onChanged: (value) =>
                            update((d) => d.copyWith(grid: value)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 一排可横向滚动的预览格。
class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _PreviewTile.height,
    child: DesktopHorizontalScroll(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) => children[index],
      ),
    ),
  );
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  static const double width = 132;
  static const double previewHeight = 88;
  static const double height = previewHeight + 34;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedContainer(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                curve: ExpressiveMotion.effects,
                height: previewHeight,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                    width: selected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExcludeSemantics(child: preview),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
