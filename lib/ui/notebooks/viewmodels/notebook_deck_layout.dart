import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'notebook_deck_entries.dart';

/// 卡组（竖向叠卡）的几何：纯函数，供卡组组件逐帧摆放卡片、命中测试与
/// 面板量高度。
///
/// - 基准位置：每张卡片高 [cardHeight]，下一张盖住它、只露出顶条 [peek]；
///   “已合上”收起时那一叠每张只露 [pilePeek]；标题条高 [headerHeight]；
///   展开了子本的卡片与标题条前的那张整张露出（见 [_advance]）。最后一张
///   完整露出。内容上方留 [topPadding] 给压叠用，下方留
///   [bottomPadding]；
/// - 压叠（[place]）：滚出顶端的卡片不直接离开，而是停在顶端压成一摞，每
///   滚过一个顶条往上错开 [pileStep]、缩小 [pileShrink]，第 [pileLayers] 层
///   之后再滚一个顶条淡没；
/// - 拉开：越过顶端 / 底端（Bouncing 物理的越界量）时卡片之间的间距像弹簧
///   一样被拉开——离被拉的那一端越远的卡片跟得越多，最近的只跟
///   [spreadNear]；
/// - 让位：抬起（按压、悬停、拖选）的卡片后面的卡片下移 [revealLift] ×
///   抬起程度，露出它的卡身。
@immutable
class NotebookDeckLayout {
  factory NotebookDeckLayout(List<NotebookDeckEntry> entries) {
    final tops = <double>[];
    var y = topPadding;
    final closedOpen = entries.any(
      (e) => e.kind == NotebookDeckEntryKind.closedHeader && e.expanded,
    );
    for (var i = 0; i < entries.length; i++) {
      tops.add(y);
      final next = i + 1 < entries.length ? entries[i + 1] : null;
      y += _advance(entries[i], next, closedOpen);
    }
    final last = entries.isEmpty ? null : entries.last;
    final extent = last == null
        ? topPadding + bottomPadding
        : tops.last + heightOf(last) + bottomPadding;
    return NotebookDeckLayout._(List<double>.unmodifiable(tops), extent);
  }

  const NotebookDeckLayout._(this.tops, this.extent);

  static const double cardHeight = 120;
  static const double peek = 60;
  static const double pilePeek = 8;
  static const double headerHeight = 40;
  static const double pileStep = 6;
  static const double pileShrink = 0.04;
  static const int pileLayers = 3;
  static const double topPadding = pileStep * pileLayers;
  static const double bottomPadding = 12;
  static const double indentStep = 16;
  static const double revealLift = 40;
  static const double spreadNear = 0.35;
  static const double groupGap = 8;

  /// 各项顶边在内容里的位置（与条目一一对应）。
  final List<double> tops;

  /// 内容总高度（滚动范围 = 它 − 视口高度）。
  final double extent;

  static double heightOf(NotebookDeckEntry entry) =>
      entry.kind == NotebookDeckEntryKind.closedHeader
      ? headerHeight
      : cardHeight;

  /// 到下一项顶边的距离：
  /// - 展开了子本的卡片整张露出（像翻开的文件夹），子本从它底下抽出、排在
  ///   它下面，不压在它的卡身上；“已合上”标题条前的那张同样整张露出，标题
  ///   不压在别的卡片上。两者后面留 [groupGap]；
  /// - “已合上”收起时那一叠每张只露 [pilePeek]；其余露出顶条 [peek]。
  static double _advance(
    NotebookDeckEntry entry,
    NotebookDeckEntry? next,
    bool closedOpen,
  ) {
    if (entry.kind == NotebookDeckEntryKind.closedHeader) {
      return headerHeight;
    }
    if (entry.expanded || next?.kind == NotebookDeckEntryKind.closedHeader) {
      return cardHeight + groupGap;
    }
    if (entry.inClosedGroup && !closedOpen) {
      return pilePeek;
    }
    return peek;
  }

  /// 第 [index] 项（共 [count] 项）此刻在视口里的摆放。
  ///
  /// [top] 为它此刻的内容位置（展开 / 收起途中由弹簧给出，静止时等于
  /// [tops]），[liftShift] 为前面抬起的卡片让它下移的量；[scroll] 是滚动
  /// 偏移（可越界），[maxScroll] 是滚动范围上限。
  static NotebookDeckPlacement place({
    required int index,
    required int count,
    required double top,
    required double scroll,
    required double maxScroll,
    double liftShift = 0,
  }) {
    final fraction = count <= 1 ? 1.0 : index / (count - 1);
    final clamped = scroll.clamp(0.0, math.max(0.0, maxScroll));
    var y = top + liftShift - clamped;
    if (scroll < 0) {
      y += -scroll * (spreadNear + (1 - spreadNear) * fraction);
    } else if (scroll > maxScroll) {
      y -=
          (scroll - maxScroll) *
          (spreadNear + (1 - spreadNear) * (1 - fraction));
    }
    if (y >= topPadding) {
      return NotebookDeckPlacement(y: y, scale: 1, opacity: 1);
    }
    final level = (topPadding - y) / peek;
    final layers = math.min(level, pileLayers.toDouble());
    final fade = level <= pileLayers
        ? 1.0
        : (1 - (level - pileLayers)).clamp(0.0, 1.0);
    return NotebookDeckPlacement(
      y: topPadding - pileStep * layers,
      scale: 1 - pileShrink * layers,
      opacity: fade,
    );
  }

  /// 把 [index] 滚到视口里时的滚动偏移：尽量让它的顶条停在视口上部三分之一
  /// 处，夹在滚动范围内。
  double revealOffset(int index, double viewport) {
    if (index < 0 || index >= tops.length) return 0;
    final maxScroll = math.max(0.0, extent - viewport);
    return (tops[index] - viewport / 3).clamp(0.0, maxScroll);
  }
}

/// 一张卡片此刻在视口里的位置（顶边 y）、缩放与不透明度。
@immutable
class NotebookDeckPlacement {
  const NotebookDeckPlacement({
    required this.y,
    required this.scale,
    required this.opacity,
  });

  final double y;
  final double scale;
  final double opacity;
}

/// 命中测试：在视口坐标 [point] 下最上层（后画的）那张卡片的下标，没有
/// 时为 -1。[rects] 为各卡片此刻的矩形，按绘制顺序排列的下标为 [paintOrder]
/// （后面的盖在前面的上面）。
int notebookDeckHitTest(Offset point, List<Rect> rects, List<int> paintOrder) {
  for (var i = paintOrder.length - 1; i >= 0; i--) {
    final index = paintOrder[i];
    if (index < rects.length && rects[index].contains(point)) {
      return index;
    }
  }
  return -1;
}
