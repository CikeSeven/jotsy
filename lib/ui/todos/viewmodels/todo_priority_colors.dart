import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// 待办优先级的配色：高红、中橙、低蓝，与主题色无关，只随明暗换算。
///
/// 为什么不跟随主题：原先取 `error / tertiary / primary`，`primary` 与
/// `tertiary` 明度相近、只靠 1.6dp 的描边很难分辨；灰色与“黑白”主题里两者
/// 都是灰（`appColorSchemeFromSeed` 只给错误色留色相），中、低完全分不出。
/// 优先级是一种固定语义，红橙蓝在任何主题下都应读成同一个意思。
///
/// 为什么不直接涂种子色：同一个橙色在暗色主题里刺眼、在浅色背景上又不够
/// 对比度。每种颜色经 `ColorScheme.fromSeed`（`fidelity` 保留种子的彩度）
/// 按当前明暗换算：
/// - [accent] 取 `contrastLevel: -1` 的主色：比标准主色（浅色 tone 40）亮
///   一档，橙色不会发褐、红橙蓝在暗色里也不再都是淡粉，与页面表面的对比度
///   仍在 4.4:1 以上；用于方框描边、勾选后的填充与菜单里的旗子；
/// - [onAccent] 为与之配对的前景（勾选后的对勾）；
/// - [tint] 为 [accent] 的半透明淡底（未勾选的方框里、优先级胶囊底），半透明
///   以便叠在玻璃卡片上；
/// - [onTint] 取标准对比度的主色（浅色 tone 40、深色 tone 80），淡底上的
///   小字也有 4.5:1。
///
/// 换算较贵，按（优先级, 明暗）缓存，最多六份。
@immutable
class TodoPriorityColors {
  const TodoPriorityColors({
    required this.accent,
    required this.onAccent,
    required this.tint,
    required this.onTint,
  });

  final Color accent;
  final Color onAccent;
  final Color tint;
  final Color onTint;

  /// 种子取自色板（`kColorPaletteFamilies`）的红、橙、蓝系。
  static const Color _highSeed = Color(0xFFD32F2F);
  static const Color _mediumSeed = Color(0xFFF57C00);
  static const Color _lowSeed = Color(0xFF1565C0);

  /// 淡底的不透明度：暗色背景上同样的比例显得更淡，取高一些。
  static const double _lightTintAlpha = 0.14;
  static const double _darkTintAlpha = 0.24;

  static final Map<(TodoPriority, Brightness), TodoPriorityColors> _cache =
      <(TodoPriority, Brightness), TodoPriorityColors>{};

  /// [priority] 在 [scheme] 的明暗下的配色；无优先级为 null（调用方用默认
  /// 外观）。
  static TodoPriorityColors? of(ColorScheme scheme, TodoPriority priority) {
    final seed = switch (priority) {
      TodoPriority.none => null,
      TodoPriority.low => _lowSeed,
      TodoPriority.medium => _mediumSeed,
      TodoPriority.high => _highSeed,
    };
    if (seed == null) return null;
    final brightness = scheme.brightness;
    return _cache[(priority, brightness)] ??= _derive(seed, brightness);
  }

  static TodoPriorityColors _derive(Color seed, Brightness brightness) {
    ColorScheme derive(double contrastLevel) => ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      contrastLevel: contrastLevel,
    );
    final vivid = derive(-1);
    final standard = derive(0);
    final alpha = brightness == Brightness.dark
        ? _darkTintAlpha
        : _lightTintAlpha;
    return TodoPriorityColors(
      accent: vivid.primary,
      onAccent: vivid.onPrimary,
      tint: vivid.primary.withValues(alpha: alpha),
      onTint: standard.primary,
    );
  }
}
