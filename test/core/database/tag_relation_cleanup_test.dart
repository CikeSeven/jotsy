import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.database.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(() => fixture.dispose());

  Future<String> diaryWithTag(int tag) => fixture.database.createDiary(
    title: 'diary',
    contentDocJson: '[{"insert":"text\\n"}]',
    contentText: 'text',
    metadataJson: '{}',
    tagIds: [tag],
  );

  test(
    'deleting a tag clears bindings without requiring SQLite foreign keys',
    () async {
      final tag = await fixture.database.createTag(
        name: 'tag',
        color: 0xff112233,
      );
      await diaryWithTag(tag);
      await diaryWithTag(tag);
      await fixture.database.deleteTag(tag);
      expect(
        await fixture.database.select(fixture.database.tags).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.diaryTags).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.diaries).get(),
        hasLength(2),
      );
    },
  );

  test(
    'permanent deletion clears only the deleted diary bindings with foreign keys off',
    () async {
      final tag = await fixture.database.createTag(
        name: 'tag',
        color: 0xff112233,
      );
      final removed = await diaryWithTag(tag);
      final retained = await diaryWithTag(tag);
      await fixture.database.hardDeleteDiary(removed);
      expect(
        (await fixture.database.select(fixture.database.diaries).getSingle())
            .diaryId,
        retained,
      );
      expect(
        await fixture.database.select(fixture.database.diaryTags).get(),
        hasLength(1),
      );
      expect(
        (await fixture.database.getDiaryWithTagsByDiaryId(
          retained,
        ))!.tags.map((row) => row.id),
        [tag],
      );
    },
  );
}
