import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 网盘备份界面的源码约束（AGENTS.md §6）。
void main() {
  test('data management page exposes the cloud backup entry', () async {
    final source = await File(
      'lib/ui/settings/pages/data_management_page.dart',
    ).readAsString();

    expect(source, contains('CloudBackupPage'));
    expect(source, contains('dataMgmtCloudBackup'));
    expect(source, contains('dataMgmtCloudBackupSubtitle'));
    expect(source, isNot(contains('WebDavSyncPage')));
  });

  test('cloud backup pages prevent leaving during an operation', () async {
    for (final page in [
      'lib/ui/settings/pages/cloud_backup_page.dart',
      'lib/ui/settings/pages/cloud_backup_target_page.dart',
    ]) {
      final source = await File(page).readAsString();
      expect(source, contains('HomeHintVisibilityScope.showTrackedSnackBar'));
      expect(source, contains('FontAwesomeIcons.angleLeft, size: 18'));
      expect(source, contains('ActionLoadingOverlay'));
      // 上传/恢复进行中禁止返回。
      expect(source, contains('canPop: !_busy'));
    }
  });
}
