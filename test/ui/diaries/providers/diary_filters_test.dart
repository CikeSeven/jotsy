import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';

class _EmptyDatabase extends AppDatabase {
  _EmptyDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Stream<List<DiaryWithTags>> watchDiaries({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    int? limit,
    int offset = 0,
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
    bool matchComments = false,
  }) => Stream<List<DiaryWithTags>>.value(const <DiaryWithTags>[]);
}

void main() {
  test('page and search queries include the scope in equality', () {
    DiaryPageQuery page(DiaryListScope scope) => DiaryPageQuery(
      keyword: 'k',
      requiredTagIds: const <int>[1],
      limit: 20,
      sortMode: DiarySortMode.updatedDesc,
      scope: scope,
    );
    const book = DiaryNotebookScope(notebookId: 'n');
    expect(page(DiaryListScope.all), page(const DiaryAllScope()));
    expect(page(book), page(const DiaryNotebookScope(notebookId: 'n')));
    expect(
      page(book).hashCode,
      page(const DiaryNotebookScope(notebookId: 'n')).hashCode,
    );
    expect(page(book), isNot(page(DiaryListScope.all)));
    // 搜索是否也匹配留言参与相等比较：开关一变即换一个查询实例。
    final withComments = DiaryPageQuery(
      keyword: 'k',
      requiredTagIds: const <int>[1],
      limit: 20,
      sortMode: DiarySortMode.updatedDesc,
      matchComments: true,
    );
    expect(withComments, isNot(page(DiaryListScope.all)));
    expect(withComments.timelineKey.matchComments, isTrue);

    expect(
      SearchDiaryQuery(keyword: 'k', scope: book),
      SearchDiaryQuery(keyword: ' k ', scope: book),
    );
    expect(
      SearchDiaryQuery(keyword: 'k', scope: book),
      isNot(SearchDiaryQuery(keyword: 'k')),
    );
  });

  test('setTags filters non-positive ids and replaces selected tags', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(diaryFilterProvider.notifier);
    notifier.toggleTag(99, true);

    notifier.setTags(<int>[7, 0, -2, 7, 5]);

    expect(
      container.read(diaryFilterProvider).selectedTagIds,
      unorderedEquals(<int>[7, 5]),
    );
  });
  testWidgets('idle paging query stays warm briefly, then is released', (
    tester,
  ) async {
    final database = _EmptyDatabase();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    const query = DiaryPageQuery(
      keyword: '',
      requiredTagIds: <int>[7],
      limit: 20,
      sortMode: DiarySortMode.updatedDesc,
    );
    final provider = pagedDiariesProvider(query);

    container.listen(provider, (_, _) {}).close();
    await tester.pump();
    // 刚失去监听：保留，来回切换能直接命中。
    expect(container.exists(provider), isTrue);

    // 保留期内再次被监听：释放计时取消，从最后一次失去监听重新计时。
    await tester.pump(const Duration(seconds: 20));
    container.listen(provider, (_, _) {}).close();
    await tester.pump(const Duration(seconds: 20));
    expect(container.exists(provider), isTrue);

    await tester.pump(diaryQueryIdleRetention);
    expect(container.exists(provider), isFalse);
  });
}
