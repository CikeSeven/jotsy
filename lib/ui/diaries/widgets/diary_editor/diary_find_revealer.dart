import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/widgets.dart';

import '../../controllers/diary_editor_controller.dart';
import '../../models/diary_find_query.dart';
import 'diary_editor_visible_range.dart';

/// 把查找的当前匹配滚进正文看得见的范围（[DiaryFindReplace.revealRequests]
/// 每加一次核对一次）。只在跳到下一处、换了查找条件、替换之后请求；用户
/// 在正文里打字引起的重新查找不请求，不把正在写的地方拉走。
///
/// 两种正文：
/// - 编辑页（正文自己的虚拟列表）：滚正文的列表，底部让开 [coveredHeight]
///   （页面把悬浮的查找栏算在里面）；匹配所在的块还没构建（虚拟列表只建
///   视口附近的项）时先经 [revealPath] 按列表下标跳到那一块，下一帧再按
///   实际几何校正；
/// - 收缩嵌入预览页（[pageScroll]）：滚外层的页面，底部让开查找栏自己报告
///   的高度（[DiaryFindReplace.barHeight]），顶部让开浮在正文上的顶栏。
///
/// 看得见的范围与选区菜单、拖选区把手同一口径（[diaryEditorVisibleRange]：
/// 底部还要去掉键盘），上下各留 [_margin]。已经露在里面就不动；不在里面时
/// 把匹配的顶边放到范围上方三分之一处（上下文都看得到）。校正最多再做
/// [_maxAttempts] 次（列表按估计高度跳转、高亮加粗重新排版之后，下一帧的
/// 位置可能还差一点）。
///
/// 不论查找框还是正文有焦点都工作（`DiaryEditorViewport` 只在正文有焦点时
/// 揭示光标）。直接跳到位、不带动画：连续按“下一个”时每次都立刻落定。
class DiaryFindRevealer extends StatefulWidget {
  const DiaryFindRevealer({
    super.key,
    required this.controller,
    required this.coveredHeight,
    required this.child,
    this.revealPath,
    this.pageScroll = false,
  });

  final DiaryEditorController controller;

  /// 编辑页正文底部被浮层盖住的高度；[pageScroll] 时不用（取查找栏的高度）。
  final double coveredHeight;
  final void Function(af.Path path)? revealPath;
  final bool pageScroll;
  final Widget child;

  @override
  State<DiaryFindRevealer> createState() => _DiaryFindRevealerState();
}

const double _margin = 24;
const int _maxAttempts = 3;

class _DiaryFindRevealerState extends State<DiaryFindRevealer> {
  /// 每次请求一个新编号：上一轮还在等帧回调时来了新请求，旧的那轮作废。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.find.revealRequests.addListener(_onRequest);
  }

  @override
  void didUpdateWidget(DiaryFindRevealer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.find.revealRequests.removeListener(_onRequest);
      widget.controller.find.revealRequests.addListener(_onRequest);
    }
  }

  @override
  void dispose() {
    widget.controller.find.revealRequests.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() => _schedule(++_generation, 0);

  void _schedule(int generation, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) _reveal(generation, attempt);
    });
    // 请求可能来自按钮回调，那时不一定有待画的帧。
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _reveal(int generation, int attempt) {
    final controller = widget.controller;
    if (controller.isDisposed) return;
    final match = controller.find.current;
    if (match == null || match.node.parent == null) return;
    final rects = diaryFindMatchGlobalRects(match);
    if (rects.isEmpty) {
      if (attempt >= _maxAttempts) return;
      widget.revealPath?.call(match.node.path);
      _schedule(generation, attempt + 1);
      return;
    }
    final pageScroll = widget.pageScroll;
    final range = diaryEditorVisibleRange(
      context,
      controller,
      pageScroll: pageScroll,
      coveredHeight: pageScroll
          ? controller.find.barHeight.value
          : widget.coveredHeight,
    );
    final position = diaryEditorScrollable(
      context,
      controller,
      pageScroll: pageScroll,
    )?.position;
    if (range == null || position == null || !position.hasContentDimensions) {
      return;
    }
    final rect = rects.reduce((a, b) => a.expandToInclude(b));
    if (rect.top >= range.top + _margin &&
        rect.bottom <= range.bottom - _margin) {
      return;
    }
    final height = range.bottom - range.top;
    final targetTop = range.top + math.max(_margin, height / 3);
    final target = (position.pixels + rect.top - targetTop).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() <= 0.5) return;
    position.jumpTo(target);
    if (attempt < _maxAttempts) _schedule(generation, attempt + 1);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [match] 此刻在屏幕上的矩形（全局坐标，可能折成几行）；所在的块没有
/// 组件（滚出了虚拟列表、在收起的折叠块里）或文字已经变短时为空。零宽
/// 匹配取插入点处一道 2 宽的竖线。
List<Rect> diaryFindMatchGlobalRects(DiaryFindMatch match) {
  final node = match.node;
  final length = node.delta?.length;
  final selectable = node.selectable;
  if (node.parent == null ||
      length == null ||
      match.end > length ||
      selectable == null) {
    return const [];
  }
  final path = node.path;
  final List<Rect> local;
  if (match.isEmpty) {
    final caret = selectable.getCursorRectInPosition(
      af.Position(path: path, offset: match.start),
      shiftWithBaseOffset: true,
    );
    local = caret == null
        ? const []
        : [Rect.fromLTWH(caret.left - 1, caret.top, 2, caret.height)];
  } else {
    local = selectable.getRectsInSelection(
      af.Selection(
        start: af.Position(path: path, offset: match.start),
        end: af.Position(path: path, offset: match.end),
      ),
      shiftWithBaseOffset: true,
    );
  }
  return [
    for (final rect in local)
      if (rect.width > 0 || match.isEmpty)
        selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
  ];
}
