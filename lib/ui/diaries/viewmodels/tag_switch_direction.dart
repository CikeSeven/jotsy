import 'package:flutter/widgets.dart';

/// 标签筛选在首页标签条上的位置，用来给列表切换定方向。
///
/// - 没有选中：0（最左端的 ✕ 清空按钮就代表“全部”）；
/// - 只选中一个：它在标签条显示顺序 [orderedTagIds] 里的下标 + 1；
/// - 选中多个，或选中的标签不在标签条上（如记住的筛选指向已隐藏的标签）：
///   null，没有可比的位置。
int? tagStripPosition(Set<int> selectedTagIds, List<int> orderedTagIds) {
  if (selectedTagIds.isEmpty) {
    return 0;
  }
  if (selectedTagIds.length > 1) {
    return null;
  }
  final index = orderedTagIds.indexOf(selectedTagIds.single);
  return index < 0 ? null : index + 1;
}

/// 从标签条位置 [from] 切到 [to] 时列表的水平方向（屏幕坐标）。
///
/// +1：新标签在右边，新内容从右边进来、旧内容往左离开；-1 相反；0：没有
/// 左右之分（任一端没有位置，或位置相同），列表改为纵向进出。从右往左
/// 排列（[textDirection] 为 rtl）时标签条是镜像的，方向随之取反。
int tagSwitchDirection(int? from, int? to, TextDirection textDirection) {
  if (from == null || to == null || from == to) {
    return 0;
  }
  final sign = to > from ? 1 : -1;
  return textDirection == TextDirection.rtl ? -sign : sign;
}
