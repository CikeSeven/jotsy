import 'dart:math' as math;

import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';

/// 单个按钮在工具栏里占用的边长：32dp 可见按钮，padded 触控区在 compact 密度
/// 下为 48 - 8 = 40dp。按钮样式见 `buildDiaryToolbarItemConfig`，两者须一致。
const double kDiaryToolbarButtonExtent = 40;

/// 「缩进」两个按钮之间的间距（Quill 工具栏的 section spacing）。
const double kDiaryToolbarIndentGap = 4;

/// 工具栏一排的高度。
const double kDiaryToolbarBarHeight = 44;

/// 工具栏内容距卡片左右边缘的留白。
const double kDiaryToolbarHorizontalPadding = 8;

/// 紧凑排布时相邻工具的间隔，也是等分列宽时要求的最小间隔。
const double kDiaryToolbarItemGap = 2;

/// 悬浮工具栏卡片距屏幕左右边缘的距离（编辑页摆放与设置页预估共用）。
const double kDiaryFloatingToolbarInset = 12;

/// 工具在排布里占几格：「缩进」是增/减两个按钮。
int diaryToolbarItemSlots(DiaryToolbarItem item) =>
    item == DiaryToolbarItem.indent ? 2 : 1;

/// 工具在紧凑排布里的实际宽度。
double diaryToolbarItemExtent(DiaryToolbarItem item) {
  final slots = diaryToolbarItemSlots(item);
  return slots * kDiaryToolbarButtonExtent +
      (slots - 1) * kDiaryToolbarIndentGap;
}

/// 悬浮工具栏的一次排布：一排放得下的工具常驻，放不下的收进「更多」面板。
///
/// 纯计算、不依赖 BuildContext。编辑页工具栏按卡片实际宽度排布，设置排序页按
/// 屏宽预估分界线，两处共用同一套规则，设置里看到的分界就是工具栏上的样子。
///
/// 规则：
/// - 每个按钮占 [kDiaryToolbarButtonExtent] 见方（32dp 可见按钮 + padded 触控
///   补白）；「缩进」同时显示增/减两个按钮，占两格；
/// - 紧凑排布（[kDiaryToolbarItemGap] 间隔）全部放得下时不出现「更多」；
/// - 放不下时整排按列等分，最后一格固定留给「更多」。常驻工具是启用顺序里放得
///   下的**连续前缀**：遇到第一个放不下的就停，不跳过它去塞后面更窄的工具，
///   这样“设置里排在前面的就是常驻的”始终成立；
/// - 面板沿用同样的列宽逐行排布，「缩进」在本行剩余格数不够时整体换行。
class DiaryToolbarLayout {
  const DiaryToolbarLayout._({
    required this.pinned,
    required this.overflow,
    required this.columns,
  });

  /// 常驻在工具栏一排上的工具（启用顺序的连续前缀）。
  final List<DiaryToolbarItem> pinned;

  /// 收进「更多」面板的工具，保持启用顺序。
  final List<DiaryToolbarItem> overflow;

  /// 有溢出时整排等分的列数（含「更多」占的最后一格）；无溢出时为 0。
  final int columns;

  bool get hasOverflow => overflow.isNotEmpty;

  /// 面板按 [columns] 列逐行排布的结果。
  List<List<DiaryToolbarItem>> get overflowRows {
    final rows = <List<DiaryToolbarItem>>[];
    var current = <DiaryToolbarItem>[];
    var used = 0;
    for (final item in overflow) {
      final slots = math.min(diaryToolbarItemSlots(item), columns);
      if (current.isNotEmpty && used + slots > columns) {
        rows.add(current);
        current = <DiaryToolbarItem>[];
        used = 0;
      }
      current.add(item);
      used += slots;
    }
    if (current.isNotEmpty) {
      rows.add(current);
    }
    return rows;
  }
}

