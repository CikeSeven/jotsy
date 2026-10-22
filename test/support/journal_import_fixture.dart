import 'dart:convert';
import 'dart:io';

import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;
import 'diary_content_test_helpers.dart';

/// 导入回归用的独立导出目录与暂存区；原文件位于暂存区内，复现生产环境中
/// 附件被 rename 后仍被其他条目引用的情况。
class JournalImportFixture {
  JournalImportFixture._(this.temporary, this.export, this.media);

  static const jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0];

  final Directory temporary;
  final Directory export;
  final JournalMediaStager media;

  static Future<JournalImportFixture> create() async {
    final temporary = await Directory.systemTemp.createTemp('import_fixture_');
    final staging = await Directory(p.join(temporary.path, 'staging')).create();
    final export = await Directory(p.join(staging.path, 'source')).create();
    return JournalImportFixture._(
      temporary,
      export,
      JournalMediaStager(staging.path),
    );
  }

  File write(String relative, Object content) {
    final file = File(p.join(export.path, relative));
    file.parent.createSync(recursive: true);
    if (content is List<int>) {
      file.writeAsBytesSync(content);
    } else {
      file.writeAsStringSync(content is String ? content : jsonEncode(content));
    }
    return file;
  }

  JournalImportInput get input =>
      JournalImportInput(filePath: export.path, extractedPath: export.path);

  static List<Map<String, Object?>> embeds(JournalImportEntry entry) => [
    for (final op in diaryContentQuillOps(entry.contentJson))
      if ((op as Map)['insert'] case final Map<String, Object?> data) data,
  ];

  Future<void> dispose() => temporary.delete(recursive: true);
}
