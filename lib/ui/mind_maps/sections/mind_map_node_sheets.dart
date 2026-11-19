import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../diaries/widgets/diary_link/diary_link_search_view.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/keyboard_visibility.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../models/mind_map_markers.dart';
import '../models/mind_map_options.dart';
import '../models/mind_map_themes.dart';
import '../viewmodels/mind_map_labels.dart';
import '../viewmodels/mind_map_palette.dart';
import '../viewmodels/mind_map_visuals.dart';
import '../widgets/mind_map_color_swatches.dart';
import 'mind_map_text_color_section.dart';

/// 单个主题的面板：样式、图标贴纸、标签、备注、链接与“插入”总入口。
///
/// 每个面板都只经 [MindMapEditingController] 改节点（一步一撤销，备注打字
/// 合并为一步），面板开着时随文档实时刷新；节点在面板开着时被删掉（撤销）
/// 就自动关掉。

Future<void> _showSheet(BuildContext context, WidgetBuilder builder) =>
    showAppModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: builder,
    );

/// 面板的版式：标题 + 可滚动内容，为键盘留白。
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyboardInsetPadding(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 只在节点还在时构建（被删掉就关面板）。
class _NodeListener extends StatelessWidget {
  const _NodeListener({
    required this.controller,
    required this.id,
    required this.builder,
  });

  final MindMapEditingController controller;
  final String id;
  final Widget Function(BuildContext context, MindMapNode node) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? _) {
      final node = controller.document.index[id];
      if (node == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
        return const SizedBox.shrink();
      }
      return builder(context, node);
    },
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
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

// ---------------- 插入 ----------------

/// “插入”：图标、标签、备注、链接与待办，一格一项。
Future<void> showMindMapInsertSheet(
  BuildContext host,
  MindMapEditingController controller,
  String id,
) => _showSheet(
  host,
  (BuildContext sheetContext) => _NodeListener(
    controller: controller,
    id: id,
    builder: (BuildContext context, MindMapNode node) {
      final l10n = context.l10n;
      Widget cell(
        FaIconData icon,
        String label,
        VoidCallback onTap, {
        bool selected = false,
      }) => _ActionCell(
        icon: icon,
        label: label,
        selected: selected,
        onTap: onTap,
      );
      // 先关掉这个面板，再从宿主页面打开下一个面板（不叠两层）。
      void then(Future<void> Function(BuildContext) open) {
        Navigator.of(sheetContext).pop();
        if (host.mounted) open(host);
      }

      return _SheetBody(
        title: l10n.mindMapInsert,
        children: <Widget>[
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: <Widget>[
              cell(
                FontAwesomeIcons.faceSmile,
                l10n.mindMapMarkers,
                () => then((c) => showMindMapMarkerSheet(c, controller, id)),
                selected: node.icons.isNotEmpty,
              ),
              cell(
                FontAwesomeIcons.tag,
                l10n.mindMapLabels,
                () => then((c) => showMindMapLabelsSheet(c, controller, id)),
                selected: node.labels.isNotEmpty,
              ),
              cell(
                FontAwesomeIcons.noteSticky,
                l10n.mindMapNote,
                () => then((c) => showMindMapNoteSheet(c, controller, id)),
                selected: (node.note ?? '').trim().isNotEmpty,
              ),
              cell(
                FontAwesomeIcons.link,
                l10n.mindMapLink,
                () => then((c) => showMindMapLinkSheet(c, controller, id)),
                selected: (node.href ?? '').trim().isNotEmpty,
              ),
              cell(
                FontAwesomeIcons.squareCheck,
                l10n.mindMapTask,
                () => controller.updateNode(
                  id,
                  (n) => n.copyWith(
                    task: n.isTask ? null : <String, Object?>{'done': false},
                  ),
                ),
                selected: node.isTask,
              ),
            ],
          ),
        ],
      );
    },
  ),
);

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = selected
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHigh;
    final ink = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FaIcon(icon, size: 20, color: ink),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ink,
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

// ---------------- 样式 ----------------

