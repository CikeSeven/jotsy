import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_platform.dart';
import '../sections/settings_app_lock_tile.dart';
import '../sections/settings_lan_sync_tile.dart';
import '../widgets/settings_card_group.dart';
import 'data_management_page.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 设置-数据与隐私二级页。
///
/// 职责：
/// - 收纳高风险/高复杂项入口，降低设置首页信息密度；
/// - 复用现有应用锁、数据管理、回收站能力，不引入新业务协议；应用锁与验证
///   方式收在“应用锁与密码”三级页（[SettingsAppLockTile]）。
class DataPrivacyPage extends ConsumerWidget {
  const DataPrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
                      // 局域网同步：iOS 不支持（见 AppPlatform.supportsLanSync）。
                      if (AppPlatform.supportsLanSync)
                        const SettingsLanSyncTile(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    children: <Widget>[
                      const SettingsAppLockTile(),
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
