import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart'
    show DragStartBehavior, kLongPressTimeout, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_block_selection.dart';
import '../../controllers/diary_editor_controller.dart';
import '../diary_block_actions/diary_block_actions.dart';
import 'diary_block_drop_targets.dart';
import 'diary_block_line_geometry.dart';
import 'diary_block_select_target.dart';
import 'diary_block_selection_painter.dart';
import 'diary_edge_auto_scroll.dart';
import 'diary_editor_trailing_region.dart';
import 'diary_editor_visible_range.dart';

/// 段落选择模式在正文上的一层（段落把手层里、编辑器外面）。模式外只是
/// 透传，不多做任何事。模式里：
/// - 绘制选中块的色块（[DiaryBlockSelectionPainter]，文字块衬在正文下、
///   自带底色的块盖在正文上），逐块淡入淡出（`fast`）；退出后色块淡出完
///   才撤掉绘制；
/// - 左侧页边距那一列（页边距 + 4dp，不画任何东西）的手势：点按切换；竖向
///   滑动连选 / 连续取消（以起点那块的新状态为准，以开始滑动时的选择为底
///   逐帧重算，滑回去的块恢复原状），到看得见的范围边缘自动滚动；长按拖动
///   整组。这一列吃掉竖向拖动，从页边距起手不滚动页面；
/// - 自己取得焦点，接实体键盘的 Esc（退出、键盘不弹）/ Enter（完成）/
///   Delete / Backspace（删除）/ Ctrl·⌘ + A / C / X / D（全选 / 复制 /
///   剪切 / 创建副本）/ Alt + Shift + ↑ / ↓（移动）；焦点交给别的输入框
///   （点标题）即退出；
/// - 每次增删、移动块后：页面以一个不受影响、看得见的顶层块为锚点停在原处
///   （见 `diaryBlockDragAnchor`；上游长列表按跳转过的那一项排版，块挪过
///   锚点时整页会错开），再把选中的块滚进看得见的范围；
/// - 退出后按退出方式（[DiaryBlockSelectionExit]）恢复光标与键盘：「完成」
///   光标回到第一块末尾、进入时键盘弹着就重新弹出；Esc / 返回键光标同样
///   回去、手机上键盘保持收起；别处接手的不动选区。
///
/// 输入：编辑控制器、几何、把手层的拖动入口；输出：选择变化与段落操作，
/// 不直接改文档以外的状态。
class DiaryBlockSelectionLayer extends StatefulWidget {
  const DiaryBlockSelectionLayer({
    super.key,
    required this.controller,
    required this.relay,
    required this.geometry,
    required this.child,
    this.focusNode,
    this.contentLeft = 0,
    this.childIndent = 28,
    this.coveredHeight = 0,
    this.pinPath,
    this.revealPath,
  });

  final DiaryEditorController controller;
  final DiaryBlockDragRelay relay;
  final DiaryBlockLineGeometry geometry;
  final Widget child;

  /// 正文的焦点：退出后要回到正文时请求它。
  final FocusNode? focusNode;
  final double contentLeft;
  final double childIndent;

  /// 编辑器底部被浮层（段落操作栏）盖住的高度：揭示与自动滚动不计入。
  final double coveredHeight;

  /// 让顶层块停在列表视口的给定比例处（以它为锚点），见把手层。
  final void Function(af.Path path, double alignment)? pinPath;

  /// 跳到某一块（它远在视口外、还没建出来时）。
  final void Function(af.Path path)? revealPath;

  @override
  State<DiaryBlockSelectionLayer> createState() =>
      _DiaryBlockSelectionLayerState();
}