/// 一个主题的样式：形状、底色、文字颜色与文字高亮（正文同款的颜色面板，
/// 见 [MindMapTextColorSection]）、分支颜色、粗 / 斜 / 下划线 / 删除线、
/// 字号。改动经 [MindMapOps.setStyle]：文字有关的几项改的是整条，同名的
/// 局部样式随之去掉；重置样式连局部样式一起清掉。底色与分支色是主题配色，
/// 仍是按明暗换算的种子色。
Future<void> showMindMapNodeStyleSheet(
  BuildContext context,
  MindMapEditingController controller,
  String id,
  MindMapPalette palette,
) => _showSheet(
  context,
  (BuildContext context) => _NodeListener(
    controller: controller,
    id: id,
    builder: (BuildContext context, MindMapNode node) {
      final l10n = context.l10n;
      final style = MindMapNodeStyle(node.style);
      void set(String key, Object? value) => controller.updateDocument(
        (document) => MindMapOps.setStyle(document, id, key, value),
      );
      Color? seed(Object? raw) =>
          MindMapNodeStyle(<String, Object?>{kMindMapStyleFillKey: raw}).fill;
      // 底色预览容器色（节点上实际的样子），分支色预览强调色。
      Widget colors(String key, {bool container = false}) =>
          MindMapColorSwatches(
            selected: seed(node.style[key]),
            preview: (c) {
              final colors = palette.custom(c);
              return container
                  ? MindMapBranchColors(
                      accent: colors.container,
                      onAccent: colors.onContainer,
                      container: colors.container,
                      onContainer: colors.onContainer,
                    )
                  : colors;
            },
            onPick: (color) => set(
              key,
              color == null ? null : MindMapNodeStyle.encodeColor(color),
            ),
          );
      return _SheetBody(
        title: l10n.mindMapNodeStyleTitle,
        children: <Widget>[
          _SectionLabel(l10n.mindMapShape),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final shape in MindMapNodeShape.values)
                ChoiceChip(
                  label: Text(_shapeLabel(l10n, shape)),
                  selected: style.shape == shape,
                  onSelected: (on) =>
                      set(kMindMapStyleShapeKey, on ? shape.id : null),
                ),
            ],
          ),
          _SectionLabel(l10n.mindMapFill),
          colors(kMindMapStyleFillKey, container: true),
          // 文字颜色 / 文字高亮的切换就是这一节的标题。
          const SizedBox(height: 16),
          MindMapTextColorSection(controller: controller, id: id),
          _SectionLabel(l10n.mindMapBranchColor),
          colors(kMindMapStyleBranchKey),
          _SectionLabel(l10n.mindMapTextStyle),
          Row(
            children: <Widget>[
              _ToggleIcon(
                icon: FontAwesomeIcons.bold,
                tooltip: l10n.mindMapBold,
                selected: style.bold == true,
                onTap: () =>
                    set(kMindMapStyleBoldKey, style.bold == true ? null : true),
              ),
              _ToggleIcon(
                icon: FontAwesomeIcons.italic,
                tooltip: l10n.mindMapItalic,
                selected: style.italic == true,
                onTap: () => set(
                  kMindMapStyleItalicKey,
                  style.italic == true ? null : true,
                ),
              ),
              _ToggleIcon(
                icon: FontAwesomeIcons.underline,
                tooltip: l10n.mindMapUnderline,
                selected: style.underline == true,
                onTap: () => set(
                  kMindMapStyleUnderlineKey,
                  style.underline == true ? null : true,
                ),
              ),
              _ToggleIcon(
                icon: FontAwesomeIcons.strikethrough,
                tooltip: l10n.mindMapStrike,
                selected: style.strike == true,
                onTap: () => set(
                  kMindMapStyleStrikeKey,
                  style.strike == true ? null : true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpressiveButtonGroup<MindMapTextSize>(
            minSegmentWidth: 56,
            segments: <ButtonSegment<MindMapTextSize>>[
              for (final size in MindMapTextSize.values)
                ButtonSegment<MindMapTextSize>(
                  value: size,
                  label: Text(mindMapTextSizeLabel(l10n, size)),
                ),
            ],
            selected: <MindMapTextSize>{style.size},
            onSelectionChanged: (value) => set(
              kMindMapStyleSizeKey,
              value.first == MindMapTextSize.medium ? null : value.first.id,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: node.style.isEmpty && !mindMapHasRichText(node)
                  ? null
                  : () => controller.updateNode(
                      id,
                      (n) => n.copyWith(
                        style: const <String, Object?>{},
                        delta: null,
                      ),
                    ),
              icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 14),
              label: Text(l10n.mindMapResetStyle),
            ),
          ),
        ],
      );
    },
  ),
);

