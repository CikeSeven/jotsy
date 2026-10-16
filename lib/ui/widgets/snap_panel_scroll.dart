import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'snap_panel_controller.dart';

// [SnapPanel] 与面板内滚动内容的联动：内容优先滚动，内容已在顶端还往下拉时
// 收起面板。

/// 把子树里的主滚动视图接到面板上：内容优先滚动，滚到顶端再往下拉时收起
/// 面板（见 [SnapPanelScrollController]）。
///
/// 每个子树持有自己的滚动控制器，随子树创建与释放，标签页之间的滚动位置互不
/// 干扰。经 [PrimaryScrollController] 提供：没有指定 controller 的竖向
/// ListView、ReorderableListView 会自动使用它；框架默认只在移动平台继承，这里
/// 在所有平台上启用，桌面端行为一致。
class SnapPanelScrollScope extends StatefulWidget {
  const SnapPanelScrollScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final SnapPanelController controller;
  final Widget child;

  @override
  State<SnapPanelScrollScope> createState() => _SnapPanelScrollScopeState();
}

class _SnapPanelScrollScopeState extends State<SnapPanelScrollScope> {
  late SnapPanelScrollController _scrollController = SnapPanelScrollController(
    panel: widget.controller,
  );

  @override
  void didUpdateWidget(covariant SnapPanelScrollScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // 滚动视图在这一帧才换用新控制器，旧的等这一帧结束再释放。
      final previous = _scrollController;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _scrollController = SnapPanelScrollController(panel: widget.controller);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _scrollController,
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: widget.child,
    );
  }
}

/// 面板里的滚动内容使用的控制器：内容优先滚动；内容已在顶端还往下拉时收起
/// 面板（同一次拖动里再往上推，先把面板推回原位）。
///
/// 中档是“边看预览边调选项”的主要状态，因此不采用底部面板常见的“面板优先”
/// （上滑先把面板推到顶）：那样在中档就滚不动选项了。展开面板靠拖动条与表头；
/// 滚到末端再往上推只有正常的越界效果——末端已贴着视口底边，面板变高只会露出
/// 空白，或让内容停在手指下不动，都不跟手。
class SnapPanelScrollController extends ScrollController {
  SnapPanelScrollController({required this.panel, super.debugLabel});

  final SnapPanelController panel;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SnapPanelScrollPosition(
      panel: panel,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

/// 拖动分三步分配手指位移：
/// 1. 本次拖动已把面板往下带过、手指又往上时，先把面板推回拖动开始时的高度；
/// 2. 其余位移先滚动内容；
/// 3. 内容已在顶端还往下拉，剩下的位移收起面板；面板也到最低档时才交还内容
///    做越界效果。
///
/// 松手时若面板被带动过，面板按松手速度吸附档位，内容不再惯性滚动；否则内容
/// 照常惯性滚动（同时让被打断的吸附落到最近的档位）。
///
/// 面板变高时视口随之变大：停在末端的内容由默认的 RangeMaintainingScrollPhysics
/// 夹回新的末端，不会露出空白。
class _SnapPanelScrollPosition extends ScrollPositionWithSingleContext {
  _SnapPanelScrollPosition({
    required this.panel,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final SnapPanelController panel;

  /// 本次内容拖动开始时的面板高度；没有进行中的拖动时为 null。
  double? _dragStartExtent;

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is _SnapPanelScrollPosition) {
      _dragStartExtent = other._dragStartExtent;
      other._dragStartExtent = null;
    }
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    panel.beginDrag();
    _dragStartExtent = panel.extent;
    return super.drag(details, dragCancelCallback);
  }

  @override
  void applyUserOffset(double delta) {
    final start = _dragStartExtent;
    // 回弹物理下可能已越界（如 iOS 回弹途中），这时不与面板联动。
    if (start == null || outOfRange) {
      super.applyUserOffset(delta);
      return;
    }
    var rest = delta;
    if (rest < 0 && panel.extent < start) {
      rest = panel.dragBy(rest, limit: start);
    }
    if (rest != 0) {
      final room = rest > 0
          ? pixels - minScrollExtent
          : maxScrollExtent - pixels;
      final content = rest > 0 ? math.min(rest, room) : math.max(rest, -room);
      if (content != 0) {
        super.applyUserOffset(content);
        rest -= content;
      }
    }
    if (rest > 0) {
      rest = panel.dragBy(rest);
    }
    if (rest != 0) {
      super.applyUserOffset(rest);
    }
  }

  @override
  void goBallistic(double velocity) {
    final start = _dragStartExtent;
    _dragStartExtent = null;
    if (start == null) {
      super.goBallistic(velocity);
      return;
    }
    if ((panel.extent - start).abs() > precisionErrorTolerance) {
      // 滚动速度以“内容向末端滚”为正，即手指向上；换成手指速度（向下为正）。
      panel.endDrag(-velocity);
      super.goBallistic(0);
      return;
    }
    panel.endDrag(0);
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_dragStartExtent != null) {
      _dragStartExtent = null;
      panel.cancelDrag();
    }
    super.dispose();
  }
}
