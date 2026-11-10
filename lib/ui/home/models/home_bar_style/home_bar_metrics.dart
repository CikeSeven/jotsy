import 'dart:math' as math;

import 'home_bar_style_enums.dart';

/// 悬浮底栏的固定几何（不随用户设置变化，只按文字模式分两档）。
///
/// 为什么写死：这些数值互相牵制——指示器要贴着胶囊内壁留一圈等宽的缝并与
/// 胶囊同心，图标与文字要在指示器里竖直居中，项宽要刚好容下最长的名称。
/// 作为一组经过校对的比例一起给出，栏在任何 Tab 数量、任何语言下都是同一
/// 副样子；规格见 DESIGN.md §5.19。
///
/// 一个导航项就是一格：宽 [itemWidth]、高为栏高减去上下的 [inset]。选中
/// 指示器铺满一格，所以它到胶囊内壁四周都是 [inset]，圆角（格高的一半）
/// 与胶囊的圆角（栏高的一半）同心。胶囊的宽度 = 项数 × 项宽 + 2 × [inset]，
/// 在屏幕上水平居中：项越少栏越短，不再左右撑满。
abstract final class HomeBarMetrics {
  /// 栏高：显示文字时 60，只有图标时 54。指示器高 = 栏高 − 2 × [inset]
  /// （48 / 42），比格宽矮得多，是一颗扁的胶囊而不是近乎方形的一块；图标 +
  /// 间距 + 文字共约 40，上下各留约 4。
  static const double labeledBarHeight = 60;
  static const double compactBarHeight = 54;

  /// 导航项宽度：显示文字时 72（四项共 296，360 宽的屏上两侧各留 32），
  /// 只有图标时 64（格子 64×42，仍是一颗横向的胶囊而不是圆点）。
  static const double labeledItemWidth = 72;
  static const double compactItemWidth = 64;

  /// 屏幕太窄放不下时项宽等比收窄，但不小于它（再窄点按区域就不够了）。
  static const double minItemWidth = 44;

  /// 导航项（也就是选中指示器）与胶囊内壁之间的缝：指示器四周离胶囊边
  /// 都是这么宽，圆角 = 栏圆角 − 它，两者同心。
  static const double inset = 6;

  /// 胶囊与屏幕左右边缘至少留出的距离；与系统手势条之间的距离（手势条
  /// 本身已经让出约 20，再留 4 就够，栏贴近底边、不悬得太高）。
  static const double minSideMargin = 16;
  static const double bottomGap = 4;

  /// 胶囊底缘到屏幕底边至少留出的距离：没有手势条的设备（实体按键、
  /// 桌面窄窗口）上只留 [bottomGap] 会让栏贴到屏幕边、投影被切掉。
  static const double minBottomSpace = 12;

  /// 并排的新建按钮与胶囊之间的距离。
  static const double inlineGap = 8;

  /// 图标的字号与它占的方框：框比图标大 2，容纳选中时的放大与弹跳，
  /// 不会压到文字。
  static const double iconSize = 22;
  static const double iconBox = 24;

  /// 图标框与文字之间的距离；文字字号（行高 1.2）。
  static const double labelGap = 3;
  static const double labelFontSize = 11;

  /// 文字与格子左右边缘至少留出的距离：长名称在这之内等比缩小，不省略。
  static const double labelSideInset = 4;

  /// 背景模糊半径的两端：底色最淡时 [minBlurSigma]、最浓时 [maxBlurSigma]，
  /// 中间按不透明度线性取值（见 `HomeBarResolvedStyle.blurSigma`）。
  ///
  /// 为什么跟着不透明度走：玻璃感来自“看得见后面的东西”。底色淡而模糊重
  /// 时，后面的文字与照片被抹成一片均匀的颜色，再淡也像一块实色；底色淡
  /// 时轻模糊，透出来的照片和文字仍看得出轮廓（通透），底色浓时重模糊，
  /// 只剩色块（磨砂）。一个“通透程度”滑块同时调两者，不会调出又淡又糊、
  /// 或又浓又清晰这种不像玻璃的组合。
  static const double minBlurSigma = 6;
  static const double maxBlurSigma = 24;

  /// 模糊后背景的饱和度倍数：透出来的颜色更鲜亮，玻璃不发灰。
  static const double saturation = 1.6;

  /// 描边粗细。
  static const double borderWidth = 1;

  /// 胶囊底缘到屏幕底边的距离：系统手势条 [bottomInset] 之上再留
  /// [bottomGap]，且不少于 [minBottomSpace]。
  static double bottomSpace(double bottomInset) =>
      math.max(bottomInset + bottomGap, minBottomSpace);

  static double barHeight(HomeBarLabelMode mode) =>
      mode == HomeBarLabelMode.never ? compactBarHeight : labeledBarHeight;

  static double itemWidth(HomeBarLabelMode mode) =>
      mode == HomeBarLabelMode.never ? compactItemWidth : labeledItemWidth;

  /// 导航项（与指示器）的高度。
  static double itemHeight(double barHeight) => barHeight - inset * 2;

  /// [count] 个宽 [itemWidth] 的导航项拼成的胶囊宽度。
  static double pillWidth(int count, double itemWidth) =>
      count * itemWidth + inset * 2;

  /// 可用宽度 [available]（已扣掉屏幕边距与并排按钮）放不下 [count] 个
  /// [preferred] 宽的导航项时，等比收窄后的项宽；放得下时就是 [preferred]。
  ///
  /// 不小于 [minItemWidth]：极端窄的窗口宁可让栏超出一点（外层会裁切），
  /// 也不把点按区域压到按不中。[available] 无界（测试里常见）时不收窄。
  static double fitItemWidth(double preferred, int count, double available) {
    if (count <= 0 || !available.isFinite) {
      return preferred;
    }
    final fit = (available - inset * 2) / count;
    return math.min(preferred, math.max(minItemWidth, fit));
  }
}
