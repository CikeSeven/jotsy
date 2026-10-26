// 窗口尺寸分档与内容宽度 token。
//
// 职责：给全应用一个统一的“按窗口宽度换布局”的口径。布局一律按窗口
// **宽度**判断，不按平台：Android 平板、横屏手机与桌面窗口落在同一档时
// 得到同一套布局；窗口拖动跨过分界时布局随之切换。
//
// - [AppWindowClass] / [AppBreakpoints]：紧凑（< 600，即今天的手机布局，
//   保持不变）、中等（600–1023）、展开（≥ 1024）三档，分界取 M3 的窗口
//   尺寸类别；
// - [AppContentWidth]：宽窗口下各类内容的最大宽度，以及把内容居中时左右
//   留白的算法 [AppContentWidth.gutter]；
// - [CenteredContent]：不滚动的内容按最大宽度居中。
//
// 纯常量与无状态 widget，没有副作用。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 窗口宽度分档（M3 窗口尺寸类别的前三档）。
enum AppWindowClass {
  /// < 600：手机竖屏，底部导航栏，界面与改版前完全一致。
  compact,

  /// 600–1023：小平板、横屏手机、窄桌面窗口；首页改为左侧导航栏。
  medium,

  /// ≥ 1024：大平板与常规桌面窗口，可放下双栏等更宽的布局。
  expanded;

  /// 是否为宽窗口（中等或展开）：首页用侧边导航栏而不是底栏。
  bool get isWide => this != AppWindowClass.compact;
}

/// 窗口宽度的分界值与换算。
abstract final class AppBreakpoints {
  /// 中等档的起点：窗口宽度 ≥ 600 时不再是手机布局。
  static const double medium = 600;

  /// 展开档的起点：窗口宽度 ≥ 1024。
  static const double expanded = 1024;

  /// 按窗口宽度 [width] 分档；分界值本身归入较宽的一档。
  static AppWindowClass classOf(double width) {
    if (width >= expanded) {
      return AppWindowClass.expanded;
    }
    if (width >= medium) {
      return AppWindowClass.medium;
    }
    return AppWindowClass.compact;
  }

  /// 当前窗口的分档。只依赖 `MediaQuery` 的尺寸（[MediaQuery.sizeOf]），
  /// 键盘、内边距等其他变化不会让调用方重建。
  static AppWindowClass of(BuildContext context) =>
      classOf(MediaQuery.sizeOf(context).width);
}

/// 宽窗口下各类内容的最大宽度（逻辑像素）。
///
/// 窄于最大宽度时内容照常铺满（左右至少留 [gutter] 的 `minGutter`）；更宽
/// 时内容居中、两侧留白。手机上这些值都比屏幕宽，不会改变现有布局。
abstract final class AppContentWidth {
  /// 阅读：预览页正文等长文本，控制每行字数，便于阅读。
  static const double reading = 720;

  /// 编辑：编辑页正文，比阅读略宽，给工具栏与行首标记留位置。
  static const double editor = 760;

  /// 表单：设置页、发布面板等成列的选项行。
  static const double form = 720;

  /// 探索页：统计卡片与媒体网格。
  static const double explore = 960;

  /// 网格：瀑布流、日历等可横向多列的内容。
  static const double grid = 1200;

  /// 首页左侧导航栏的宽度（宽窗口时取代底栏）。
  static const double navRail = 96;

  /// 把最大宽度为 [maxWidth] 的内容居中放进 [available] 宽的区域时，
  /// 每侧的留白：`max(minGutter, (available − maxWidth) / 2)`。
  ///
  /// 用作滚动视图的左右内边距（而不是把滚动视图本身收窄并居中），这样
  /// 滚动条与滚动手势仍贴在窗口边缘，留白处的滚轮也能滚动内容。
  static double gutter(
    double available,
    double maxWidth, {
    double minGutter = 16,
  }) => math.max(minGutter, (available - maxWidth) / 2);
}

/// 不滚动的内容按 [maxWidth] 居中：区域更宽时两侧留白，更窄时铺满。
///
/// 只收窄宽度（两侧等量留白），高度约束原样交给 [child]：父级给的是紧约束
/// 时子级仍铺满高度。宽度无界时（如横向滚动里）不做处理。滚动内容请改用
/// [AppContentWidth.gutter] 作为内边距，滚动条才会留在窗口边缘。
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return child;
        }
        final side = math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        );
      },
    );
  }
}
