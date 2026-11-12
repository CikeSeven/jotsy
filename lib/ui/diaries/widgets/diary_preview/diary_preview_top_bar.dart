import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
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
/// 右侧固定为分享、编辑与“更多”（不随样式开关）：最常点的编辑紧挨“更多”。
/// “更多”是弹出菜单（[ExpressiveMenuButton]，条目由页面给出，见
/// `diary_preview_more_menu.dart`）。预览嵌在页面里（宽窗口日记页的右栏，见
/// [DiaryPreviewHostScope]）时没有返回按钮，也不显示标题（右栏本就是阅读区，
/// “日记”之类的标题多余），只留右侧的动作。
///
/// 材质：经典时底色为 [background]（与页面相同），滚动到正文上方时不加阴影与
/// 染色。组件材质里顶栏（`AppGlassComponent.topBars`）为玻璃时，栏本身透明，
/// 整条栏（含状态栏区域）是 `flexibleSpace` 里的一片 [AppGlassSurface]，底缘
/// 一条细线（描边开时），与二级页 `AppTopBar` 同一画法。不同的是这里的栏
/// 浮在正文上（固定或随滚动出现时，文字与图片都从栏下滑过），模糊按
/// [AppGlassBlur.always]，而不是只在背景是图片时才开。
class DiaryPreviewTopBar extends StatelessWidget {
  const DiaryPreviewTopBar({
    super.key,
    required this.style,
    required this.title,
    required this.background,
    required this.pageColor,
    required this.onEdit,
    required this.onShare,
    required this.moreItems,
    this.titleSemantics,
    this.onBack,
    this.sliver = true,
    this.editSlot,
  });

  final DiaryPreviewPageStyle style;

  /// 顶栏标题；null 表示不显示。
  final String? title;

  /// 标题的读屏文字（如位置“3 / 57”读作“第 3 篇，共 57 篇”）；null 时读标题。
  final String? titleSemantics;

  /// 经典材质时的底色。
  final Color background;

  /// 栏下面的页面底色（纸色；让位给页面背景时透明），玻璃底色是自定义色时
  /// 据此检查前景是否看得清（见 [AppGlassResolved.foregroundFor]）。
  final Color pageColor;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  /// “更多”弹出菜单的条目（[ExpressiveMenuItem] 与分隔线）。为空时（设置页的
  /// 样式预览）按钮照常画出、点了没反应，与真实页面长得一样。
  final List<Widget> moreItems;

  /// 返回按钮；null 时返回上一页（设置页的预览里换成空操作）。
  final VoidCallback? onBack;

  /// true（默认）时是滚动视图里的 [SliverAppBar]；false 时是普通 [AppBar]，
  /// 供阅读式编辑页放进 Scaffold 的顶栏位置（正文在编辑器自己的虚拟滚动
  /// 里，没有 sliver 可放；顶栏常驻，不随滚动隐藏）。
  final bool sliver;

  /// 不为 null 时代替“编辑”按钮的位置：阅读式编辑页在编辑中放“完成”，
  /// 其余时候放空占位；手动保存时一直放“保存”。
  final Widget? editSlot;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    if (!glass.isGlass(AppGlassComponent.topBars)) {
      return _buildBar(context, background: background);
    }
    final glassBar = Builder(
      builder: (BuildContext context) => _buildBar(
        context,
        background: Colors.transparent,
        flexibleSpace: AppGlassSurface(
          component: AppGlassComponent.topBars,
          blur: AppGlassBlur.always,
          showBorder: false,
          bottomHairline: glass.hairline,
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (!glass.customTint) {
      return glassBar;
    }
    // 自定义底色可能让主题前景看不清。标题与按钮不在玻璃表面的子树里（它们
    // 由 SliverAppBar 画在 flexibleSpace 之上），所以前景兜底包在整条栏外面；
    // 栏下面是纸色，让位给背景时是背景本身。
    final under = Color.alphaBlend(
      pageColor,
      AppPageBackdrop.of(context).estimatedColor,
    );
    return AppGlassForegroundTheme(
      foreground: glass.foregroundFor(under),
      child: glassBar,
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required Color background,
    Widget? flexibleSpace,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final embedded = DiaryPreviewHostScope.isEmbedded(context);
    final title = embedded ? null : this.title;
    final pinned = style.topBar == DiaryPreviewTopBarMode.pinned;
    final leading = embedded ? null : DiaryPreviewBackButton(onPressed: onBack);
    final titleWidget = title == null
        ? null
        : Text(title, semanticsLabel: titleSemantics);
    final overlayStyle =
        theme.appBarTheme.systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        );
    final editSlot = this.editSlot;
    const moreIcon = FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16);
    final actions = <Widget>[
      IconButton(
        tooltip: context.l10n.previewShare,
        onPressed: onShare,
        icon: const FaIcon(FontAwesomeIcons.shareFromSquare, size: 16),
      ),
      editSlot ??
          IconButton(
            tooltip: context.l10n.commonEdit,
            onPressed: onEdit,
            icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
          ),
      if (moreItems.isEmpty)
        IconButton(
          tooltip: context.l10n.autoT0125,
          onPressed: () {},
          icon: moreIcon,
        )
      else
        ExpressiveMenuButton(
          tooltip: context.l10n.autoT0125,
          icon: moreIcon,
          items: moreItems,
        ),
    ];
    if (!sliver) {
      return AppBar(
        // 与 SliverAppBar 的默认高度一致，不跟随主题里的顶栏高度。
        toolbarHeight: kToolbarHeight,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: leading,
        title: titleWidget,
        systemOverlayStyle: overlayStyle,
        actions: actions,
        flexibleSpace: flexibleSpace,
        foregroundColor: colorScheme.onSurface,
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      );
    }
    return SliverAppBar(
      floating: !pinned,
      pinned: pinned,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: leading,
      title: titleWidget,
      systemOverlayStyle: overlayStyle,
      actions: actions,
      flexibleSpace: flexibleSpace,
      foregroundColor: colorScheme.onSurface,
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }
}
