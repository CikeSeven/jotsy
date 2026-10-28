import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/style_library/saved_style.dart';
import '../../explore/models/explore_presets.dart';
import '../../explore/models/explore_settings.dart';
import '../pages/explore_layout_page.dart';
import 'explore_layout/explore_layout_labels.dart';

/// 外观与语言页的“探索页”入口（只在探索 Tab 开启时由页面放进分组）。
///
/// 副标题显示当前布局的名字：内置布局名、我的布局名或“自定义”，跟随 raw
/// notifier 实时更新（从自定义页返回、恢复备份后都会刷新）。
class SettingsExploreLayoutTile extends StatelessWidget {
  const SettingsExploreLayoutTile({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  static String displayName(AppLocalizations l10n, ExploreSettings settings) {
    final preset = ExplorePreset.matching(settings.current);
    if (preset != null) {
      return ExploreLayoutLabels.presets(
        l10n,
      ).firstWhere((option) => option.id == preset).name;
    }
    return SavedStyles.matching(settings.saved, settings.current)?.name ??
        l10n.exploreLayoutCustom;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return settingsAsync.when(
      data: (SettingsService settings) => ValueListenableBuilder<String?>(
        valueListenable: settings.exploreLayoutRawNotifier,
        builder: (BuildContext context, String? raw, Widget? child) {
          final name = displayName(l10n, ExploreSettings.decode(raw));
          return ListTile(
            contentPadding: padding,
            title: Text(l10n.settingsExploreLayout),
            subtitle: Text(l10n.settingsExploreLayoutSubtitle(name)),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () => Navigator.of(
              context,
            ).push(ExploreLayoutPage.route(settingsService: settings)),
          );
        },
      ),
      loading: () => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.settingsExploreLayout),
      ),
      error: (Object error, StackTrace stackTrace) => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.settingsExploreLayout),
      ),
    );
  }
}