String _shapeLabel(AppLocalizations l10n, MindMapNodeShape shape) =>
    switch (shape) {
      MindMapNodeShape.rounded => l10n.mindMapShapeRounded,
      MindMapNodeShape.pill => l10n.mindMapShapePill,
      MindMapNodeShape.rect => l10n.mindMapShapeRect,
      MindMapNodeShape.ellipse => l10n.mindMapShapeEllipse,
      MindMapNodeShape.underline => l10n.mindMapShapeUnderline,
      MindMapNodeShape.plain => l10n.mindMapShapePlain,
    };

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final FaIconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    style: AppGlassField.tonalButtonStyle(context),
    isSelected: selected,
    onPressed: onTap,
    icon: FaIcon(icon, size: 15),
  );
}

// ---------------- 图标贴纸 ----------------

/// 图标贴纸：按分组排列，点一下加上（同组替换），再点去掉；末尾可输入任意
/// emoji。
Future<void> showMindMapMarkerSheet(
  BuildContext context,
  MindMapEditingController controller,
  String id,
) => _showSheet(
  context,
  (BuildContext context) => _MarkerSheet(controller: controller, id: id),
);

class _MarkerSheet extends StatefulWidget {
  const _MarkerSheet({required this.controller, required this.id});

  final MindMapEditingController controller;
  final String id;

  @override
  State<_MarkerSheet> createState() => _MarkerSheetState();
}

class _MarkerSheetState extends State<_MarkerSheet> {
  final TextEditingController _emoji = TextEditingController();

  @override
  void dispose() {
    _emoji.dispose();
    super.dispose();
  }

  void _toggle(MindMapMarker marker) => widget.controller.updateNode(
    widget.id,
    (n) => n.copyWith(icons: MindMapMarker.toggle(n.icons, marker)),
  );

