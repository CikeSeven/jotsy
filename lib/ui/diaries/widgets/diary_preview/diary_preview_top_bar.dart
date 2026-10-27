import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import 'diary_preview_host.dart';

/// 预览页返回按钮（`<` 风格，18）；[onPressed] 为 null 时返回上一页。
class DiaryPreviewBackButton extends StatelessWidget {
  const DiaryPreviewBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
    );
  }
}

/// 预览页顶栏 [SliverAppBar]：随滚动隐藏或常驻（[DiaryPreviewPageStyle.topBar]），
/// 右侧依次为“字体与排版”、分享、编辑（各自可关）与常驻的“更多”：最常点的
/// 编辑紧挨“更多”，打开分享按钮时也不挪位置。底色与页面相同，滚动到正文上方
/// 时不加阴影与染色。预览嵌在页面里（宽窗口日记页的右栏，见
/// [DiaryPreviewHostScope]）时没有返回按钮，也不显示标题（右栏本就是阅读区，
/// “日记”之类的标题多余），只留右侧的动作。
class DiaryPreviewTopBar extends StatelessWidget {
  const DiaryPreviewTopBar({
    super.key,
    required this.style,
    required this.title,
    required this.background,
    required this.onOpenTypography,
    required this.onEdit,
    required this.onShare,
    required this.onMore,
    this.titleSemantics,
    this.onBack,
  });

  final DiaryPreviewPageStyle style;

  /// 顶栏标题；null 表示不显示。
  final String? title;

  /// 标题的读屏文字（如位置“3 / 57”读作“第 3 篇，共 57 篇”）；null 时读标题。
  final String? titleSemantics;
  final Color background;
  final VoidCallback onOpenTypography;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onMore;

  /// 返回按钮；null 时返回上一页（设置页的预览里换成空操作）。
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final embedded = DiaryPreviewHostScope.isEmbedded(context);
    final title = embedded ? null : this.title;
    final pinned = style.topBar == DiaryPreviewTopBarMode.pinned;
    return SliverAppBar(
      floating: !pinned,
      pinned: pinned,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: embedded ? null : DiaryPreviewBackButton(onPressed: onBack),
      title: title == null ? null : Text(title, semanticsLabel: titleSemantics),
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
        if (style.showTypographyButton)
          IconButton(
            tooltip: context.l10n.diaryTypographyQuickTooltip,
            onPressed: onOpenTypography,
            icon: const FaIcon(FontAwesomeIcons.font, size: 16),
          ),
        if (style.showShareButton)
          IconButton(
            tooltip: context.l10n.previewShare,
            onPressed: onShare,
            icon: const FaIcon(FontAwesomeIcons.shareFromSquare, size: 16),
          ),
        if (style.showEditButton)
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
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }
}
