// 快照里与日记内容有关的几节怎么取数（docs/rules/home_widgets.md「快照」）：那年今日、
// 最近日记与照片回忆各自要哪些口径 / 来源，查询后交给 home_widget_diary_sections.dart
// 组装，写出 `diaries`、`onThisDay`、`recent` 与 `photos`。应用锁开着时快照构建不调用
// 这里。

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import 'home_widget_data_source.dart';
import 'home_widget_diary_sections.dart';
import 'home_widget_native_config.dart';
import 'home_widget_snapshot_input.dart';

/// `diaries`、`onThisDay`、`recent` 与 `photos` 四节（见 home_widget_diary_sections.dart）：
/// 那年今日算桌面上与草稿里用到的口径（加上默认的同月同日，组件库与刚放下的实例
/// 用它；有照片回忆时再加前后 3 天，供它的“那年今日”来源），最近日记与照片回忆算
/// 用到的来源（加上默认的全部日记）。
Future<Map<String, Object?>> buildHomeWidgetDiarySections(
  HomeWidgetDataSource data,
  HomeWidgetSnapshotInput input,
  HomeWidgetNativeContext nativeContext,
) async {
  final photos = input.kinds.contains(HomeWidgetKind.photoMemories);
  final onThisDay = input.kinds.contains(HomeWidgetKind.onThisDay) || photos;
  final recent = input.kinds.contains(HomeWidgetKind.recentDiaries);
  if (!onThisDay && !recent) return const <String, Object?>{};
  final diaries = HomeWidgetDiaryCollector(
    l10n: input.l10n,
    now: input.now,
    localImage: data.localImage,
  );
  final result = <String, Object?>{};
  if (onThisDay) {
    final matches = <OnThisDayMatch>{
      OnThisDayContent.defaults.match,
      for (final content in input.usedContents)
        if (content is OnThisDayContent) content.match,
      // 照片回忆的“那年今日”按前后 3 天取，照片多一些。
      if (photos) OnThisDayMatch.nearby,
    };
    result['onThisDay'] = buildHomeWidgetOnThisDaySection(
      now: input.now,
      l10n: input.l10n,
      rows: await data.diariesCreatedInRanges(
        homeWidgetOnThisDayRanges(input.now, matches),
      ),
      matches: matches,
      diaries: diaries,
    );
  }
  if (recent) {
    final sources = <String, RecentDiariesContent>{
      'all': RecentDiariesContent.defaults,
      for (final content in input.usedContents)
        if (content is RecentDiariesContent)
          homeWidgetRecentSourceKey(content, nativeContext): content,
    };
    final lists = <String, Object?>{};
    for (final MapEntry(:key, value: content) in sources.entries) {
      final source = switch (key) {
        'all' => RecentDiariesSource.all,
        'pinned' => RecentDiariesSource.pinned,
        _ => content.source,
      };
      lists[key] = buildHomeWidgetRecentList(
        await data.recentDiaries(
          source,
          notebookId: content.notebookId,
          tagName: content.tagName,
          now: input.now,
          limit: kHomeWidgetRecentLimit,
        ),
        diaries,
      );
    }
    result['recent'] = lists;
  }
  if (photos) {
    final sources = <String, String?>{
      'all': null,
      for (final content in input.usedContents)
        if (content is PhotoMemoriesContent)
          if (homeWidgetPhotoSourceKey(content, nativeContext) case final key
              when key.startsWith('notebook:'))
            key: content.notebookId,
    };
    result['photos'] = <String, Object?>{
      for (final MapEntry(:key, value: notebookId) in sources.entries)
        key: buildHomeWidgetPhotoList(
          await data.photoDiaries(
            notebookId: notebookId,
            now: input.now,
            limit: kHomeWidgetPhotoLimit,
          ),
          diaries,
        ),
    };
  }
  result['diaries'] = diaries.toJson();
  return result;
}
