import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/device_auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../widgets/settings_card_group.dart';
import 'data_management_page.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 设置-数据与隐私二级页。
///
/// 职责：
/// - 收纳高风险/高复杂项入口，降低设置首页信息密度；
/// - 复用现有应用锁、数据管理、回收站能力，不引入新业务协议。
class DataPrivacyPage extends ConsumerWidget {
  const DataPrivacyPage({super.key});

  /// 开关应用锁：开启前确认设备能验证身份，关闭前先验证一次。
  ///
  /// 一律经 [DeviceAuthService]（与上锁日记本同一口径，插件异常按“不支持 /
  /// 未通过”处理）：直接调用 local_auth 在没有实现的平台（Linux）会抛出未处理
  /// 的 MissingPluginException。
  Future<void> _toggleAppLock(
    BuildContext context,
    DeviceAuthService deviceAuth,
    SettingsService settingsService,
    bool enabled,
  ) async {
    if (enabled) {
      final supported = await deviceAuth.isSupported();
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
      final verified = await deviceAuth.authenticate(
        reason: context.l10n.appLockDisableAuthReason,
        persistAcrossBackgrounding: false,
      );
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
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.settingsDataPrivacyTitle),
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
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  SettingsCardGroup(
                    children: <Widget>[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const FaIcon(
                          FontAwesomeIcons.database,
                          size: 16,
                        ),
                        title: Text(l10n.settingsDataManagement),
                        subtitle: Text(l10n.settingsDataManagementSubtitle),
                        trailing: const FaIcon(
                          FontAwesomeIcons.angleRight,
                          size: 14,
                        ),
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    children: <Widget>[
                      settingsAsync.when(
                        data: (settingsService) {
                          return ValueListenableBuilder<bool>(
                            valueListenable:
                                settingsService.appLockEnabledNotifier,
                            builder:
                                (
                                  BuildContext context,
                                  bool enabled,
                                  Widget? child,
                                ) {
                                  // 没有系统身份验证的平台（Linux）开关不可用并说明
                                  // 原因；已开启的锁由启动时的应用锁逻辑自动解除。
                                  final supported =
                                      AppPlatform.supportsDeviceAuth;
                                  return SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    value: supported && enabled,
                                    title: Text(l10n.settingsAppLock),
                                    subtitle: Text(
                                      supported
                                          ? l10n.settingsAppLockSubtitle
                                          : l10n.deviceAuthUnavailable,
                                    ),
                                    onChanged: supported
                                        ? (bool value) => _toggleAppLock(
                                            context,
                                            ref.read(deviceAuthServiceProvider),
                                            settingsService,
                                            value,
                                          )
                                        : null,
                                  );
                                },
                          );
                        },
                        loading: () => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(l10n.settingsAppLock),
                          subtitle: Text(l10n.settingsAppLockSubtitle),
                        ),
                        error: (_, __) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(l10n.settingsAppLock),
                          subtitle: Text(l10n.settingsAppLockSubtitle),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const FaIcon(
                          FontAwesomeIcons.filePen,
                          size: 16,
                        ),
                        title: Text(l10n.diaryDraftsTitle),
                        subtitle: Text(l10n.diaryDraftsSettingsSubtitle),
                        trailing: const FaIcon(
                          FontAwesomeIcons.angleRight,
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) {
                                return const DiaryDraftsPage();
                              },
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const FaIcon(
                          FontAwesomeIcons.trashCan,
                          size: 16,
                        ),
                        title: Text(l10n.settingsRecycleBin),
                        subtitle: Text(l10n.settingsRecycleBinSubtitle),
                        trailing: const FaIcon(
                          FontAwesomeIcons.angleRight,
                          size: 14,
                        ),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
