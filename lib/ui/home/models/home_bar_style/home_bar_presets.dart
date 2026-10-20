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

  /// 通透：更透、更模糊、不要投影，下方内容透得最清楚。
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

const _glass = HomeBarStyle(
  material: HomeBarMaterial.glass,
  indicator: HomeBarIndicator.block,
);

const _clear = HomeBarStyle(
  material: HomeBarMaterial.glass,
  indicator: HomeBarIndicator.block,
  blurSigma: 28,
  tintOpacity: 0.45,
  shadow: false,
);

const _frosted = HomeBarStyle(
  material: HomeBarMaterial.glass,
  indicator: HomeBarIndicator.block,
  blurSigma: 32,
  tintOpacity: 0.88,
);

const _tinted = HomeBarStyle(
  material: HomeBarMaterial.glass,
  indicator: HomeBarIndicator.block,
  tint: HomeBarTint.theme,
);

const _compact = HomeBarStyle(
  material: HomeBarMaterial.glass,
  barHeight: 56,
  cornerRadius: 16,
  sideMargin: 24,
  labelMode: HomeBarLabelMode.never,
  iconSize: 22,
  indicator: HomeBarIndicator.block,
);
