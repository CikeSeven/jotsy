import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_menu/expressive_menu_surface.dart';
import '../../controllers/diary_editor_controller.dart';

/// 光标旁的内联菜单会话（`/` 命令与 `@` 日记链接共用）。
///
/// 为什么不弹底部面板：面板是新路由，会抢走正文焦点，键盘先收起再为搜索框
/// 弹出，筛选词还要另外输入。这里沿用 Notion 式的内联菜单：触发字写进正文，
/// 用户接着输入的文字（如 `/代码`、`@旅行`）就是筛选词，焦点与键盘始终留在
/// 正文；选中时经 [consumeTrigger] 删掉“触发字 + 筛选词”再执行。
///
/// 会话边界：光标离开触发块、退到触发字之前、触发字被删掉、筛选词超过
/// [maxQueryLength] 字，或筛选词以空格结尾且 [hasMatchesFor] 认为没有匹配
/// 项时自动结束；返回键与点按菜单外也结束（见 [DiaryCaretMenuHost]），正文
/// 里已输入的文字原样保留。
abstract class DiaryCaretMenuSession extends ChangeNotifier {
  DiaryCaretMenuSession(this.editor);

  final DiaryEditorController editor;

  af.Node? _node;
  int _trigger = 0;
  String _query = '';
  StreamSubscription<af.EditorTransactionValue>? _transactions;

  /// 触发字（`/`、`@`）；会话期间它必须一直留在 [_trigger] 处。
  String get triggerCharacter;

  /// 筛选词的长度上限，超过即视为用户在写正文、结束会话。
  int get maxQueryLength => 24;

  /// 筛选词（已去掉结尾空格）是否还有匹配项：以空格结尾又没有匹配时结束。
  bool hasMatchesFor(String query);

  /// 筛选词变化（含会话刚开启时的空词）后调用，子类据此更新候选。
  @protected
  void onQueryChanged() {}

  /// 会话结束时调用，子类据此清掉候选与计时器。
  @protected
  void onClosed() {}

  bool get isOpen => _node != null;

  /// 触发字之后、光标之前的文字。
  String get query => _query;

  /// 开启会话：[node] 的 [triggerOffset] 处已写好触发字。
  void openAt(af.Node node, int triggerOffset) {
    close();
    _node = node;
    _trigger = triggerOffset;
    _query = '';
    editor.state.selectionNotifier.addListener(_sync);
    _transactions = editor.state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _sync();
    });
    onQueryChanged();
    notifyListeners();
  }

  void close() {
    if (_node == null) return;
    _node = null;
    _query = '';
    editor.state.selectionNotifier.removeListener(_sync);
    _transactions?.cancel();
    _transactions = null;
    onClosed();
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
        selection.end.offset <= _trigger ||
        _trigger >= text.length ||
        text[_trigger] != triggerCharacter) {
      close();
      return;
    }
    final query = text.substring(_trigger + 1, selection.end.offset);
    if (query.length > maxQueryLength ||
        (query.endsWith(' ') && !hasMatchesFor(query.trim()))) {
      close();
      return;
    }
    final changed = query != _query;
    _query = query;
    if (changed) onQueryChanged();
    // 筛选词不变时也通知：光标可能折到了下一行，宿主据此重新定位。
    notifyListeners();
  }

  /// 结束会话并删掉“触发字 + 筛选词”，光标停在触发字原来的位置；返回该
  /// 位置。会话没开或正文已关闭时为 null，什么也不改。
  af.Position? consumeTrigger() {
    final node = _node;
    final selection = editor.state.selection;
    final trigger = _trigger;
    close();
    if (node == null || selection == null || editor.isDisposed) return null;
    final position = af.Position(path: node.path, offset: trigger);
    final end = selection.end.offset;
    if (end > trigger) {
      final transaction = editor.state.transaction
        ..deleteText(node, trigger, end - trigger)
        ..afterSelection = af.Selection.collapsed(position);
      editor.apply(transaction);
    }
    return position;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

/// 把会话的菜单浮在光标旁：下方放得下（扣掉键盘与底部浮层）就在光标行
/// 下方，否则翻到上方；水平方向贴着光标、夹在屏幕内 16dp。外观与全应用
/// 弹出菜单相同（[ExpressiveMenuSurface]），展开 `fast` 淡入并从 0.96 放大。
/// 菜单内容由 [menu] 构建，会话每次通知都重建。
class DiaryCaretMenuHost extends StatefulWidget {
  const DiaryCaretMenuHost({
    super.key,
    required this.session,
    required this.coveredHeight,
    required this.menu,
    required this.child,
  });

  final DiaryCaretMenuSession session;

  /// 叠在正文底部的浮层（工具栏等）高度，菜单不压在它们上面。
  final double coveredHeight;
  final WidgetBuilder menu;
  final Widget child;

  @override
  State<DiaryCaretMenuHost> createState() => _DiaryCaretMenuHostState();
}

class _DiaryCaretMenuHostState extends State<DiaryCaretMenuHost>
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
    widget.session.addListener(_changed);
  }

  @override
  void didUpdateWidget(DiaryCaretMenuHost old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      old.session.removeListener(_changed);
      widget.session.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    _history?.remove();
    _revealCurve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (widget.session.isOpen) {
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
            widget.session.close();
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
      if (!mounted || !widget.session.isOpen) return;
      _schedule();
      final rects = widget.session.editor.state.selectionRects();
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
        if (widget.session.isOpen) _schedule();
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
        onTapOutside: (_) => widget.session.close(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_revealCurve),
          alignment: placeBelow ? Alignment.topLeft : Alignment.bottomLeft,
          child: ExpressiveMenuSurface(
            reveal: _revealCurve,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListenableBuilder(
                listenable: widget.session,
                builder: (context, _) => widget.menu(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 菜单行：32dp 次要容器色图标块 + 内容（`/` 命令与 `@` 候选共用）。
///
/// 不用 MenuItemButton：按钮会在点按时取得焦点，正文因此失焦、键盘收起。
/// 这里的 InkWell 不参与焦点（`canRequestFocus: false`）。[highlighted] 为
/// 键盘选中的行（桌面 ↑ / ↓），底色与悬停相同。
class DiaryCaretMenuItem extends StatelessWidget {
  const DiaryCaretMenuItem({
    super.key,
    required this.leading,
    required this.child,
    required this.onTap,
    this.highlighted = false,
  });

  final Widget leading;
  final Widget child;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: highlighted,
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
          child: Ink(
            decoration: BoxDecoration(
              color: highlighted
                  ? colors.primary.withValues(alpha: 0.08)
                  : null,
              borderRadius: BorderRadius.circular(20),
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: leading,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 菜单里的分组小标题与“没有结果”行。
class DiaryCaretMenuCaption extends StatelessWidget {
  const DiaryCaretMenuCaption(this.text, {super.key, this.first = false});

  final String text;

  /// 第一个分组上方只留 4dp。
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, first ? 4 : 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 没有匹配项时的一行：放大镜 + 说明。
class DiaryCaretMenuEmpty extends StatelessWidget {
  const DiaryCaretMenuEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
