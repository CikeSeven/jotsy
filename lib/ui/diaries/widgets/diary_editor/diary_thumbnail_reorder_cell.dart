import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_image_embed_data.dart';
import '../../models/diary_thumbnail_rows.dart';
import 'diary_embed_selectable.dart';

/// 长按拖动小图排序的宿主（`DiaryThumbnailReorderLayer`）交给每一格小图的
/// 接口。拖动链路只在宿主一处：格子只负责登记自己、按宿主给的位移让位，
/// 以及把长按交上去。
abstract interface class DiaryThumbnailReorderHost {
  /// 拖动状态变了（拿起、换落点、结束）时通知，格子据此让位或复位。
  Listenable get changes;

  /// 是否正在拖动（含松手后画面飞回格子的那一段）。
  bool get active;

  /// 长按生效：拿起 [node]，按 [pointer] 跟踪这根手指；没有拿起（只读、
  /// 段落选择模式、这一串只有一张、正在拖别的）时返回 false。
  bool start(af.Node node, int pointer, Offset position);

  /// 读屏的“前移 / 后移”：[node] 在它那一串里往前（-1）或往后（1）挪一格。
  void nudge(af.Node node, int delta);

  void attach(af.Node node, DiaryThumbnailReorderCellHandle cell);
  void detach(af.Node node, DiaryThumbnailReorderCellHandle cell);

  /// [node] 这一格此刻该让到的位移（相对它的布局位置）；不在拖动时为零。
  Offset offsetOf(af.Node node);

  /// [node] 是被拿起的那一格时，空槽在格子里的矩形（即画面的位置）：它
  /// 原地不画，跟着落点画这个空槽；其余的格子为 null。
  Rect? holeOf(af.Node node);
}

/// 一格小图交给宿主的几何与截图。
abstract interface class DiaryThumbnailReorderCellHandle {
  BuildContext get context;

  /// 格子未经位移的布局矩形（全局坐标）；没有布局时为 null。
  Rect? get layoutRect;

  /// 画面（[DiaryEmbedContent]，即小图方格）在格子里的矩形。
  Rect? get contentRect;

  /// 按屏幕像素比拍下整格；还没画过时为 null。
  ui.Image? capture();
}

/// 编辑页把拖动宿主交给正文里的小图格子；只读正文没有它，小图照常并排、
/// 不能拖。
class DiaryThumbnailReorderScope extends InheritedWidget {
  const DiaryThumbnailReorderScope({
    super.key,
    required this.host,
    required super.child,
  });

  final DiaryThumbnailReorderHost host;

  static DiaryThumbnailReorderHost? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiaryThumbnailReorderScope>()
      ?.host;

  @override
  bool updateShouldNotify(DiaryThumbnailReorderScope oldWidget) =>
      oldWidget.host != host;
}

/// 并排小图里的一格（`DiaryThumbnailRowView` 在编辑页包上）：
/// - 长按（系统长按时限）把这一格交给宿主拿起；轻点仍交给块自己（图片
///   菜单、视频菜单）。长按生效前手指一动，纵向拖动照常交给滚动。
/// - 拖动中按宿主给的位移让位，位移经真弹簧（[ExpressiveMotion.springTo]）
///   推进：落点连着换时带着速度接着走，不会每换一次都从零起步。
/// - 被拿起的那一格原地不画（浮在上面的是它的截图），在画面的位置画一个
///   空槽，空槽随落点滑过去，表示松手后落在哪里。
/// - 拖动结束（正文同一帧写入新顺序）时位移与空槽直接归零：此时格子已按
///   新顺序排在让位后的位置，不再有动画。
///
/// 不在拖动时只多一层 [RepaintBoundary]（截图要用）与零位移的平移。
class DiaryThumbnailReorderCell extends StatefulWidget {
  const DiaryThumbnailReorderCell({
    super.key,
    required this.host,
    required this.node,
    required this.child,
  });

  final DiaryThumbnailReorderHost host;
  final af.Node node;
  final Widget child;

  @override
  State<DiaryThumbnailReorderCell> createState() =>
      _DiaryThumbnailReorderCellState();
}