  void _addEmoji() {
    final value = _emoji.text.trim();
    if (value.isEmpty) return;
    final marker = MindMapMarker.parse('${MindMapMarkerGroup.emoji.id}:$value');
    if (marker != null) _toggle(marker);
    _emoji.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = MindMapPalette.of(
      MindMapThemeSpec.of(MindMapThemeId.follow),
      Theme.of(context).colorScheme,
    );
    return _NodeListener(
      controller: widget.controller,
      id: widget.id,
      builder: (BuildContext context, MindMapNode node) {
        Widget group(MindMapMarkerGroup group, String title) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionLabel(title),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final marker in MindMapMarker.catalog)
                  if (marker.group == group)
                    _MarkerTile(
                      marker: marker,
                      palette: palette,
                      selected: node.icons.contains(marker.id),
                      onTap: () => _toggle(marker),
                    ),
              ],
            ),
          ],
        );
        final emojis = <MindMapMarker>[
          for (final id in node.icons)
            if (MindMapMarker.parse(id) case final marker?
                when marker.group == MindMapMarkerGroup.emoji)
              marker,
        ];
        return _SheetBody(
          title: l10n.mindMapMarkers,
          children: <Widget>[
            group(MindMapMarkerGroup.priority, l10n.mindMapMarkerPriority),
            group(MindMapMarkerGroup.progress, l10n.mindMapMarkerProgress),
            group(MindMapMarkerGroup.flag, l10n.mindMapMarkerFlag),
            group(MindMapMarkerGroup.star, l10n.mindMapMarkerStar),
            group(MindMapMarkerGroup.face, l10n.mindMapMarkerFace),
            group(MindMapMarkerGroup.symbol, l10n.mindMapMarkerSymbol),
            _SectionLabel(l10n.mindMapMarkerEmoji),
            Row(
              children: <Widget>[
                for (final marker in emojis)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MarkerTile(
                      marker: marker,
                      palette: palette,
                      selected: true,
                      onTap: () => _toggle(marker),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _emoji,
                    contextMenuBuilder: appTextContextMenuBuilder,
                    maxLength: 8,
                    decoration: InputDecoration(
                      hintText: l10n.mindMapEmojiHint,
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addEmoji(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.mindMapAdd,
                  onPressed: _addEmoji,
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
                ),
              ],
            ),
            if (node.icons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => widget.controller.updateNode(
                      widget.id,
                      (n) => n.copyWith(icons: const <String>[]),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.eraser, size: 14),
                    label: Text(l10n.mindMapClearMarkers),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({
    required this.marker,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final MindMapMarker marker;
  final MindMapPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget glyph = switch (marker.look) {
      MindMapNumberLook(:final number, :final color) => CircleAvatar(
        radius: 12,
        backgroundColor: palette.marker(color).accent,
        child: Text(
          '$number',
          style: TextStyle(
            color: palette.marker(color).onAccent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      MindMapProgressLook(:final percent) => SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressRing(
          value: percent / 100,
          color: palette.marker(MindMapMarkerColor.blue).accent,
          track: palette
              .marker(MindMapMarkerColor.blue)
              .accent
              .withValues(alpha: 0.16),
        ),
      ),
      MindMapGlyphLook(:final icon, :final color) => FaIcon(
        icon,
        size: 20,
        color: palette.marker(color).accent,
      ),
      MindMapEmojiLook(:final emoji) => Text(
        emoji,
        style: const TextStyle(fontSize: 20, height: 1),
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.secondary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: glyph,
        ),
      ),
    );
  }
}

/// 贴纸面板里的进度饼（与画布上的画法一致）。
class CircularProgressRing extends StatelessWidget {
  const CircularProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(value: value, color: color, track: track),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(rect.center, size.width / 2, Paint()..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect.deflate(size.width * 0.14),
        -1.5708,
        6.2832 * value,
        true,
        Paint()..color = color,
      );
    }
    canvas.drawCircle(
      rect.center,
      size.width / 2 - 0.6,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

// ---------------- 标签 ----------------

/// 标签：已有的为可删除的胶囊，下方输入新标签。
Future<void> showMindMapLabelsSheet(
  BuildContext context,
  MindMapEditingController controller,
  String id,
) => _showSheet(
  context,
  (BuildContext context) => _LabelsSheet(controller: controller, id: id),
);

class _LabelsSheet extends StatefulWidget {
  const _LabelsSheet({required this.controller, required this.id});

  final MindMapEditingController controller;
  final String id;

  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final value = _input.text.trim();
    if (value.isEmpty) return;
    widget.controller.updateNode(
      widget.id,
      (n) => n.labels.contains(value)
          ? n
          : n.copyWith(labels: <String>[...n.labels, value]),
    );
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _NodeListener(
      controller: widget.controller,
      id: widget.id,
      builder: (BuildContext context, MindMapNode node) => _SheetBody(
        title: l10n.mindMapLabels,
        children: <Widget>[
          if (node.labels.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final label in node.labels)
                  InputChip(
                    label: Text(label),
                    onDeleted: () => widget.controller.updateNode(
                      widget.id,
                      (n) => n.copyWith(
                        labels: <String>[
                          for (final l in n.labels)
                            if (l != label) l,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            autofocus: node.labels.isEmpty,
            contextMenuBuilder: appTextContextMenuBuilder,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.mindMapLabelHint,
              counterText: '',
              suffixIcon: IconButton(
                tooltip: l10n.mindMapAdd,
                onPressed: _add,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
    );
  }
}

// ---------------- 备注 ----------------

/// 备注：多行输入，边打边写（同一节点连续输入合并为一步撤销）；[readOnly]
/// 时只显示。
Future<void> showMindMapNoteSheet(
  BuildContext context,
  MindMapEditingController controller,
  String id, {
  bool readOnly = false,
}) => _showSheet(
  context,
  (BuildContext context) =>
      _NoteSheet(controller: controller, id: id, readOnly: readOnly),
);

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({
    required this.controller,
    required this.id,
    required this.readOnly,
  });

  final MindMapEditingController controller;
  final String id;
  final bool readOnly;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _input = TextEditingController(
    text: widget.controller.document.index[widget.id]?.note ?? '',
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _changed(String value) => widget.controller.updateNode(
    widget.id,
    (n) => n.copyWith(note: value.trim().isEmpty ? null : value),
    coalesce: ('note', widget.id),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _SheetBody(
      title: l10n.mindMapNote,
      children: <Widget>[
        if (widget.readOnly)
          SelectableText(
            _input.text,
            style: theme.textTheme.bodyLarge,
            contextMenuBuilder: appTextContextMenuBuilder,
          )
        else
          TextField(
            controller: _input,
            autofocus: _input.text.isEmpty,
            contextMenuBuilder: appTextContextMenuBuilder,
            minLines: 4,
            maxLines: 12,
            maxLength: kMindMapMaxTextLength,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: l10n.mindMapNoteHint,
              counterText: '',
            ),
            onChanged: _changed,
          ),
      ],
    );
  }
}

// ---------------- 链接 ----------------

/// 链接：网址或一篇日记；已有链接时可打开（由 [onOpen] 处理）或移除。
Future<void> showMindMapLinkSheet(
  BuildContext context,
  MindMapEditingController controller,
  String id, {
  ValueChanged<String>? onOpen,
}) => _showSheet(
  context,
  (BuildContext context) =>
      _LinkSheet(controller: controller, id: id, onOpen: onOpen),
);

enum _LinkKind { url, diary }

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.controller, required this.id, this.onOpen});

  final MindMapEditingController controller;
  final String id;
  final ValueChanged<String>? onOpen;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final String _current =
      widget.controller.document.index[widget.id]?.href?.trim() ?? '';
  late _LinkKind _kind = DiaryLinkTarget.isLink(_current)
      ? _LinkKind.diary
      : _LinkKind.url;
  late final TextEditingController _url = TextEditingController(
    text: DiaryLinkTarget.isLink(_current) ? '' : _current,
  );
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _write(String? href) {
    widget.controller.updateNode(widget.id, (n) => n.copyWith(href: href));
    Navigator.of(context).maybePop();
  }

  void _saveUrl() {
    var value = _url.text.trim();
    if (value.isEmpty) return;
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      setState(() => _error = context.l10n.mindMapLinkInvalid);
      return;
    }
    _write(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SheetBody(
      title: l10n.mindMapLink,
      children: <Widget>[
        if (_current.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: <Widget>[
                if (widget.onOpen != null)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: AppGlassField.tonalButtonStyle(context),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        widget.onOpen!(_current);
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.arrowUpRightFromSquare,
                        size: 14,
                      ),
                      label: Text(l10n.mindMapLinkOpen),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _write(null),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const FaIcon(FontAwesomeIcons.linkSlash, size: 14),
                  label: Text(l10n.mindMapLinkRemove),
                ),
              ],
            ),
          ),
        ExpressiveButtonGroup<_LinkKind>(
          minSegmentWidth: 72,
          segments: <ButtonSegment<_LinkKind>>[
            ButtonSegment<_LinkKind>(
              value: _LinkKind.url,
              label: Text(l10n.mindMapLinkUrl),
            ),
            ButtonSegment<_LinkKind>(
              value: _LinkKind.diary,
              label: Text(l10n.mindMapLinkDiary),
            ),
          ],
          selected: <_LinkKind>{_kind},
          onSelectionChanged: (value) => setState(() => _kind = value.first),
        ),
        const SizedBox(height: 12),
        if (_kind == _LinkKind.url)
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            contextMenuBuilder: appTextContextMenuBuilder,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'https://',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: l10n.mindMapAdd,
                onPressed: _saveUrl,
                icon: const FaIcon(FontAwesomeIcons.check, size: 16),
              ),
            ),
            onSubmitted: (_) => _saveUrl(),
          )
        else
          SizedBox(
            height: 360,
            child: DiaryLinkSearchView(
              kind: DiaryLinkKind.diary,
              onPick: (candidate) => _write(candidate.target.toHref()),
            ),
          ),
      ],
    );
  }
}
