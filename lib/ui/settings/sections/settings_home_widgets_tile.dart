import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../home_widgets/pages/home_widgets_page.dart';
import '../widgets/settings_nav_tile.dart';

/// 设置首页“通用”里的“桌面小组件”行（只在支持桌面小组件的平台出现，见
/// `AppPlatform.supportsHomeWidgets`；调用方据此决定是否放这一行）。
class SettingsHomeWidgetsTile extends ConsumerWidget {
  const SettingsHomeWidgetsTile({super.key});

  /// 当前平台是否有这一行。
  static bool get available => AppPlatform.supportsHomeWidgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsNavTile(
      icon: FontAwesomeIcons.tableCellsLarge,
      title: l10n.homeWidgetsTitle,
      subtitle: l10n.homeWidgetsSubtitle,
      onTap: () async {
        final settings = await ref.read(settingsServiceProvider.future);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                HomeWidgetsPage(settingsService: settings),
          ),
        );
      },
    );
  }
}
