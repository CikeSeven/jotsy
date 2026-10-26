import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu_surface.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_commands.dart';

/// 手机上的 `/` 命令会话。
///
/// 为什么不弹底部面板：面板是新路由，会抢走正文焦点，键盘先收起再为搜索框
/// 弹出，筛选词还要另外输入。这里沿用 Notion 式的内联菜单：`/` 写进正文，
/// 用户接着输入的文字（如 `/代码`、`/h2`）就是筛选词，焦点与键盘始终留在
/// 正文；选中命令时删掉 `/筛选词` 再执行。
///
/// 会话边界：光标离开触发块、退到斜杠之前、斜杠被删掉、筛选词超过 24 字，
/// 或筛选词以空格结尾且没有匹配项时自动结束；返回键与点按菜单外也结束，
/// 正文里已输入的文字原样保留。
class DiarySlashMenuController extends ChangeNotifier {
  DiarySlashMenuController(this.editor);

  final DiaryEditorController editor;

  af.Node? _node;
  int _slash = 0;
  String _query = '';
  List<DiaryBlockCommand> _commands = const [];
  StreamSubscription<af.EditorTransactionValue>? _transactions;

  bool get isOpen => _node != null;

  /// 斜杠之后、光标之前的文字。
  String get query => _query;

  /// 按筛选词过滤后的命令，保持定义顺序（分组顺序）。
  List<DiaryBlockCommand> get matches =>
      _commands.where((command) => command.matches(_query)).toList();

