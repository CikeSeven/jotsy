import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show ScrollController, ScrollPosition;
import 'package:flutter_quill/flutter_quill.dart'
    show Block, QuillController, RenderEditor;

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_code_language_tracker.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_code_block_header_geometry.dart';
import 'diary_code_block_header_gestures.dart';
import 'diary_code_block_header_painter.dart';

// 代码块标题栏（语言名 + 复制按钮）的渲染层：包在 QuillEditor 外面，在
// 每个代码块上方预留的外边距里画标题栏，并接管这块区域的点按与读屏。
//
// 输入：代码块外观（是否开启、配色、圆角、边框、外边距）、正文控制器、
// 语言识别状态、可选的编辑器滚动控制器、文案与“刚复制过”的代码块。
// 输出：绘制；复制按钮的点按与读屏动作回调 [onCopy]。
// 副作用：监听控制器 / 识别状态 / 滚动控制器以触发重绘。
//
// 为什么在绘制阶段从渲染树取几何，而不是放一组 widget：标题栏要贴着代码块
// 走，代码块的位置只有在本帧布局完成后才确定。用 widget 就只能读上一帧的
// 布局再 setState，打字时标题栏会比代码块慢一帧（肉眼可见的抖动）。绘制
// 发生在布局之后，这时读 RenderEditor 子节点的位置就是本帧的结果（几何约定
// 见 diary_code_block_header_geometry.dart）。
//
// 重绘时机：编辑器不可滚动时，RenderEditor 重新布局 / 重绘都会让包含本层的
// 重绘边界一起重画，标题栏天然同步；可滚动的编辑器（模板编辑页）里滚动视图
// 是独立的重绘边界，内部变化不会重画本层，因此另外监听控制器（文档与选区）、
// 识别结果与滚动控制器。
//
// 命中：落在标题栏上的指针只命中本层、不进入 QuillEditor，Quill 的选区手势
// 看不到这次点按，光标不会被挪动；祖先（页面滚动视图）仍在命中路径上，从
// 标题栏开始的竖向拖动照常滚动页面（可滚动编辑器的拖动转交见
// diary_code_block_header_gestures.dart）。命中与读屏都以最近一次绘制的
// 标题栏为准：所见即所点。
//
// 关闭标题栏（look.header 为 false）时本层完全透明：只画子节点、命中直接
// 交给子节点、不产生读屏节点。

/// 代码块标题栏渲染层；由 DiaryCodeBlockChrome 创建。
class RenderDiaryCodeBlockChrome extends RenderProxyBox {
  RenderDiaryCodeBlockChrome({
    required DiaryCodeBlockLook look,
    required this._controller,
    required this._tracker,
    required this._scrollController,
    required this._l10n,
    required TextStyle labelStyle,
    required TextScaler textScaler,
    required this._textDirection,
    required this._copiedBlock,
    required this.onCopy,
  }) : _look = look,
       _labelStyle = labelStyle,
       _textScaler = textScaler,
       _painter = DiaryCodeBlockHeaderPainter(
         palette: look.palette,
         radius: look.style.radius,
         border: look.style.border,
         labelStyle: labelStyle,
         textScaler: textScaler,
       );

  final DiaryCodeBlockHeaderPainter _painter;

  /// 点按复制按钮（或读屏的点按动作）时调用。
  ValueChanged<Block> onCopy;

  late final DiaryCodeBlockHeaderGestures _gestures =
      DiaryCodeBlockHeaderGestures(
        debugOwner: this,
        onCopy: (block) => onCopy(block),
        scrollPosition: () => _scrollPosition,
      );

  DiaryCodeBlockLook get look => _look;
  DiaryCodeBlockLook _look;
  set look(DiaryCodeBlockLook value) {
    if (identical(value, _look)) {
      return;
    }
    final headerChanged = value.header != _look.header;
    _look = value;
    _updatePainter();
    markNeedsPaint();
    if (headerChanged) {
      markNeedsSemanticsUpdate();
    }
  }

