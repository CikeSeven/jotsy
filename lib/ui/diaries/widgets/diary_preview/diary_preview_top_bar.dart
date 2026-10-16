import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';

/// 预览页返回按钮（`<` 风格，18）。
class DiaryPreviewBackButton extends StatelessWidget {
  const DiaryPreviewBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
    );
  }
}

/// 预览页顶栏：随滚动隐藏的浮动 [SliverAppBar]，右侧依次为“字体与排版”
/// 快捷面板、编辑与“更多”。
class DiaryPreviewTopBar extends StatelessWidget {
  const DiaryPreviewTopBar({
    super.key,
    required this.onOpenTypography,
    required this.onEdit,
    required this.onMore,
  });

  final VoidCallback onOpenTypography;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return SliverAppBar(
      floating: true,
      pinned: false,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: const DiaryPreviewBackButton(),
      title: Text(context.l10n.autoT0120),
      systemOverlayStyle:
          theme.appBarTheme.systemOverlayStyle ??
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isLight
                ? Brightness.dark
                : Brightness.light,
            statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isLight
                ? Brightness.dark
                : Brightness.light,
          ),
      actions: <Widget>[
        IconButton(
          tooltip: context.l10n.diaryTypographyQuickTooltip,
          onPressed: onOpenTypography,
          icon: const FaIcon(FontAwesomeIcons.font, size: 16),
        ),
        IconButton(
          tooltip: context.l10n.commonEdit,
          onPressed: onEdit,
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
        ),
        IconButton(
          tooltip: context.l10n.autoT0125,
          onPressed: onMore,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
        ),
      ],
      foregroundColor: colorScheme.onSurface,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }
}
