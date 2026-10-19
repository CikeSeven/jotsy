import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_service.dart';

/// 读到一篇笔记，同时记下跳过与只读到摘要的篇数。
class _SkippingProvider implements CloudNoteProvider {
  @override
  final CloudReadIssues issues = CloudReadIssues();

  @override
  Future<String> probe() async => 'account';

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    issues
      ..skip(JournalSkipReason.encrypted, 2)
      ..skip(JournalSkipReason.unsupported)
      ..summaryOnly = 1;
    return [
      CloudNote(
        id: 'n1',
        title: '留下的',
        createdAt: DateTime(2024, 5, 1),
        writeBody: (writer, resolve) => writer.text('正文'),
      ),
    ];
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory documents;
  late AppDatabase database;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('jotsy_cloud_session_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProvider,
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? documents.path
              : null,
        );
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    await database.close();
    await documents.delete(recursive: true);
  });

  test('the import preview reports skipped and summary-only notes', () async {
    final session = await JournalImportService.prepareCloud(
      database: database,
      source: JournalImportSource.wpsNotes,
      provider: _SkippingProvider(),
    );
    addTearDown(session.dispose);

    expect(session.preview.diaryCount, 1);
    expect(session.preview.skippedNotes, {
      JournalSkipReason.encrypted: 2,
      JournalSkipReason.unsupported: 1,
    });
    expect(session.preview.summaryOnlyCount, 1);
  });
}
