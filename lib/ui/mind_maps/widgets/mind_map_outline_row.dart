import 'dart:math' as math;

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
import '../../diaries/viewmodels/diary_text_appearance.dart';
import '../../widgets/rich_text/inline_rich_text_controller.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../models/mind_map_markers.dart';
import '../models/mind_map_themes.dart';
import '../viewmodels/mind_map_outline_style.dart';
import '../viewmodels/mind_map_palette.dart';
import '../viewmodels/mind_map_visuals.dart';

/// 大纲视图里的一行主题（见 MindMapOutlineView）。
///
/// - 文字样式见 [mindMapOutlineTextStyle]（随正文排版、层级与主题字号）；
///   行首的折叠箭头 / 圆点、待办框、贴纸与行尾的备注 / 链接标记都对齐到
///   文字第一行的中线，字号与行距变了也不错开；
/// - 点一行编辑文字（只读时展开收起）；长按（手机）或右键（桌面）弹出与
///   画布相同的主题菜单（[onNodeMenu]），正在编辑的这一行不弹，长按留给
///   输入框选字；
/// - 开始编辑时不主动滚动：输入框获得焦点、键盘升起、打字换行时自己把光标
///   露出来（只在被挡住时最小幅度地滚），[revealPadding] 是光标四周要让开
///   的距离（顶上盖着顶栏与视图切换）。为什么不用 `Scrollable.ensureVisible`
///   按比例对齐：那会把本来就看得见的行也挪走，键盘升着时视口只剩上面一
///   小截，40% 处紧贴顶栏，点哪行哪行就跳到最上面；
/// - 编辑中的按键：Enter 在后面加同级（行首回车加在前面，手机软键盘的回车
///   同样、键盘不收起），空行退格删除这一行并编辑上一行；桌面另有 Tab /
///   Shift + Tab 缩进与取消缩进、Alt + ↑ / ↓ 上移下移、Esc 结束编辑。
class MindMapOutlineRow extends StatefulWidget {
  const MindMapOutlineRow({
    super.key,
    required this.controller,
    required this.styles,
    required this.appearance,
    required this.node,
    required this.depth,
    required this.branchColor,
    required this.collapsed,
    required this.onToggle,
    required this.onNodePart,
    required this.onNodeMenu,
    required this.previousVisible,
    this.revealPadding = const EdgeInsets.all(20),
  });

  final MindMapEditingController controller;
  final MindMapStyleResolver styles;
  final DiaryTextAppearance appearance;
  final MindMapNode node;
  final int depth;
  final Color branchColor;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(String id, String part)? onNodePart;
  final void Function(String id, Offset globalPosition)? onNodeMenu;

  /// 列表里上一行的节点（空行退格后编辑它）。
  final String? previousVisible;

  /// 编辑框露出光标时四周让开的距离（`TextField.scrollPadding`）。
  final EdgeInsets revealPadding;

  /// 文字上下的留白（编辑框与只读文字相同，开始编辑时行高不跳）。
  static const double textPadding = 6;

  @override
  State<MindMapOutlineRow> createState() => _MindMapOutlineRowState();
}

class _MindMapOutlineRowState extends State<MindMapOutlineRow> {
  InlineRichTextController? _text;
  FocusNode? _focus;

  MindMapEditingController get _controller => widget.controller;
  bool get _editing => _controller.editingId == widget.node.id;