/// 按卡片宽度 [width] 排布已启用的工具 [items]。
DiaryToolbarLayout resolveDiaryToolbarLayout(
  List<DiaryToolbarItem> items, {
  required double width,
}) {
  final contentWidth = math.max(
    0.0,
    width - 2 * kDiaryToolbarHorizontalPadding,
  );
  var naturalWidth = 0.0;
  for (var index = 0; index < items.length; index++) {
    naturalWidth += diaryToolbarItemExtent(items[index]);
    if (index > 0) {
      naturalWidth += kDiaryToolbarItemGap;
    }
  }
  if (naturalWidth <= contentWidth) {
    return DiaryToolbarLayout._(
      pinned: List<DiaryToolbarItem>.unmodifiable(items),
      overflow: const <DiaryToolbarItem>[],
      columns: 0,
    );
  }

  // 至少两格：一个工具 + 「更多」。极窄时常驻可能为空，只剩「更多」。
  final columns = math.max(
    2,
    ((contentWidth + kDiaryToolbarItemGap) /
            (kDiaryToolbarButtonExtent + kDiaryToolbarItemGap))
        .floor(),
  );
  final capacity = columns - 1;
  var used = 0;
  var pinnedCount = 0;
  for (final item in items) {
    final slots = diaryToolbarItemSlots(item);
    if (used + slots > capacity) {
      break;
    }
    used += slots;
    pinnedCount++;
  }
  return DiaryToolbarLayout._(
    pinned: List<DiaryToolbarItem>.unmodifiable(items.take(pinnedCount)),
    overflow: List<DiaryToolbarItem>.unmodifiable(items.skip(pinnedCount)),
    columns: columns,
  );
}

/// 设置排序页的分界线位置：[order] 中前多少项（含夹在其间的已隐藏项）显示在
/// 线上方，即常驻在工具栏上。全部放得下时返回 null，不显示分界线。
///
/// [order] 须是完整顺序（`decodeDiaryToolbarOrder` 的结果），返回值按它计下标。
int? diaryToolbarOverflowBoundary(
  List<DiaryToolbarItem> order,
  Set<DiaryToolbarItem> hiddenItems, {
  required double width,
}) {
  final layout = resolveDiaryToolbarLayout(
    filterEnabledDiaryToolbarOrder(order, hiddenItems),
    width: width,
  );
  if (!layout.hasOverflow) {
    return null;
  }
  if (layout.pinned.isEmpty) {
    return order.indexOf(layout.overflow.first);
  }
  return order.indexOf(layout.pinned.last) + 1;
}

/// 设置排序页拖放后，让被拖动的工具 [moved] 留在用户放下的那一侧
/// （[pinned] 为 true 表示放在分界线上方）。
///
/// 常驻区容量固定，分界线只是“前缀放不放得下”的结果。把常驻工具拖到线下方
/// 正下方时，常驻区空出的位置会由紧随其后的工具补上——补位的恰好是它自己，
/// 于是它又回到线上方，看起来像拖不过线；反方向同理会挤掉它自己。这里在落点
/// 不符时，把它与相邻的已启用工具逐个交换，直到它位于用户选择的一侧：从常驻
/// 拖下来时，下方第一个工具补位上去；从「更多」拖上来时，上方最后一个工具被
/// 挤下去。已隐藏的工具不参与排布，位置保持不动。
List<DiaryToolbarItem> keepDiaryToolbarItemOnSide(
  List<DiaryToolbarItem> order, {
  required DiaryToolbarItem moved,
  required bool pinned,
  required Set<DiaryToolbarItem> hiddenItems,
  required double width,
}) {
  final result = List<DiaryToolbarItem>.of(order);
  if (hiddenItems.contains(moved)) {
    return result;
  }
  bool isPinned() => resolveDiaryToolbarLayout(
    filterEnabledDiaryToolbarOrder(result, hiddenItems),
    width: width,
  ).pinned.contains(moved);

  while (isPinned() != pinned) {
    final index = result.indexOf(moved);
    final step = pinned ? -1 : 1;
    var neighbor = index + step;
    while (neighbor >= 0 &&
        neighbor < result.length &&
        hiddenItems.contains(result[neighbor])) {
      neighbor += step;
    }
    if (neighbor < 0 || neighbor >= result.length) {
      break;
    }
    result[index] = result[neighbor];
    result[neighbor] = moved;
  }
  return result;
}
