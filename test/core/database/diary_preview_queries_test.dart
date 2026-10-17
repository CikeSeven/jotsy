import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

/// 预览页左右滑动用到的两条数据库路径：按列表口径取全部 id，以及只改正文
/// 的待办写入。
///
/// drift 默认以秒存储 DateTime，测试时间戳之间至少相差 1 秒。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> insert(
    String title, {
    required int day,
    String text = '正文',
    List<int> tagIds = const <int>[],
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$text\\n"}]',
      contentText: text,
      metadataJson: '{}',
      tagIds: tagIds,
      createdAtOverride: DateTime(2026, 10, day, 9),
    );
  }

  Future<List<String>> listed({
    String keyword = '',
    List<int> tagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
  }) async {
    final items = await db
        .watchDiaries(
          keyword: keyword,
          requiredTagIds: tagIds,
          sortMode: sortMode,
        )
        .first;
    return items.map((item) => item.diary.diaryId).toList();
  }

  test('ids follow the list filter and order exactly', () async {
    final travel = await db.createTag(name: '旅行', color: 0xFF4CAF50);
    final a = await insert('海边', day: 1, text: '看日落', tagIds: <int>[travel]);
    await insert('山里', day: 2, text: '爬山');
    final c = await insert('', day: 3, text: '海风很大');
    final archived = await insert('归档', day: 4, text: '海');
    final deleted = await insert('删除', day: 5, text: '海');
    await db.archiveDiary(archived);
    await db.softDeleteDiary(deleted);
    await db.pinDiary(a);

    for (final mode in DiarySortMode.values) {
      expect(
        await db.getActiveDiaryIds(sortMode: mode),
        await listed(sortMode: mode),
        reason: mode.name,
      );
    }
    final keyword = await db.getActiveDiaryIds(keyword: '海');
    expect(keyword, await listed(keyword: '海'));
    expect(keyword, <String>[a, c]);
    expect(await db.getActiveDiaryIds(requiredTagIds: <int>[travel]), <String>[
      a,
    ]);
  });

  test('a todo write only touches the body and the update time', () async {
    final tag = await db.createTag(name: '待办', color: 0xFF2196F3);
    final id = await insert('清单', day: 1, tagIds: <int>[tag]);
    await db.archiveDiary(id);
    await db.pinDiary(id);
    final before = (await db.getDiaryWithTagsByDiaryId(id))!;

    await Future<void>.delayed(const Duration(seconds: 1));
    await db.updateDiaryContent(
      diaryId: id,
      contentDocJson: '[{"insert":"已勾选\\n"}]',
      contentText: '已勾选',
    );
    final after = (await db.getDiaryWithTagsByDiaryId(id))!;
    expect(after.diary.content, '[{"insert":"已勾选\\n"}]');
    expect(after.diary.contentText, '已勾选');
    expect(after.diary.updatedAt.isAfter(before.diary.updatedAt), isTrue);
    expect(after.diary.isArchived, isTrue);
    expect(after.diary.isPinned, isTrue);
    expect(after.diary.isDeleted, isFalse);
    expect(after.diary.title, before.diary.title);
    expect(after.diary.metadata, before.diary.metadata);
    expect(after.diary.createdAt, before.diary.createdAt);
    expect(after.tags.map((t) => t.id), <int>[tag]);

    // 不存在的日记静默不写。
    await db.updateDiaryContent(
      diaryId: 'missing',
      contentDocJson: '[]',
      contentText: '',
    );
  });
}