class _DiaryThumbnailReorderCellState extends State<DiaryThumbnailReorderCell>
    with TickerProviderStateMixin
    implements DiaryThumbnailReorderCellHandle {
  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _dx = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _dy = AnimationController.unbounded(
    vsync: this,
  );
  late final Listenable _offset = Listenable.merge([_dx, _dy]);

  /// 空槽的显现（0–1），拿起时淡入。
  late final AnimationController _holePresence = AnimationController(
    vsync: this,
  );

  /// 正在 initState 里登记：此时不能 setState，直接改字段。
  bool _binding = false;

  /// 这一格是被拿起的那一格时空槽的矩形（格子里的画面位置）。
  Rect? _hole;

  /// 按下的指针：[GestureDetector] 的长按回调不带指针 id。
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _bind(widget);
  }

  void _bind(DiaryThumbnailReorderCell cell) {
    cell.host.attach(cell.node, this);
    cell.host.changes.addListener(_sync);
    if (!cell.host.active) return;
    // 拖动途中才建出来的格子（滚进列表的缓存区）：直接站到让位后的位置。
    // 这一帧还没有布局，自己的格位是推算的；布局后再按实测核对一次。
    _binding = true;
    _sync(animate: false);
    _binding = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(animate: false));
  }

  void _unbind(DiaryThumbnailReorderCell cell) {
    cell.host.changes.removeListener(_sync);
    cell.host.detach(cell.node, this);
  }

  @override
  void didUpdateWidget(DiaryThumbnailReorderCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host || oldWidget.node != widget.node) {
      _unbind(oldWidget);
      _bind(widget);
    }
  }

  @override
  void dispose() {
    _unbind(widget);
    _dx.dispose();
    _dy.dispose();
    _holePresence.dispose();
    super.dispose();
  }

  void _sync({bool animate = true}) {
    if (!mounted) return;
    final host = widget.host;
    if (!host.active) {
      // 拖动结束：正文已按新顺序排好，格子就在让位后的位置上，直接归零。
      _dx.value = 0;
      _dy.value = 0;
      _holePresence.value = 0;
      _setHole(null);
      return;
    }
    final target = host.offsetOf(widget.node);
    if (animate) {
      ExpressiveMotion.springTo(context, _dx, target.dx);
      ExpressiveMotion.springTo(context, _dy, target.dy);
    } else {
      _dx.value = target.dx;
      _dy.value = target.dy;
    }
    final hole = host.holeOf(widget.node);
    if (hole == _hole) return;
    final appeared = _hole == null;
    _setHole(hole);
    if (hole == null) {
      _holePresence.value = 0;
    } else if (appeared && animate) {
      _holePresence.animateTo(
        1,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
      );
    } else {
      _holePresence.value = 1;
    }
  }

  void _setHole(Rect? hole) {
    if (hole == _hole) return;
    if (_binding) {
      _hole = hole;
    } else {
      setState(() => _hole = hole);
    }
  }

  RenderBox? get _boundaryBox {
    final box = _boundary.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  @override
  Rect? get layoutRect {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Rect? get contentRect {
    final box = _boundaryBox;
    // 截图边界与格子同一原点（之间只有位移，位移作用在两者之外）。
    return box == null ? null : DiaryEmbedContent.rectIn(box);
  }

  @override
  ui.Image? capture() {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return null;
    }
    try {
      return box.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (error) {
      debugPrint('Capturing the thumbnail failed: $error');
      return null;
    }
  }

  void _longPress(LongPressStartDetails details) {
    final pointer = _pointer;
    if (pointer != null) {
      widget.host.start(widget.node, pointer, details.globalPosition);
    }
  }

  void _nudge(int delta) => widget.host.nudge(widget.node, delta);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final run = diaryThumbnailRunOf(widget.node);
    final index = run == null ? -1 : widget.node.path.last - run.start;
    final last = run == null ? -1 : run.end - run.start - 1;
    // 每格自成一个读屏节点：同一排几格的“前移 / 后移”不能并进同一个节点。
    return Semantics(
      container: true,
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: l10n.diaryThumbnailMoveEarlier): () =>
              _nudge(-1),
        if (index >= 0 && index < last)
          CustomSemanticsAction(label: l10n.diaryThumbnailMoveLater): () =>
              _nudge(1),
      },
      child: Listener(
        onPointerDown: (event) => _pointer = event.pointer,
        child: GestureDetector(
          onLongPressStart: _longPress,
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => Transform.translate(
              offset: Offset(_dx.value, _dy.value),
              child: child,
            ),
            child: CustomPaint(
              painter: _HolePainter(
                rect: _hole,
                presence: _holePresence,
                color: colors.secondaryContainer,
              ),
              child: Opacity(
                opacity: _hole == null ? 1 : 0,
                child: RepaintBoundary(key: _boundary, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 被拿起的那一格留下的空槽：与小图同样大小、同样圆角的一块
/// `secondaryContainer` 色调底（与拖动手柄按住时的胶囊同色）。
class _HolePainter extends CustomPainter {
  _HolePainter({
    required this.rect,
    required this.presence,
    required this.color,
  }) : super(repaint: presence);

  final Rect? rect;
  final Animation<double> presence;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    final t = presence.value;
    if (rect == null || t <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(kDiaryImageThumbnailRadius),
      ),
      Paint()..color = color.withValues(alpha: color.a * t),
    );
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.color != color ||
      oldDelegate.presence != presence;
}
