import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/app_effects.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../controllers/notebook_switcher_controller.dart';
import '../../providers/home_notebook_scope_provider.dart';
import '../../providers/notebook_providers.dart';
import '../../viewmodels/notebook_deck_entries.dart';
import '../../viewmodels/notebook_deck_layout.dart';
import '../../viewmodels/notebook_tree.dart';
import '../../viewmodels/notebook_view.dart';
import '../notebook_cover_parts.dart';
import 'notebook_deck_card.dart';
import 'notebook_switcher_indicator.dart';
import 'notebook_switcher_panel.dart';

/// 日记本卡组的浮层（经 `OverlayPortal` 画在首页路由之上、之后推入的页面
/// 之下）：遮罩、从起点形变成面板的容器、落进切换胶囊时的胶囊副本。
///
/// 几何逐帧按 [NotebookSwitcherController.stage] 计算（见控制器的类注释），
/// 面板竖直方向悬浮在唤出的位置（[NotebookSwitcherController.panelAnchor]）：
/// - 0 → 1：左缘胶囊，左端藏在屏外，纵向中心跟着手指；
/// - 1 → 2：容器从起点（左缘胶囊 / 切换胶囊）插值到面板，圆角插值到 28；
///   面板内容始终按最终尺寸排版、由容器裁切露出；
/// - 遮罩 = 24% × (stage − 1)。
///
/// 容器内的过渡都在容器表面之内：胶囊里的图标淡出、顶栏与卡片发牌进场；
/// 从切换胶囊打开 / 收进切换胶囊时，容器表面在胶囊附近淡入淡出，胶囊
/// 副本（与真实胶囊同一个组件）在它上面接力，落地时与真实胶囊逐像素一致
/// 再换回真实胶囊。
class NotebookSwitcherOverlay extends ConsumerStatefulWidget {
  const NotebookSwitcherOverlay({
    super.key,
    required this.controller,
    required this.chipReplica,
  });

  final NotebookSwitcherController controller;

  /// 切换胶囊的副本（当前范围，样式与真实胶囊相同），收进 / 从胶囊打开时
  /// 盖在胶囊的位置上。
  final WidgetBuilder chipReplica;

  /// 面板与列表栏边缘、屏幕上下安全区的间距。
  static const double margin = 12;
  static const double maxWidth = 360;

  /// 窄窗口里面板右侧至少露出的列表宽度（点它关闭）。
  static const double listPeek = 60;
  static const double wideMaxHeight = 640;
  static const double panelRadius = 28;

  /// 左缘胶囊藏在屏外的宽度、武装时露出的宽度与高度范围。
  static const double pillHidden = 24;
  static const double pillWidth = 30;
  static const double pillMinHeight = 56;
  static const double pillMaxHeight = 72;

  @override
  ConsumerState<NotebookSwitcherOverlay> createState() =>
      _NotebookSwitcherOverlayState();
}

