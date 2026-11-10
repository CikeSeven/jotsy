import 'home_bar_style.dart';

/// 首页栏的内置预设；名称、说明与图标由设置页按枚举值解析（模型层不含
/// 文案）。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[glass] 就是
/// 默认样式。栏的行为（滚动隐藏等）是独立设置，预设不改动它。
enum HomeBarPreset {
  /// 玻璃：默认的毛玻璃悬浮底栏，选中项用圆角块标出。
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
// 特征（更透 / 更浓 / 染色 / 紧凑）。
const _clear = HomeBarStyle(
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

const _frosted = HomeBarStyle(blurSigma: 32, tintOpacity: 0.88);

const _tinted = HomeBarStyle(tint: HomeBarTint.theme);

const _compact = HomeBarStyle(
  barHeight: 52,
  cornerRadius: 16,
  sideMargin: 32,
  labelMode: HomeBarLabelMode.never,
);
