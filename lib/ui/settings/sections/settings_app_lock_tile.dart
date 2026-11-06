import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../../core/services/app_service.dart';
import '../../app_lock/pages/app_lock_settings_page.dart';
import '../widgets/settings_nav_tile.dart';

/// 设置首页“数据与安全”组里的“应用锁与密码”入口（DESIGN.md §5.31）。
///
/// 副标题随状态：应用锁开着时为“已开启 · 系统验证 / 应用密码”，关着时为
/// “未开启”（设了应用密码时补一句“上锁的日记本使用应用密码”，免得以为密码
/// 没生效）。设置服务未就绪时只显示功能说明。
class SettingsAppLockTile extends ConsumerWidget {
  const SettingsAppLockTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    final passcode = ref.watch(
      appPasscodeConfigProvider.select((config) => config.hasPasscode),
    );
    Widget tile(String subtitle) => SettingsNavTile(
      icon: FontAwesomeIcons.lock,
      title: l10n.settingsAppLockAndPasscode,
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const AppLockSettingsPage(),
          ),
        );
      },
    );
    if (settings == null) {
      return tile(l10n.settingsAppLockSubtitle);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: settings.appLockEnabledNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        final String subtitle;
        if (enabled) {
          subtitle = passcode
              ? l10n.appLockStatusPasscode
              : l10n.appLockStatusSystem;
        } else {
          subtitle = passcode
              ? l10n.appLockStatusOffPasscode
              : l10n.appLockStatusOff;
        }
        return tile(subtitle);
      },
    );
  }
}
