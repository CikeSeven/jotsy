import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../scroll_chrome_hider.dart';
import 'floating_action_island.dart';
import 'floating_island.dart';
import 'floating_top_bar.dart';

/// 把浮岛顶栏叠在一页内容上：内容在最下，其上是状态栏底条连同往下渐隐的
/// 那一截（[FloatingTopBarStatusStrip]），浮岛在最上、浮在渐隐带之上；并按
/// 内容冒泡上来的纵向滚动决定浮岛显隐与标题胶囊。
///
/// 输入：内容 [child]（自己负责在顶端留出状态栏的高度，静止时不想被岛盖住
/// 的部分再多留 [FloatingTopBar.extent]）、左右两颗岛、标题。输出：一个
/// Stack。无副作用。
///
/// 状态与时机：
/// - 显隐：[hideOnScroll] 时经 [ScrollChromeHider]（滚到顶端与底端都显示），
///   以 `springSpatial` 弹簧推动，滚动中途反向时带着速度改道；关掉时始终
///   显示。
/// - 标题胶囊：给了 [titleAnchor] 时，锚点（通常是页头的末尾）的下缘滚进
///   浮岛那一行之后才浮出；锚点不在树上（编辑器的虚拟滚动已把页头回收）时
///   视为已滚过。没给锚点时只要有 [title] 就一直显示（日期、翻页位置）。
/// - [resetKey] 变化（翻到另一篇）时浮岛立即回来、按新的锚点重新判断标题。
class FloatingTopBarHost extends StatefulWidget {
  const FloatingTopBarHost({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.title,
    this.titleAnchor,
    this.onTitleTap,
    this.titleTooltip,
    this.titleSemantics,
    this.hideOnScroll = false,
    this.statusBarColor,
    this.contentMaxWidth,
    this.resetKey,
    this.theme,
    this.middle,
    this.insetChild = false,
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  /// 标题胶囊的文字；null 时没有标题胶囊。
  final String? title;
  final GlobalKey? titleAnchor;
  final VoidCallback? onTitleTap;
  final String? titleTooltip;
  final String? titleSemantics;
  final bool hideOnScroll;

  /// 状态栏底条（连同往下渐隐的那一截）的颜色（经典材质时；玻璃时为
  /// 玻璃）；null 时不画底条（嵌在页面里、上方没有状态栏时）。
  final Color? statusBarColor;
  final double? contentMaxWidth;
  final Object? resetKey;

  /// 只给浮岛与状态栏底条用的主题（内容保持自己的主题）；变化时补间过渡。
  /// null 时沿用所在位置的主题。翻页器在所有页之上画浮岛时传当前这篇的
  /// 整页主题，换篇时浮岛颜色随之过渡。
  final ThemeData? theme;

  /// 自定义的中间岛（如导图页的标题，由调用方自己随内容刷新）；给出时代替
  /// 标题胶囊（[title] 不再使用）。
  final Widget? middle;

  /// 为 true 时 [child] 整体从浮岛那一行以下开始（不滚动的页面：读取中、
  /// 出错、封存页），否则 [child] 铺满、自己在顶端留白。
  final bool insetChild;

  @override
  State<FloatingTopBarHost> createState() => _FloatingTopBarHostState();
}

class _FloatingTopBarHostState extends State<FloatingTopBarHost>
    with SingleTickerProviderStateMixin {
  /// 显隐值以 0..1 计，判定停稳的阈值相应缩小（默认阈值按像素量给）。
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  late final AnimationController _reveal = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  final ScrollChromeHider _hider = ScrollChromeHider(revealAtEnd: true);
  bool _revealed = true;
  bool _titlePast = false;
  ScrollMetrics? _pendingTitleMetrics;

  @override
  void didUpdateWidget(FloatingTopBarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      _hider.reset();
      _setRevealed(true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTitle(null));
    } else if (!widget.hideOnScroll && oldWidget.hideOnScroll) {
      _setRevealed(true);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _setRevealed(bool revealed) {
    if (_revealed == revealed) {
      return;
    }
    _revealed = revealed;
    ExpressiveMotion.springTo(
      context,
      _reveal,
      revealed ? 1 : 0,
      tolerance: _tolerance,
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (widget.hideOnScroll) {
      final hidden = _hider.handle(notification);
      if (hidden != null) {
        _setRevealed(!hidden);
      }
    }
    _scheduleTitleSync(notification.metrics);
    return false;
  }

  /// 滚动通知在滚动位置改变时、视口重新布局之前发出，这时读到的锚点位置
  /// 还是上一帧的。改为每帧最多一次、在这一帧布局完成后判断。
  void _scheduleTitleSync(ScrollMetrics metrics) {
    if (widget.titleAnchor == null) {
      return;
    }
    final scheduled = _pendingTitleMetrics != null;
    _pendingTitleMetrics = metrics;
    if (scheduled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingTitleMetrics;
      _pendingTitleMetrics = null;
      _syncTitle(pending);
    });
  }

  /// 锚点下缘是否已滚进浮岛那一行（见类注释）；[metrics] 为 null 时（翻页
  /// 后补判）锚点不在树上按未滚过算。
  void _syncTitle(ScrollMetrics? metrics) {
    final anchor = widget.titleAnchor;
    if (!mounted || anchor == null) {
      return;
    }
    final box = anchor.currentContext?.findRenderObject();
    final host = context.findRenderObject();
    bool past;
    if (box is RenderBox &&
        box.attached &&
        box.hasSize &&
        host is RenderBox &&
        host.attached) {
      final bottom = box
          .localToGlobal(Offset(0, box.size.height), ancestor: host)
          .dy;
      past =
          bottom <=
          MediaQuery.viewPaddingOf(context).top + FloatingTopBar.extent;
    } else {
      past = metrics != null && metrics.pixels > metrics.minScrollExtent;
    }
    if (past != _titlePast) {
      setState(() => _titlePast = past);
    }
  }

  /// 给浮岛与底条套上 [FloatingTopBarHost.theme]（有时）。
  Widget _themed(BuildContext context, Widget child) {
    final theme = widget.theme;
    if (theme == null) {
      return child;
    }
    return AnimatedTheme(
      data: theme,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      child: child,
    );
  }

  /// 此刻被状态栏与浮岛盖住的部分的下缘（全局纵坐标）：浮岛显示时到岛那
  /// 一行的下缘。画了渐隐带时岛收起后那一行仍被渐隐带罩着，照样算遮挡；
  /// 没有渐隐带时收起途中按显隐进度缩短，完全收起时只剩状态栏。
  double _coveredBottom() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) {
      return 0;
    }
    final reveal = _bandFades ? 1.0 : _reveal.value.clamp(0.0, 1.0);
    return box.localToGlobal(Offset.zero).dy +
        _statusBar +
        FloatingTopBar.extent * reveal;
  }

  /// 最近一次构建时的状态栏高度与是否画了渐隐带（[_coveredBottom] 在构建
  /// 之外调用，不在那里读 MediaQuery）。
  double _statusBar = 0;
  bool _bandFades = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final statusBarColor = widget.statusBarColor;
    _statusBar = MediaQuery.viewPaddingOf(context).top;
    _bandFades =
        statusBarColor != null && FloatingTopBarStatusStrip.fadesOf(context);
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: FloatingTopBarCover(
            coveredBottom: _coveredBottom,
            child: widget.insetChild
                ? Padding(
                    padding: EdgeInsets.only(
                      top: _statusBar + FloatingTopBar.extent,
                    ),
                    child: widget.child,
                  )
                : widget.child,
          ),
        ),
        if (statusBarColor != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _themed(
              context,
              FloatingTopBarStatusStrip(color: statusBarColor),
            ),
          ),
        // 浮岛在渐隐带之上；隐藏时整行上移出屏并淡出。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _themed(
            context,
            FloatingIslandBand(
              onBand: _bandFades,
              child: FloatingTopBar(
                reveal: _reveal,
                contentMaxWidth: widget.contentMaxWidth,
                leading: widget.leading,
                trailing: widget.trailing,
                middle:
                    widget.middle ??
                    (title == null
                        ? null
                        : FloatingTitleChip(
                            title: title,
                            visible: widget.titleAnchor == null || _titlePast,
                            onTap: widget.onTitleTap,
                            tooltip: widget.titleTooltip,
                            semanticsLabel: widget.titleSemantics,
                          )),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 浮岛顶栏盖住内容顶部的范围，给下面的内容查询：正文的光标避让、选区菜单
/// 与查找跳转据此把“看得见的范围”的上沿压到岛的下面（日记编辑器经
/// `diaryEditorVisibleRange` 与 `DiaryEditorViewport` 读取）。
///
/// 只提供查询函数、不随浮岛显隐通知重建：显隐每帧都在变，读取方只在指针
/// 事件与帧回调里按需取值。
class FloatingTopBarCover extends InheritedWidget {
  const FloatingTopBarCover({
    super.key,
    required this.coveredBottom,
    required super.child,
  });

  /// 被状态栏与浮岛盖住的部分的下缘（全局纵坐标）。
  final double Function() coveredBottom;

  /// [context] 上方浮岛盖住部分的下缘（全局纵坐标）；不在浮岛顶栏之下时为
  /// null。不建立依赖。
  static double? coveredBottomOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<FloatingTopBarCover>();
    return (element?.widget as FloatingTopBarCover?)?.coveredBottom();
  }

  @override
  bool updateShouldNotify(FloatingTopBarCover oldWidget) => false;
}
