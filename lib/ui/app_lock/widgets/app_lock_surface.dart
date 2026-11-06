import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';

/// 锁屏遮罩的外框（应用锁、上锁日记本的重锁遮罩在应用密码方式下用）。
///
/// 遮罩挂在 MaterialApp 的 builder 里、Navigator 之上，这里缺两样东西，由
/// 本组件补上：
/// - [Material]：数字键的墨水波纹与文字样式需要祖先里有 Material；
/// - [Overlay]：Tooltip 等依赖最近的 Overlay，Navigator 之上没有，
///   `Overlay.wrap` 给子树一个，防止以后在遮罩里加了带提示的按钮直接报错。
///
/// 背景取首页区域的背景（[AppPageBackground]，区域 diaries）再铺不透明的页面
/// 底色：锁屏看起来与首页同一张底，日记内容一点也透不出来。
class AppLockSurface extends StatelessWidget {
  const AppLockSurface({super.key, required this.builder});

  /// [viewportHeight] 为内容区可见高度（已扣掉上下留白），给键盘挑尺寸。
  final Widget Function(BuildContext context, double viewportHeight) builder;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Overlay.wrap(
        child: AppPageBackground(
          area: AppBackgroundArea.diaries,
          child: Builder(
            builder: (BuildContext context) => ColoredBox(
              color: AppPageBackdrop.pageColorOf(context),
              child: SafeArea(child: AppLockScrollBody(builder: builder)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 可滚动的内容区：内容比可见区域高时（横屏、小窗、大字号）滚动，否则按
/// [alignment] 放置（默认竖直居中）。锁屏遮罩与验证页、设置页共用。
///
/// 设置密码页传 `Alignment.topCenter`：那里可以在数字与图案之间切换，两种
/// 输入区高度不同，居中会让顶部的形式选择跟着上下跳。
class AppLockScrollBody extends StatelessWidget {
  const AppLockScrollBody({
    super.key,
    required this.builder,
    this.alignment = Alignment.center,
  });

  static const double verticalPadding = 24;

  final Widget Function(BuildContext context, double viewportHeight) builder;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final viewport = math.max(
          0.0,
          constraints.maxHeight - verticalPadding * 2,
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: verticalPadding),
                child: builder(context, viewport),
              ),
            ),
          ),
        );
      },
    );
  }
}
