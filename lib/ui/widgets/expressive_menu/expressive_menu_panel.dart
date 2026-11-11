import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../glass/glass_surface.dart';
import 'expressive_menu_motion.dart';
import 'expressive_menu_row.dart';
import 'expressive_menu_selection.dart';
import 'expressive_menu_surface.dart';

/// 一块菜单面板的内容（主菜单或二级菜单）：可滚动的一列菜单行，背后是滑动的
/// 高亮胶囊，最外面是这块面板唯一的点按 / 跟手滑选手势层。玻璃底由
/// [ExpressiveMenuGlass] 单独画（形变时按面板矩形裁出），这里只管内容。
///
/// - 宽度：取内容固有宽度，夹在 [minWidth]–[maxWidth]（160–288；二级菜单至少
///   与主菜单同宽，由布局经约束给出），超过可用宽度时再收窄。
/// - 高度：超过布局给出的最大高度时内部滚动；只在展开完成后显示滚动条。
/// - 上下各留 [ExpressiveMenuRowMetrics.panelPadding]；有 [header]（二级菜单的
///   标题行）时它是第一行。
/// - 手势见 [ExpressiveMenuSelection]：[ready] 为 false 时（展开未到 98%、被
///   二级菜单盖住）不接管；[jelly] 为这块面板的按压形变。
class ExpressiveMenuPanel extends StatefulWidget {
  const ExpressiveMenuPanel({
    super.key,
    required this.showScrollbar,
    required this.children,
    this.ready,
    this.jelly,
    this.scrollController,
    this.header,
    this.minWidth = defaultMinWidth,
    this.maxWidth = defaultMaxWidth,
  });

  static const double defaultMinWidth = 160;
  static const double defaultMaxWidth = 288;

  final bool showScrollbar;
  final List<Widget> children;
  final bool Function()? ready;
  final ExpressiveMenuJelly? jelly;

  /// 不传时面板自己建一个（二级菜单每次展开都是新的一块，滚动从顶部开始）。
  final ScrollController? scrollController;
  final Widget? header;
  final double minWidth;
  final double maxWidth;

  @override
  State<ExpressiveMenuPanel> createState() => _ExpressiveMenuPanelState();
}

class _ExpressiveMenuPanelState extends State<ExpressiveMenuPanel>
    with TickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'ExpressiveMenuPanel');
  late final ExpressiveMenuSelection _selection = ExpressiveMenuSelection(
    vsync: this,
  );
  ScrollController? _ownScroll;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _selection
      ..contentBox = _contentBox
      ..ready = _ready
      ..fits = _fits
      ..reduceMotion = _reduceMotion
      ..jelly = widget.jelly;
  }

  RenderBox? _contentBox() {
    final box = _contentKey.currentContext?.findRenderObject();
    return box is RenderBox ? box : null;
  }

  bool _ready() => mounted && (widget.ready?.call() ?? true);

  bool _fits() {
    final scroll = _scroll;
    return !scroll.hasClients || scroll.position.maxScrollExtent <= 1;
  }

  bool _reduceMotion() => mounted && ExpressiveMotion.reduceMotion(context);

  @override
  void didUpdateWidget(ExpressiveMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection.jelly = widget.jelly;
  }

  @override
  void dispose() {
    _selection.dispose();
    _ownScroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final header = widget.header;
    final maskColor = colors.onSurface.withValues(
      alpha: colors.brightness == Brightness.dark ? 0.10 : 0.06,
    );
    final content = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _selection.handlePointerDown,
      onPointerMove: _selection.handlePointerMove,
      onPointerUp: _selection.handlePointerUp,
      onPointerCancel: _selection.handlePointerCancel,
      // 胶囊的画布、行位置的参照盒与手势层三者原点必须重合：行的位置相对
      // [_contentKey] 量，按下的位置相对 Listener 量，胶囊画在 CustomPaint
      // 上。所以留白放在画布里面，不能把画布放进留白（那样胶囊整体下移
      // panelPadding）。
      child: CustomPaint(
        key: _contentKey,
        painter: ExpressiveMenuMaskPainter(
          selection: _selection,
          color: maskColor,
          inset: ExpressiveMenuRowMetrics.inset,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: ExpressiveMenuRowMetrics.panelPadding,
          ),
          child: ListBody(children: <Widget>[?header, ...widget.children]),
        ),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
      ),
      // 按最终尺寸布局，形变只发生在绘制阶段，文字不会逐帧重排。
      child: IntrinsicWidth(
        child: Material(
          type: MaterialType.transparency,
          child: ExpressiveMenuSelectionScope(
            selection: _selection,
            child: ScrollConfiguration(
              // 关掉平台默认滚动条与越界效果，滚动条由下面的 Scrollbar 按
              // [showScrollbar] 控制。
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                overscroll: false,
                physics: const ClampingScrollPhysics(),
              ),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: widget.showScrollbar,
                child: SingleChildScrollView(
                  controller: _scroll,
                  primary: false,
                  child: RepaintBoundary(child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板的玻璃底（[GlassSurface]：半透明底色 + 背景模糊，直角，由布局按此刻的
/// 面板矩形裁成超椭圆）。底色、模糊随 [ExpressiveMenuMotion.containerAlpha]
/// 显现；不接收点按、不进语义。减少动画或高对比度时为不透明底、不模糊。
class ExpressiveMenuGlass extends StatelessWidget {
  const ExpressiveMenuGlass({super.key, required this.motion});

  final ExpressiveMenuMotion motion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final solid = ExpressiveMenuSurface.solidOf(context);
    final tint = ExpressiveMenuSurface.tintOf(colors);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: motion,
          builder: (BuildContext context, Widget? child) => GlassSurface(
            fill: solid ? Color.alphaBlend(tint, colors.surface) : tint,
            blurSigma: ExpressiveMenuSurface.blurSigma,
            blur: !solid,
            progress: motion.containerAlpha,
            child: child!,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
