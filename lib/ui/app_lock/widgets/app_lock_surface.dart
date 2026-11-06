import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';

/// 锁屏遮罩的外框（应用锁、上锁日记本的重锁遮罩在密码方式下用）。
///
/// 遮罩挂在 MaterialApp 的 builder 里、Navigator 之上，这里缺两样输入框
/// 需要的东西，由本组件补上：
/// - [Material]：TextField 要求祖先里有 Material（墨水与文字样式）；
/// - [Overlay]：选区手柄、文字选区菜单都放进最近的 Overlay，Navigator 之上
///   没有，`Overlay.wrap` 给子树一个；
///
/// 背景取首页区域的背景（[AppPageBackground]，区域 diaries）再铺不透明的页面
/// 底色：锁屏看起来与首页同一张底，日记内容一点也透不出来。
///
/// 内容放进 [AppLockScrollBody]：键盘弹出时可滚动、按可见区域居中。
class AppLockSurface extends StatelessWidget {
  const AppLockSurface({super.key, required this.child});

  final Widget child;

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
              child: SafeArea(child: AppLockScrollBody(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 竖直居中、可滚动的内容区：可见高度扣除键盘（`viewInsets.bottom`），内容
/// 比可见区域高时滚动，聚焦的输入框会被滚进视野。
///
/// 在 Scaffold 的 body 里键盘高度已被 Scaffold 扣掉（body 的 viewInsets 为
/// 0），同一组件两处都能用。
class AppLockScrollBody extends StatelessWidget {
  const AppLockScrollBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboard),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - keyboard),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
