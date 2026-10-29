import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/synced_data_refresh.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';

class _CountingDatabase extends AppDatabase {
  _CountingDatabase() : super.forTesting(NativeDatabase.memory());

  int detailReads = 0;

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) {
    detailReads++;
    return super.getDiaryWithTagsByDiaryId(diaryId);
  }
}

void main() {
  late _CountingDatabase database;
  late ProviderContainer container;

  setUp(() {
    EditingSessionRegistry.instance.debugReset();
    database = _CountingDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<String> createDiary(String title) => database.createDiary(
    title: title,
    contentDocJson: '[{"insert":"body\\n"}]',
    contentText: 'body',
    metadataJson: '{}',
  );

  test(
    'synced writes make an open diary detail read the database again',
    () async {
      final id = await createDiary('Before sync');
      container.listen(syncedDataRefreshProvider, (_, _) {});
      final detail = container.listen(diaryDetailProvider(id), (_, _) {});
      final before = await container.read(diaryDetailProvider(id).future);
      expect(before!.diary.title, 'Before sync');
      expect(database.detailReads, 1);

      // 同步直接改写了这一行（不经 UI 写库函数）。
      await database.customStatement(
        'UPDATE diaries SET title = ? WHERE diary_id = ?',
        ['After sync', id],
      );
      EditingSessionRegistry.instance.notifyDataReplaced();
      await Future<void>.delayed(Duration.zero);

      final refreshed = await container.read(diaryDetailProvider(id).future);
      expect(database.detailReads, 2);
      expect(refreshed!.diary.title, 'After sync');
      expect(detail.read().value?.diary.title, 'After sync');
    },
  );

  test('without a sync event the detail is not read again', () async {
    final id = await createDiary('Stable');
    container.listen(syncedDataRefreshProvider, (_, _) {});
    container.listen(diaryDetailProvider(id), (_, _) {});
    await container.read(diaryDetailProvider(id).future);
    await Future<void>.delayed(Duration.zero);
    await container.read(diaryDetailProvider(id).future);
    expect(database.detailReads, 1);
  });
}
