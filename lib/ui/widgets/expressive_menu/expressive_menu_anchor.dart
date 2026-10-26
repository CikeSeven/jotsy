import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import 'expressive_menu_layout.dart';
import 'expressive_menu_panel.dart';
import 'expressive_menu_surface.dart';

export 'expressive_menu_layout.dart' show ExpressiveMenuPlacement;

/// 菜单入口的构建回调：拿到菜单状态（是否展开、开合方法）来画触发控件，
/// 与 `FormField.builder` 拿到 `FormFieldState` 是同一种用法。
typedef ExpressiveMenuTriggerBuilder =
    Widget Function(
      BuildContext context,
      ExpressiveMenuAnchorState menu,
      Widget? child,
    );

/// 应用统一的锚定弹出菜单（移植自 phase 的 AppMenuAnchor），基于 [RawMenuAnchor]。
///
/// 为什么不用 SDK 的 MenuAnchor / PopupMenuButton：MenuAnchor 的展开时长固定
/// 为 500ms，PopupMenuButton 是整页路由、从中心放大且不随锚点对齐；这里用
/// 底层锚点自己掌握表面、动效与定位。
///
/// - 表面：玻璃表面 [ExpressiveMenuSurface]（半透明底 + 背景模糊 + 细描边 +
///   外侧投影，28 圆角），内边距 8；宽度取内容固有宽度，最小 176、最大为
///   屏宽 − 32；高度受安全区限制，超出时内部滚动。
/// - 动效：展开 0.96→1 缩放，同时底色、描边、模糊由浅到深、内容淡入
///   （fast / effects），收起反向（exit），从贴着锚点的角缩放；减少动画时瞬时
///   开合。收起过程中不可交互。
/// - 定位：见 [ExpressiveMenuPosition]，默认菜单结束边对齐锚点结束边、落在
///   锚点下方 4dp，下方放不下时翻到上方，并夹在安全区内（留 8dp 边距）。
/// - 行为：点外部关闭且不穿透；系统返回 / 预测式返回先关菜单（打开期间在
///   所在路由登记 [LocalHistoryEntry]）；Esc 关闭；↑/↓ 在菜单项间移动焦点；
///   关闭时焦点回到 [childFocusNode]。
/// - 指定位置打开（右键菜单）：[ExpressiveMenuAnchorState.openAt] 把菜单的
///   起始角放在给定的全局坐标上（指针处，间距 0，不看 [placement]），同样
///   上下翻转并夹进安全区；打开后焦点停在菜单上（键盘打开时落在第一项），
///   Esc / ↑↓ 由菜单自己处理，关闭时焦点回到打开前的位置。
///
/// 菜单项用 [ExpressiveMenuItem]：RawMenuAnchor 不会替条目自动关闭菜单。
class ExpressiveMenuAnchor extends StatefulWidget {
  const ExpressiveMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
    this.child,
    this.controller,
    this.childFocusNode,
    this.placement = ExpressiveMenuPlacement.end,
    this.onOpen,
    this.onClose,
    this.onAnimationStatusChanged,
  });

  /// 菜单内容，通常是若干 [ExpressiveMenuItem]。
  final List<Widget> menuChildren;

  /// 触发控件；菜单展开状态变化时会重新调用。
  final ExpressiveMenuTriggerBuilder builder;

  /// 原样传给 [builder] 的子树，用于不随展开状态重建的部分。
  final Widget? child;

  /// 外部控制开合时传入；不传则内部创建。
  final MenuController? controller;

  /// 触发控件的焦点；菜单关闭时焦点交还给它。
  final FocusNode? childFocusNode;
  final ExpressiveMenuPlacement placement;

  /// 浮层挂上时调用（收起途中被重新展开时也会再调一次）。
  final VoidCallback? onOpen;

  /// 收起动画结束、浮层移除后调用。
  final VoidCallback? onClose;
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  @override
  State<ExpressiveMenuAnchor> createState() => ExpressiveMenuAnchorState();
}

