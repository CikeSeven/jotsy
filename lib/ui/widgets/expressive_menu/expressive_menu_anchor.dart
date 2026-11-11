import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
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

/// 应用统一的锚定弹出菜单，外观与动效移植自 NexioSchedule 的 ListPopup /
/// LiquidGlassDropdownMenu（二级菜单沿用 miuix 的级联方式），基于 [RawMenuAnchor]。
///
/// 为什么不用 SDK 的 MenuAnchor / PopupMenuButton：MenuAnchor 的展开时长固定
/// 为 500ms，PopupMenuButton 是整页路由、从中心放大且不随锚点对齐；这里用
/// 底层锚点自己掌握表面、动效与定位。
///
/// - 表面：玻璃面板（[ExpressiveMenuGlass]，22 圆角的超椭圆，环形外投影 +
///   细描边），宽 160–288，高度受安全区限制、超出时内部滚动；行样式见
///   [ExpressiveMenuItem]。不铺变暗层。
/// - 从哪长出来（容器变换，见 [ExpressiveMenuMotion]）：
///   - 图标按钮（[iconTrigger]，或不超过 56 × 56 的锚点）：面板盖住按钮，从
///     按钮那个不超过 40 的圆长成面板（贴着圆的角对齐），图标随之淡出；
///   - 其余不高于 56、不宽于 288 的入口（文字按钮、胶囊）：面板盖住它，从它
///     本身的矩形长出来，入口随之淡出；
///   - 更大的锚点（卡片、书架格）与 [ExpressiveMenuAnchorState.openAt]：面板
///     放在锚点下方 8dp（放不下翻到上方；指针处间距 0），从贴着锚点那个角上
///     28 的小圆长出来。
///   面板宽高各自以弹簧从起点插值到最终尺寸，同时从起点的角迁向自身中心；
///   内容按最终尺寸布局一次、等比缩放、分段淡入并在中途短暂模糊。收起反向，
///   图标按钮带一下回弹。减少动画时瞬时开合。收起过程中不可交互。
/// - 点按：面板统一处理——按下即亮起高亮胶囊，按住滑动可换到别的行，松手
///   执行（[ExpressiveMenuSelection]）。
/// - 二级菜单（[ExpressiveSubmenuItem]）：触发行的胶囊就地长成新面板盖在主菜单
///   上，主菜单缩到 0.95 并盖上半透明遮罩；标题行是触发行的副本，点它、点
///   遮罩、点外部、系统返回、Esc 或 ←（RTL 为 →）都先收回二级菜单。级联深度
///   上限为 2。重新展开时总是从主菜单开始。
/// - 行为：点外部关闭且不穿透；系统返回 / 预测式返回先关菜单（打开期间在
///   所在路由登记 [LocalHistoryEntry]）；Esc 关闭；↑/↓ 在菜单项间移动焦点；
///   关闭时焦点回到 [childFocusNode]。
/// - 指定位置打开（右键 / 长按菜单）：[ExpressiveMenuAnchorState.openAt] 把
///   菜单的起始角放在给定的全局坐标上（不看 [placement]），同样上下翻转并夹进
///   安全区；打开后焦点停在菜单上（键盘打开时落在第一项），关闭时焦点回到
///   打开前的位置。
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
    this.iconTrigger = false,
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

  /// 触发控件是图标按钮：面板从按钮那个圆长出来，收起时带回弹。
  final bool iconTrigger;

  /// 面板放在大锚点旁边时与它的竖直间距。
  static const double anchorGap = 8;

  /// 图标按钮那个圆的最大直径（触控区 48 里看得见的 40）。
  static const double iconSeedSize = 40;

  /// 不超过这个尺寸的锚点按图标按钮处理；不高于它的入口从自身长出来。
  static const double compactTrigger = 56;

  @override
  State<ExpressiveMenuAnchor> createState() => ExpressiveMenuAnchorState();
}

/// 当前显示的二级菜单：触发项与触发行的胶囊（主菜单内容坐标，按下时取定）。
class _OpenSubmenu {
  _OpenSubmenu({
    required this.item,
    required this.pill,
    required this.triggerFocus,
    required this.serial,
  });

  final ExpressiveSubmenuItem item;
  final Rect pill;
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

