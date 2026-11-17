import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 卡组的滚动视口：占满父级给的尺寸，把视口高度与内容高度 [extent] 报给
/// [offset]（滚动范围由此而来），子组件（卡组的 Flow）与视口同尺寸、不随
/// 滚动平移——卡片在哪由 Flow 按滚动偏移逐帧算（压叠、拉开），所以这里
/// 不像普通视口那样整体平移内容。
class NotebookDeckViewport extends SingleChildRenderObjectWidget {
  const NotebookDeckViewport({
    super.key,
    required this.offset,
    required this.extent,
    super.child,
  });

  final ViewportOffset offset;
  final double extent;

  @override
  RenderNotebookDeckViewport createRenderObject(BuildContext context) =>
      RenderNotebookDeckViewport(offset, extent);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderNotebookDeckViewport renderObject,
  ) {
    renderObject
      ..offset = offset
      ..extent = extent;
  }
}

class RenderNotebookDeckViewport extends RenderProxyBox {
  RenderNotebookDeckViewport(this._offset, this._extent);

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (identical(value, _offset)) return;
    _offset = value;
    markNeedsLayout();
  }

  double _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    child?.layout(BoxConstraints.tight(size));
    _offset.applyViewportDimension(size.height);
    _offset.applyContentDimensions(0, math.max(0, _extent - size.height));
  }
}
