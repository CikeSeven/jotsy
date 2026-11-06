import 'package:flutter/material.dart';

/// 应用内置字体（HarmonyOS Sans SC）的字族名，见 `pubspec.yaml`。
const String kAppBundledFontFamily = 'HarmonyOSSansSC';

/// 主题携带的字体选择：界面字体与日记内容字体。
///
/// 输入：用户在“正文字体与排版”里选的字体及“用于整个界面”开关（由
/// `appFontsProvider` 解析成字族名）；输出：随 [ThemeData] 往下传的两个字族名。
/// 无副作用。
///
/// 为什么放进主题而不是各自读 provider：
/// - [interface] 决定整份主题的字阶（`buildSeededAppTheme` 据此装配），预览页
///   按心情重新着色、设置页另一种明暗的预览等由 `SeededThemeCache` 另建的主题
///   只要传入 `AppFonts.of(appTheme)` 就与应用外壳同一字体；
/// - [diary] 给日记卡片的标题与摘要用：卡片样式按主题实例解析并缓存
///   （`DiaryCardResolvedStyle`），字体跟着主题走，换字体时主题换实例、缓存
///   自然失效，卡片组件也不必依赖 ProviderScope。
///
/// 两项为 null 都表示内置字体：默认主题与改版前逐像素一致。
@immutable
class AppFonts extends ThemeExtension<AppFonts> {
  const AppFonts({this.interface, this.diary});

  /// 界面字族；null 为内置字体。只有开启“用于整个界面”时才非空。
  final String? interface;

  /// 日记内容（卡片标题与摘要）的字族；null 为内置字体。
  final String? diary;

  /// 主题里没有这份扩展（测试里直接装配的主题）时按内置字体处理。
  static AppFonts of(ThemeData theme) =>
      theme.extension<AppFonts>() ?? const AppFonts();

  @override
  AppFonts copyWith({String? interface, String? diary}) => AppFonts(
    interface: interface ?? this.interface,
    diary: diary ?? this.diary,
  );

  /// 字族不能插值：主题过渡动画过半时整体换成新字体（与 TextStyle 的
  /// fontFamily 插值同一时机）。
  @override
  AppFonts lerp(covariant AppFonts? other, double t) {
    if (other == null) {
      return this;
    }
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      other is AppFonts && other.interface == interface && other.diary == diary;

  @override
  int get hashCode => Object.hash(interface, diary);

  @override
  String toString() => 'AppFonts(interface: $interface, diary: $diary)';
}
