// 日记页（首页“日记”Tab）按窗口宽度的排布。
//
// 输入：窗口分档（[AppWindowClass]，按整个窗口的宽度）、日记页实际拿到的
// 宽度（宽窗口里已扣掉左侧导航栏）与当前是否为瀑布流；输出：单栏还是
// 左右双栏、左栏（单栏时即整页）的宽度、内容列每侧补的留白、列表可用宽度
// 与瀑布流至少的列数。纯换算，没有副作用。
//
// - 紧凑（< 600）：与改版前完全一致，整页就是内容列；
// - 中等（600–1023）：仍是单栏，列表内容列最宽 720、瀑布流最宽 1200 并
//   居中，瀑布流按每列约 320 加列（不少于用户设的列数）；
// - 展开（≥ 1024）：列表–详情双栏，左栏取页面宽度的 38%（夹在 360–440），
//   里面与同宽的手机完全一样（瀑布流用用户设的列数），右栏阅读选中的一篇。

import 'dart:math' as math;

import '../../../app/theme/app_breakpoints.dart';

/// 日记页的排布（见文件头）。
class DiariesPageLayout {
  const DiariesPageLayout._({
    required this.twoPane,
    required this.listPaneWidth,
    required this.contentInset,
    required this.minWaterfallColumns,
  });

  /// 按窗口分档 [windowClass]、日记页宽度 [width] 与布局（[waterfall]）换算。
  factory DiariesPageLayout.resolve({
    required AppWindowClass windowClass,
    required double width,
    required bool waterfall,
  }) {
    switch (windowClass) {
      case AppWindowClass.compact:
        return DiariesPageLayout._(
          twoPane: false,
          listPaneWidth: width,
          contentInset: 0,
          minWaterfallColumns: 0,
        );
      case AppWindowClass.medium:
        final maxWidth = waterfall ? AppContentWidth.grid : maxListWidth;
        final inset = math.max(0.0, (width - maxWidth) / 2);
        final column = width - inset * 2;
        return DiariesPageLayout._(
          twoPane: false,
          listPaneWidth: width,
          contentInset: inset,
          minWaterfallColumns: waterfall
              ? (column / waterfallColumnWidth).floor()
              : 0,
        );
      case AppWindowClass.expanded:
        return DiariesPageLayout._(
          twoPane: true,
          listPaneWidth: (width * listPaneFraction).clamp(
            minListPaneWidth,
            maxListPaneWidth,
          ),
          contentInset: 0,
          minWaterfallColumns: 0,
        );
    }
  }

  /// 中等窗口里列表布局内容列的最大宽度（卡片自带的左右边距在列内）。
  static const double maxListWidth = AppContentWidth.reading;

  /// 中等窗口里瀑布流每多 320 宽加一列。
  static const double waterfallColumnWidth = 320;

  /// 双栏时左栏占页面宽度的比例与上下限。
  static const double listPaneFraction = 0.38;
  static const double minListPaneWidth = 360;
  static const double maxListPaneWidth = 440;

  /// 是否为列表–详情双栏。
  final bool twoPane;

  /// 左栏宽度；单栏时为整页宽度。
  final double listPaneWidth;

  /// 内容列（刊头、标签栏、日记本头部与列表）每侧补的留白；只在中等窗口
  /// 比内容列更宽时大于 0。
  final double contentInset;

  /// 瀑布流至少的列数；0 表示只用卡片样式里的列数。
  final int minWaterfallColumns;

  /// 列表可用的宽度（含卡片左右边距），卡片样式按它解析。
  double get listWidth => listPaneWidth - contentInset * 2;
}
