import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../providers/home_widget_providers.dart';
import '../sections/home_widget_gallery_card.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../widgets/home_widget_kind_labels.dart';
import '../widgets/home_widget_preview_demand.dart';
import 'home_widget_studio_page.dart';

/// 设置 → 桌面小组件。
///
/// 上面是桌面上现有的小组件（点开进工作室，改动即时同步到桌面）；下面是
/// 按四组分区的组件库，每张卡片是原生画出来的真实预览，点开设计一个新的
/// 再“添加到桌面”。所需功能关闭的种类不出现在组件库里。
///
/// 页面在的期间快照为全部种类计算数据（[HomeWidgetPreviewDemandMixin]），
/// 预览用的是真实内容；每次打开都重读一遍桌面上的实例（启动器不会主动
/// 通知增删）。
class HomeWidgetsPage extends ConsumerStatefulWidget {
  const HomeWidgetsPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  ConsumerState<HomeWidgetsPage> createState() => _HomeWidgetsPageState();
}

class _HomeWidgetsPageState extends ConsumerState<HomeWidgetsPage>
    with HomeWidgetPreviewDemandMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(installedHomeWidgetsProvider);
    });
  }

  Future<void> _openStudio(HomeWidgetKind kind, {int? widgetId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeWidgetStudioPage(
          settingsService: widget.settingsService,
          kind: kind,
          widgetId: widgetId,
        ),
      ),
    );
    // 从工作室回来时可能刚添加了一个（启动器确认框之后）。
    if (mounted) ref.invalidate(installedHomeWidgetsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = ref.watch(appFeaturesProvider);
    final installed =
        ref.watch(installedHomeWidgetsProvider).value ??
        const <InstalledHomeWidget>[];
    final settings = ref.watch(homeWidgetSettingsProvider);
    final kinds = <HomeWidgetKind>[
      for (final kind in HomeWidgetKind.values)
        if (homeWidgetKindAvailable(kind, features)) kind,
    ];
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.homeWidgetsTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 32),
                children: <Widget>[
                  SettingsCardGroup(
                    title: l10n.homeWidgetsInstalledGroup,
                    children: <Widget>[
                      if (installed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Text(
                            l10n.homeWidgetsInstalledEmpty,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      for (final widget in installed)
                        SettingsNavTile(
                          icon: homeWidgetKindIcon(widget.kind),
                          title: homeWidgetKindName(l10n, widget.kind),
                          subtitle: _styleSummary(
                            l10n,
                            settings
                                .instanceFor(widget.widgetId, widget.kind)
                                .style,
                          ),
                          onTap: () => _openStudio(
                            widget.kind,
                            widgetId: widget.widgetId,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Text(
                      l10n.homeWidgetsGalleryGroup,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final group in HomeWidgetGroup.values)
                    if (kinds.any((kind) => kind.group == group)) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(
                          homeWidgetGroupName(l10n, group),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      for (final kind in kinds)
                        if (kind.group == group)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: HomeWidgetGalleryCard(
                              kind: kind,
                              onTap: () => _openStudio(kind),
                            ),
                          ),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 已添加的小组件的一句话外观：配色 · 底色。
String _styleSummary(AppLocalizations l10n, HomeWidgetStyle style) {
  final palette = switch (style.palette) {
    HomeWidgetPalette.app => l10n.homeWidgetPaletteApp,
    HomeWidgetPalette.wallpaper => l10n.homeWidgetPaletteWallpaper,
    HomeWidgetPalette.seed => l10n.homeWidgetPaletteCustom,
  };
  final background = switch (style.background) {
    HomeWidgetBackground.surface => l10n.homeWidgetBackgroundSurface,
    HomeWidgetBackground.tonal => l10n.homeWidgetBackgroundTonal,
    HomeWidgetBackground.vivid => l10n.homeWidgetBackgroundVivid,
    HomeWidgetBackground.clear => l10n.homeWidgetBackgroundClear,
  };
  return '$palette · $background';
}