  @override
  void didUpdateWidget(MindMapOutlineRow oldWidget) {
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
        if (mounted) _focus?.requestFocus();
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

  void _openMenu(Offset globalPosition) {
    final id = widget.node.id;
    _controller.select(id);
    widget.onNodeMenu?.call(id, globalPosition);
  }

  /// 回车：在这一行后面加同级（光标在有字的行首时加在前面），中心主题加
  /// 子主题；新主题接着编辑，键盘不收起。硬件回车与手机软键盘的动作键都
  /// 走这里。
  void _addNextTopic() {
    final text = _text;
    if (text == null) return;
    final id = widget.node.id;
    _controller.select(id);
    final atStart =
        text.selection.isCollapsed &&
        text.selection.baseOffset == 0 &&
        text.text.isNotEmpty;
    if (id == _controller.document.root.id) {
      _controller.addChild(parentId: id);
    } else {
      _controller.addSibling(before: atStart);
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
      _addNextTopic();
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
    final style = mindMapOutlineTextStyle(
      (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
      ),
      appearance: widget.appearance,
      styles: widget.styles,
      node: node,
      depth: depth,
    );
    TextStyle? runStyle(InlineTextMarks marks) => widget.styles.runStyle(
      marks,
      base: style.decoration,
      ink: style.color,
      backdrop: scheme.surface,
      taskDone: node.taskDone,
    );
    _text
      ?..runStyle = runStyle
      ..base = inlineBaseMarksOf(style);
    // 第一行文字的中线：行首行尾的小部件按它居中（字号、行距、系统字体
    // 缩放都会改变行高）。
    final lineExtent =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16) *
        (style.height ?? 1.2);
    final lineCenter = MindMapOutlineRow.textPadding + lineExtent / 2;
    EdgeInsets alignTo(double height, {double left = 0, double right = 0}) =>
        EdgeInsets.only(
          top: math.max(0, lineCenter - height / 2),
          left: left,
          right: right,
        );
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
    const textPadding = EdgeInsets.symmetric(
      vertical: MindMapOutlineRow.textPadding,
    );
    final Widget text = _editing && _text != null
        ? TextField(
            controller: _text,
            focusNode: _focus,
            style: style,
            maxLines: null,
            maxLength: kMindMapMaxTextLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            contextMenuBuilder: appTextContextMenuBuilder,
            scrollPadding: widget.revealPadding,
            keyboardType: TextInputType.multiline,
            // 手机软键盘的回车是动作键（不输入换行），按下同硬件回车加下一
            // 个主题，所以标成“下一项”而不是“完成”；结束编辑经附件条的
            // 完成。必须给 onEditingComplete：不给时 next / done 动作会先
            // 让输入框失焦、收起键盘。桌面的回车由 [_onKey] 接走。
            textInputAction: AppPlatform.isDesktop
                ? TextInputAction.newline
                : TextInputAction.next,
            onEditingComplete: _addNextTopic,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterText: '',
              hintText: placeholder,
              contentPadding: textPadding,
            ),
          )
        : Padding(
            padding: textPadding,
            child: node.text.trim().isEmpty
                ? Text(
                    placeholder,
                    style: style.copyWith(color: scheme.onSurfaceVariant),
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
    // 小号的 IconButton（compact）是 40dp 见方。
    const compactButton = 40.0;
    const markerSize = 18.0;
    final href = node.href?.trim() ?? '';
    // 菜单手势始终挂着（不用时回调为 null），开始 / 结束编辑时这一行的子树
    // 不重新挂载。
    final menuEnabled =
        widget.onNodeMenu != null && !_controller.readOnly && !_editing;
    return Padding(
      padding: EdgeInsets.only(left: depth * 22.0, bottom: 2),
      child: GestureDetector(
        onLongPressStart: menuEnabled
            ? (details) => _openMenu(details.globalPosition)
            : null,
        onSecondaryTapUp: menuEnabled
            ? (details) => _openMenu(details.globalPosition)
            : null,
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
                  Padding(padding: alignTo(28), child: leading),
                  if (node.isTask)
                    Padding(
                      padding: alignTo(compactButton),
                      child: IconButton(
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
                    ),
                  for (final marker in markers)
                    Padding(
                      padding: alignTo(markerSize, right: 4),
                      child: SizedBox(
                        height: markerSize,
                        child: Center(child: _OutlineMarker(marker: marker)),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(child: text),
                  if ((node.note ?? '').trim().isNotEmpty)
                    Padding(
                      padding: alignTo(compactButton),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            widget.onNodePart?.call(node.id, 'note'),
                        icon: FaIcon(
                          FontAwesomeIcons.solidNoteSticky,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (href.isNotEmpty)
                    Padding(
                      padding: alignTo(compactButton),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            widget.onNodePart?.call(node.id, 'link'),
                        icon: FaIcon(
                          DiaryLinkTarget.isLink(href)
                              ? FontAwesomeIcons.bookOpen
                              : FontAwesomeIcons.link,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (node.collapsed && hasChildren)
                    Padding(
                      padding: alignTo(markerSize, left: 6),
                      child: SizedBox(
                        height: markerSize,
                        child: Center(
                          child: Text(
                            '+${_controller.document.index.descendantCountOf(node.id)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.branchColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
