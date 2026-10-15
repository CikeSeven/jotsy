import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 编辑已发布日记时改写发表时间（created_at）的写库口径。
///
/// drift 默认以秒存储 DateTime，测试时间戳都取整秒。
void main() {
  late AppDatabase db;
  late String diaryId;
  final publishedAt = DateTime(2025, 3, 15, 10, 30, 45);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await db.createDiary(
      title: 'Spring walk',
      contentDocJson: '[{"insert":"Body\\n"}]',
      contentText: 'Body',
      metadataJson: '{}',
      createdAtOverride: publishedAt,
    );
  });
  tearDown(() => db.close());

  Future<Diary> stored() async =>
      (await db.getDiaryWithTagsByDiaryId(diaryId))!.diary;

  Future<void> update({DateTime? createdAt}) => db.updateDiary(
    diaryId: diaryId,
    title: 'Spring walk',
    contentDocJson: '[{"insert":"Body edited\\n"}]',
    contentText: 'Body edited',
    metadataJson: '{}',
    createdAt: createdAt,
  );

  test('a new publish time moves the diary to its new calendar day', () async {
    final republishedAt = DateTime(2024, 12, 31, 23, 59);
    await update(createdAt: republishedAt);

    final diary = await stored();
    expect(diary.createdAt, republishedAt);
    expect(diary.updatedAt.isAfter(publishedAt), isTrue);
    expect(
      await db.watchDiariesCreatedOnDay(DateTime(2024, 12, 31)).first,
      hasLength(1),
    );
    expect(
      await db.watchDiariesCreatedOnDay(DateTime(2025, 3, 15)).first,
      isEmpty,
    );
  });

  test('updates without a publish time keep the original one', () async {
    await update();

    final diary = await stored();
    expect(diary.contentText, 'Body edited');
    expect(diary.createdAt, publishedAt);
  });
}
