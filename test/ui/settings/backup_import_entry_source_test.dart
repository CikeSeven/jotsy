import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 覆盖本机数据前必须经过导入方式选择与严重警告（见 AGENTS.md §6）。新增
/// 导入入口时要么复用 chooseBackupImportMode，要么在这里显式登记并说明理由。
void main() {
  Future<List<String>> callersOf(String call) async {
    final callers = <String>[];
    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if ((await entity.readAsString()).contains(call)) {
        callers.add(entity.path.replaceAll('\\', '/'));
      }
    }
    return callers..sort();
  }

  test('archive imports only start from the reviewed entry points', () async {
    expect(await callersOf('importFromZip('), <String>[
      'lib/core/services/data_archive_service.dart',
      'lib/core/services/webdav_sync_service.dart',
      'lib/ui/settings/controllers/data_management_controller.dart',
    ]);
    expect(await callersOf('restoreFromLocalBackup('), <String>[
      'lib/core/services/webdav_sync_service.dart',
      'lib/ui/settings/pages/webdav_sync_page.dart',
    ]);
    // 其他日记应用的导出经转换后同样走合并导入（首项是构造函数自身）。
    expect(await callersOf('BackupMerge('), <String>[
      'lib/core/services/backup_merge.dart',
      'lib/core/services/data_archive_service.dart',
      'lib/core/services/journal_import_service.dart',
    ]);
    expect(await callersOf('JournalImportService.prepare('), <String>[
      'lib/ui/settings/controllers/journal_import_controller.dart',
    ]);
  });

  test('every import entry chooses the mode before writing', () async {
    for (final path in <String>[
      'lib/ui/settings/controllers/data_management_controller.dart',
      'lib/ui/settings/controllers/journal_import_controller.dart',
      'lib/ui/settings/pages/webdav_sync_page.dart',
    ]) {
      final source = await File(path).readAsString();
      expect(source, contains('chooseBackupImportMode('), reason: path);
      expect(source, contains('mode: mode'), reason: path);
    }
  });
}