  /// 上一次浮层构建时面板是否盖住触发控件：盖住时触发控件随面板长大淡出。
  bool _coverTrigger = false;
  late final Animation<double> _triggerOpacity = _TriggerOpacity(this);
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
  /// [ExpressiveSubmenuItem] 调用）。触发行的胶囊在这时取定（主菜单内容坐标），
  /// 二级菜单显示期间不再跟着主菜单的缩放走。
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
    // 整行（含左右缩进）在主菜单内容里的矩形，缩进后就是那块胶囊。
    final rowRect = MatrixUtils.transformRect(
      row.getTransformTo(primary),
      Offset.zero & row.size,
    );
    final pill = Rect.fromLTRB(
      rowRect.left + ExpressiveMenuRowMetrics.inset,
      rowRect.top,
      rowRect.right - ExpressiveMenuRowMetrics.inset,
      rowRect.bottom,
    ).intersect(Offset.zero & primary.size);
    final submenu = _OpenSubmenu(
      item: item,
      pill: pill,
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
        if (mounted && _reduced) _motion.settleNow();
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
        _shortcuts(
          // 面板盖住触发控件长大时，触发控件随之淡出、收回时提早淡入（读屏
          // 仍能读到它的展开状态）。
          FadeTransition(
            opacity: _triggerOpacity,
            alwaysIncludeSemantics: true,
            child: widget.builder(context, this, child),
          ),
        ),
    overlayBuilder: _buildOverlay,
    child: widget.child,
  );

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    // 指定位置打开时，锚点收成那一点（零尺寸、零间距）、按起始边对齐：菜单
    // 的起始角贴着指针，也从这个角长出来。
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
    const compact = ExpressiveMenuAnchor.compactTrigger;
    final icon =
        position == null &&
        (widget.iconTrigger ||
            (anchor.width <= compact && anchor.height <= compact));
    final textTrigger =
        position == null &&
        !icon &&
        anchor.height <= compact &&
        anchor.width <= ExpressiveMenuPanel.defaultMaxWidth;
    final Rect? seed;
    if (icon) {
      final d = ExpressiveMenuAnchor.iconSeedSize.clamp(
        0.0,
        anchor.shortestSide,
      );
      seed = Rect.fromCenter(center: anchor.center, width: d, height: d);
    } else if (textTrigger) {
      seed = anchor;
    } else {
      seed = null;
    }
    _coverTrigger = seed != null;
    _motion.style = icon
        ? ExpressiveMenuMorphStyle.button
        : ExpressiveMenuMorphStyle.dropdown;
    final colors = Theme.of(context).colorScheme;
    final submenu = _submenu;
    final maskAlpha = colors.brightness == Brightness.dark ? 0.3 : 0.15;
    final cascade = ExpressiveMenuCascade(
      anchor: anchor,
      bounds: area.bounds,
      cover: seed != null,
      seed: seed,
      gap: position == null ? ExpressiveMenuAnchor.anchorGap : 0,
      placement: position == null
          ? widget.placement
          : ExpressiveMenuPlacement.start,
      textDirection: Directionality.of(context),
      motion: _motion,
      shadowColor: ExpressiveMenuSurface.ringShadowOf(colors),
      borderColor: ExpressiveMenuSurface.borderOf(colors),
      submenuPill: submenu?.pill,
      children: <Widget>[
        ExpressiveMenuGlass(motion: _motion),
        KeyedSubtree(
          key: _primaryKey,
          child: _primaryPanel(colors.scrim.withValues(alpha: maskAlpha)),
        ),
        if (submenu != null) ...<Widget>[
          ExpressiveMenuGlass(motion: _motion),
          _secondaryPanel(submenu),
        ],
      ],
    );
    return TapRegion(
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
    );
  }

  /// 主菜单：二级菜单展开时让出焦点与语义，盖上一层可点按收回的遮罩
  /// （透明度随变形进度，收回途中不拦点按）。树结构始终不变，主菜单的
  /// 滚动位置与条目状态不受二级菜单开合影响。
  Widget _primaryPanel(Color maskColor) {
    final active = submenuOpen;
    return Stack(
      children: <Widget>[
        ExcludeFocus(
          excluding: active,
          child: ExcludeSemantics(
            excluding: active,
            child: ExpressiveMenuPanel(
              scrollController: _scroll,
              jelly: _motion.primaryJelly,
              ready: () =>
                  interactive && !submenuOpen && _motion.dragSelectReadyNow,
              // 只在展开完成后显示滚动条，形变过程中不闪现。
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
  Widget _secondaryPanel(_OpenSubmenu submenu) {
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
                jelly: _motion.secondaryJelly,
                ready: () =>
                    interactive &&
                    submenuOpen &&
                    _motion.expand.value >=
                        ExpressiveMenuMotion.dragSelectReady,
                showScrollbar:
                    active && _motion.status == AnimationStatus.completed,
                header: ExpressiveSubmenuHeader(
                  item: submenu.item,
                  arrow: _motion.arrow,
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

/// 触发控件的不透明度：面板盖住它时随 [ExpressiveMenuMotion.triggerOpacity]
/// 淡出，否则恒为 1。是否盖住要等浮层布局才知道，所以每次取值时现读。
class _TriggerOpacity extends Animation<double>
    with AnimationWithParentMixin<double> {
  _TriggerOpacity(this._state);

  final ExpressiveMenuAnchorState _state;

  @override
  Animation<double> get parent => _state._motion.triggerOpacity;

  @override
  double get value =>
      _state._coverTrigger && _state.controller.isOpen ? parent.value : 1;
}
