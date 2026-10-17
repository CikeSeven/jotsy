import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 网盘备份界面的源码约束（AGENTS.md §6）。
void main() {
  const uiFiles = [
    'lib/ui/settings/pages/cloud_backup_page.dart',
    'lib/ui/settings/pages/cloud_backup_target_page.dart',
    'lib/ui/settings/sections/cloud_backup_account_section.dart',
    'lib/ui/settings/sections/cloud_backup_config_forms.dart',
    'lib/ui/settings/sections/cloud_backup_remote_list.dart',
    'lib/ui/settings/widgets/cloud_backup_authorization_dialogs.dart',
    'lib/ui/settings/widgets/cloud_backup_config_field.dart',
    'lib/ui/settings/widgets/cloud_backup_dialogs.dart',
    'lib/ui/settings/widgets/cloud_backup_provider_sheet.dart',
  ];

  test('data management page exposes the cloud backup entry', () async {
    final source = await File(
      'lib/ui/settings/pages/data_management_page.dart',
    ).readAsString();

    expect(source, contains('CloudBackupPage'));
    expect(source, contains('dataMgmtCloudBackup'));
    expect(source, contains('dataMgmtCloudBackupSubtitle'));
    expect(source, isNot(contains('WebDavSyncPage')));
  });

  test('cloud backup UI follows feedback, loading and color rules', () async {
    for (final path in uiFiles) {
      final source = await File(path).readAsString();
      expect(source, isNot(contains('ScaffoldMessenger')), reason: path);
      expect(
        source,
        isNot(contains('CircularProgressIndicator')),
        reason: path,
      );
      expect(source, isNot(contains('Gradient(')), reason: path);
      expect(source, isNot(contains('Colors.white')), reason: path);
      expect(source, isNot(contains('Colors.black')), reason: path);
      expect(source, isNot(contains('Duration(milliseconds')), reason: path);
      // 图标只用 FontAwesome，不混用 Material Icons。
      expect(
        source,
        isNot(contains(RegExp(r'(?<!FontAwesome)Icons\.'))),
        reason: path,
      );
    }
    for (final page in uiFiles.where((path) => path.contains('/pages/'))) {
      final source = await File(page).readAsString();
      expect(source, contains('HomeHintVisibilityScope.showTrackedSnackBar'));
      expect(source, contains('FontAwesomeIcons.angleLeft, size: 18'));
      expect(source, contains('ActionLoadingOverlay'));
      // 上传/恢复进行中禁止返回。
      expect(source, contains('canPop: !_busy'));
    }
  });

  test('config fields share one aligned prefix-icon builder', () async {
    final field = await File(
      'lib/ui/settings/widgets/cloud_backup_config_field.dart',
    ).readAsString();
    final forms = await File(
      'lib/ui/settings/sections/cloud_backup_config_forms.dart',
    ).readAsString();

    expect(field, contains('prefixIconConstraints'));
    expect(forms, isNot(contains('prefixIcon:')));
    expect(forms, contains('CloudBackupConfigField('));
  });

  test('cloud backup l10n keys have metadata in both languages', () async {
    final zh =
        jsonDecode(await File('lib/l10n/app_zh.arb').readAsString()) as Map;
    final en =
        jsonDecode(await File('lib/l10n/app_en.arb').readAsString()) as Map;
    final keys = zh.keys
        .whereType<String>()
        .where(
          (key) =>
              key.startsWith('cloudBackup') ||
              key.startsWith('s3') ||
              key.startsWith('dataMgmtCloudBackup'),
        )
        .toList();
    expect(keys.length, greaterThan(100));
    for (final key in keys) {
      expect(en.containsKey(key), isTrue, reason: key);
      expect((zh['@$key'] as Map?)?['description'], isNotNull, reason: key);
      expect((en['@$key'] as Map?)?['description'], isNotNull, reason: key);
    }
    // 旧的 WebDAV 页面文案已并入网盘备份，不能残留。
    expect(zh.containsKey('webDavTitle'), isFalse);
    expect(zh.containsKey('dataMgmtWebDav'), isFalse);
  });
}
