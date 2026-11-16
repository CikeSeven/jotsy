import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../../widgets/rich_text/inline_rich_text_controller.dart';
import '../models/mind_map_markers.dart';
import '../viewmodels/mind_map_look.dart';
import '../models/mind_map_themes.dart';
import '../viewmodels/mind_map_palette.dart';
import '../viewmodels/mind_map_visuals.dart';

/// 大纲视图：同一张导图的缩进列表，与画布编辑的是同一份文档、同一个
/// 选中与编辑状态。
///
/// - 点一行选中并编辑文字；行首圆点为分支色，有子主题时是可点的折叠箭头；
///   字号按层级，主题的文字样式（整条的与局部的）照画，编辑框同样经
///   [InlineRichTextController] 设局部样式（格式条与快捷键与画布相同）；
/// - 编辑中：Enter 在后面加同级（行首回车加在前面），空行退格删除这一行并
///   编辑上一行；桌面另有 Tab / Shift + Tab 缩进与取消缩进、Alt + ↑ / ↓
///   上移下移；手机上这些操作在键盘上方的附件条里（由工作区提供）；
/// - 只读时只能展开收起（不写回文档，见 [MindMapEditingController] 的只读）。
class MindMapOutlineView extends StatefulWidget {
  const MindMapOutlineView({
    super.key,
    required this.controller,
    this.padding = EdgeInsets.zero,
    this.onNodePart,
  });

  final MindMapEditingController controller;
  final EdgeInsets padding;

  /// 点了一行的备注 / 链接标记。
  final void Function(String id, String part)? onNodePart;

  @override
  State<MindMapOutlineView> createState() => _MindMapOutlineViewState();
}

class _MindMapOutlineViewState extends State<MindMapOutlineView> {
  final Set<String> _readOnlyExpanded = <String>{};
  final Set<String> _readOnlyCollapsed = <String>{};

  MindMapEditingController get _controller => widget.controller;

  bool _collapsed(MindMapNode node) {
    if (!_controller.readOnly) return node.collapsed;
    if (_readOnlyCollapsed.contains(node.id)) return true;
    if (_readOnlyExpanded.contains(node.id)) return false;
    return node.collapsed;
  }

  void _toggle(MindMapNode node) {
    if (_controller.readOnly) {
      setState(() {
        if (_collapsed(node)) {
          _readOnlyCollapsed.remove(node.id);
          _readOnlyExpanded.add(node.id);
        } else {
          _readOnlyExpanded.remove(node.id);
          _readOnlyCollapsed.add(node.id);
        }
      });
      return;
    }
    _controller.toggleCollapsed(node.id);
  }

  List<(MindMapNode, int)> _rows(MindMapDocument document) {
    final rows = <(MindMapNode, int)>[];
    void visit(MindMapNode node, int depth) {
      rows.add((node, depth));
      if (_collapsed(node)) return;
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    visit(document.root, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final document = controller.document;
        final look = MindMapLook.of(context, document);
        final styles = look.styles;
        final rows = _rows(document);
        return ListView.builder(
          padding: widget.padding + const EdgeInsets.fromLTRB(8, 8, 16, 24),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int i) {
            final (node, depth) = rows[i];
            final visual = styles.visualOf(document.index, node);
            return _OutlineRow(
              key: ValueKey<String>('outline-${node.id}'),
              controller: controller,
              styles: styles,
              node: node,
              depth: depth,
              branchColor: depth == 0
                  ? Theme.of(context).colorScheme.primary
                  : visual.branchColor,
              collapsed: _collapsed(node),
              onToggle: () => _toggle(node),
              onNodePart: widget.onNodePart,
              previousVisible: i == 0 ? null : rows[i - 1].$1.id,
            );
          },
        );
      },
    );
  }
}

class _OutlineRow extends StatefulWidget {
  const _OutlineRow({
    super.key,
    required this.controller,
    required this.styles,
    required this.node,
    required this.depth,
    required this.branchColor,
    required this.collapsed,
    required this.onToggle,
    required this.onNodePart,
    required this.previousVisible,
  });

  final MindMapEditingController controller;
  final MindMapStyleResolver styles;
  final MindMapNode node;
  final int depth;
  final Color branchColor;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(String id, String part)? onNodePart;

  /// 列表里上一行的节点（空行退格后编辑它）。
  final String? previousVisible;

  @override
  State<_OutlineRow> createState() => _OutlineRowState();
}

