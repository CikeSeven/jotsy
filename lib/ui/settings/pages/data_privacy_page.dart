import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import 'data_management_page.dart';

/// 设置-数据与隐私二级页。
///
/// 职责：
/// - 收纳高风险/高复杂项入口，降低设置首页信息密度；
/// - 复用现有应用锁、数据管理、回收站能力，不引入新业务协议。
class DataPrivacyPage extends ConsumerWidget {
  const DataPrivacyPage({super.key});

  Future<void> _toggleAppLock(
    BuildContext context,
    SettingsService settingsService,
    bool enabled,
  ) async {
    final localAuth = LocalAuthentication();
    if (enabled) {
      final supported =
          await localAuth.isDeviceSupported() ||
          await localAuth.canCheckBiometrics;
      if (!context.mounted) {
        return;
      }
      if (!supported) {
        await HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(context.l10n.appLockNotSupported)),
        );
        return;
      }
    }
    if (!enabled) {
      bool verified = false;
      try {
        verified = await localAuth.authenticate(
          localizedReason: context.l10n.appLockDisableAuthReason,
          biometricOnly: false,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: false,
        );
      } catch (_) {
        verified = false;
      }
      if (!context.mounted) {
        return;
      }
      if (!verified) {
        await HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(context.l10n.appLockDisableVerifyFailed),
          ),
        );
        return;
      }
    }
    await settingsService.setAppLockEnabled(enabled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(settingsServiceProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.settingsDataPrivacyTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.database, size: 16),
            title: Text(l10n.settingsDataManagement),
            subtitle: Text(l10n.settingsDataManagementSubtitle),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return const DataManagementPage();
                  },
                ),
              );
            },
          ),
          const Divider(),
          settingsAsync.when(
            data: (settingsService) {
              return ValueListenableBuilder<bool>(
                valueListenable: settingsService.appLockEnabledNotifier,
                builder: (BuildContext context, bool enabled, Widget? child) {
                  return SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: Text(l10n.settingsAppLock),
                    subtitle: Text(l10n.settingsAppLockSubtitle),
                    onChanged:
                        (bool value) =>
                            _toggleAppLock(context, settingsService, value),
                  );
                },
              );
            },
            loading:
                () => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsAppLock),
                  subtitle: Text(l10n.settingsAppLockSubtitle),
                ),
            error:
                (_, __) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsAppLock),
                  subtitle: Text(l10n.settingsAppLockSubtitle),
                ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
            title: Text(l10n.settingsRecycleBin),
            subtitle: Text(l10n.settingsRecycleBinSubtitle),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return const RecycleBinPage();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
