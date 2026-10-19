import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_export_controller.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_text.dart';

import '../../../support/backup_test_fixture.dart';
import '../export/diary_export_test_fixtures.dart';

/// 导出成书经控制器：按书序（不按日期重排）、跳过胶囊并去掉空章、以书名
/// 命名，关掉书籍结构或换成表格时照常导出。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  final now = DateTime(2026, 10, 19, 12);

  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  Future<DiaryWithTags> diary(
    String title, {
    required DateTime createdAt,
    DateTime? capsuleUnlockAt,
  }) async {
    final id = await fixture.database.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$title 正文\\n"}]',
      contentText: '$title 正文',
      metadataJson: '{}',
      createdAtOverride: createdAt,
      capsuleLockedAt: capsuleUnlockAt == null ? null : createdAt,
      capsuleUnlockAt: capsuleUnlockAt,
    );
    return (await fixture.database.getDiaryWithTagsByDiaryId(id))!;
  }

  DiaryExportController controller() => DiaryExportController(
    database: fixture.database,
    now: () => now,
    shareFile: (File file, {required String mimeType}) async {},
  );

  String idOf(DiaryWithTags d) => d.diary.diaryId;

  test('keeps the book order, drops sealed capsules with their empty chapter '
      'and names the file after the book', () async {
    final late = await diary('晚', createdAt: DateTime(2026, 5, 3));
    final early = await diary('早', createdAt: DateTime(2026, 5, 1));
    final loose = await diary('散', createdAt: DateTime(2026, 4, 1));
    final sealed = await diary(
      '胶囊',
      createdAt: DateTime(2026, 5, 2),
      capsuleUnlockAt: DateTime(2099),
    );
    final book = DiaryExportBook(
      title: '旅行/日记',
      chapters: <DiaryExportBookChapter>[
        DiaryExportBookChapter(
          title: '第一章',
          diaryIds: <String>[idOf(late), idOf(early)],
        ),
        DiaryExportBookChapter(title: '封存', diaryIds: <String>[idOf(sealed)]),
        DiaryExportBookChapter(diaryIds: <String>[idOf(loose)]),
      ],
    );

    final artifact = await controller().build(
      // 传入顺序与书序不同：以书为准。
      <DiaryWithTags>[loose, sealed, early, late],
      options: const DiaryExportOptions(
        format: DiaryExportFormat.text,
        order: DiaryExportOrder.newestFirst,
      ),
      labels: testExportLabels,
      languageTag: 'zh',
      book: book,
    );

    expect(artifact.fileName, '旅行_日记.txt');
    expect(artifact.exportedCount, 3);
    expect(artifact.skippedCapsules, 1);
    final text = await artifact.file.readAsString();
    expect(text, startsWith('旅行/日记\n'));
    expect(text, contains('目录\n\n第一章\n  2026-5-3  晚\n  2026-5-1  早\n未分章'));
    expect(text, isNot(contains('封存')));
    expect(text, isNot(contains('胶囊')));
    final body = text.substring(text.lastIndexOf('第一章\n'));
    expect(body.indexOf('晚 正文'), lessThan(body.indexOf('早 正文')));
    expect(body.indexOf('早 正文'), lessThan(body.indexOf('散 正文')));
  });

  test('with the book structure off the output is a plain export in book '
      'order', () async {
    final a = await diary('一', createdAt: DateTime(2026, 5, 1));
    final b = await diary('二', createdAt: DateTime(2026, 5, 2));
    final book = DiaryExportBook(
      title: '小本',
      chapters: <DiaryExportBookChapter>[
        DiaryExportBookChapter(title: '章', diaryIds: <String>[idOf(a)]),
        DiaryExportBookChapter(diaryIds: <String>[idOf(b)]),
      ],
    );
    const options = DiaryExportOptions(format: DiaryExportFormat.text);

    final off = await controller().build(
      <DiaryWithTags>[b, a],
      options: options,
      labels: testExportLabels,
      languageTag: 'zh',
      book: book,
      bookStructure: false,
    );
    final offText = await off.file.readAsString();
    expect(off.fileName, '小本.txt');

    final plain = await controller().build(
      <DiaryWithTags>[a, b],
      options: options,
      labels: testExportLabels,
      languageTag: 'zh',
    );
    // 书序与日期先后一致时，与普通的多篇导出逐字相同。
    expect(offText, await plain.file.readAsString());
    expect(offText, isNot(contains('目录')));
    expect(offText, contains(DiaryTextWriter.separator));
  });

  test('CSV ignores the structure but follows the book order', () async {
    final a = await diary('一', createdAt: DateTime(2026, 5, 1));
    final b = await diary('二', createdAt: DateTime(2026, 5, 2));
    final book = DiaryExportBook(
      title: '小本',
      chapters: <DiaryExportBookChapter>[
        DiaryExportBookChapter(
          title: '章',
          diaryIds: <String>[idOf(b), idOf(a)],
        ),
      ],
    );
    final artifact = await controller().build(
      <DiaryWithTags>[a, b],
      options: const DiaryExportOptions(format: DiaryExportFormat.csv),
      labels: testExportLabels,
      languageTag: 'zh',
      book: book,
    );
    expect(artifact.fileName, '小本.csv');
    final rows = (await artifact.file.readAsString()).split('\r\n');
    expect(rows[1], contains(',二,'));
    expect(rows[2], contains(',一,'));
    expect(rows.join(), isNot(contains('目录')));
  });
}