class _OutlineRowState extends State<_OutlineRow> {
  InlineRichTextController? _text;
  FocusNode? _focus;

  MindMapEditingController get _controller => widget.controller;
  bool get _editing => _controller.editingId == widget.node.id;

  @override
  void didUpdateWidget(_OutlineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEditor();
  }

  @override
  void initState() {
    super.initState();
    _syncEditor();
  }

  @override
  void dispose() {
    _disposeEditor();
    super.dispose();
  }

  void _syncEditor() {
    if (_editing && _text == null) {
      final text = InlineRichTextController(
        runs: mindMapRunsOf(widget.node),
        onChanged: _onChanged,
      )..selection = TextSelection.collapsed(offset: widget.node.text.length);
      _text = text;
      _controller.textSession.attach(text);
      _focus = FocusNode(onKeyEvent: _onKey);
      _focus!.addListener(_onFocus);
      _controller.textSession.toolbarFocus.addListener(_onFocus);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focus?.requestFocus();
        Scrollable.ensureVisible(
          context,
          alignment: 0.4,
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          curve: ExpressiveMotion.effects,
        );
      });
    } else if (!_editing && _text != null) {
      _disposeEditor();
    }
  }

  void _disposeEditor() {
    if (_text case final text?) {
      _controller.textSession.detach(text);
      _controller.textSession.toolbarFocus.removeListener(_onFocus);
    }
    _text?.dispose();
    _focus?.removeListener(_onFocus);
    _focus?.dispose();
    _text = null;
    _focus = null;
  }

  void _onChanged(
    String text,
    List<InlineTextRun> runs, {
    bool format = false,
  }) => _controller.setRichText(widget.node.id, text, runs, format: format);

  void _onFocus() {
    if (!(_focus?.hasFocus ?? true) &&
        !_controller.textSession.keepsEditing &&
        _editing) {
      _controller.stopEditing();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final text = _text;
    if (text == null || text.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (inlineFormatShortcut(event) case final mark?) {
      text.toggle(mark);
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final id = widget.node.id;
    final isRoot = id == _controller.document.root.id;
    if (key == LogicalKeyboardKey.enter && !keys.isShiftPressed) {
      _controller.select(id);
      final atStart =
          text.selection.isCollapsed &&
          text.selection.baseOffset == 0 &&
          text.text.isNotEmpty;
      if (isRoot) {
        _controller.addChild(parentId: id);
      } else {
        _controller.addSibling(before: atStart);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace && text.text.isEmpty && !isRoot) {
      final previous = widget.previousVisible;
      _controller.select(id);
      _controller.deleteSelected();
      if (previous != null) _controller.startEditing(previous);
      return KeyEventResult.handled;
    }
    if (!AppPlatform.isDesktop) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.tab) {
      _controller.commit(
        keys.isShiftPressed
            ? MindMapOps.outdent(_controller.document, id)
            : MindMapOps.indent(_controller.document, id),
        select: id,
      );
      _controller.startEditing(id);
      return KeyEventResult.handled;
    }
    if (keys.isAltPressed &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      _controller.commit(
        MindMapOps.shift(
          _controller.document,
          id,
          up: key == LogicalKeyboardKey.arrowUp,
        ),
        select: id,
      );
      _controller.startEditing(id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _controller.stopEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final node = widget.node;
    final depth = widget.depth;
    final selected = _controller.selectedId == node.id;
    // 字号与粗细按层级，整条的文字样式（粗斜体、装饰线、颜色、高亮）
    // 叠在上面，完成的待办再整体变淡并划掉；局部样式逐段叠在最上面。
    var style = switch (depth) {
      0 => theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      1 => theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      _ => theme.textTheme.bodyLarge,
    }?.copyWith(color: scheme.onSurface);
    style = style?.merge(
      widget.styles.runStyle(MindMapNodeStyle(node.style).textMarks),
    );
    if (node.taskDone) {
      final color = style?.color ?? scheme.onSurface;
      style = style?.copyWith(
        decoration: TextDecoration.combine(<TextDecoration>[
          style.decoration ?? TextDecoration.none,
          TextDecoration.lineThrough,
        ]),
        color: color.withValues(alpha: color.a * 0.55),
      );
    }
    TextStyle? runStyle(InlineTextMarks marks) => widget.styles.runStyle(
      marks,
      base: style?.decoration,
      ink: style?.color,
      backdrop: scheme.surface,
      taskDone: node.taskDone,
    );
    _text
      ?..runStyle = runStyle
      ..base = inlineBaseMarksOf(style);
    final placeholder = depth == 0
        ? context.l10n.mindMapRootPlaceholder
        : context.l10n.mindMapNodePlaceholder;
    final hasChildren = node.children.isNotEmpty;
    final leading = SizedBox(
      width: 28,
      height: 28,
      child: hasChildren
          ? IconButton(
              padding: EdgeInsets.zero,
              iconSize: 13,
              onPressed: widget.onToggle,
              icon: AnimatedRotation(
                turns: widget.collapsed ? 0 : 0.25,
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                curve: ExpressiveMotion.effects,
                child: FaIcon(
                  FontAwesomeIcons.angleRight,
                  size: 13,
                  color: widget.branchColor,
                ),
              ),
            )
          : Center(
              child: Container(
                width: depth == 0 ? 10 : 7,
                height: depth == 0 ? 10 : 7,
                decoration: BoxDecoration(
                  color: widget.branchColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
    );
    final markers = <MindMapMarker>[
      for (final id in node.icons) ?MindMapMarker.parse(id),
    ];
    final Widget text = _editing && _text != null
        ? TextField(
            controller: _text,
            focusNode: _focus,
            style: style,
            maxLines: null,
            maxLength: kMindMapMaxTextLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            contextMenuBuilder: appTextContextMenuBuilder,
            keyboardType: TextInputType.multiline,
            textInputAction: AppPlatform.isDesktop
                ? TextInputAction.newline
                : TextInputAction.done,
            onSubmitted: (_) => _controller.stopEditing(),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterText: '',
              hintText: placeholder,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: node.text.trim().isEmpty
                ? Text(
                    placeholder,
                    style: style?.copyWith(color: scheme.onSurfaceVariant),
                  )
                : Text.rich(
                    TextSpan(
                      style: style,
                      children: <InlineSpan>[
                        for (final run in mindMapRunsOf(node))
                          TextSpan(text: run.text, style: runStyle(run.marks)),
                      ],
                    ),
                  ),
          );
    final href = node.href?.trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(left: depth * 22.0, bottom: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (_controller.readOnly) {
              if (hasChildren) widget.onToggle();
              return;
            }
            _controller.startEditing(node.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(padding: const EdgeInsets.only(top: 2), child: leading),
                if (node.isTask)
                  IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: _controller.readOnly
                        ? null
                        : () => _controller.toggleTask(node.id),
                    icon: FaIcon(
                      node.taskDone
                          ? FontAwesomeIcons.solidSquareCheck
                          : FontAwesomeIcons.square,
                      size: 17,
                      color: widget.branchColor,
                    ),
                  ),
                for (final marker in markers)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: _OutlineMarker(marker: marker),
                  ),
                const SizedBox(width: 4),
                Expanded(child: text),
                if ((node.note ?? '').trim().isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onNodePart?.call(node.id, 'note'),
                    icon: FaIcon(
                      FontAwesomeIcons.solidNoteSticky,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (href.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onNodePart?.call(node.id, 'link'),
                    icon: FaIcon(
                      DiaryLinkTarget.isLink(href)
                          ? FontAwesomeIcons.bookOpen
                          : FontAwesomeIcons.link,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (node.collapsed && hasChildren)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 6),
                    child: Text(
                      '+${_controller.document.index.descendantCountOf(node.id)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.branchColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 大纲行里的一个贴纸（小号）。
class _OutlineMarker extends StatelessWidget {
  const _OutlineMarker({required this.marker});

  final MindMapMarker marker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = MindMapPalette.of(
      MindMapThemeSpec.of(MindMapThemeId.follow),
      scheme,
    );
    return switch (marker.look) {
      MindMapNumberLook(:final number, :final color) => CircleAvatar(
        radius: 9,
        backgroundColor: palette.marker(color).accent,
        child: Text(
          '$number',
          style: TextStyle(
            color: palette.marker(color).onAccent,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      MindMapProgressLook(:final percent) => Text(
        '$percent%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.marker(MindMapMarkerColor.blue).accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      MindMapGlyphLook(:final icon, :final color) => FaIcon(
        icon,
        size: 15,
        color: palette.marker(color).accent,
      ),
      MindMapEmojiLook(:final emoji) => Text(
        emoji,
        style: const TextStyle(fontSize: 15, height: 1.1),
      ),
    };
  }
}
