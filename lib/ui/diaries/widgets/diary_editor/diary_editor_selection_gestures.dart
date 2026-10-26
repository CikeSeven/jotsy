import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 上游公开的 selectionService.onPan* 参数使用了未导出的枚举；这里只桥接
// 固定版本的原生把手服务，选区、跨块定位与拖动结束仍由上游维护。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../controllers/diary_editor_controller.dart';

enum DiarySelectionHandleSide { start, end }

/// 嵌入阅读页的原生选区把手手势。输入为只读会话和编辑器，按原生把手几何
/// 接管触点，再把拖动交回 AppFlowy；不写正文、不改页面的滚动或翻页阈值。
class DiaryEditorSelectionGestures extends StatelessWidget {
  const DiaryEditorSelectionGestures({
    super.key,
    required this.controller,
    required this.child,
  });

  final DiaryEditorController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    Offset adjustment(DiarySelectionHandleSide side) {
      final ball = controller.state.editorStyle.mobileDragHandleBallSize.width;
      return Offset(
        0,
        ios
            ? (side == DiarySelectionHandleSide.start ? ball : -ball)
            : -2 * ball,
      );
    }

    MobileSelectionDragMode mode(DiarySelectionHandleSide side) =>
        side == DiarySelectionHandleSide.start
        ? MobileSelectionDragMode.leftSelectionHandle
        : MobileSelectionDragMode.rightSelectionHandle;

    return DiarySelectionHandleGestureRegion(
      key: ObjectKey(controller),
      // editorStyle 在子编辑器挂载时初始化，按下触点时再读取其最终把手尺寸。
      resolveHandle: (point) => controller.isDisposed
          ? null
          : _handleAt(
              point,
              ios: ios,
              ball: controller.state.editorStyle.mobileDragHandleBallSize.width,
            ),
      onStart: (details, side) {
        if (controller.isDisposed) return;
        final offset = adjustment(side);
        controller.state.service.selectionService.onPanStart(
          DragStartDetails(
            sourceTimeStamp: details.sourceTimeStamp,
            globalPosition: details.globalPosition + offset,
            localPosition: details.localPosition + offset,
            kind: details.kind,
          ),
          mode(side),
        );
      },
      onUpdate: (details, side) {
        if (controller.isDisposed) return;
        final offset = adjustment(side);
        controller.state.service.selectionService.onPanUpdate(
          DragUpdateDetails(
            sourceTimeStamp: details.sourceTimeStamp,
            globalPosition: details.globalPosition + offset,
            localPosition: details.localPosition + offset,
            delta: details.delta,
            primaryDelta: details.primaryDelta,
          ),
          mode(side),
        );
      },
      onEnd: (details, side) {
        if (controller.isDisposed) return;
        controller.state.service.selectionService.onPanEnd(details, mode(side));
      },
      onCancel: (side) {
        if (controller.isDisposed) return;
        // 父路由退出或系统取消触点时，同样结束原生拖动，避免残留扩选模式。
        controller.state.service.selectionService.onPanEnd(
          DragEndDetails(),
          mode(side),
        );
      },
      child: child,
    );
  }

  DiarySelectionHandleSide? _handleAt(
    Offset point, {
    required bool ios,
    required double ball,
  }) {
    if (controller.isDisposed) return null;
    final selection = controller.state.selection?.normalized;
    if (selection == null || selection.isCollapsed) return null;
    DiarySelectionHandleSide? closest;
    var distance = double.infinity;
    for (final side in DiarySelectionHandleSide.values) {
      final start = side == DiarySelectionHandleSide.start;
      final position = start ? selection.start : selection.end;
      final selectable = controller.document
          .nodeAtPath(position.path)
          ?.selectable;
      final local = selectable?.getCursorRectInPosition(position);
      if (selectable == null || local == null) continue;
      final rect = selectable.transformRectToGlobal(local);
      final center = ios
          ? (start ? rect.topCenter : rect.bottomCenter) +
                Offset(0, start ? -ball / 2 : ball / 2)
          : rect.bottomCenter + Offset(start ? -ball : ball, ball);
      final target = Rect.fromCenter(
        center: center,
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
      );
      final candidateDistance = (point - center).distanceSquared;
      // 短选区的两块触控区可能相交，按水滴距离确定抓住的是哪一端；按下后
      // 识别器会固定这一端，穿过另一把手或暂时折叠时也不会换边。
      if (target.contains(point) && candidateDistance < distance) {
        closest = side;
        distance = candidateDistance;
      }
    }
    return closest;
  }
}

/// 只在把手触控区参与竞技场，首次小幅移动即接管拖动。原生 pan 的阈值是
/// 单方向滚动的两倍，等到它认定拖动时，外层阅读滚动/翻页已经先胜出；仅
/// 调整把手识别器可保留正文滚动、长按选字与媒体控件的原有手感。
class DiarySelectionHandleGestureRegion extends StatelessWidget {
  const DiarySelectionHandleGestureRegion({
    super.key,
    required this.resolveHandle,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final DiarySelectionHandleSide? Function(Offset) resolveHandle;
  final void Function(DragStartDetails, DiarySelectionHandleSide) onStart;
  final void Function(DragUpdateDetails, DiarySelectionHandleSide) onUpdate;
  final void Function(DragEndDetails, DiarySelectionHandleSide) onEnd;
  final ValueChanged<DiarySelectionHandleSide> onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      _SelectionHandlePanRecognizer:
          GestureRecognizerFactoryWithHandlers<_SelectionHandlePanRecognizer>(
            _SelectionHandlePanRecognizer.new,
            (recognizer) {
              recognizer
                ..resolveHandle = resolveHandle
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (details) {
                  recognizer.started = true;
                  onStart(details, recognizer.side!);
                }
                ..onUpdate = (details) {
                  onUpdate(details, recognizer.side!);
                }
                ..onEnd = (details) {
                  onEnd(details, recognizer.side!);
                }
                ..onCancel = () {
                  if (recognizer.started) onCancel(recognizer.side!);
                };
            },
          ),
    },
    child: child,
  );
}

class _SelectionHandlePanRecognizer extends PanGestureRecognizer {
  late DiarySelectionHandleSide? Function(Offset) resolveHandle;
  DiarySelectionHandleSide? side;
  bool started = false;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      side == null &&
      resolveHandle(event.position) != null &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    side = resolveHandle(event.position);
    started = false;
    super.addAllowedPointer(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() > 0;

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    side = null;
    started = false;
  }

  @override
  void dispose() {
    if (started) onCancel?.call();
    side = null;
    started = false;
    super.dispose();
  }
}
