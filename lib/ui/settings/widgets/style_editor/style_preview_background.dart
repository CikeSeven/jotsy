import 'package:flutter/material.dart';

import '../../../app_surface/models/app_surface_enums.dart';
import '../../../app_surface/widgets/app_page_background.dart';

/// 样式编辑页的实时预览所模拟的界面区域（如卡片样式 → 日记页）。
///
/// 由 `StyleEditorScaffold(previewArea:)` 包在预览外面，预览自己在“页面”
/// 所在的位置放 [StylePreviewBackground] 读取它。之所以不由外壳直接画背景：
/// 各预览在自己内部按“预览明暗”另套一份主题，背景遮罩与估计色要跟随
/// 预览主题（`AppPageBackground` 读所在位置的 Theme），而且导航栏样式的
/// 背景只该铺在手机画框里，只有预览自己知道“页面”在哪一层。
class StylePreviewArea extends InheritedWidget {
  const StylePreviewArea({super.key, required this.area, required super.child});

  /// 为 null：预览不模拟任何区域，按无背景处理。
  final AppBackgroundArea? area;

  static AppBackgroundArea? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StylePreviewArea>()?.area;

  @override
  bool updateShouldNotify(StylePreviewArea oldWidget) => area != oldWidget.area;
}

/// 预览里“页面”的背景：在 [child] 下面画 [StylePreviewArea] 所指区域已保存
/// 的背景（与真实页面同一个 [AppPageBackground]，读同一份设置、同一套解码
/// 缓存、遮罩与交叉淡入），并经 [AppPageBackdrop] 把该区域的页面底色、实色
/// 栏底色、估计色与内容玻璃的共享背景键交给预览子树——半透明卡片的对比度、
/// 玻璃卡片 / 玻璃栏的模糊因此与真实页面一致。
///
/// 必须放在预览自己的主题覆盖（预览明暗）之内：切到另一种明暗时背景遮罩
/// 与估计色随之换成那一套。预览里的页面底色一律改读
/// `AppPageBackdrop.pageColorOf`（画了背景时透明、露出背景）。
///
/// 没有区域时插入 [AppPageBackdrop.plain]：盖住外层设置页背景的信息（设置
/// 页设了背景图时，预览不该按设置页的背景算对比度或拿它的共享键去模糊），
/// 取值与预览主题的原页面颜色相同，画面与接入前逐像素一致。区域没有背景时
/// `AppPageBackground` 同样不画任何东西、给出原页面颜色。
class StylePreviewBackground extends StatelessWidget {
  const StylePreviewBackground({
    super.key,
    required this.child,
    this.deferScrim = false,
  });

  final Widget child;

  /// 与真实页面一致地把图片遮罩交给预览里的页面画（见
  /// `AppPageBackground.deferScrim`），如预览页样式的“背景遮罩随基调染色”。
  final bool deferScrim;

  @override
  Widget build(BuildContext context) {
    final area = StylePreviewArea.maybeOf(context);
    if (area == null) {
      return AppPageBackdropScope(
        backdrop: AppPageBackdrop.plain(Theme.of(context).colorScheme),
        child: child,
      );
    }
    return AppPageBackground(area: area, deferScrim: deferScrim, child: child);
  }
}