class _NotebookSwitcherOverlayState
    extends ConsumerState<NotebookSwitcherOverlay>
    with TickerProviderStateMixin {
  /// 面板高度（展开 / 收起子本时弹簧到新高度）。
  late final AnimationController _height = AnimationController.unbounded(
    vsync: this,
  );
  double? _heightTarget;

  /// 发牌进度：stage 1 → 2 映射到 0 → 1。
  late final Animation<double> _reveal = widget.controller.stage.drive(
    Animatable<double>.fromCallback(
      (double stage) => (stage - 1).clamp(0.0, 1.0),
    ),
  );

  /// 打开时为露出当前本子而展开的项（见 [notebookDeckRevealKeys]）：只在
  /// 打开那一刻算一次，切换途中范围变了也不重新展开、卡片不跳；用户收起
  /// 其中一项时从这里移除，之后照常能收能放。
  Set<String>? _revealed;

  Set<String> _revealedFor(List<NotebookView> notebooks, NotebookTree tree) {
    final cached = _revealed;
    if (cached != null) return cached;
    final current = ref.read(homeNotebookScopeProvider).notebookId;
    // 书架还没读到当前本子时先不定下来，读到后再算。
    if (current != null && tree[current] == null) return const <String>{};
    return _revealed = <String>{
      ...notebookDeckRevealKeys(
        notebooks: notebooks,
        tree: tree,
        currentNotebookId: current,
      ),
    };
  }

  Rect? _lastChip;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAnchorChanged);
  }

  @override
  void didUpdateWidget(covariant NotebookSwitcherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleAnchorChanged);
      widget.controller.addListener(_handleAnchorChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAnchorChanged);
    _topShift.dispose();
    _height.dispose();
    super.dispose();
  }

  bool _isCurrent(NotebookDeckEntry entry, HomeNotebookScope scope) =>
      switch (entry.kind) {
        NotebookDeckEntryKind.all => scope.isAll,
        NotebookDeckEntryKind.unfiled => scope.unfiled,
        NotebookDeckEntryKind.notebook =>
          entry.notebook!.id == scope.notebookId,
        NotebookDeckEntryKind.closedHeader => false,
      };

  /// 展开 / 收起子本或“已合上”这一叠。打开时自动展开的项收起时也要从
  /// [_revealed] 里拿掉，否则它一直被并进展开状态、收不起来。
  void _toggle(NotebookDeckEntry entry) {
    final key = entry.kind == NotebookDeckEntryKind.closedHeader
        ? deckGroupPrefix(NotebookDeckGroup.closed)
        : '${deckGroupPrefix(entry.group)}:${entry.notebook!.id}';
    final notifier = ref.read(notebookDeckExpandedProvider.notifier);
    final stored = ref.read(notebookDeckExpandedProvider).contains(key);
    final revealed = _revealed?.contains(key) ?? false;
    if (stored || revealed) {
      if (revealed) setState(() => _revealed!.remove(key));
      if (stored) notifier.toggle(key);
    } else {
      notifier.toggle(key);
    }
  }

  /// 拉出时先把前几张封面解码好：卡片出现时不再中途淡入。
  void _precache(List<NotebookDeckEntry> entries, double cardWidth) {
    if (_precached) return;
    _precached = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      var count = 0;
      for (final entry in entries) {
        final notebook = entry.notebook;
        final path = notebook?.coverPath;
        if (notebook == null || path == null) continue;
        precacheImage(
          NotebookCoverImage.providerFor(
            path: path,
            width: cardWidth,
            height: NotebookDeckLayout.cardHeight - NotebookDeckLayout.peek,
            style: notebook.coverStyle,
            devicePixelRatio: dpr,
          ),
          context,
          onError: (Object _, StackTrace? _) {},
        );
        if (++count >= 8) break;
      }
    });
  }

  /// 面板的矩形（全局坐标）：贴列表栏行首，竖直方向悬浮在唤出的位置
  /// （[NotebookPanelAnchor]：右滑以武装时手指的高度为中心，切换胶囊时顶边
  /// 贴在胶囊下方；还没武装时以手指为中心），夹在上下安全区之内。面板比
  /// 可用高度还高时铺满（中宽窗口最高 640）。
  Rect _panelRect({
    required Rect pane,
    required double height,
    required MediaQueryData view,
    required double sign,
    required NotebookPanelAnchor? anchor,
    required double fallbackY,
    bool record = false,
  }) {
    const margin = NotebookSwitcherOverlay.margin;
    final padding = view.padding;
    final compact = !AppBreakpoints.classOf(pane.width).isWide;
    final width = compact
        ? math.min(
            pane.width - NotebookSwitcherOverlay.listPeek - margin,
            NotebookSwitcherOverlay.maxWidth,
          )
        : math.min(NotebookSwitcherOverlay.maxWidth, pane.width - 2 * margin);
    final left = sign > 0
        ? math.max(pane.left + margin, padding.left + margin)
        : math.min(
                pane.right - margin,
                view.size.width - padding.right - margin,
              ) -
              width;
    final topBound = padding.top + margin;
    final bottomBound = view.size.height - padding.bottom - margin;
    final room = bottomBound - topBound;
    final h = math.min(
      height,
      compact ? room : math.min(NotebookSwitcherOverlay.wideMaxHeight, room),
    );
    final maxTop = math.max(topBound, bottomBound - h);
    final double settled;
    if (anchor == null) {
      settled = (fallbackY - h / 2).clamp(topBound, maxTop);
    } else {
      // 第一次见到的锚点（从切换胶囊打开时一开始就有）直接定下顶边；之后
      // 的更换由 [_handleAnchorChanged] 在构建之外处理。
      if (!identical(anchor, _topAnchor)) _adoptAnchor(anchor, h);
      settled = _anchorTop.clamp(topBound, maxTop);
    }
    final top = settled + _topShift.value;
    if (record) {
      _lastTop = top;
      _lastHeight = h;
      _lastTopBound = topBound;
      _lastMaxTop = maxTop;
    }
    return Rect.fromLTWH(left, top, width, h);
  }

  /// 当前锚点与它换算出的面板顶边（未夹取）。以中心定位的锚点只在第一次
  /// 见到时按当时的高度换算并记住：之后展开子本、面板变高时顶边不动、只
  /// 往下长（手指刚点的角标不会被推走），碰到底边才由夹取往上让。
  NotebookPanelAnchor? _topAnchor;
  double _anchorTop = 0;

  void _adoptAnchor(NotebookPanelAnchor anchor, double height) {
    _topAnchor = anchor;
    _anchorTop = anchor.top ? anchor.y : anchor.y - height / 2;
  }

  /// 锚点更换时面板顶边的过渡位移：从旧位置出发，弹簧归零。
  late final AnimationController _topShift = AnimationController.unbounded(
    vsync: this,
  );

  /// 上一帧面板的顶边、高度与顶边的夹取范围（锚点更换时据此算出位移）。
  double? _lastTop;
  double _lastHeight = 0;
  double _lastTopBound = 0;
  double _lastMaxTop = 0;

  /// 控制器换了锚点（收回途中在别处被手指接住、拉回阈值内换个高度再武装）：
  /// 面板已经在屏上时从原来的位置滑到新位置，而不是瞬移。在监听回调里
  /// 处理（不在构建中启动动画）。
  void _handleAnchorChanged() {
    final anchor = widget.controller.panelAnchor;
    if (identical(anchor, _topAnchor)) return;
    if (anchor == null) {
      _topAnchor = null;
      return;
    }
    final hadAnchor = _topAnchor != null;
    final previous = _lastTop;
    _adoptAnchor(anchor, _lastHeight);
    if (!hadAnchor || previous == null || !mounted) return;
    final next = _anchorTop.clamp(_lastTopBound, _lastMaxTop);
    final shift = previous - next;
    if (shift.abs() < 0.5) return;
    _topShift.value = shift;
    ExpressiveMotion.springTo(
      context,
      _topShift,
      0,
      spring: ExpressiveMotion.springSpatial,
    );
  }

  /// 左缘胶囊在进度 [t]（0–1）时的矩形。
  Rect _pillRect(Rect pane, double t, double fingerY, double sign) {
    const hidden = NotebookSwitcherOverlay.pillHidden;
    final width = NotebookSwitcherOverlay.pillWidth * t;
    final height =
        NotebookSwitcherOverlay.pillMinHeight +
        (NotebookSwitcherOverlay.pillMaxHeight -
                NotebookSwitcherOverlay.pillMinHeight) *
            t;
    final room = NotebookSwitcherOverlay.pillMaxHeight;
    final centerY = pane.height <= room * 2
        ? pane.center.dy
        : fingerY.clamp(pane.top + room, pane.bottom - room);
    final edge = sign > 0 ? pane.left : pane.right;
    return sign > 0
        ? Rect.fromLTRB(
            edge - hidden,
            centerY - height / 2,
            edge + width,
            centerY + height / 2,
          )
        : Rect.fromLTRB(
            edge - width,
            centerY - height / 2,
            edge + hidden,
            centerY + height / 2,
          );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scope = ref.watch(homeNotebookScopeProvider);
    final notebooks =
        ref.watch(notebooksProvider).value ?? const <NotebookView>[];
    final tree = ref.watch(notebookTreeProvider) ?? NotebookTree.empty;
    final expanded = <String>{
      ...ref.watch(notebookDeckExpandedProvider),
      ..._revealedFor(notebooks, tree),
    };
    final entries = buildNotebookDeckEntries(
      notebooks: notebooks,
      tree: tree,
      expanded: expanded,
    );
    final layout = NotebookDeckLayout(entries);
    // 真实的窗口安全区（首页 Scaffold 给 body 的 padding 含底栏槽位）；
    // 依赖窗口尺寸，旋转或改窗口大小时重新排面板。
    MediaQuery.sizeOf(context);
    final view = MediaQueryData.fromView(View.of(context));
    final pane = controller.pane ?? Offset.zero & view.size;
    final sign = controller.directionSign;
    final contentHeight = NotebookSwitcherPanel.headerHeight + layout.extent;
    final target = _panelRect(
      pane: pane,
      height: contentHeight,
      view: view,
      sign: sign,
      anchor: controller.panelAnchor,
      fallbackY: controller.fingerY,
    );
    final heightTarget = _heightTarget;
    if (heightTarget == null) {
      _heightTarget = target.height;
      _height.value = target.height;
    } else if (heightTarget != target.height) {
      // 展开 / 收起子本：面板高度弹簧到新高度（放到帧后，build 里不启动
      // 动画）。
      _heightTarget = target.height;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final next = _heightTarget;
        if (!mounted || next == null) return;
        ExpressiveMotion.springTo(
          context,
          _height,
          next,
          spring: ExpressiveMotion.springSpatial,
        );
      });
    }
    final cardWidth =
        target.width -
        NotebookSwitcherPanel.deckPadding * 2 -
        NotebookDeckCard.paperRoom;
    _precache(entries, cardWidth);
    final panel = RepaintBoundary(
      child: NotebookSwitcherPanel(
        entries: entries,
        layout: layout,
        controller: controller,
        reveal: _reveal,
        viewportHeight: target.height - NotebookSwitcherPanel.headerHeight,
        isCurrent: (NotebookDeckEntry entry) => _isCurrent(entry, scope),
        onToggle: _toggle,
      ),
    );
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    return NotificationListener<ScrollNotification>(
      // 卡组的滚动不往上冒：首页按滚动隐藏底栏的监听不认层级。
      onNotification: (_) => true,
      // 打开后在面板或遮罩上横向拖动：往回收起（与右滑拉出同一根进度轴
      // 反着跟手）。纵向滚动卡组照旧，谁先越过自己方向的溢出距离谁接手。
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(
                  debugOwner: this,
                  supportedDevices: _dragDevices,
                ),
                (HorizontalDragGestureRecognizer instance) {
                  instance
                    ..gestureSettings = gestureSettings
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = (DragStartDetails details) {
                      controller.closeDragStart(details.globalPosition);
                    }
                    ..onUpdate = (DragUpdateDetails details) {
                      controller.dragUpdate(
                        details.globalPosition,
                        details.delta.dx,
                      );
                    }
                    ..onEnd = (DragEndDetails details) {
                      controller.dragEnd(details.velocity.pixelsPerSecond.dx);
                    }
                    ..onCancel = controller.dragCancel;
                },
              ),
        },
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            controller,
            controller.stage,
            controller.armPop,
            _height,
            _topShift,
          ]),
          child: panel,
          builder: (BuildContext context, Widget? panel) =>
              _frame(context, panel!, pane: pane, view: view, sign: sign),
        ),
      ),
    );
  }

  /// 收起用的拖动只认触屏与手写笔，与右滑拉出一致。
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  Widget _frame(
    BuildContext context,
    Widget panel, {
    required Rect pane,
    required MediaQueryData view,
    required double sign,
  }) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final stage = controller.stage.value;
    final fromChip = controller.origin == NotebookSwitcherOrigin.chip;
    final chip = controller.host.chipRect ?? _lastChip;
    if (chip != null) _lastChip = chip;
    final panelRect = _panelRect(
      pane: pane,
      height: _height.value,
      view: view,
      sign: sign,
      anchor: controller.panelAnchor,
      fallbackY: controller.fingerY,
      record: true,
    );
    final useChip = fromChip && chip != null;
    final anchor = useChip
        ? chip
        : _pillRect(pane, 1, controller.fingerY, sign);
    final anchorRadius = useChip ? 10.0 : anchor.height / 2;
    final Rect rect;
    final double radius;
    if (!useChip && stage <= 1) {
      rect = _pillRect(pane, stage.clamp(0.0, 1.0), controller.fingerY, sign);
      radius = rect.height / 2;
    } else {
      final t = math.max(0.0, stage - 1);
      rect = Rect.lerp(anchor, panelRect, t)!;
      radius = lerpDouble(
        anchorRadius,
        NotebookSwitcherOverlay.panelRadius,
        t.clamp(0.0, 1.0),
      )!;
    }
    final open = (stage - 1).clamp(0.0, 1.0);
    final surface = useChip ? ((stage - 1) / 0.3).clamp(0.0, 1.0) : 1.0;
    final replica = useChip ? 1 - ((stage - 1) / 0.25).clamp(0.0, 1.0) : 0.0;
    final pillContent = useChip ? 0.0 : 1 - ((stage - 1) / 0.3).clamp(0.0, 1.0);
    final interactive = controller.phase == NotebookSwitcherPhase.open;
    final borderRadius = BorderRadius.circular(radius);

    // 胶囊里图标的中心：露在屏内那一段的正中。
    final visible = math.max(
      0.0,
      rect.width - NotebookSwitcherOverlay.pillHidden,
    );
    final iconCenterX = sign > 0
        ? NotebookSwitcherOverlay.pillHidden + visible / 2
        : rect.width - NotebookSwitcherOverlay.pillHidden - visible / 2;

    // 面板内容钉在容器的行首上角、按最终尺寸排版：容器长大时内容跟着它
    // 从左缘（或胶囊处）滑出来，顶栏最先露出；再带一点从 0.92 起的整体
    // 缩放，像窗口从起点“长”出来。只是合成层的变换，不重排。
    final contentScale = lerpDouble(0.92, 1, open)!;
    // 左缘胶囊时铺一层次要容器色：亮色页面上白色胶囊看不出来；长成面板的
    // 前 30% 里褪成面板底色（同一块表面里的颜色过渡，不透出下面的列表）。
    final tint = useChip ? 0.0 : 1 - ((stage - 1) / 0.3).clamp(0.0, 1.0);
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // 子项结构恒定（染色层常驻，透明时 ColoredBox 不画）：增删前面的
          // 子项会让面板换下标、整棵卡组被重建，滚动与弹簧状态全丢。
          Positioned.fill(
            child: ColoredBox(
              color: scheme.secondaryContainer.withValues(alpha: tint),
            ),
          ),
          Positioned(
            left: sign > 0 ? 0 : rect.width - panelRect.width,
            top: 0,
            width: panelRect.width,
            height: panelRect.height,
            child: Transform.scale(
              scale: contentScale,
              alignment: sign > 0 ? Alignment.topLeft : Alignment.topRight,
              child: IgnorePointer(ignoring: !interactive, child: panel),
            ),
          ),
          if (pillContent > 0)
            Positioned(
              left: iconCenterX - NotebookSwitcherIndicator.size / 2,
              top: rect.height / 2 - NotebookSwitcherIndicator.size / 2,
              child: Opacity(
                opacity: pillContent,
                child: NotebookSwitcherIndicator(
                  progress: stage.clamp(0.0, 1.0),
                  armPop: controller.armPop.value,
                ),
              ),
            ),
        ],
      ),
    );

    final glass = AppGlass.of(context).isGlass(AppGlassComponent.sheets);
    final Widget container;
    if (glass) {
      container = AppGlassSurface(
        component: AppGlassComponent.sheets,
        borderRadius: borderRadius,
        progress: surface,
        blur: AppGlassBlur.always,
        shadow: true,
        child: content,
      );
    } else {
      final base =
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          scheme.surfaceContainerLow;
      container = DecoratedBox(
        decoration: BoxDecoration(
          color: base.withValues(alpha: base.a * surface),
          borderRadius: borderRadius,
          boxShadow: surface < 1 ? null : AppEffects.softShadow(scheme),
        ),
        child: content,
      );
    }

    final l10n = context.l10n;
    return Semantics(
      scopesRoute: interactive,
      namesRoute: interactive,
      explicitChildNodes: true,
      label: interactive ? l10n.notebookTitle : null,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Semantics(
              button: interactive,
              label: interactive ? l10n.commonClose : null,
              onTap: interactive ? controller.close : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: interactive ? controller.close : null,
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.24 * open),
                ),
              ),
            ),
          ),
          Positioned.fromRect(rect: rect, child: container),
          if (replica > 0 && chip != null)
            Positioned.fromRect(
              rect: chip,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: replica,
                    child: widget.chipReplica(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
