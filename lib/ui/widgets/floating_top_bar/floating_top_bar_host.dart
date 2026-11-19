import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../scroll_chrome_hider.dart';
import 'floating_action_island.dart';
import 'floating_top_bar.dart';

/// 把浮岛顶栏叠在一页内容上：内容在下、状态栏底条与浮岛在上，并按内容
/// 冒泡上来的纵向滚动决定浮岛显隐与标题胶囊。
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
    this.hideOnScroll = false,
    this.statusBarColor,
    this.contentMaxWidth,
    this.resetKey,
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  /// 标题胶囊的文字；null 时没有标题胶囊。
  final String? title;
  final GlobalKey? titleAnchor;
  final VoidCallback? onTitleTap;
  final String? titleTooltip;
  final bool hideOnScroll;

  /// 状态栏底条的颜色（经典材质时；玻璃时为玻璃）；null 时不画底条（嵌在
  /// 页面里、上方没有状态栏时）。
  final Color? statusBarColor;
  final double? contentMaxWidth;
  final Object? resetKey;

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

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final statusBarColor = widget.statusBarColor;
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: widget.child,
        ),
        // 浮岛隐藏时上移，从状态栏底条下面退出屏幕。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FloatingTopBar(
            reveal: _reveal,
            contentMaxWidth: widget.contentMaxWidth,
            leading: widget.leading,
            trailing: widget.trailing,
            middle: title == null
                ? null
                : FloatingTitleChip(
                    title: title,
                    visible: widget.titleAnchor == null || _titlePast,
                    onTap: widget.onTitleTap,
                    tooltip: widget.titleTooltip,
                  ),
          ),
        ),
        if (statusBarColor != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBarStatusStrip(color: statusBarColor),
          ),
      ],
    );
  }
}
