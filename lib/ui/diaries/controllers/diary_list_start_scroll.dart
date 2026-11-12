import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 把日记页列表定位到“列表开头”：第一张卡片（加上 [leadingGap] 的顶部
/// 间距）紧贴固定的标签栏下沿。只在列表已经滚过这个位置时向上跳，没滚到
/// 时（开头还在标签栏下方看得见）不动。返回是否跳了。
///
/// 输入：标签栏里的任一 context [tagBarContext]（经它找到标签栏所在的
/// sliver、视口与滚动位置）与列表 sliver 的渲染对象 [listSliver]。必须在
/// 列表不可见的那一帧调用（筛选过渡退场之后、换数据之前），跳动看不见。
///
/// 为什么不直接跳到最顶：刊头是浮动的（下滑收起、上滑即现），跳到最顶会
/// 让刊头重新出现，用户正盯着的标签栏随之下移一整个刊头高度。这里按标签栏
/// 此刻的下沿算目标，并保持刊头此刻的露出量：
/// - 目标偏移 = 列表 sliver 之前的滚动范围 − 标签栏下沿在视口里的位置
///   （刊头与标签栏此刻的绘制高度之和）− [leadingGap]；
/// - 浮动刊头在滚动位置变小时会按“上一次开始滚动的方向”决定是否展开
///   （`RenderSliverFloatingPersistentHeader.updateScrollStartDirection`）。
///   `jumpTo` 不算用户滚动，方向停在上一次手势上——若上一次是往上滑，大幅
///   向上跳会把收起的刊头整个拉出来。跳之前把它记为往下，刊头的有效偏移
///   被夹在目标偏移以内：收起的仍收起、露出一半的仍露出一半、完全露出的
///   仍完全露出（目标偏移恰好让三者的露出量不变）。用户下一次开始滚动时
///   方向照常更新。
bool jumpDiaryListToStart({
  required BuildContext tagBarContext,
  required RenderSliver listSliver,
  double leadingGap = 0,
}) {
  final tagBar = tagBarContext.findAncestorRenderObjectOfType<RenderSliver>();
  final viewport = tagBarContext
      .findAncestorRenderObjectOfType<RenderViewport>();
  final position = Scrollable.maybeOf(tagBarContext)?.position;
  if (tagBar == null ||
      viewport == null ||
      position == null ||
      !position.hasContentDimensions ||
      !listSliver.attached ||
      !identical(listSliver.parent, viewport)) {
    return false;
  }
  final header = viewport.childBefore(tagBar);
  final barBottom =
      (header?.geometry?.paintExtent ?? 0) +
      (tagBar.geometry?.paintExtent ?? 0);
  final target =
      (listSliver.constraints.precedingScrollExtent - barBottom - leadingGap)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
  // 半个像素以内视为已在开头，免得为亚像素差跳一次。
  if (position.pixels <= target + 0.5) {
    return false;
  }
  if (header is RenderSliverFloatingPersistentHeader) {
    header.updateScrollStartDirection(ScrollDirection.reverse);
  }
  position.jumpTo(target);
  return true;
}
