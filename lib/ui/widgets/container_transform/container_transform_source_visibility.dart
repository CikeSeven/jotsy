import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 一张来源卡片的绘制占用：转场持有期间保留布局与状态，只让飞行画面显示。
///
/// 句柄由路由释放；计数与幂等释放避免反向、路由提前移除或卡片先卸载时
/// 留下空位。只通知渲染对象，不重建列表，也不把玻璃卡片放进透明度层。
class ContainerTransformSourceVisibility extends ChangeNotifier {
  int _holds = 0;
  bool _disposed = false;

  bool get visible => _holds == 0;

  VoidCallback hold() {
    if (_disposed) return () {};
    _holds++;
    if (_holds == 1) notifyListeners();
    var released = false;
    return () {
      if (released || _disposed) return;
      released = true;
      _holds--;
      if (_holds == 0) notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ContainerTransformSourcePaintGate extends SingleChildRenderObjectWidget {
  const ContainerTransformSourcePaintGate({
    super.key,
    required this.visibility,
    required super.child,
  });

  final ContainerTransformSourceVisibility visibility;

  @override
  RenderContainerTransformSourcePaintGate createRenderObject(
    BuildContext context,
  ) => RenderContainerTransformSourcePaintGate(visibility);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderContainerTransformSourcePaintGate renderObject,
  ) => renderObject.visibility = visibility;
}

class RenderContainerTransformSourcePaintGate extends RenderProxyBox {
  RenderContainerTransformSourcePaintGate(this._visibility);

  ContainerTransformSourceVisibility _visibility;
  set visibility(ContainerTransformSourceVisibility value) {
    if (identical(value, _visibility)) return;
    if (attached) _visibility.removeListener(_changed);
    _visibility = value;
    if (attached) _visibility.addListener(_changed);
    _changed();
  }

  void _changed() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _visibility.addListener(_changed);
  }

  @override
  void detach() {
    _visibility.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_visibility.visible) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _visibility.visible && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visibility.visible) super.visitChildrenForSemantics(visitor);
  }
}
