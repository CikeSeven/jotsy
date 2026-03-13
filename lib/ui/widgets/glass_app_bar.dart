import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_effects.dart';

/// 全局玻璃质感 AppBar。
///
/// 统一使用高模糊 + 低透明底色 + 柔和阴影，避免各页面单独重复配置。
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.foregroundColor,
    this.backgroundColor,
    this.toolbarHeight,
    this.bottom,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final resolvedToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(resolvedToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    final resolvedOverlayColor = backgroundColor ?? colorScheme.surface.withAlpha(10);

    return Container(
      decoration: const BoxDecoration(
        boxShadow: AppEffects.softShadow,
      ),
      child: AppBar(
        title: title,
        leading: leading,
        actions: actions,
        centerTitle: centerTitle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        foregroundColor: resolvedForeground,
        backgroundColor: Colors.transparent,
        toolbarHeight: toolbarHeight,
        bottom: bottom,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
              tileMode: TileMode.mirror,
            ),
            child: ColoredBox(color: resolvedOverlayColor),
          ),
        ),
      ),
    );
  }
}
