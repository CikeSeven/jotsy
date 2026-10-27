import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_background.dart';
import '../../../diaries/widgets/diary_floating_toolbar_surface.dart';

// “背景与材质”预览样稿里的各块组件：顶栏、内容卡片、编辑器工具栏与新建
// 按钮。每块都按草稿材质（预览外包的 AppGlassScope）在经典与玻璃两种画法
// 之间二选一，画法与正式组件同源。

/// 二级页顶栏样条：顶部 24 的“状态栏”与 56 高的标题行是同一片表面，
/// 与真实顶栏一样铺到状态栏下面。经典为实色栏底色（随页面背景，见
/// `AppPageBackdrop.solidBarColor`），玻璃与 `AppTopBar` 同一写法。
class AppSurfacePreviewTopBar extends StatelessWidget {
  const AppSurfacePreviewTopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final content = Builder(
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final color = theme.colorScheme.onSurface;
        return SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Row(
              children: <Widget>[
                FaIcon(FontAwesomeIcons.angleLeft, size: 18, color: color),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final glass = AppGlass.of(context);
    if (glass.isGlass(AppGlassComponent.topBars)) {
      return AppGlassSurface(
        component: AppGlassComponent.topBars,
        showBorder: false,
        bottomHairline: glass.hairline,
        child: content,
      );
    }
    return ColoredBox(
      color: AppPageBackdrop.solidBarColorOf(context),
      child: content,
    );
  }
}

/// 内容卡片：真实的 [AppCardSurface]，经典 / 玻璃由它自己按材质选择。
class AppSurfacePreviewCard extends StatelessWidget {
  const AppSurfacePreviewCard({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      padding: const EdgeInsets.all(16),
      child: Builder(
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 编辑器悬浮工具栏样条：外壳就是编辑页真实的 [DiaryFloatingToolbarSurface]
/// （经典 / 玻璃由它自己按材质选择），里面换成几个示意图标。
class AppSurfacePreviewToolbar extends StatelessWidget {
  const AppSurfacePreviewToolbar({super.key});

  static const List<FaIconData> _icons = <FaIconData>[
    FontAwesomeIcons.bold,
    FontAwesomeIcons.italic,
    FontAwesomeIcons.listUl,
    FontAwesomeIcons.squareCheck,
    FontAwesomeIcons.image,
    FontAwesomeIcons.palette,
  ];

  @override
  Widget build(BuildContext context) {
    return DiaryFloatingToolbarSurface(
      child: Builder(
        builder: (BuildContext context) {
          // 在外壳之内读颜色：玻璃自定义底色需要换前景时已在这里换好。
          final color = Theme.of(context).colorScheme.onSurfaceVariant;
          return SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (final icon in _icons) FaIcon(icon, color: color),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 圆形新建按钮（小控件材质）：真实的 [FloatingActionButton]，玻璃时套上首页
/// 新建按钮同一个外壳 [AppGlassFab]（圆角与按钮外形一致）。不可交互，也不
/// 参与 Hero（预览里可能同时存在多个）。
class AppSurfacePreviewCreateButton extends StatelessWidget {
  const AppSurfacePreviewCreateButton({super.key});

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    // 给一个空回调而不是 null：null 会按禁用态绘制，与真实按钮不同（预览外层
    // 已 IgnorePointer，点不到）。
    final button = FloatingActionButton(
      heroTag: null,
      onPressed: () {},
      shape: const CircleBorder(),
      child: const FaIcon(FontAwesomeIcons.plus, size: 20),
    );
    if (AppGlass.of(context).isGlass(AppGlassComponent.controls)) {
      return AppGlassFab(
        borderRadius: BorderRadius.circular(_size / 2),
        child: button,
      );
    }
    return button;
  }
}
