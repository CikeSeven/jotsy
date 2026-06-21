import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data management page exposes WebDAV sync entry', () async {
    final source =
        await File(
          'lib/ui/settings/pages/data_management_page.dart',
        ).readAsString();

    expect(source, contains('WebDavSyncPage'));
    expect(source, contains('dataMgmtWebDav'));
    expect(source, contains('dataMgmtWebDavSubtitle'));
  });

  test(
    'WebDAV sync page follows UI feedback and loading conventions',
    () async {
      final source =
          await File(
            'lib/ui/settings/pages/webdav_sync_page.dart',
          ).readAsString();

      expect(source, contains('HomeHintVisibilityScope.showTrackedSnackBar'));
      expect(source, isNot(contains('ScaffoldMessenger')));
      expect(source, contains('LoadingIndicatorM3E'));
      expect(source, isNot(contains('CircularProgressIndicator')));
      expect(source, contains('FontAwesomeIcons.angleLeft'));
      expect(source, isNot(contains('LinearGradient')));
      expect(source, isNot(contains('RadialGradient')));
      expect(source, isNot(contains('SweepGradient')));
      expect(source, contains('_messageForError'));
      expect(source, isNot(contains("webDavOperationFailed('\$error')")));
    },
  );

  test('config fields use a shared aligned prefix-icon builder', () async {
    final source =
        await File(
          'lib/ui/settings/pages/webdav_sync_page.dart',
        ).readAsString();

    // 四个配置字段统一走 _buildConfigField，避免各自内联 InputDecoration
    // 导致 prefixIcon 盒子宽度随字形漂移、图标参差不齐。
    expect(source, contains('Widget _buildConfigField('));
    expect(source, contains('prefixIconConstraints'));
    // 修复后不应再出现“裸 FaIcon 直接作为 prefixIcon”的写法。
    expect(source, isNot(contains('prefixIcon: const FaIcon(')));
  });

  test('WebDAV l10n keys include metadata in both languages', () async {
    final zh = await File('lib/l10n/app_zh.arb').readAsString();
    final en = await File('lib/l10n/app_en.arb').readAsString();

    for (final key in <String>[
      'dataMgmtWebDav',
      'webDavTitle',
      'webDavServerUrl',
      'webDavUploadBackup',
      'webDavRestoreConfirmContent',
      'webDavDeleteConfirmContent',
    ]) {
      expect(zh, contains('"$key"'));
      expect(zh, contains('"@$key"'));
      expect(en, contains('"$key"'));
      expect(en, contains('"@$key"'));
    }
  });
}