  QuillController get controller => _controller;
  QuillController _controller;
  set controller(QuillController value) {
    if (identical(value, _controller)) {
      return;
    }
    if (attached) {
      _controller.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _controller = value;
    markNeedsPaint();
  }

  DiaryCodeLanguageTracker get tracker => _tracker;
  DiaryCodeLanguageTracker _tracker;
  set tracker(DiaryCodeLanguageTracker value) {
    if (identical(value, _tracker)) {
      return;
    }
    if (attached) {
      _tracker.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _tracker = value;
    markNeedsPaint();
  }

  ScrollController? get scrollController => _scrollController;
  ScrollController? _scrollController;
  set scrollController(ScrollController? value) {
    if (identical(value, _scrollController)) {
      return;
    }
    if (attached) {
      _scrollController?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _scrollController = value;
    markNeedsPaint();
  }

  AppLocalizations get l10n => _l10n;
  AppLocalizations _l10n;
  set l10n(AppLocalizations value) {
    if (identical(value, _l10n)) {
      return;
    }
    _l10n = value;
    markNeedsPaint();
  }

  TextStyle _labelStyle;
  set labelStyle(TextStyle value) {
    _labelStyle = value;
    _updatePainter();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    _textScaler = value;
    _updatePainter();
  }

  /// 读屏标签的文字方向（标题栏本身始终从左到右画）。
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  /// 正显示“已复制”对勾的代码块。
  Block? get copiedBlock => _copiedBlock;
  Block? _copiedBlock;
  set copiedBlock(Block? value) {
    if (identical(value, _copiedBlock)) {
      return;
    }
    _copiedBlock = value;
    markNeedsPaint();
  }

  void _updatePainter() {
    final changed = _painter.update(
      palette: _look.palette,
      radius: _look.style.radius,
      border: _look.style.border,
      labelStyle: _labelStyle,
      textScaler: _textScaler,
    );
    if (changed) {
      markNeedsPaint();
    }
  }

  List<DiaryCodeBlockHeaderGeometry> _headers =
      const <DiaryCodeBlockHeaderGeometry>[];

  /// 最近一次绘制的标题栏（本层局部坐标）。
  @visibleForTesting
  List<DiaryCodeBlockHeaderGeometry> get headers => _headers;

  RenderEditor? _editor;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
    _tracker.addListener(markNeedsPaint);
    _scrollController?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    _tracker.removeListener(markNeedsPaint);
    _scrollController?.removeListener(markNeedsPaint);
    _gestures.cancelScroll();
    _editor = null;
    super.detach();
  }

  @override
  void dispose() {
    _gestures.dispose();
    _painter.dispose();
    super.dispose();
  }

  /// 包在本层下的 RenderEditor；缓存，被卸下或换成别的实例时重找。
  RenderEditor? _findEditor() {
    final cached = _editor;
    if (cached != null && cached.attached && _isDescendant(cached)) {
      return cached;
    }
    final child = this.child;
    return _editor = child == null ? null : findDiaryRenderEditor(child);
  }

  bool _isDescendant(RenderObject node) {
    for (RenderObject? current = node; current != null;) {
      if (identical(current, this)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  void _setHeaders(List<DiaryCodeBlockHeaderGeometry> headers) {
    if (listEquals(headers, _headers)) {
      return;
    }
    _headers = headers;
    // 语义更新排在绘制之后（同一帧），读屏节点随标题栏一起更新。
    markNeedsSemanticsUpdate();
  }

  DiaryCodeBlockHeaderGeometry? _headerAt(Offset position) {
    for (final header in _headers) {
      if (header.rect.contains(position)) {
        return header;
      }
    }
    return null;
  }

  // ---- 绘制 ----

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final editor = _look.header ? _findEditor() : null;
    final headers = editor == null
        ? const <DiaryCodeBlockHeaderGeometry>[]
        : collectDiaryCodeBlockHeaders(
            editor: editor,
            ancestor: this,
            look: _look,
            tracker: _tracker,
            l10n: _l10n,
          );
    _setHeaders(headers);
    if (headers.isEmpty) {
      return;
    }
    final bounds = Offset.zero & size;
    void paintHeaders(PaintingContext context, Offset offset) {
      final canvas = context.canvas;
      for (final header in headers) {
        if (!header.rect.overlaps(bounds)) {
          continue;
        }
        _painter.paint(
          canvas,
          header.rect.shift(offset),
          label: header.label,
          copied: identical(header.block, _copiedBlock),
        );
      }
    }

    // 只有可滚动的编辑器会把标题栏滚到本层之外，这时才裁切（省一个裁切层）。
    if (headers.every((header) => _encloses(bounds, header.rect))) {
      paintHeaders(context, offset);
    } else {
      context.pushClipRect(needsCompositing, offset, bounds, paintHeaders);
    }
  }

  static bool _encloses(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  // ---- 命中 ----

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_look.header &&
        size.contains(position) &&
        _headerAt(position) != null) {
      // 不测试子节点：Quill 的选区手势收不到，光标不动。
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent || !_look.header) {
      return;
    }
    // 落在正文上的指针也会经过本层（子节点命中后本层随之入列），只处理
    // 标题栏上的按下。
    final header = _headerAt(entry.localPosition);
    if (header == null) {
      return;
    }
    _gestures.addPointer(
      event,
      copyBlock: header.copyRect.contains(entry.localPosition)
          ? header.block
          : null,
    );
  }

  /// 编辑器自带滚动视图时它的滚动位置（模板编辑页）；不可滚动的编辑器由
  /// 页面滚动视图在命中路径上自行处理拖动，这里为 null。
  ScrollPosition? get _scrollPosition {
    final controller = _scrollController;
    if (controller == null || controller.positions.length != 1) {
      return null;
    }
    return controller.position;
  }

  // ---- 读屏 ----

  /// 每个标题栏的复制按钮一个读屏节点，按顺序复用。
  List<SemanticsNode> _buttonNodes = <SemanticsNode>[];

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // 成为语义边界，才能在 assembleSemanticsNode 里挂上复制按钮的节点。
    config.isSemanticBoundary = _look.header;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final bounds = Offset.zero & size;
    final clip = node.parentPaintClipRect;
    final buttons = <SemanticsNode>[];
    for (final header in _headers) {
      final copyRect = header.copyRect;
      if (!copyRect.overlaps(bounds)) {
        continue;
      }
      final rect = copyRect.intersect(bounds);
      final SemanticsNode button;
      if (buttons.length < _buttonNodes.length) {
        button = _buttonNodes[buttons.length];
      } else {
        late final SemanticsNode created;
        created = SemanticsNode(
          showOnScreen: () => showOnScreen(rect: created.rect),
        );
        button = created;
      }
      final block = header.block;
      final buttonConfig = SemanticsConfiguration()
        ..isButton = true
        ..label = header.semanticsLabel
        ..textDirection = _textDirection
        ..onTap = () => onCopy(block);
      if (clip != null) {
        // 被页面滚动视图裁到视口外的按钮标为隐藏（与 RenderParagraph 一致）。
        buttonConfig.isHidden = !clip.overlaps(rect);
      }
      button
        ..updateWith(config: buttonConfig)
        ..rect = rect;
      buttons.add(button);
    }
    _buttonNodes = buttons;
    // 复制按钮画在正文之上，按“逆绘制顺序”排在前面。
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: <SemanticsNode>[...buttons, ...children],
    );
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _buttonNodes = <SemanticsNode>[];
  }
}