class _DiaryBlockSelectionLayerState extends State<DiaryBlockSelectionLayer>
    with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode(debugLabel: 'DiaryBlockSelection');

  /// 绘制的重绘源之一：滚动、布局变化时加一。
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  StreamSubscription<af.EditorTransactionValue>? _transactions;
  bool _watching = false;
  int? _signature;

  /// 增删块的事务之前量好的锚点，事务之后钉住。
  (af.Node, double)? _anchor;
  bool _revealScheduled = false;

  // ---- 选中色的淡入淡出 ----

  /// 要画的块与它的淡入进度（0–1，线性；绘制时再套曲线）：选中的块朝 1 走，
  /// 取消的朝 0 走、到 0 即移出。退出模式后选择为空，全部淡出。
  final Map<af.Node, double> _fades = <af.Node, double>{};
  late final Ticker _fadeTicker = createTicker(_tickFade);
  Duration _fadeElapsed = Duration.zero;

  // ---- 页边距里连选 ----
  late final Ticker _rangeTicker = createTicker((_) => _trackRange());
  late final DiaryEdgeAutoScrollDriver _autoScroll = DiaryEdgeAutoScrollDriver(
    _trackRange,
  );
  af.Node? _rangeFrom;
  af.Node? _rangeTo;
  bool _rangeSelect = true;
  List<af.Node> _rangeBase = const [];
  Offset? _rangePointer;

  /// 页边距那一列按下的指针：长按时交给把手层拖动整组。
  int? _pointer;

  /// 正文上按下的点与时刻：点在最后一块下方的空白处即「完成」。
  (int, Offset, Duration)? _down;

  DiaryBlockSelection get _selection => widget.controller.blockSelection;

  @override
  void initState() {
    super.initState();
    _bind(widget.controller);
    _focus.addListener(_onFocus);
  }

  void _bind(DiaryEditorController controller) {
    controller.blockSelection.addListener(_onSelectionChanged);
    controller.blockSelection.active.addListener(_onActive);
    if (controller.blockSelection.isActive) _onActive();
  }

  void _unbind(DiaryEditorController controller) {
    controller.blockSelection.removeListener(_onSelectionChanged);
    controller.blockSelection.active.removeListener(_onActive);
    unawaited(_transactions?.cancel());
    _transactions = null;
  }

  @override
  void didUpdateWidget(DiaryBlockSelectionLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _unbind(old.controller);
      _fades.clear();
      _bind(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbind(widget.controller);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _rangeTicker.dispose();
    _fadeTicker.dispose();
    _autoScroll.stop();
    _repaint.dispose();
    super.dispose();
  }

  void _onActive() {
    if (!mounted) return;
    if (_selection.isActive) {
      _transactions ??= widget.controller.state.transactionStream.listen(
        _onTransaction,
      );
      // 等这一帧建好（焦点节点挂上可聚焦的状态）再取得焦点：实体键盘的
      // Esc、Delete 等按键交到这里，正文的输入法已随选区清空断开。
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selection.isActive) _focus.requestFocus();
      });
      _watch();
    } else {
      unawaited(_transactions?.cancel());
      _transactions = null;
      _endRange();
      _restoreAfterExit();
    }
    setState(() {});
  }

  /// 选择变了（进入、点选、连选、批量操作换了块、退出）：新选中的块从 0
  /// 淡入，取消的淡出。关闭动画时直接到位。
  void _onSelectionChanged() {
    if (!mounted) return;
    for (final root in _selection.roots) {
      _fades.putIfAbsent(root, () => 0);
    }
    if (_fades.isEmpty) return;
    if (ExpressiveMotion.duration(context, ExpressiveMotion.fast) ==
        Duration.zero) {
      _advanceFades(1);
    } else if (!_fadeTicker.isActive) {
      _fadeElapsed = Duration.zero;
      unawaited(_fadeTicker.start());
    }
  }

  void _tickFade(Duration elapsed) {
    final total = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final delta = elapsed - _fadeElapsed;
    _fadeElapsed = elapsed;
    _advanceFades(
      total == Duration.zero ? 1 : delta.inMicroseconds / total.inMicroseconds,
    );
  }

  /// 每块朝自己的目标走 [step]（1 即一步到位）；都到位后停表，退出模式后
  /// 最后一块淡完时重建一次、撤掉绘制。
  void _advanceFades(double step) {
    final selected = _selection.roots.toSet();
    var moving = false;
    for (final node in _fades.keys.toList()) {
      final value = _fades[node]!;
      final target = selected.contains(node) ? 1.0 : 0.0;
      final next = target > value
          ? math.min(target, value + step)
          : math.max(target, value - step);
      if (next == 0 && target == 0) {
        _fades.remove(node);
      } else {
        _fades[node] = next;
        moving = moving || next != target;
      }
    }
    _repaint.value++;
    if (moving) return;
    if (_fadeTicker.isActive) _fadeTicker.stop();
    if (_fades.isEmpty && !_selection.isActive) setState(() {});
  }

  /// 焦点交给了别的输入框（点标题、颜色代码框）：由它接手，退出模式。
  /// 交给正文自己（上游的点按、长按手势会顺带让正文取得焦点）时收回来：
  /// 模式里实体键盘的按键要交到这一层，正文也没有选区可编辑。
  void _onFocus() {
    if (_focus.hasFocus || !_selection.isActive) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused?.context?.findAncestorWidgetOfExactType<EditableText>() !=
        null) {
      _selection.exit(DiaryBlockSelectionExit.release);
      return;
    }
    final editorFocus = widget.focusNode;
    if (focused == null || focused == editorFocus) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selection.isActive && !_focus.hasFocus) {
          _focus.requestFocus();
        }
      });
    }
  }

  /// 按退出方式恢复光标与键盘，见类注释。手机上不弹键盘的那几种不请求
  /// 正文焦点（获得焦点可能接上输入法），只放下选区；桌面一律回到正文，
  /// 接着就能打字。
  void _restoreAfterExit() {
    final exit = _selection.takeExit();
    if (exit == null || widget.controller.isDisposed) return;
    final (how, roots) = exit;
    if (how == DiaryBlockSelectionExit.release) return;
    final caret = _caretAfter(roots);
    if (caret == null) return;
    final refocus =
        AppPlatform.isDesktop ||
        (how == DiaryBlockSelectionExit.done && _selection.keyboardWasVisible);
    if (refocus) {
      widget.focusNode?.requestFocus();
      widget.controller.select(caret);
    } else {
      widget.controller.holdingKeyboard(() => widget.controller.select(caret));
    }
  }

  /// 第一块（仍在文档里的）末尾：文字块为文字末尾，表格为第一格开头，
  /// 嵌入块为它的右侧。
  af.Selection? _caretAfter(List<af.Node> roots) {
    for (final root in roots) {
      if (root.parent == null) continue;
      if (root.delta case final delta?) {
        return af.Selection.collapsed(
          af.Position(path: root.path, offset: delta.length),
        );
      }
      af.Node? text;
      void find(Iterable<af.Node> nodes) {
        for (final node in nodes) {
          if (text != null) return;
          if (node.delta != null) {
            text = node;
            return;
          }
          find(node.children);
        }
      }

      find(root.children);
      if (text case final node?) {
        return af.Selection.collapsed(af.Position(path: node.path));
      }
      return af.Selection.collapsed(af.Position(path: root.path, offset: 1));
    }
    return null;
  }

  // ---- 增删块后稳住页面、揭示选中的块 ----

  void _onTransaction(af.EditorTransactionValue event) {
    final time = event.$1;
    final transaction = event.$2;
    if (!_selection.isActive || widget.controller.draggingBlock) return;
    if (time == af.TransactionTime.before) {
      _anchor = _anchorFor(transaction);
      return;
    }
    final anchor = _anchor;
    _anchor = null;
    if (anchor != null) widget.pinPath?.call(anchor.$1.path, anchor.$2);
    _repaint.value++;
    _scheduleReveal();
  }

  /// 事务之前（块还在原处、几何是上一帧的）量好：增删动到的顶层块之外，
  /// 一个完全看得见的块与它在视口里的比例。
  (af.Node, double)? _anchorFor(af.Transaction transaction) {
    int? low;
    int? high;
    for (final operation in transaction.operations) {
      if (operation is! af.InsertOperation &&
          operation is! af.DeleteOperation) {
        continue;
      }
      final path = operation.path;
      if (path.isEmpty) continue;
      final count = operation is af.InsertOperation
          ? operation.nodes.length
          : 1;
      low = math.min(low ?? path.first, path.first);
      high = math.max(high ?? path.first, path.first + count);
    }
    final range = diaryEditorVisibleRange(
      context,
      widget.controller,
      pageScroll: false,
      coveredHeight: widget.coveredHeight,
    );
    if (low == null || high == null || range == null) return null;
    return diaryBlockDragAnchor(
      widget.controller.document.root,
      low: low,
      high: high,
      viewportTop: range.viewportTop,
      viewportHeight: range.viewportBottom - range.viewportTop,
      itemInset: widget.controller.state.editorStyle.padding.top,
    );
  }

  void _scheduleReveal() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted && _selection.isActive) _reveal();
    });
  }

  /// 选中的块没有整个露在看得见的范围里时滚过去：先保证第一块的上沿露出，
  /// 放得下时整组露出。块远在视口外、还没建出来时直接跳过去。
  void _reveal() {
    final roots = _selection.roots;
    if (roots.isEmpty) return;
    final range = diaryEditorVisibleRange(
      context,
      widget.controller,
      pageScroll: false,
      coveredHeight: widget.coveredHeight,
    );
    final scrollable = widget.controller.state.scrollableState;
    if (range == null || scrollable == null) return;
    Rect? union;
    for (final root in roots) {
      final rect = root.rect;
      if (rect == Rect.zero) continue;
      union = union?.expandToInclude(rect) ?? rect;
    }
    if (union == null) {
      widget.revealPath?.call(roots.first.path);
      return;
    }
    const margin = 16.0;
    double delta = 0;
    if (union.top < range.top + margin) {
      delta = union.top - range.top - margin;
    } else if (union.bottom > range.bottom - margin) {
      delta = math.min(
        union.bottom - range.bottom + margin,
        union.top - range.top - margin,
      );
    }
    if (delta.abs() < 1) return;
    final position = scrollable.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    if (duration == Duration.zero) {
      position.jumpTo(target);
    } else {
      unawaited(
        position.animateTo(
          target,
          duration: duration,
          curve: ExpressiveMotion.effects,
        ),
      );
    }
  }

  /// 模式里每帧结束核对一次块的几何（图片解码长高、折叠展开等不经滚动
  /// 与事务的布局变化），变了才重绘。帧尾回调本身不请求新帧，界面静止时
  /// 没有开销。
  void _watch() {
    if (_watching || !mounted) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      if (!mounted || !_selection.isActive) return;
      final signature = Object.hashAll([
        for (final unit in diaryBlockSelectionUnits(
          widget.controller.document.root,
        ))
          unit.rect,
      ]);
      if (signature != _signature) {
        _signature = signature;
        _repaint.value++;
      }
      _watch();
    });
  }

  // ---- 点在正文下方的空白处 ----

  void _onPointerDown(PointerDownEvent event) =>
      _down = (event.pointer, event.position, event.timeStamp);

  /// 只旁听指针、不参与手势竞争：点按（没挪动、没到长按）落在最后一块
  /// 下方的空白处（页尾里不属于正文的内容除外）时完成，回到打字。
  void _onPointerUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null || down.$1 != event.pointer || !_selection.isActive) {
      return;
    }
    if ((event.position - down.$2).distance > kTouchSlop ||
        event.timeStamp - down.$3 > kLongPressTimeout) {
      return;
    }
    final blocks = widget.controller.document.root.children;
    final last = blocks.isEmpty ? null : blocks.last.rect;
    if (last == null || last == Rect.zero || event.position.dy <= last.bottom) {
      return;
    }
    if (DiaryEditorTrailingRegion.isHit(context, event.position)) return;
    _selection.exit();
  }

  // ---- 按键 ----

  /// 一直挂在这一层的焦点上，模式外原样放行（见 build 里的说明）。正文的
  /// 按键先经正文自己的焦点，没处理的才冒泡到这里：模式外吃掉的话，正文
  /// 上没有快捷规则的 Enter 就到不了输入法，不会换行（#231）。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_selection.isActive ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final command = keys.isControlPressed || keys.isMetaPressed;
    final key = event.logicalKey;
    final controller = widget.controller;
    if (key == LogicalKeyboardKey.escape) {
      _selection.exit(DiaryBlockSelectionExit.dismiss);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _selection.exit();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      DiaryBlockActions.delete(context, controller);
    } else if (keys.isAltPressed &&
        keys.isShiftPressed &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      DiaryBlockActions.step(controller, up: key == LogicalKeyboardKey.arrowUp);
    } else if (command && key == LogicalKeyboardKey.keyA) {
      _selection.selectAll();
    } else if (command && key == LogicalKeyboardKey.keyC) {
      unawaited(DiaryBlockActions.copy(context, controller));
    } else if (command && key == LogicalKeyboardKey.keyX) {
      unawaited(DiaryBlockActions.cut(context, controller));
    } else if (command && key == LogicalKeyboardKey.keyD) {
      DiaryBlockActions.duplicate(controller);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---- 页边距那一列 ----

  af.Node? _unitAt(double globalDy) {
    final hit = diaryBlockAt(widget.controller.document.root, globalDy);
    return hit == null ? null : diaryBlockSelectionUnitOf(hit);
  }

  void _stripTap(TapUpDetails details) {
    final unit = _unitAt(details.globalPosition.dy);
    if (unit == null) return;
    unawaited(HapticFeedback.selectionClick());
    if (HardwareKeyboard.instance.isShiftPressed) {
      _selection.selectRange(unit);
    } else {
      _selection.toggle(unit);
    }
  }

  void _stripLongPress(LongPressStartDetails details) {
    final pointer = _pointer;
    final unit = _unitAt(details.globalPosition.dy);
    if (pointer == null || unit == null) return;
    if (!_selection.isSelected(unit) && !_selection.isCovered(unit)) {
      _selection.toggle(unit);
    }
    widget.relay.start?.call(pointer, details.globalPosition, unit);
  }

  void _startRange(DragStartDetails details) {
    final unit = _unitAt(details.globalPosition.dy);
    if (unit == null) return;
    _rangeFrom = unit;
    _rangeTo = null;
    _rangeSelect = !_selection.isSelected(unit) && !_selection.isCovered(unit);
    _rangeBase = _selection.roots;
    _rangePointer = details.globalPosition;
    _trackRange();
    if (!_rangeTicker.isActive) unawaited(_rangeTicker.start());
  }

  /// 每帧按手指位置重算连选：自动滚动时手指不动，手指下的块仍在变。
  void _trackRange() {
    final from = _rangeFrom;
    final pointer = _rangePointer;
    if (!mounted || from == null || pointer == null) return;
    final range = diaryEditorVisibleRange(
      context,
      widget.controller,
      pageScroll: false,
      coveredHeight: widget.coveredHeight,
    );
    final double dy = range == null
        ? pointer.dy
        : pointer.dy.clamp(
            range.top + 1,
            math.max(range.top + 1, range.bottom - 1),
          );
    final to = _unitAt(dy) ?? _rangeTo;
    if (to != null && to != _rangeTo) {
      _rangeTo = to;
      unawaited(HapticFeedback.selectionClick());
      _selection.replace(
        _selection.rangeApplied(
          base: _rangeBase,
          from: from,
          to: to,
          select: _rangeSelect,
        ),
      );
    }
    final scrollable = widget.controller.state.scrollableState;
    if (range != null && scrollable != null) {
      _autoScroll.update(
        scrollable,
        pointer,
        visibleTop: range.top,
        visibleBottom: range.bottom,
        viewportTop: range.viewportTop,
        viewportBottom: range.viewportBottom,
      );
    }
  }

  void _endRange() {
    _rangeFrom = null;
    _rangeTo = null;
    _rangePointer = null;
    _rangeBase = const [];
    if (_rangeTicker.isActive) _rangeTicker.stop();
    _autoScroll.stop();
  }

  @override
  Widget build(BuildContext context) {
    final active = _selection.isActive;
    final theme = Theme.of(context);
    // 半透明的主色：衬在文字下与盖在图片、代码块上是同一种颜色，页面有
    // 背景图或玻璃时也透得出来。暗色主题的主色偏亮，要多一些才看得清。
    final tint = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
    );
    final painting = active || _fades.isNotEmpty;
    DiaryBlockSelectionPainter painter({required bool overlay}) =>
        DiaryBlockSelectionPainter(
          opacities: _fades,
          curve: ExpressiveMotion.effects,
          blockRect: _localRect,
          textTop: _localTextTop,
          contentLeft: widget.contentLeft,
          color: tint,
          overlay: overlay,
          repaint: _repaint,
        );
    return Focus(
      focusNode: _focus,
      canRequestFocus: active,
      skipTraversal: true,
      // 不能按模式传 null：`Focus` 的 onKeyEvent 为 null 时取的是焦点节点上
      // 已有的回调，节点上的 _onKey 就一直留着，退出模式后照样拦下按键
      // （#231：退出后输入法以按键送来的回车被吞，无法换行，重进编辑页
      // 才好）。由 _onKey 自己在模式外放行。
      onKeyEvent: _onKey,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          if (active) _repaint.value++;
          return false;
        },
        child: Listener(
          onPointerDown: active ? _onPointerDown : null,
          onPointerUp: active ? _onPointerUp : null,
          child: CustomPaint(
            painter: painting ? painter(overlay: false) : null,
            foregroundPainter: painting ? painter(overlay: true) : null,
            // 子层都带 key：页边距那一列出现或消失时不按位置复用元素，编辑器
            // 不会被重建。
            child: Stack(
              children: [
                KeyedSubtree(
                  key: const ValueKey('editor'),
                  child: widget.child,
                ),
                if (active)
                  Positioned(
                    key: const ValueKey('select-column'),
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.contentLeft + 4,
                    child: Listener(
                      onPointerDown: (event) => _pointer = event.pointer,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // 连选从手指按下的那一块算起，不是越过拖动阈值时
                        // 手指所在的块。
                        dragStartBehavior: DragStartBehavior.down,
                        onTapUp: _stripTap,
                        onLongPressStart: _stripLongPress,
                        onVerticalDragStart: _startRange,
                        onVerticalDragUpdate: (details) =>
                            _rangePointer = details.globalPosition,
                        onVerticalDragEnd: (_) => _endRange(),
                        onVerticalDragCancel: _endRange,
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

  Rect? _localRect(af.Node node) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    return DiaryBlockLineGeometry.blockRect(
      node,
      box,
      contentLeft: widget.contentLeft,
      childIndent: widget.childIndent,
    );
  }

  double? _localTextTop(af.Node node) {
    final box = context.findRenderObject();
    final y = widget.geometry.textTop(node);
    if (y == null) return null;
    return box is RenderBox && box.hasSize
        ? box.globalToLocal(Offset(0, y)).dy
        : y;
  }
}
