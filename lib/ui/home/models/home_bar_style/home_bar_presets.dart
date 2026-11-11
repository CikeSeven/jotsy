import 'home_bar_style.dart';

/// 首页栏的内置预设；名称、说明与图标由设置页按枚举值解析（模型层不含
/// 文案）。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[glass] 就是
/// 默认样式。栏的行为（滚动隐藏等）是独立设置，预设不改动它。
enum HomeBarPreset {
  /// 玻璃：默认的毛玻璃悬浮底栏。
  glass,

  /// 通透：底色更淡，下方内容透得最清楚。
  clear,

  /// 磨砂：底色更浓，透出的内容只剩色块，文字最稳。
  frosted,

  /// 染色：玻璃向主题色容器色偏一点。
  tinted,

  /// 方圆：圆角矩形的栏，选中块跟着变成同心的圆角矩形。
  rounded,

  /// 舒展：更大的图标与文字、更宽的导航项。
  roomy,

  /// 聚焦：只显示选中项的文字，指示器离胶囊边更近、更饱满。
  focus,

  /// 紧凑：只有图标，栏更矮更短。
  compact;

  HomeBarStyle get style => switch (this) {
    HomeBarPreset.glass => HomeBarStyle.defaults,
    HomeBarPreset.clear => _clear,
    HomeBarPreset.frosted => _frosted,
    HomeBarPreset.tinted => _tinted,
    HomeBarPreset.rounded => _rounded,
    HomeBarPreset.roomy => _roomy,
    HomeBarPreset.focus => _focus,
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

// 各预设只写与默认样式不同的字段：默认值调整时预设跟着走，只保留各自的
// 特征。前四个只改玻璃：模糊强度随不透明度一起变（见
// `HomeBarResolvedStyle.blurSigma`），所以一个数值就决定了玻璃的性格：
// - 默认 0.50：σ 约 15，后面的照片与文字透出模糊的轮廓；
// - 通透 0.20：σ 约 7.5，几乎看得清后面是什么，只有一层薄薄的雾；
// - 浓雾 0.65：σ 约 19，后面只剩柔和的色块，仍透得出颜色，不是实色；
// - 主题色 0.45：与默认同样通透，底色带主题色。
// 后四个改形状与导航项（栏高由内容推导，见 `HomeBarMetrics.itemHeight`）：
// - 方圆：圆角 45%，栏高 60 时胶囊圆角约 13.5、指示器约 7.5，像一块
//   圆角卡片而不是药丸；
// - 舒展：图标 24、文字 12、间距 4、项宽 78、缝 7——格高 52、栏高 66，
//   四项共 326 宽，360 宽的屏上两侧各留 16 仍放得下不收窄；
// - 聚焦：只显示选中项文字、缝 4——栏高 56，指示器 48 高几乎撑满胶囊；
// - 紧凑：只有图标、项宽 60、缝 5——格子 60×42、栏高 52。
const _clear = HomeBarStyle(tintOpacity: 0.2);

const _frosted = HomeBarStyle(tintOpacity: 0.65);

const _tinted = HomeBarStyle(tint: HomeBarTint.theme, tintOpacity: 0.45);

const _rounded = HomeBarStyle(roundness: 0.45);

const _roomy = HomeBarStyle(
  itemWidth: 78,
  itemInset: 7,
  itemIconSize: 24,
  itemLabelSize: 12,
  itemLabelGap: 4,
);

const _focus = HomeBarStyle(labelMode: HomeBarLabelMode.selected, itemInset: 4);

const _compact = HomeBarStyle(
  labelMode: HomeBarLabelMode.never,
  itemWidth: 60,
  itemInset: 5,
);
