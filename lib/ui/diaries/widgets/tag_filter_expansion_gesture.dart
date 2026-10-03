import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Separates expansion, tag browsing, and collapse without forwarding to diaries.
///
/// Expanded content hands vertical drags to its own always-scrollable viewport;
/// only the separate footer can collapse it. Inactive padding/bounds consume
/// unused drags, so Home's scroller and tab PageView cannot take over the panel.
class TagFilterExpansionGesture extends StatelessWidget {
  const TagFilterExpansionGesture({
    super.key,
    required this.child,
    required this.canExpand,
    required this.canCollapse,
    required this.allowHorizontalScroll,
    required this.allowVerticalScroll,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Widget child;
  final bool Function() canExpand;
  final bool Function(Offset startPosition) canCollapse;
  final bool Function(Offset startPosition) allowHorizontalScroll;
  final bool Function(Offset startPosition) allowVerticalScroll;
  final ValueChanged<bool> onStart;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      // Expanded rows have gaps without an InkWell underneath. They belong to
      // the tag panel too, but taps still compete with the individual chips.
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _TagFilterExpansionGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _TagFilterExpansionGestureRecognizer
            >(_TagFilterExpansionGestureRecognizer.new, (
              _TagFilterExpansionGestureRecognizer instance,
            ) {
              // RawGestureDetector does not propagate device touch slop. Match
              // the surrounding scrollables or Android's smaller threshold
              // lets the page win before this recognizer sees a vertical drag.
              instance.gestureSettings = MediaQuery.maybeGestureSettingsOf(
                context,
              );
              instance.canExpand = canExpand;
              instance.canCollapse = canCollapse;
              instance.allowHorizontalScroll = allowHorizontalScroll;
              instance.allowVerticalScroll = allowVerticalScroll;
              instance.onStart = onStart;
              instance.onUpdate = onUpdate;
              instance.onEnd = onEnd;
            }),
      },
      child: child,
    );
  }
}

/// Defers arena resolution until movement has a clear dominant axis.
class _TagFilterExpansionGestureRecognizer
    extends OneSequenceGestureRecognizer {
  bool Function()? canExpand;
  bool Function(Offset startPosition)? canCollapse;
  bool Function(Offset startPosition)? allowHorizontalScroll;
  bool Function(Offset startPosition)? allowVerticalScroll;
  ValueChanged<bool>? onStart;
  ValueChanged<double>? onUpdate;
  ValueChanged<double>? onEnd;

  final Map<int, _TagFilterPointerState> _pointers =
      <int, _TagFilterPointerState>{};
  int? _activePointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final isPrimary = _activePointer == null;
    if (isPrimary) {
      _activePointer = event.pointer;
    }
    _pointers[event.pointer] = _TagFilterPointerState(
      event,
      isPrimary: isPrimary,
    );
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final state = _pointers[event.pointer];
    if (state == null) {
      stopTrackingIfPointerNoLongerDown(event);
      return;
    }

    if (event is PointerMoveEvent) {
      state.velocityTracker.addPosition(event.timeStamp, event.position);
      if (state.dragStarted && state.changeExpansion) {
        onUpdate?.call(event.delta.dy);
      } else if (!state.resolved) {
        _resolveMove(event, state);
      }
    } else if (event is PointerUpEvent) {
      if (state.dragStarted) {
        if (state.changeExpansion) {
          onEnd?.call(state.velocityTracker.getVelocity().pixelsPerSecond.dy);
        }
      } else {
        resolvePointer(event.pointer, GestureDisposition.rejected);
      }
      _finishPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      if (state.dragStarted) {
        if (state.changeExpansion) {
          onEnd?.call(0);
        }
      } else {
        resolvePointer(event.pointer, GestureDisposition.rejected);
      }
      _finishPointer(event.pointer);
    }
  }

  void _resolveMove(PointerMoveEvent event, _TagFilterPointerState state) {
    if (!state.isPrimary) {
      state.resolved = true;
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }
    final offset = event.position - state.startPosition;
    final dx = offset.dx.abs();
    final dy = offset.dy.abs();
    final slop = computeHitSlop(event.kind, gestureSettings);
    if (offset.distance < slop) {
      return;
    }

    // Let diagonal movement settle before choosing an axis. The chip row wins
    // useful horizontal drags; all other drags stay within this panel even at
    // its bounds, rather than turning into diary scrolling or Home tab swipes.
    final vertical = dy > dx * 1.15;
    final horizontal = dx > dy * 1.15;
    if (!vertical && !horizontal && offset.distance < slop * 1.5) {
      return;
    }
    state.resolved = true;
    final horizontalDrag = !vertical && (horizontal || dy <= dx);
    if (horizontalDrag &&
        allowHorizontalScroll?.call(state.localStartPosition) == true) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }
    if (!horizontalDrag &&
        allowVerticalScroll?.call(state.localStartPosition) == true) {
      // The expanded list always has an active vertical recognizer, even at
      // its bounds. Yield only to that child; content browsing never collapses.
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }

    final expanding = offset.dy > 0;
    final canHandle = expanding
        ? canExpand?.call()
        : canCollapse?.call(state.localStartPosition);
    state.expanding = expanding;
    state.pendingDelta = offset.dy;
    state.directionAccepted = true;
    state.changeExpansion = !horizontalDrag && canHandle == true;
    if (state.wonArena) {
      _startDragIfReady(state);
    } else {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    }
  }

  @override
  void acceptGesture(int pointer) {
    final state = _pointers[pointer];
    if (state == null || !state.isPrimary) {
      return;
    }
    // If neither scrollable overflows, Flutter can make this recognizer the
    // default winner on pointer down, before any direction exists. Remember
    // that ownership, then wait for a useful vertical movement to start. A
    // second resolve(accepted) would not trigger another acceptGesture callback
    // because that arena has already been removed.
    state.wonArena = true;
    _startDragIfReady(state);
  }

  void _startDragIfReady(_TagFilterPointerState state) {
    if (!state.directionAccepted || state.dragStarted) {
      return;
    }
    state.dragStarted = true;
    if (!state.changeExpansion) {
      return;
    }
    onStart?.call(state.expanding);
    onUpdate?.call(state.pendingDelta);
  }

  @override
  void rejectGesture(int pointer) {
    final state = _pointers[pointer];
    if (state != null) {
      state.resolved = true;
      state.directionAccepted = false;
      state.wonArena = false;
      state.dragStarted = false;
    }
  }

  void _finishPointer(int pointer) {
    _pointers.remove(pointer);
    if (_activePointer == pointer) {
      _activePointer = null;
    }
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'tag filter expansion drag';
}

class _TagFilterPointerState {
  _TagFilterPointerState(PointerDownEvent event, {required this.isPrimary})
    : startPosition = event.position,
      localStartPosition = event.localPosition,
      velocityTracker = VelocityTracker.withKind(event.kind) {
    velocityTracker.addPosition(event.timeStamp, event.position);
  }

  final Offset startPosition;
  final Offset localStartPosition;
  final VelocityTracker velocityTracker;
  final bool isPrimary;
  bool resolved = false;
  bool directionAccepted = false;
  bool wonArena = false;
  bool dragStarted = false;
  bool changeExpansion = false;
  bool expanding = false;
  double pendingDelta = 0;
}
