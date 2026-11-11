import 'dart:math' as math;

/// 悬浮底栏的几何：不开放调节的常量，以及由样式参数推导栏尺寸的纯函数。
///
/// 用户能调的是圆角程度、项宽、缝、图标、文字与间距（`HomeBarStyle`）；
/// 其余尺寸由它们推导，而不是各自独立的滑块——这些数值互相牵制（指示器要
/// 贴着胶囊内壁留一圈等宽的缝并与胶囊同心，图标与文字要在指示器里竖直
/// 居中），推导能保证任意组合都不失衡；规格见 DESIGN.md §5.19。
///
/// 一个导航项就是一格：宽为项宽、高为 [itemHeight]（内容加上下留白）。
/// 选中指示器铺满一格，所以它到胶囊内壁四周都是缝（inset），胶囊的高 =
/// 格高 + 2 × 缝、宽 = 项数 × 项宽 + 2 × 缝，在屏幕上水平居中：项越少栏越
/// 短，不再左右撑满。
abstract final class HomeBarMetrics {
  /// 屏幕太窄放不下时项宽等比收窄，但不小于它（再窄点按区域就不够了）。
  static const double minItemWidth = 44;

  /// 胶囊与屏幕左右边缘至少留出的距离；与系统手势条之间的距离（手势条
  /// 本身已经让出约 20，再留 4 就够，栏贴近底边、不悬得太高）。
  static const double minSideMargin = 16;
  static const double bottomGap = 4;

  /// 胶囊底缘到屏幕底边至少留出的距离：没有手势条的设备（实体按键、
  /// 桌面窄窗口）上只留 [bottomGap] 会让栏贴到屏幕边、投影被切掉。
  static const double minBottomSpace = 12;

  /// 并排的新建按钮与胶囊之间的距离。
  static const double inlineGap = 8;

  /// 图标占的方框比图标大这么多：容纳选中时的放大与弹跳，不会压到文字。
  static const double iconBoxExtra = 2;

  /// 文字的行高倍数。
  static const double labelLineHeight = 1.2;

  /// 格子里内容（图标 + 间距 + 文字）上下各留的白：默认参数下格高 48，
  /// 图标框 24 + 间距 3 + 文字 13.2 约 40，上下各约 4。文字放大到 1.3 倍时
  /// 多出的高度也从这里让出，不会溢出指示器。
  static const double labeledContentPadding = 4;

  /// 只有图标时上下各留的白：格子仍是一颗横向的扁胶囊（默认 72×42），
  /// 不是只裹着图标的小圆点。
  static const double iconOnlyContentPadding = 9;

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

  /// 图标占的方框边长。
  static double iconBox(double iconSize) => iconSize + iconBoxExtra;

  /// 导航项（与指示器）的高度：内容的高度加上下留白，取整到整像素，免得
  /// 胶囊边缘落在半像素上发虚。[labelSize] 为 null 表示只有图标。
  static double itemHeight({
    required double iconSize,
    double? labelSize,
    double labelGap = 0,
  }) {
    final box = iconBox(iconSize);
    if (labelSize == null) {
      return (box + iconOnlyContentPadding * 2).roundToDouble();
    }
    return (box +
            labelGap +
            labelSize * labelLineHeight +
            labeledContentPadding * 2)
        .roundToDouble();
  }

  /// [count] 个宽 [itemWidth] 的导航项、四周缝为 [inset] 的胶囊宽度。
  static double pillWidth(int count, double itemWidth, double inset) =>
      count * itemWidth + inset * 2;

  /// 可用宽度 [available]（已扣掉屏幕边距与并排按钮）放不下 [count] 个
  /// [preferred] 宽的导航项（两侧另有 [inset] 的缝）时，等比收窄后的项宽；
  /// 放得下时就是 [preferred]。
  ///
  /// 不小于 [minItemWidth]：极端窄的窗口宁可让栏超出一点（外层会裁切），
  /// 也不把点按区域压到按不中。[available] 无界（测试里常见）时不收窄。
  static double fitItemWidth(
    double preferred,
    int count,
    double available, {
    required double inset,
  }) {
    if (count <= 0 || !available.isFinite) {
      return preferred;
    }
    final fit = (available - inset * 2) / count;
    return math.min(preferred, math.max(minItemWidth, fit));
  }
}
