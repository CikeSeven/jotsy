import 'package:flutter/material.dart';

import '../../ui/app_surface/widgets/app_page_backdrop.dart';
import '../../ui/home/widgets/home_bar/home_chrome_scope.dart';
import '../../ui/widgets/glass_safe_stretch_indicator.dart';

/// 全应用的滚动行为（挂在 `MaterialApp.scrollBehavior`）。
///
/// 只改 Android Material 3 的拉伸越界效果，其余（滚动条、拖动设备、physics、
/// 其他平台与 Material 2 的发光效果）全部沿用 [MaterialScrollBehavior]。
///
/// 为什么：Impeller 上 SDK 的拉伸把整块滚动内容放进离屏图层，滚动内容里
/// 的玻璃（BackdropFilter）在拉伸期间采不到页面背景，回弹结束前突然变得
/// 更透明。这里换成 [GlassSafeStretchingOverscrollIndicator]：可能有正在
/// 模糊的玻璃时用不产生离屏图层的缩放拉伸，否则仍交给 SDK 的拉伸，像素与
/// 动画与原来一致。
///
/// `ScrollConfiguration.of(context).copyWith(...)` 得到的包装行为把
/// `buildOverscrollIndicator` 委托回本类（`overscroll: false` 时不画越界
/// 效果，与原来相同），所以局部改滚动条 / 拖动设备的位置不会退回 SDK 默认。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // 裁切取 decorationClipBehavior：父类读的已弃用 clipBehavior 就是它的
    // 别名，值相同。
    // 平台取 getPlatform 而不是 AppPlatform：与父类同一口径（尊重
    // Theme.platform 与 ScrollConfiguration 的 platform 覆盖），只有父类会
    // 画拉伸的那一种情形（Android + Material 3）才接管。
    if (getPlatform(context) == TargetPlatform.android &&
        Theme.of(context).useMaterial3) {
      return GlassSafeStretchingOverscrollIndicator(
        axisDirection: details.direction,
        clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
        avoidOffscreenLayer: mayHaveBlurringGlass,
        child: child,
      );
    }
    return super.buildOverscrollIndicator(context, child, details);
  }

  /// 这个滚动视图里是否可能有正在模糊的玻璃（在滚动视图内部的 context 上
  /// 判断，只读继承数据）。
  ///
  /// - 高对比度：所有玻璃都不模糊（不透明底色），用原生拉伸；
  /// - 首页导航栏为玻璃顶栏：日记 Tab 的刊头与标签栏是滚动视图里的
  ///   sliver，模糊的是下面滚过的列表内容，与有没有背景图无关；
  /// - 页面背景是图片：内容玻璃（卡片、分组，`AppGlassBlur.auto`）与玻璃
  ///   材质的日记卡片只在这时模糊。不再细分“卡片是不是玻璃”：日记卡片的
  ///   材质存在 Riverpod 的卡片样式里，在滚动行为里读 provider 既要拿
  ///   ProviderContainer、又订阅不到变化；而背景图本身就是用户为“透出背景”
  ///   做的选择，此时统一用缩放拉伸，视觉差别只是拉伸变成整体等比的伸长，
  ///   换来判定简单、不漏掉任何一种玻璃。无背景或纯色背景时内容玻璃不模糊，
  ///   保持原生拉伸。
  @visibleForTesting
  static bool mayHaveBlurringGlass(BuildContext context) {
    if (MediaQuery.maybeHighContrastOf(context) ?? false) return false;
    if (HomeChromeScope.glassTopBarsOf(context)) return true;
    return AppPageBackdrop.maybeOf(context)?.hasImage ?? false;
  }
}
