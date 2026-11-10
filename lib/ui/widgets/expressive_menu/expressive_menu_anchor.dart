import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import 'expressive_menu_layout.dart';
import 'expressive_menu_motion.dart';
import 'expressive_menu_panel.dart';
import 'expressive_menu_row.dart';
import 'expressive_menu_surface.dart';
import 'expressive_submenu.dart';

export 'expressive_menu_layout.dart' show ExpressiveMenuPlacement;

/// 菜单入口的构建回调：拿到菜单状态（是否展开、开合方法）来画触发控件，
/// 与 `FormField.builder` 拿到 `FormFieldState` 是同一种用法。
typedef ExpressiveMenuTriggerBuilder =
    Widget Function(
      BuildContext context,
      ExpressiveMenuAnchorState menu,
      Widget? child,
    );

/// 应用统一的锚定弹出菜单，外观与动效移植自 miuix 的 OverlayListPopup /
/// OverlayCascadingListPopup，基于 [RawMenuAnchor]。
///
/// 为什么不用 SDK 的 MenuAnchor / PopupMenuButton：MenuAnchor 的展开时长固定
/// 为 500ms，PopupMenuButton 是整页路由、从中心放大且不随锚点对齐；这里用
/// 底层锚点自己掌握表面、动效与定位。
///
/// - 表面：[ExpressiveMenuPanel]（16 的超椭圆圆角、外侧投影），宽 200–288，
///   高度受安全区限制、超出时内部滚动；行样式见 [ExpressiveMenuItem]。
///   打开时整屏铺一层变暗（亮色 30% / 暗色 60% 的 scrim），面板为不透明底
///   （同 miuix；半透明玻璃叠在变暗层上只会发灰）。桌面在指针处打开的右键
///   菜单不变暗，面板保持玻璃 + 细描边。
/// - 定位：见 [placeExpressiveMenu]——默认菜单结束边对齐锚点结束边、落在锚点
///   下方 8dp，下方放不下翻到上方，都放不下以锚点居中，夹进安全区。
/// - 动效（[ExpressiveMenuMotion]）：从贴着锚点的角以弹簧放大（0.15 → 1），
///   同时按落点方向“拉开”（下方的菜单从顶边往下长，上方的从底边往上），
///   内容与玻璃 200ms 淡入、变暗层 300ms；收起沿同一弹簧缩回，150ms 淡完即
///   移除。减少动画时瞬时开合。收起过程中不可交互。
/// - 二级菜单（[ExpressiveSubmenuItem]）：触发行就地变形成一块新面板盖在
///   主菜单上，主菜单缩到 0.95 并盖上半透明遮罩；标题行是触发行的副本，
///   点它、点遮罩、点外部、系统返回、Esc 或 ←（RTL 为 →）都先收回二级
///   菜单。级联深度上限为 2。重新展开时总是从主菜单开始。
/// - 行为：点外部关闭且不穿透；系统返回 / 预测式返回先关菜单（打开期间在
///   所在路由登记 [LocalHistoryEntry]）；Esc 关闭；↑/↓ 在菜单项间移动焦点；
///   关闭时焦点回到 [childFocusNode]。
/// - 指定位置打开（右键 / 长按菜单）：[ExpressiveMenuAnchorState.openAt] 把
///   菜单的起始角放在给定的全局坐标上（间距 0，不看 [placement]），同样
///   上下翻转并夹进安全区；打开后焦点停在菜单上（键盘打开时落在第一项），
///   关闭时焦点回到打开前的位置。
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

  /// 菜单与锚点之间的竖直间距（miuix 的 dropdown verticalMargin）。
  static const double anchorGap = 8;

  @override
  State<ExpressiveMenuAnchor> createState() => ExpressiveMenuAnchorState();
}

