import 'home_bar_style.dart';

/// 首页栏的内置预设；名称、说明与图标由设置页按枚举值解析（模型层不含
/// 文案）。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[classic] 就是
/// 默认的实色栏。栏的行为（滚动隐藏等）是独立设置，预设不改动它。
enum HomeBarPreset {
  /// 经典：改版前的实色栏。
  classic,

  /// 玻璃：默认参数的毛玻璃悬浮底栏，选中项用圆角块标出。
  glass,

  /// 通透：更透、更模糊、不要投影，下方内容透得最清楚；描边换成明亮的
  /// 边缘高光，勾出玻璃的轮廓。
  clear,

  /// 磨砂：底色更浓，透出的内容只剩色块，文字最稳。
  frosted,

  /// 染色：玻璃向主题色容器色偏一点。
  tinted,

  /// 紧凑：更矮、两侧收得更窄，只有图标。
  compact;

  HomeBarStyle get style => switch (this) {
    HomeBarPreset.classic => HomeBarStyle.defaults,
    HomeBarPreset.glass => _glass,
    HomeBarPreset.clear => _clear,
    HomeBarPreset.frosted => _frosted,
    HomeBarPreset.tinted => _tinted,
    HomeBarPreset.compact => _compact,
  };

  /// 与 [style] 完全相同的第一个预设；不是任何预设时为 null。
  static HomeBarPreset? matching(HomeBarStyle style) {
    for (final preset in values) {
      if (preset.style == style) {
        return preset;
      }
    }
    return null;
  }
}

// 玻璃系预设的间距与 HomeBarStyle.withMaterial 切到玻璃时的结果一致：
// 从经典栏切到玻璃、再选圆角块，得到的正是“玻璃”预设，预设标记才能对上。
const _glass = HomeBarStyle(
  material: HomeBarMaterial.glass,
  labelGap: HomeBarStyle.glassLabelGap,
  indicator: HomeBarIndicator.block,
);

const _clear = HomeBarStyle(
  material: HomeBarMaterial.glass,
  labelGap: HomeBarStyle.glassLabelGap,
  indicator: HomeBarIndicator.block,
  blurSigma: 28,
  tintOpacity: 0.45,
  shadow: false,
  // 没有投影、底色又淡，灰色描边在浅色内容上几乎看不见；换成高光边缘，
  // 像玻璃边缘反光一样勾出栏的轮廓。
  borderLine: HomeBarLineStyle(
    color: HomeBarLineColor.highlight,
    opacity: 0.7,
    width: 1.0,
  ),
);

const _frosted = HomeBarStyle(
  material: HomeBarMaterial.glass,
  labelGap: HomeBarStyle.glassLabelGap,
  indicator: HomeBarIndicator.block,
  blurSigma: 32,
  tintOpacity: 0.88,
);

const _tinted = HomeBarStyle(
  material: HomeBarMaterial.glass,
  labelGap: HomeBarStyle.glassLabelGap,
  indicator: HomeBarIndicator.block,
  tint: HomeBarTint.theme,
);

const _compact = HomeBarStyle(
  material: HomeBarMaterial.glass,
  labelGap: HomeBarStyle.glassLabelGap,
  barHeight: 56,
  cornerRadius: 16,
  sideMargin: 24,
  labelMode: HomeBarLabelMode.never,
  iconSize: 22,
  indicator: HomeBarIndicator.block,
);