  void open(af.Node node, int slashOffset, List<DiaryBlockCommand> commands) {
    close();
    _node = node;
    _slash = slashOffset;
    _query = '';
    _commands = commands;
    editor.state.selectionNotifier.addListener(_sync);
    _transactions = editor.state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _sync();
    });
    notifyListeners();
  }

  void close() {
    if (_node == null) return;
    _node = null;
    _query = '';
    editor.state.selectionNotifier.removeListener(_sync);
    _transactions?.cancel();
    _transactions = null;
    notifyListeners();
  }

  void _sync() {
    final node = _node;
    if (node == null) return;
    final selection = editor.state.selection;
    final text = node.delta?.toPlainText();
    if (editor.isDisposed ||
        node.parent == null ||
        text == null ||
        selection == null ||
        !selection.isCollapsed ||
        !selection.end.path.equals(node.path) ||
        selection.end.offset <= _slash ||
        _slash >= text.length ||
        text[_slash] != '/') {
      close();
      return;
    }
    final query = text.substring(_slash + 1, selection.end.offset);
    if (query.length > 24 ||
        (query.endsWith(' ') &&
            !_commands.any((command) => command.matches(query.trim())))) {
      close();
      return;
    }
    // 筛选词不变时也通知：光标可能折到了下一行，宿主据此重新定位。
    _query = query;
    notifyListeners();
  }

  /// 删掉 `/筛选词`，再按命令转换当前块或插入内容。
  void run(DiaryBlockCommand command) {
    final node = _node;
    final selection = editor.state.selection;
    close();
    if (node == null || selection == null || editor.isDisposed) return;
    final end = selection.end.offset;
    if (end > _slash) {
      final transaction = editor.state.transaction
        ..deleteText(node, _slash, end - _slash)
        ..afterSelection = af.Selection.collapsed(
          af.Position(path: node.path, offset: _slash),
        );
      editor.apply(transaction);
    }
    applyDiaryBlockCommand(editor, command);
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

/// 把 `/` 菜单浮在光标旁：下方放得下（扣掉键盘与底部浮层）就在光标行
/// 下方，否则翻到上方；水平方向贴着光标、夹在屏幕内 16dp。外观与全应用
/// 弹出菜单相同（[ExpressiveMenuSurface]），展开 `fast` 淡入并从 0.96 放大。
class DiarySlashMenuHost extends StatefulWidget {
  const DiarySlashMenuHost({
    super.key,
    required this.menu,
    required this.coveredHeight,
    required this.child,
  });

  final DiarySlashMenuController menu;

  /// 叠在正文底部的浮层（工具栏等）高度，菜单不压在它们上面。
  final double coveredHeight;
  final Widget child;

  @override
  State<DiarySlashMenuHost> createState() => _DiarySlashMenuHostState();
}

class _DiarySlashMenuHostState extends State<DiarySlashMenuHost>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.fast,
  );
  late final CurvedAnimation _revealCurve = CurvedAnimation(
    parent: _reveal,
    curve: ExpressiveMotion.effects,
  );
  Rect? _caret;

  /// 菜单可用区域的下沿（Overlay 坐标）：编辑器下沿与键盘上沿取较高者，
  /// 再扣掉叠在正文底部的浮层，与光标避让（DiaryEditorViewport）同一口径。
  double? _bottomLimit;
  LocalHistoryEntry? _history;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.menu.addListener(_changed);
  }

  @override
  void didUpdateWidget(DiarySlashMenuHost old) {
    super.didUpdateWidget(old);
    if (old.menu != widget.menu) {
      old.menu.removeListener(_changed);
      widget.menu.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.menu.removeListener(_changed);
    _history?.remove();
    _revealCurve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (widget.menu.isOpen) {
      if (!_portal.isShowing) {
        _portal.show();
        _reveal.duration = ExpressiveMotion.duration(
          context,
          ExpressiveMotion.fast,
        );
        _reveal.forward(from: 0);
        _history = LocalHistoryEntry(
          onRemove: () {
            _history = null;
            widget.menu.close();
          },
        );
        ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
      }
      _schedule();
    } else if (_portal.isShowing) {
      _portal.hide();
      final history = _history;
      _history = null;
      history?.remove();
    }
  }

  /// 光标几何要等本帧布局完成后才准确。菜单打开期间每帧结束都核对一次
  /// （帧尾回调不请求新帧）：页头建议条收起这类动画会移动光标所在行。
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.menu.isOpen) return;
      _schedule();
      final rects = widget.menu.editor.state.selectionRects();
      final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
      final host = context.findRenderObject();
      if (rects.isEmpty ||
          overlay is! RenderBox ||
          !overlay.hasSize ||
          host is! RenderBox ||
          !host.hasSize) {
        return;
      }
      final view = View.of(context);
      final keyboardTop =
          (view.physicalSize.height - view.viewInsets.bottom) /
          view.devicePixelRatio;
      final hostBottom = host.localToGlobal(Offset(0, host.size.height)).dy;
      final bottom =
          overlay
              .globalToLocal(Offset(0, math.min(hostBottom, keyboardTop)))
              .dy -
          widget.coveredHeight;
      final caret =
          overlay.globalToLocal(rects.first.topLeft) & rects.first.size;
      if (caret != _caret || bottom != _bottomLimit) {
        setState(() {
          _caret = caret;
          _bottomLimit = bottom;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        if (widget.menu.isOpen) _schedule();
        return false;
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: widget.child,
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final caret = _caret;
    final available = _bottomLimit;
    if (caret == null || available == null) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final size = media.size;
    final width = math.min(300.0, size.width - 32);
    final bottomLimit = available - 8;
    // 不盖住顶栏：上方最多到状态栏下 56dp 处。
    final topLimit = media.padding.top + kToolbarHeight + 8;
    final below = bottomLimit - (caret.bottom + 6);
    final above = (caret.top - 6) - topLimit;
    const preferred = 320.0;
    final placeBelow = below >= math.min(preferred, 200) || below >= above;
    final maxHeight = math.max(
      120.0,
      math.min(preferred, placeBelow ? below : above),
    );
    final left = (caret.left - 20).clamp(16.0, size.width - width - 16);
    return Positioned(
      left: left,
      width: width,
      top: placeBelow ? caret.bottom + 6 : null,
      bottom: placeBelow ? null : size.height - caret.top + 6,
      child: TapRegion(
        onTapOutside: (_) => widget.menu.close(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_revealCurve),
          alignment: placeBelow ? Alignment.topLeft : Alignment.bottomLeft,
          child: ExpressiveMenuSurface(
            reveal: _revealCurve,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListenableBuilder(
                listenable: widget.menu,
                builder: (context, _) => _SlashMenuList(menu: widget.menu),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashMenuList extends StatelessWidget {
  const _SlashMenuList({required this.menu});

  final DiarySlashMenuController menu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final matches = menu.matches;
    final grouped = menu.query.isEmpty;
    final caption = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.diaryEditorCommandEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final children = <Widget>[];
    DiaryBlockCommandGroup? group;
    for (final command in matches) {
      if (grouped && command.group != group) {
        group = command.group;
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(16, children.isEmpty ? 4 : 12, 16, 4),
            child: Text(
              diaryBlockCommandGroupLabel(l10n, command.group),
              style: caption,
            ),
          ),
        );
      }
      children.add(
        _SlashMenuItem(command: command, onTap: () => menu.run(command)),
      );
    }
    if (grouped) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            l10n.diaryEditorCommandTypeToFilter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: l10n.diaryEditorSlashCommands,
      explicitChildNodes: true,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        children: children,
      ),
    );
  }
}

/// 命令行：32dp 次要容器色图标块 + 名称 + 行尾 Markdown 写法。
///
/// 不用 MenuItemButton：按钮会在点按时取得焦点，正文因此失焦、键盘收起。
/// 这里的 InkWell 不参与焦点（`canRequestFocus: false`）。
class _SlashMenuItem extends StatelessWidget {
  const _SlashMenuItem({required this.command, required this.onTap});

  final DiaryBlockCommand command;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final markdown = command.markdown;
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? colors.primary.withValues(alpha: 0.12)
                : states.contains(WidgetState.hovered)
                ? colors.primary.withValues(alpha: 0.08)
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _CommandIcon(command: command),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      command.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (markdown != null) ...[
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Text(
                        markdown,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Menlo', 'Consolas'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 标题命令在图标上叠一个小号级别数字，三级标题一眼可分。
class _CommandIcon extends StatelessWidget {
  const _CommandIcon({required this.command});

  final DiaryBlockCommand command;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = command.attributes['level'];
    if (command.type != 'heading' || level is! int) {
      return FaIcon(command.icon, size: 14, color: colors.onSecondaryContainer);
    }
    return Text(
      'H$level',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: colors.onSecondaryContainer,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}
