import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/rendering.dart';

/// AppFlowy 的服务 Overlay 要求有限高度；阅读页的正文则在外部滚动视图中。
/// 此 page 先在有限视口内正常布局完整正文，再报告实际高度给外层编辑器。
/// 不使用 IntrinsicHeight：图片和长图含 LayoutBuilder，无法进行固有尺寸测量。
/// 图片解码、字体或宽度变化会重新报告尺寸，外层只在尺寸变化时更新。
class DiaryInlinePageBuilder extends af.BlockComponentBuilder {
  DiaryInlinePageBuilder({
    required this.state,
    required this.onHeight,
    required this.padding,
  });
  final af.EditorState state;
  final ValueChanged<double> onHeight;
  final EdgeInsets padding;
  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _InlinePage(
        node: context.node,
        state: state,
        onHeight: onHeight,
        padding: padding,
        header: context.header,
        footer: context.footer,
      );
}

class _InlinePage extends af.BlockComponentStatelessWidget {
  const _InlinePage({
    required super.node,
    required this.state,
    required this.onHeight,
    required this.padding,
    this.header,
    this.footer,
  }) : super(configuration: const af.BlockComponentConfiguration());
  final af.EditorState state;
  final ValueChanged<double> onHeight;
  final EdgeInsets padding;
  final Widget? header;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => _InlineScrollProxy(
    position: Scrollable.maybeOf(context)?.position,
    // 连同末行把手预留的空白一起转交滚动；把手位于服务层的兄弟节点，
    // 它与外层滚动的手势竞争由 DiaryEditorSelectionGestures 提前接管。
    child: SingleChildScrollView(
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      child: _MeasureHeight(
        onHeight: onHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            for (final child in node.children)
              Padding(
                padding: padding,
                child: state.renderer.build(context, child),
              ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}

/// 上游的 Android 泛方向 pan 识别器会赢过外层阅读页的纵向滚动，然后忽略
/// 纵向位移。正文内部的纵向识别器先接管，再交给外层 ScrollPosition，保留
/// 原有物理惯性；长按选字和选区把手不走这条链，媒体的横向拖动也不受影响。
class _InlineScrollProxy extends StatefulWidget {
  const _InlineScrollProxy({required this.position, required this.child});
  final ScrollPosition? position;
  final Widget child;
  @override
  State<_InlineScrollProxy> createState() => _InlineScrollProxyState();
}

class _InlineScrollProxyState extends State<_InlineScrollProxy> {
  Drag? _drag;
  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.position == null
      ? widget.child
      : GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) =>
              _drag = widget.position!.drag(details, () => _drag = null),
          onVerticalDragUpdate: (details) => _drag?.update(details),
          onVerticalDragEnd: (details) => _drag?.end(details),
          onVerticalDragCancel: () => _drag?.cancel(),
          child: widget.child,
        );
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureHeightRender(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureHeightRender renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _MeasureHeightRender extends RenderProxyBox {
  _MeasureHeightRender(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reportedHeight;
  bool _pending = false;
  @override
  void performLayout() {
    super.performLayout();
    if (size.height == _reportedHeight || _pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!attached || !hasSize || size.height == _reportedHeight) return;
      _reportedHeight = size.height;
      onHeight(size.height);
    });
  }
}
