import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

/// 面板收起栏上的一项摘要。
sealed class PublishSummaryItem {
  const PublishSummaryItem();
}

/// 已设置时间胶囊（定时锁）。
final class PublishSummaryCapsule extends PublishSummaryItem {
  const PublishSummaryCapsule();
}

final class PublishSummaryMood extends PublishSummaryItem {
  const PublishSummaryMood(this.emoji);

  final String emoji;
}

final class PublishSummaryWeather extends PublishSummaryItem {
  const PublishSummaryWeather({required this.iconCode, required this.text});

  final String? iconCode;
  final String text;
}

/// 第一个已选标签；[more] 为其余已选标签数。
final class PublishSummaryTag extends PublishSummaryItem {
  const PublishSummaryTag({required this.tag, required this.more});

  final Tag tag;
  final int more;
}

/// 第一本所在的日记本；[more] 为其余日记本数。
final class PublishSummaryNotebook extends PublishSummaryItem {
  const PublishSummaryNotebook({required this.notebook, required this.more});

  final NotebookView notebook;
  final int more;
}

final class PublishSummaryPlace extends PublishSummaryItem {
  const PublishSummaryPlace(this.text);

  final String text;
}

/// 把面板草稿压成收起栏的摘要，按“最能说明这篇日记会怎么发”的顺序：
/// 胶囊 → 心情 → 天气 → 标签 → 日记本 → 地点。收起栏很窄，排在后面的项在
/// 空间不足时会被省略号截掉。没有任何元数据时返回空列表，收起栏显示提示语。
///
/// [tags] 是全部标签，用来把已选 id 解析成名称与颜色；已删除的标签不显示。
/// [notebooks] 是书架上的日记本，同样只显示仍存在的（按勾选先后取第一本）。
/// [includeCapsule] 为 false（时间胶囊功能关闭，发布时忽略胶囊）时不列胶囊。
List<PublishSummaryItem> publishPanelSummary(
  DiaryMetaDraft draft,
  List<Tag> tags, {
  List<NotebookView> notebooks = const <NotebookView>[],
  bool includeCapsule = true,
}) {
  final selectedTags = tags
      .where((tag) => draft.tagIds.contains(tag.id))
      .toList(growable: false);
  final selectedNotebooks = publishSelectedNotebooks(draft, notebooks);
  final mood = draft.moodEmoji;
  final weather = draft.weather;
  final location = draft.location;
  return <PublishSummaryItem>[
    if (includeCapsule && draft.capsule != null) const PublishSummaryCapsule(),
    if (mood != null) PublishSummaryMood(mood),
    if (weather != null)
      PublishSummaryWeather(iconCode: draft.weatherIconCode, text: weather),
    if (selectedTags.isNotEmpty)
      PublishSummaryTag(tag: selectedTags.first, more: selectedTags.length - 1),
    if (selectedNotebooks.isNotEmpty)
      PublishSummaryNotebook(
        notebook: selectedNotebooks.first,
        more: selectedNotebooks.length - 1,
      ),
    if (location != null) PublishSummaryPlace(shortPlace(location)),
  ];
}

/// 草稿所选、仍在书架上的日记本，按勾选先后。
List<NotebookView> publishSelectedNotebooks(
  DiaryMetaDraft draft,
  List<NotebookView> notebooks,
) {
  if (draft.notebookIds.isEmpty) return const <NotebookView>[];
  final byId = <String, NotebookView>{
    for (final notebook in notebooks) notebook.id: notebook,
  };
  return <NotebookView>[for (final id in draft.notebookIds) ?byId[id]];
}

/// 地点的短写：自动定位的文案按层级用“ · ”连接（如“北京市 · 望京街道”），
/// 收起栏只取最具体的最后一段；手写地点原样返回。
String shortPlace(String location) {
  final parts = location
      .split('·')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? location.trim() : parts.last;
}