/// [ExpressiveMenuAnchor] 的状态；[ExpressiveMenuItem] 经 [maybeOf] 找到它来关闭菜单。
class ExpressiveMenuAnchorState extends State<ExpressiveMenuAnchor>
    with SingleTickerProviderStateMixin {
  static const double _openScale = 0.96;

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.fast,
    reverseDuration: ExpressiveMotion.fast,
  )..addStatusListener(_statusChanged);
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _animation,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: _openScale,
    end: 1,
  ).animate(_progress);
  final FocusScopeNode _menuFocus = FocusScopeNode(
    debugLabel: 'ExpressiveMenu',
  );
  final ScrollController _scroll = ScrollController();
  MenuController? _internalController;
  VoidCallback? _hideOverlay;
  LocalHistoryEntry? _history;
  bool _reduced = false;

  /// 本次是否经 [openAt] 在指定位置打开（相对锚点左上角的位置记在
  /// [_openPosition]），以及打开后焦点该落在第一项还是菜单本身。
  Offset? _openPosition;
  bool _focusFirstItem = false;

  /// [openAt] 打开前的焦点：没有 [ExpressiveMenuAnchor.childFocusNode] 时，
  /// 关闭后把焦点还给它。
  FocusNode? _focusBeforeOpen;

  /// 找到包住 [context] 的菜单（菜单浮层在元素树上仍是锚点的后代）。
  static ExpressiveMenuAnchorState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ExpressiveMenuAnchorState>();

  MenuController get controller =>
      widget.controller ?? (_internalController ??= MenuController());

  /// 展开中或已展开：收起动画开始后即为 false，触发控件据此显示“已收起”。
  bool get isExpanded => _animation.status.isForwardOrCompleted;

  /// 菜单项只在展开中或已展开时响应，收起途中的点按不再执行动作。
  bool get interactive => isExpanded;

  void open() => controller.open();

  void close() => controller.close();

  /// 收起途中再点触发控件会重新展开，而不是被当作“已打开”再关一次。
  void toggle() => isExpanded ? close() : open();

  /// 在全局坐标 [globalPosition]（通常是右键的指针位置）打开菜单：菜单的
  /// 起始角贴着这一点（LTR 为左上角，下方放不下时翻到上方），夹在安全区内。
  ///
  /// 为什么打开后要把焦点移进菜单：右键时焦点通常还在页面上（如日记页的
  /// 键盘焦点），Esc 与方向键会先被页面处理（清除选中、移动卡片），而不是
  /// 关菜单。[focusFirstItem] 为 true（键盘的菜单键 / Shift+F10 打开）时焦点
  /// 直接落在第一项，回车即可执行；鼠标打开时停在菜单本身，↓ 再进入第一项。
  /// 已打开时换到新位置会从新位置重新展开。
  void openAt(Offset globalPosition, {bool focusFirstItem = false}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _focusBeforeOpen = FocusManager.instance.primaryFocus;
    _focusFirstItem = focusFirstItem;
    controller.open(position: box.globalToLocal(globalPosition));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ExpressiveMotion.reduceMotion(context);
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    _animation
      ..duration = duration
      ..reverseDuration = duration;
    // 动画途中切换到减少动画：下一帧直接跳到终点，不留半开的菜单。
    if (_reduced && _animation.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reduced) _animation.value = isExpanded ? 1 : 0;
      });
    }
  }

  @override
  void didUpdateWidget(ExpressiveMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        widget.controller != null) {
      _internalController = null;
    }
  }

  void _statusChanged(AnimationStatus status) {
    setState(() {});
    widget.onAnimationStatusChanged?.call(status);
    if (status == AnimationStatus.dismissed) _finishClose();
  }

  void _open(Offset? position, VoidCallback showOverlay) {
    // 收起途中重新展开：沿用当前浮层与进度，不重建内容，也丢掉上次收起的回调。
    _hideOverlay = null;
    final moved = controller.isOpen && position != _openPosition;
    _openPosition = position;
    if (!controller.isOpen || moved) {
      // 换到新位置：RawMenuAnchor 重新挂浮层，缩放也从头播放（从新的角）。
      showOverlay();
      if (moved && !_reduced) _animation.value = 0;
    } else if (!interactive) {
      widget.onOpen?.call();
    }
    _addHistory();
    if (!interactive) _animation.forward();
    if (position != null) {
      // 浮层这一帧才建出来，焦点要等它挂进焦点树之后再移。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.isOpen || !interactive) return;
        if (_focusFirstItem) {
          _moveFocus(forward: true);
        } else {
          _menuFocus.requestScopeFocus();
        }
      });
    }
  }

  void _close(VoidCallback hideOverlay) {
    if (!controller.isOpen) return;
    _hideOverlay = hideOverlay;
    // 收起一开始就撤掉返回拦截：动画中的返回手势应当作用于页面本身。
    _removeHistory();
    if (_menuFocus.hasFocus) {
      final returnTo = widget.childFocusNode ?? _focusBeforeOpen;
      // 打开前的焦点可能已随页面卸载（context 为 null），那时不再交还。
      if (returnTo != null && returnTo.context != null) {
        returnTo.requestFocus();
      }
    }
    _focusBeforeOpen = null;
    if (_animation.status == AnimationStatus.reverse) return;
    if (_reduced || _animation.value == 0) {
      _animation.value = 0;
      _finishClose();
    } else {
      _animation.reverse();
    }
  }

  void _finishClose() {
    final hide = _hideOverlay;
    _hideOverlay = null;
    hide?.call();
  }

  /// 打开期间在所在路由登记一条局部历史：系统返回 / 预测式返回先弹出它
  /// （从而关闭菜单），页面本身不会被返回。
  void _addHistory() {
    if (_history != null) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      // 不让 AppBar 因此把返回键换成关闭键。
      impliesAppBarDismissal: false,
      onRemove: () {
        // 自己撤销时 _history 已先置空；只有被返回弹出时才需要关菜单。
        if (_history != entry) return;
        _history = null;
        controller.close();
      },
    );
    _history = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _removeHistory() {
    final entry = _history;
    _history = null;
    entry?.remove();
  }

  void _handleClosed() {
    _removeHistory();
    widget.onClose?.call();
  }

  void _moveFocus({required bool forward}) {
    final menuContext = _menuFocus.context;
    if (!interactive || menuContext == null) return;
    // 焦点停在菜单本身（[openAt] 用鼠标打开）时还没有当前项，按“首次进入”
    // 处理：↓ 落在第一项、↑ 落在最后一项。
    if (_menuFocus.hasFocus && !_menuFocus.hasPrimaryFocus) {
      forward ? _menuFocus.nextFocus() : _menuFocus.previousFocus();
    } else {
      final policy = FocusTraversalGroup.of(menuContext);
      final node = forward
          ? policy.findFirstFocus(_menuFocus, ignoreCurrentFocus: true)
          : policy.findLastFocus(_menuFocus, ignoreCurrentFocus: true);
      node?.requestFocus();
    }
  }

  Widget _shortcuts(Widget child) => CallbackShortcuts(
    bindings: <ShortcutActivator, VoidCallback>{
      if (controller.isOpen) ...<ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): close,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveFocus(forward: true),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveFocus(forward: false),
      },
    },
    child: child,
  );

  @override
  void dispose() {
    _hideOverlay = null;
    _removeHistory();
    _progress.dispose();
    _animation.dispose();
    _menuFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: controller,
    childFocusNode: widget.childFocusNode,
    consumeOutsideTaps: true,
    onOpenRequested: _open,
    onCloseRequested: _close,
    onOpen: widget.onOpen,
    onClose: _handleClosed,
    builder: (BuildContext context, MenuController _, Widget? child) =>
        _shortcuts(widget.builder(context, this, child)),
    overlayBuilder: _buildOverlay,
    child: widget.child,
  );

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final area = ExpressiveMenuArea.of(context, info);
    // 指定位置打开时，锚点收成那一点（零尺寸、零间距）、按起始边对齐：菜单
    // 的起始角贴着指针，缩放也从这个角开始。
    final position = info.position;
    final anchor = position == null
        ? info.anchorRect
        : Rect.fromLTWH(
            info.anchorRect.left + position.dx,
            info.anchorRect.top + position.dy,
            0,
            0,
          );
    return ExpressiveMenuPosition(
      anchor: anchor,
      bounds: area.bounds,
      placement: position == null
          ? widget.placement
          : ExpressiveMenuPlacement.start,
      gap: position == null ? ExpressiveMenuPosition.defaultGap : 0,
      textDirection: Directionality.of(context),
      scale: _scale,
      child: TapRegion(
        groupId: info.tapRegionGroupId,
        consumeOutsideTaps: true,
        onTapOutside: (_) => close(),
        child: ExcludeSemantics(
          excluding: !interactive,
          child: ExcludeFocus(
            excluding: !interactive,
            child: IgnorePointer(
              ignoring: !interactive,
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                child: FocusTraversalGroup(
                  child: FocusScope(
                    node: _menuFocus,
                    skipTraversal: true,
                    child: _shortcuts(
                      ExpressiveMenuPanel(
                        reveal: _progress,
                        scrollController: _scroll,
                        // 只在展开完成后显示滚动条，缩放过程中不闪现。
                        showScrollbar:
                            _animation.status == AnimationStatus.completed,
                        maxWidth: area.maxWidth,
                        children: widget.menuChildren,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
