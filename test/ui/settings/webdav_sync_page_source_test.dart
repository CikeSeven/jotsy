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
    },
  );

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
