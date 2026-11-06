import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/form_width.dart';
import '../controllers/app_update_controller.dart';
import '../models/app_update_state.dart';
import '../pages/app_update_page.dart';
import 'app_update_badge.dart';

// 关于页（`AboutPage`）的组成部分：顶栏、卡片表面、操作行与“检查更新”行。

class AboutHeader extends StatelessWidget {
  const AboutHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.backTooltip,
  });

  static const double contentHeight = 56;

  final String title;
  final VoidCallback onBack;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        // 实色顶栏：设了纯色背景时与页面同色，图片背景时保持不透明。
        color: AppPageBackdrop.solidBarColorOf(context),
        child: Padding(
          padding: EdgeInsets.only(top: topSafeInset),
          child: SizedBox(
            height: contentHeight,
            // 宽窗口：返回键随内容列内收（与 AppTopBar 的 contentMaxWidth 同一口径）。
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          AppSpacing.m + FormWidth.extra(constraints.maxWidth),
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: backTooltip,
                          onPressed: onBack,
                          icon: const FaIcon(
                            FontAwesomeIcons.angleLeft,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              title,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutSectionCard extends StatelessWidget {
  const AboutSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 玻璃材质时改为内容玻璃（共用页面背景读取、无背景图不模糊）；经典
    // 分支保持原来的 Card 写法不变。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
        shadow: true,
        child: Padding(padding: padding, child: child),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: ExpressiveSurfaces.cardColor(colorScheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// “检查更新”行：打开软件更新页；副标题随全局更新状态显示新版本、下载
/// 进度或待安装，有新版本时右侧显示“新版本”胶囊。
class AboutCheckUpdateTile extends ConsumerWidget {
  const AboutCheckUpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(appUpdateControllerProvider);
    final release = state.release;
    final fraction = state.progress?.fraction;
    final String? subtitle = switch (state.phase) {
      AppUpdatePhase.downloading when fraction != null =>
        l10n.aboutUpdateSubtitleDownloading((fraction * 100).floor()),
      AppUpdatePhase.readyToInstall => l10n.aboutUpdateSubtitleReady,
      AppUpdatePhase.upToDate => l10n.appUpdateUpToDate,
      _ when state.hasUpdate && release != null =>
        l10n.aboutUpdateSubtitleAvailable('v${release.version.name}'),
      _ => null,
    };
    return AboutActionTile(
      icon: FontAwesomeIcons.arrowsRotate,
      title: l10n.aboutCheckUpdate,
      subtitle: subtitle,
      trailing: state.hasUpdate
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AppUpdateBadge(),
                const SizedBox(width: 8),
                FaIcon(
                  FontAwesomeIcons.angleRight,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const AppUpdatePage(),
        ),
      ),
    );
  }
}

class AboutActionTile extends StatelessWidget {
  const AboutActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconColor = colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 6, 18),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: FaIcon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                FaIcon(FontAwesomeIcons.angleRight, size: 15, color: iconColor),
          ],
        ),
      ),
    );
  }
}