/// 当前显示的二级菜单：触发项、触发行在主菜单里的矩形（按下时取定）等。
class _OpenSubmenu {
  _OpenSubmenu({
    required this.item,
    required this.anchor,
    required this.anchorIsFirst,
    required this.anchorIsLast,
    required this.anchorPadTop,
    required this.triggerFocus,
    required this.serial,
  });

  final ExpressiveSubmenuItem item;
  final Rect anchor;
  final bool anchorIsFirst;
  final bool anchorIsLast;
  final double anchorPadTop;
  final FocusNode? triggerFocus;
  final int serial;
  LocalHistoryEntry? history;
}

/// 标记二级菜单的子树：其中的 [ExpressiveSubmenuItem] 不再展开（深度上限 2）。
class _SecondaryScope extends InheritedWidget {
  const _SecondaryScope({required super.child});

  @override
  bool updateShouldNotify(_SecondaryScope oldWidget) => false;
}

/// 透明度类进度（弹簧可能有极小的过冲）夹回 0…1。
class _Clamp01 extends Animatable<double> {
  const _Clamp01();

  @override
  double transform(double t) => t.clamp(0.0, 1.0);
}

/// [ExpressiveMenuAnchor] 的状态；[ExpressiveMenuItem] 经 [maybeOf] 找到它来关闭菜单。
class ExpressiveMenuAnchorState extends State<ExpressiveMenuAnchor>
    with TickerProviderStateMixin {
  late final ExpressiveMenuMotion _motion = ExpressiveMenuMotion(
    vsync: this,
    onStatusChanged: _statusChanged,
    onSecondaryCollapsed: _submenuSettled,
  );
  late final Animation<double> _maskOpacity = _motion.expand.drive(
    const _Clamp01(),
  );
  final FocusScopeNode _menuFocus = FocusScopeNode(
    debugLabel: 'ExpressiveMenu',
  );
  final ScrollController _scroll = ScrollController();
  final GlobalKey _primaryKey = GlobalKey(debugLabel: 'ExpressiveMenuPrimary');
  final ExpressiveSubmenuMetrics _submenuMetrics = ExpressiveSubmenuMetrics();
  MenuController? _internalController;
  VoidCallback? _hideOverlay;
  LocalHistoryEntry? _history;
  bool _reduced = false;

  /// 正在显示（含收回途中）的二级菜单。
  _OpenSubmenu? _submenu;
  int _submenuSerial = 0;

  /// 本次是否经 [openAt] 在指定位置打开（相对锚点左上角的位置记在
  /// [_openPosition]），以及打开后焦点该落在第一项还是菜单本身。
  Offset? _openPosition;
  bool _focusFirstItem = false;

  /// [openAt] 打开前的焦点：没有 [ExpressiveMenuAnchor.childFocusNode] 时，
  /// 关闭后把焦点还给它。
  FocusNode? _focusBeforeOpen;

  /// 所在子树的 ticker 是否在走（见 [didChangeDependencies]）。
  bool _tickersEnabled = true;

  /// 找到包住 [context] 的菜单（菜单浮层在元素树上仍是锚点的后代）。
  static ExpressiveMenuAnchorState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ExpressiveMenuAnchorState>();

  MenuController get controller =>
      widget.controller ?? (_internalController ??= MenuController());

  /// 展开中或已展开：收起动画开始后即为 false，触发控件据此显示“已收起”。
  bool get isExpanded => _motion.status.isForwardOrCompleted;

  /// 浮层是否还挂着（从展开到收起动画结束）：图标按钮据此保持按下的底色，
  /// 同 miuix 的 holdDown 到 onDismissFinished 才松开。
  bool get isShowing => controller.isOpen;

  /// 菜单项只在展开中或已展开时响应，收起途中的点按不再执行动作。
  bool get interactive => isExpanded;

  /// 二级菜单是否展开着（收回途中为 false）。
  bool get submenuOpen => _submenu != null && _motion.secondaryExpanded;

  void open() => controller.open();

  void close() => controller.close();

  /// 收起途中再点触发控件会重新展开，而不是被当作“已打开”再关一次；
  /// 二级菜单开着时先收回二级菜单（同点外部）。
  void toggle() {
    if (!isExpanded) {
      open();
    } else if (submenuOpen) {
      closeSubmenu();
    } else {
      close();
    }
  }

  /// 从 [itemContext] 所在的那一行展开 [item] 的二级菜单（由
  /// [ExpressiveSubmenuItem] 调用）。触发行的矩形在这时取定（主菜单自身
  /// 坐标；首末行延伸到面板边缘），二级菜单显示期间不再跟着主菜单的缩放走。
  void openSubmenu(
    ExpressiveSubmenuItem item,
    BuildContext itemContext,
    FocusNode? triggerFocus,
  ) {
    if (!interactive || submenuOpen) return;
    if (itemContext.getInheritedWidgetOfExactType<_SecondaryScope>() != null) {
      assert(false, 'ExpressiveSubmenuItem 只支持两级：二级菜单里的不会再展开。');
      return;
    }
    final row = itemContext.findRenderObject();
    final primary = _primaryKey.currentContext?.findRenderObject();
    if (row is! RenderBox ||
        primary is! RenderBox ||
        !row.hasSize ||
        !primary.hasSize) {
      return;
    }
    final bounds = MatrixUtils.transformRect(
      row.getTransformTo(primary),
      Offset.zero & row.size,
    );
    final extension =
        ExpressiveMenuRowEdges.maybeOf(itemContext)?.extensionFor(row) ??
        EdgeInsets.zero;
    final anchor = Rect.fromLTRB(
      bounds.left,
      bounds.top - extension.top,
      bounds.right,
      bounds.bottom + extension.bottom,
    ).intersect(Offset.zero & primary.size);
    final submenu = _OpenSubmenu(
      item: item,
      anchor: anchor,
      anchorIsFirst: extension.top > 0,
      anchorIsLast: extension.bottom > 0,
      anchorPadTop: ExpressiveMenuRowMetrics.verticalPadding + extension.top,
      triggerFocus: triggerFocus,
      serial: ++_submenuSerial,
    );
    final route = ModalRoute.of(context);
    if (route != null) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        // 不让 AppBar 因此把返回键换成关闭键。
        impliesAppBarDismissal: false,
        onRemove: () {
          // 主动收回时已先解除关联；只有被系统返回弹出时才收回。
          if (submenu.history != entry) return;
          submenu.history = null;
          if (identical(_submenu, submenu)) _collapseSubmenu();
        },
      );
      submenu.history = entry;
      route.addLocalHistoryEntry(entry);
    }
    setState(() => _submenu = submenu);
    _motion.expandSecondary(reduced: _reduced);
    if (!_menuFocus.hasFocus) return;
    // 键盘操作：焦点落到二级菜单的第一项（标题行），↑↓ 可以接着移动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menuContext = _menuFocus.context;
      if (!mounted || !submenuOpen || menuContext == null) return;
      FocusTraversalGroup.of(
        menuContext,
      ).findFirstFocus(_menuFocus, ignoreCurrentFocus: true)?.requestFocus();
    });
  }

  /// 收回二级菜单；没有展开时什么也不做。
  void closeSubmenu() {
    if (!interactive || !submenuOpen) return;
    _collapseSubmenu();
  }

  void _collapseSubmenu() {
    final submenu = _submenu;
    if (submenu == null || !_motion.secondaryExpanded) return;
    _releaseSubmenuHistory(submenu);
    final refocus = _menuFocus.hasFocus ? submenu.triggerFocus : null;
    setState(() {});
    _motion.collapseSecondary(reduced: _reduced);
    if (refocus == null) return;
    // 主菜单要等这一帧解除 ExcludeFocus 后才能接回焦点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && refocus.context != null && !submenuOpen) {
        refocus.requestFocus();
      }
    });
  }

  /// 二级菜单的收回弹簧落定：卸掉它。
  void _submenuSettled() {
    if (!mounted || _motion.secondaryExpanded || _submenu == null) return;
    setState(() => _submenu = null);
  }

  void _releaseSubmenuHistory(_OpenSubmenu submenu) {
    final entry = submenu.history;
    submenu.history = null;
    entry?.remove();
  }

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
    // 动画途中切换到减少动画：下一帧直接跳到终点，不留半开的菜单。
    if (_reduced && _motion.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reduced) _motion.settle();
      });
    }
    // 所在页面的 ticker 被静音（首页切走了这个 Tab，如“更多 → 设置”）：
    // 开合动画不会再前进，收起永远等不到结束，浮层连同点外部拦截
    // （consumeOutsideTaps）一直留着，吞掉底栏等别处的点按。此时直接关掉
    // 菜单、不播动画。build 期间不能开合，放到这一帧之后。
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    if (!_tickersEnabled && controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_tickersEnabled) _dismissImmediately();
      });
    }
  }

  /// 不播动画地关掉菜单（还没开始收起时先发起收起，再直接跳到终点）。
  void _dismissImmediately() {
    if (!controller.isOpen) return;
    if (_motion.status != AnimationStatus.reverse) controller.close();
    _motion.snapClosed();
    _finishClose();
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
    if (mounted) setState(() {});
    widget.onAnimationStatusChanged?.call(status);
    if (status == AnimationStatus.dismissed) _finishClose();
  }

  void _open(Offset? position, VoidCallback showOverlay) {
    // 收起途中重新展开：沿用当前浮层与进度，不重建内容，也丢掉上次收起的回调。
    _hideOverlay = null;
    final moved = controller.isOpen && position != _openPosition;
    _openPosition = position;
    if (!controller.isOpen || moved) {
      // 重新挂浮层的展开总是从主菜单开始。
      _submenu = null;
      _motion.collapseSecondary(reduced: true);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      showOverlay();
      // 换到新位置：RawMenuAnchor 重新挂浮层，展开也从头播放（从新的角）。
      if (moved && !_reduced) _motion.restart();
    } else if (!interactive) {
      widget.onOpen?.call();
    }
    _addHistory();
    if (!interactive) {
      _reduced ? _motion.snapOpen() : _motion.open();
    }
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
    final submenu = _submenu;
    if (submenu != null) _releaseSubmenuHistory(submenu);
    _removeHistory();
    if (_menuFocus.hasFocus) {
      final returnTo = widget.childFocusNode ?? _focusBeforeOpen;
      // 打开前的焦点可能已随页面卸载（context 为 null），那时不再交还。
      if (returnTo != null && returnTo.context != null) {
        returnTo.requestFocus();
      }
    }
    _focusBeforeOpen = null;
    if (_motion.status == AnimationStatus.reverse) return;
    if (_reduced || _motion.status == AnimationStatus.dismissed) {
      _motion.snapClosed();
      _finishClose();
    } else {
      _motion.close();
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
    final submenu = _submenu;
    if (submenu != null) _releaseSubmenuHistory(submenu);
    _submenu = null;
    widget.onClose?.call();
  }

  void _handleOutsideTap() => submenuOpen ? closeSubmenu() : close();

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
        // 二级菜单开着时 Esc 先收回它，与系统返回一致。
        const SingleActivator(LogicalKeyboardKey.escape): _handleOutsideTap,
        if (submenuOpen)
          SingleActivator(
            Directionality.of(context) == TextDirection.rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          ): closeSubmenu,
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
    final submenu = _submenu;
    if (submenu != null) _releaseSubmenuHistory(submenu);
    _removeHistory();
    _motion.dispose();
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
    final area = ExpressiveMenuArea.of(context, info.overlaySize, anchor);
    final colors = Theme.of(context).colorScheme;
    // 桌面的右键菜单（在指针处打开）不铺变暗层：右键随手就点，整窗一暗太重。
    final dimmed = position == null || !AppPlatform.isDesktop;
    final dimAlpha = colors.brightness == Brightness.dark ? 0.6 : 0.3;
    final submenu = _submenu;
    final cascade = ExpressiveMenuCascade(
      anchor: anchor,
      bounds: area.bounds,
      placement: position == null
          ? widget.placement
          : ExpressiveMenuPlacement.start,
      textDirection: Directionality.of(context),
      margin: position == null ? ExpressiveMenuAnchor.anchorGap : 0,
      motion: _motion,
      shadowColor: ExpressiveMenuSurface.shadowOf(colors),
      // 变暗层上的面板是不透明底，不需要描边勾轮廓（同 miuix）。
      borderColor: dimmed
          ? Colors.transparent
          : ExpressiveMenuSurface.borderOf(colors),
      submenuAnchor: submenu?.anchor,
      submenuAnchorIsFirst: submenu?.anchorIsFirst ?? false,
      submenuAnchorIsLast: submenu?.anchorIsLast ?? false,
      submenuMetrics: _submenuMetrics,
      primary: KeyedSubtree(
        key: _primaryKey,
        child: _primaryPanel(
          colors.scrim.withValues(alpha: dimAlpha / 2),
          solid: dimmed,
        ),
      ),
      secondary: submenu == null
          ? null
          : _secondaryPanel(submenu, solid: dimmed),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (dimmed)
          IgnorePointer(
            child: FadeTransition(
              opacity: _motion.dim,
              child: ColoredBox(
                color: colors.scrim.withValues(alpha: dimAlpha),
              ),
            ),
          ),
        TapRegion(
          groupId: info.tapRegionGroupId,
          consumeOutsideTaps: true,
          onTapOutside: (_) => _handleOutsideTap(),
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
                      child: _shortcuts(cascade),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 主菜单：二级菜单展开时让出焦点与语义，盖上一层可点按收回的遮罩
  /// （透明度随变形进度，收回途中不拦点按）。树结构始终不变，主菜单的
  /// 滚动位置与条目状态不受二级菜单开合影响。
  Widget _primaryPanel(Color maskColor, {required bool solid}) {
    final active = submenuOpen;
    return Stack(
      children: <Widget>[
        ExcludeFocus(
          excluding: active,
          child: ExcludeSemantics(
            excluding: active,
            child: ExpressiveMenuPanel(
              alpha: _motion.alpha,
              solid: solid,
              scrollController: _scroll,
              // 只在展开完成后显示滚动条，缩放过程中不闪现。
              showScrollbar: _motion.status == AnimationStatus.completed,
              children: widget.menuChildren,
            ),
          ),
        ),
        if (_submenu != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !active,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: closeSubmenu,
                child: FadeTransition(
                  opacity: _maskOpacity,
                  child: ColoredBox(color: maskColor),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 二级菜单：标题行（触发行的副本）+ 分隔线 + 条目；收回途中不再响应。
  Widget _secondaryPanel(_OpenSubmenu submenu, {required bool solid}) {
    final active = submenuOpen;
    return _SecondaryScope(
      child: KeyedSubtree(
        // 每次展开都是新的一块：不复用上一个二级菜单的条目状态与滚动位置。
        key: ValueKey<int>(submenu.serial),
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: IgnorePointer(
              ignoring: !active,
              child: ExpressiveMenuPanel(
                alpha: _motion.alpha,
                solid: solid,
                showScrollbar:
                    active && _motion.status == AnimationStatus.completed,
                header: ExpressiveSubmenuHeader(
                  item: submenu.item,
                  expand: _motion.expand,
                  arrow: _motion.arrow,
                  anchorHeight: submenu.anchor.height,
                  anchorPadTop: submenu.anchorPadTop,
                  metrics: _submenuMetrics,
                  onCollapse: closeSubmenu,
                ),
                children: <Widget>[
                  const ExpressiveMenuDivider(),
                  ...submenu.item.menuChildren,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
