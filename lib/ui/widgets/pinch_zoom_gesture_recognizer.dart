import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// 只认两根及以上手指的捏合识别器：第二根手指落下的那一刻就在手势竞技场
/// 里胜出。
///
/// 为什么需要它：看图页里同一根手指同时被三方争抢——外层 PageView 的水平
/// 拖动、下拉关闭的竖向拖动（触发阈值都是 18）与 InteractiveViewer 的缩放
/// 识别器。后者要等两指间距变化约 36、或比例变化超过 5% 才接受，而捏合时
/// 后落下的那根手指单独走 18 就让拖动先赢了：想缩放却翻了页、想缩小却关掉
/// 了图片（#252）。这里不比阈值，只看手指数：只要第一根手指的竞技场还没
/// 判出胜负（没有拖出 18），第二根手指落下即接受，两根手指都归捏合。
///
/// - 单指永不接受：父类的平移判定（焦点移动 > 36）被 [resolve] 拦下，单指
///   拖动仍属于翻页、下拉关闭或 InteractiveViewer 的平移；第二根手指落下前
///   第一根已走过触摸阈值（18）就是拖动，这里主动退出竞技场，不再占位——
///   否则没有翻页的视口里 InteractiveViewer 等不到“只剩它一个”而提前胜出，
///   要多走到平移阈值 36 才开始跟手（长图滚动会吃掉前面一段）；
/// - 只收触摸与手写笔：触控板的捏合（PointerPanZoom）与鼠标滚轮仍交给
///   InteractiveViewer 自己处理；
/// - 第一根手指已被别的识别器拿走（已经在翻页 / 下拉）时这里只剩一根手指，
///   同样不接受，不打断进行中的拖动。
///
/// 接受后回调与 [ScaleGestureRecognizer] 相同；中途抬起一根手指时父类会先
/// 发 onEnd 再在剩下那根手指下一次移动时重发 onStart，宿主应据此重新取
/// 基准。剩下的手指不动就抬起时父类不再发 onEnd，所以收尾（回弹、夹回
/// 范围）一律放在 [onRelease]。
class PinchZoomGestureRecognizer extends ScaleGestureRecognizer {
  PinchZoomGestureRecognizer({super.debugOwner})
    : super(supportedDevices: _touchDevices);

  static const Set<PointerDeviceKind> _touchDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  /// 接受过的这次捏合里最后一根手指离开时调用（中途抬起过几根都只调一次，
  /// 在最后一个 onEnd 之后）。
  VoidCallback? onRelease;

  bool _claimed = false;

  /// 尚未接受时各手指的落点（全局坐标），用来判断单指是否已经拖开。
  final Map<int, Offset> _downPositions = <int, Offset>{};

  // 父类无条件接受触控板捏合，这里必须显式拒绝，否则会抢走 InteractiveViewer
  // 的触控板缩放。
  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    _claimed = true;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final claimed = _claimed;
    _claimed = false;
    _downPositions.clear();
    super.didStopTrackingLastPointer(pointer);
    final callback = onRelease;
    if (claimed && callback != null) {
      invokeCallback<void>('onRelease', callback);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _downPositions.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (_claimed) {
      return;
    }
    if (event is PointerDownEvent) {
      _downPositions[event.pointer] = event.position;
      if (pointerCount >= 2) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerMoveEvent && pointerCount < 2) {
      final down = _downPositions[event.pointer];
      final slop = computeHitSlop(event.kind, gestureSettings);
      if (down != null && (event.position - down).distance > slop) {
        resolve(GestureDisposition.rejected);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _downPositions.remove(event.pointer);
    }
  }

  /// 少于两根手指时不接受；放弃（父类在最后一根手指离开时调用）照常放行。
  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted && pointerCount < 2) {
      return;
    }
    super.resolve(disposition);
  }

  @override
  String get debugDescription => 'pinch zoom';
}
