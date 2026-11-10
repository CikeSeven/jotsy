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

  /// 紧凑：只有图标，栏更矮更短。
  compact;

  HomeBarStyle get style => switch (this) {
    HomeBarPreset.glass => HomeBarStyle.defaults,
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

// 各预设只写与默认样式不同的字段：默认值调整时预设跟着走，只保留各自的
// 特征（更透 / 更浓 / 染色 / 紧凑）。模糊强度随不透明度一起变（见
// `HomeBarResolvedStyle.blurSigma`），所以一个数值就决定了玻璃的性格：
// - 默认 0.50：σ 约 15，后面的照片与文字透出模糊的轮廓；
// - 通透 0.20：σ 约 7.5，几乎看得清后面是什么，只有一层薄薄的雾；
// - 磨砂 0.65：σ 约 19，后面只剩柔和的色块，仍透得出颜色，不是实色；
// - 主题色 0.45：与默认同样通透，底色带主题色。
const _clear = HomeBarStyle(tintOpacity: 0.2);

const _frosted = HomeBarStyle(tintOpacity: 0.65);

const _tinted = HomeBarStyle(tint: HomeBarTint.theme, tintOpacity: 0.45);

const _compact = HomeBarStyle(labelMode: HomeBarLabelMode.never);
