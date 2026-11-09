// 日记的只读工具：搜索、读全文、统计。
//
// 隐私口径（与“与日记对话”相同）：
// - 多篇只经 `getAiContextDiaries`：总是排除私密日记、回收站、未解封的时间
//   胶囊，并叠加 AI 隐私里排除的日记本与标签；
// - 读全文时私密日记一律不给（智能体可以连续调用工具，比单篇功能更严：
//   “允许对私密日记使用 AI”只放开写作、回应这类单篇功能），排除的本子与
//   标签同样不给；
// - 日期、心情、标签、天气、地点按 AI 隐私里的“发送”开关决定给不给；
// - 摘录与正文的字数从本轮的“最多发送”预算里扣，用完了只给标题与日期。

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/ai/ai_vision.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../explore/controllers/explore_stats_builder.dart';
import '../../explore/viewmodels/explore_entry.dart';
import '../../notebooks/models/notebook_scope_resolver.dart';
import '../viewmodels/ai_context_budget.dart';
import '../viewmodels/ai_recap_material.dart';
import '../viewmodels/ai_retrieval.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tools_images.dart';

/// 搜索结果每篇的摘录上限（字）。
const int _excerptWords = 60;

/// 按关键词、日期、标签、心情、日记本查日记，返回编号、日期、标题与摘录。
class SearchDiariesTool extends AiTool {
  const SearchDiariesTool();

  @override
  String get name => 'search_diaries';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Find diary entries. Keywords match title or body (any keyword); '
      'dates are inclusive; tags must all match. Returns each entry with a '
      'reference like D3, its id, date, title, a short excerpt and `photos` '
      '(how many photos it has; entries without it have none); use '
      'read_diaries for full text. Private entries are never returned. '
      'Cite entries in your answer as [D3].';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'query': AiStringSchema(description: 'Keywords separated by spaces.'),
      'from': AiDateSchema(description: 'First day, YYYY-MM-DD.'),
      'to': AiDateSchema(description: 'Last day, YYYY-MM-DD.'),
      'tags': AiArraySchema(
        items: AiStringSchema(),
        maxItems: 10,
        description: 'Tag names.',
      ),
      'mood': AiStringSchema(
        description: "One of the user's mood options (an emoji).",
      ),
      'notebook_id': AiStringSchema(),
      'include_archived': AiBooleanSchema(),
      'sort': AiStringSchema(
        enumValues: <String>['relevant', 'newest', 'oldest'],
      ),
      'limit': AiIntegerSchema(minimum: 1, maximum: 50),
    },
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final query = args['query'];
    return query is String && query.trim().isNotEmpty
        ? l10n.aiToolSearchDiariesFor(query.trim())
        : l10n.aiToolSearchDiaries;
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final keywords = _keywords(args['query'] as String?);
    final mood = (args['mood'] as String?)?.trim();
    final diaries = await _query(context, args, keywords: keywords, limit: 400);
    final filtered = [
      for (final diary in diaries)
        if (mood == null || diary.mood?.trim() == mood) diary,
    ];
    final sort =
        args['sort'] as String? ?? (keywords.isEmpty ? 'newest' : 'relevant');
    final ordered = switch (sort) {
      'relevant' => aiRankDiaries(filtered, keywords, now: context.now),
      'oldest' => [
        ...filtered,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      _ => [...filtered]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    };
    final limit = args['limit'] as int? ?? 20;
    final picked = ordered.take(limit).toList();
    final photos = await aiDiaryPhotoCounts(context, [
      for (final diary in picked) diary.diaryId,
    ]);
    final notebook = await aiNotebookParamSubject(context, args['notebook_id']);
    return AiToolOutcome(
      data: <String, Object?>{
        'matched': filtered.length,
        if (diaries.length >= 400) 'matched_is_lower_bound': true,
        'returned': picked.length,
        'diaries': [
          for (final diary in picked)
            _summaryItem(
              context,
              diary,
              keywords,
              photos: photos[diary.diaryId] ?? 0,
            ),
        ],
        if (photos.isNotEmpty) 'photos_hint': aiPhotosHint(context),
        if (picked.isEmpty)
          'hint':
              'Nothing matched. Try fewer or different keywords, a wider '
              'date range, or no filters.',
      },
      summary: context.l10n.aiToolFoundEntries(filtered.length),
      subjects: [
        ?notebook,
        ...aiTagParamSubjects(args['tags']),
        for (final diary in picked) aiContextDiarySubject(diary),
      ],
    );
  }

  static List<String> _keywords(String? query) {
    if (query == null) return const <String>[];
    final parts = query
        .split(RegExp(r'[\s,，、;；]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList();
    // 模型偶尔把整句话塞进来：那就按本地规则抽关键词。
    if (parts.length == 1 && parts.single.length > 12) {
      return aiQueryKeywords(parts.single);
    }
    return parts.take(16).toList();
  }

  Map<String, Object?> _summaryItem(
    AiToolContext context,
    AiContextDiary diary,
    List<String> keywords, {
    required int photos,
  }) {
    final excerpt = _excerpt(diary.contentText, keywords);
    final granted = context.allowance.take(TextStats.countWords(excerpt));
    return <String, Object?>{
      ...aiDiaryToolHeader(context, diary, photos: photos),
      'words': TextStats.countWords(diary.contentText),
      if (granted > 0) 'excerpt': aiTruncateWords(excerpt, granted),
    };
  }

  /// 有关键词时取第一个命中处附近，否则取开头。
  static String _excerpt(String text, List<String> keywords) {
    final body = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    var start = 0;
    for (final keyword in keywords) {
      final index = body.toLowerCase().indexOf(keyword.toLowerCase());
      if (index >= 0) {
        start = index > 20 ? index - 20 : 0;
        break;
      }
    }
    final excerpt = aiTruncateWords(body.substring(start), _excerptWords);
    return start > 0 ? '…$excerpt' : excerpt;
  }
}

/// 按 id 读日记全文（一次最多 10 篇）。
class ReadDiariesTool extends AiTool {
  const ReadDiariesTool();

  @override
  String get name => 'read_diaries';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Read the full text of diary entries by id or reference like D3 (from '
      'search_diaries). Photos are marked in the text as [Photo n]; use '
      'view_images to look at them. Long entries may be cut when the '
      'per-turn text budget runs out.';

  @override
  Set<String> get diaryIdArgs => const <String>{'ids'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 10),
    },
    required: <String>['ids'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolReadDiaries(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final ids = (args['ids']! as List).cast<String>().toSet();
    final results = <Map<String, Object?>>[];
    final subjects = <AiToolSubject>[];
    var read = 0;
    var photos = false;
    for (final id in ids) {
      // 读得到才给：口径见 aiAgentReadDiary（找不到时不断言“在回收站 /
      // 是时间胶囊”，先提示换成查询结果里的 id 或编号）。
      final access = await aiAgentReadDiary(
        context.container,
        prefs: context.prefs,
        id: id,
        now: context.now,
      );
      final found = access.diary;
      if (found == null) {
        results.add(<String, Object?>{'id': id, 'error': access.refusal});
        continue;
      }
      // 正文里的图片写成“[图片 n]”，编号与 view_images 相同。
      final diary = aiDiaryWithText(
        found,
        aiDiaryTextWithImageMarks(context.kit.l10n, found),
      );
      final photoCount = AiVisionImages.sourcesOf(
        found.contentJson ?? '',
      ).length;
      if (photoCount > 0) photos = true;
      final words =
          TextStats.countWords(diary.contentText) +
          TextStats.countWords(diary.title);
      final granted = context.allowance.take(words);
      if (granted <= 0) {
        results.add(<String, Object?>{
          ...aiDiaryToolHeader(context, diary, photos: photoCount),
          'error':
              'The diary text budget for this turn is used up; the body was '
              'not sent. Answer with what you have.',
        });
        continue;
      }
      final ref = _ref(context, diary);
      results.add(<String, Object?>{
        'id': id,
        'ref': ref,
        'text': context.kit.diary(
          diary,
          ref: '[$ref]',
          maxWords: granted < words ? granted : null,
        ),
        if (photoCount > 0) 'photos': photoCount,
      });
      subjects.add(aiContextDiarySubject(diary));
      read++;
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'diaries': results,
        if (photos) 'photos_hint': aiPhotosHint(context),
      },
      summary: context.l10n.aiToolReadEntries(read),
      subjects: subjects,
    );
  }
}

/// 统计一段时间（可限定日记本、标签）的篇数、字数、心情、标签与连续天数。
class DiaryStatsTool extends AiTool {
  const DiaryStatsTool();

  @override
  String get name => 'diary_stats';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Count diary entries and words for a period (all time if no dates), '
      'with top moods, top tags, days written and streaks, optionally '
      'grouped by day, week, month or year. Archived entries count; '
      'private entries, the recycle bin and sealed time capsules do not.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'from': AiDateSchema(description: 'First day, YYYY-MM-DD.'),
      'to': AiDateSchema(description: 'Last day, YYYY-MM-DD.'),
      'tags': AiArraySchema(items: AiStringSchema(), maxItems: 10),
      'notebook_id': AiStringSchema(),
      'group_by': AiStringSchema(
        enumValues: <String>['none', 'day', 'week', 'month', 'year'],
      ),
    },
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDiaryStats;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final diaries = await _query(
      context,
      args,
      includeArchived: true,
      keywords: const <String>[],
    );
    final privacy = context.prefs.privacy;
    final stats = AiRecapStats.of(diaries);
    final days = <DateTime>{
      for (final diary in diaries)
        DateTime(
          diary.createdAt.year,
          diary.createdAt.month,
          diary.createdAt.day,
        ),
    };
    final to = args['to'] as DateTime?;
    final groupBy = args['group_by'] as String? ?? 'none';
    final groups = <String, ({int entries, int words})>{};
    if (groupBy != 'none') {
      for (final diary in diaries) {
        final key = _periodKey(diary.createdAt, groupBy);
        final previous = groups[key] ?? (entries: 0, words: 0);
        groups[key] = (
          entries: previous.entries + 1,
          words: previous.words + TextStats.countWords(diary.contentText),
        );
      }
    }
    final ordered = groups.keys.toList()..sort();
    final notebook = await aiNotebookParamSubject(context, args['notebook_id']);
    return AiToolOutcome(
      data: <String, Object?>{
        'entries': stats.entries,
        'words': stats.words,
        'days_written': days.length,
        'longest_streak_days': ExploreStatsBuilder.longestStreak(days),
        if (to == null || !to.isBefore(context.today))
          'current_streak_days': ExploreStatsBuilder.currentStreak({
            for (final day in days) exploreDayKey(day),
          }, context.now),
        if (privacy.sendMood)
          'top_moods': [
            for (final (mood, count) in stats.moods)
              <String, Object?>{'mood': mood, 'count': count},
          ],
        if (privacy.sendTags)
          'top_tags': [
            for (final (tag, count) in stats.tags)
              <String, Object?>{'tag': tag, 'count': count},
          ],
        if (ordered.isNotEmpty)
          'groups': [
            for (final key in ordered.take(400))
              <String, Object?>{
                'period': key,
                'entries': groups[key]!.entries,
                'words': groups[key]!.words,
              },
          ],
      },
      summary: context.l10n.aiToolStatsEntries(stats.entries),
      subjects: [?notebook, ...aiTagParamSubjects(args['tags'])],
    );
  }

  static String _periodKey(DateTime time, String groupBy) {
    String two(int value) => value.toString().padLeft(2, '0');
    switch (groupBy) {
      case 'day':
        return aiToolDate(time);
      case 'week':
        // 以周一开头的那一周，用周一的日期表示。
        final monday = DateTime(
          time.year,
          time.month,
          time.day - (time.weekday - 1),
        );
        return 'week of ${aiToolDate(monday)}';
      case 'year':
        return '${time.year}';
      default:
        return '${time.year}-${two(time.month)}';
    }
  }
}

/// 日记的头部信息：编号、id、日期、按隐私开关给出的元数据，以及图片张数
/// （[photos]，有图片时才写）。
Map<String, Object?> aiDiaryToolHeader(
  AiToolContext context,
  AiContextDiary diary, {
  int photos = 0,
}) {
  final privacy = context.prefs.privacy;
  return <String, Object?>{
    'ref': _ref(context, diary),
    'id': diary.diaryId,
    if (privacy.sendDate) 'date': aiToolDateTime(diary.createdAt),
    if (diary.title.trim().isNotEmpty) 'title': diary.title.trim(),
    if (privacy.sendMood && diary.mood != null) 'mood': diary.mood,
    if (privacy.sendTags && diary.tags.isNotEmpty) 'tags': diary.tags,
    if (privacy.sendWeather && diary.weather != null) 'weather': diary.weather,
    if (privacy.sendLocation && diary.location != null)
      'location': diary.location,
    if (diary.isArchived) 'archived': true,
    if (photos > 0) 'photos': photos,
  };
}

String _ref(AiToolContext context, AiContextDiary diary) => context.citations
    .refFor(diary.diaryId, title: diary.title, date: diary.createdAt);

/// 按工具参数查日记（统一经 `getAiContextDiaries`）。
Future<List<AiContextDiary>> _query(
  AiToolContext context,
  Map<String, Object?> args, {
  required List<String> keywords,
  bool? includeArchived,
  int? limit,
}) async {
  final database = context.database;
  final privacy = context.prefs.privacy;
  final from = args['from'] as DateTime?;
  final to = args['to'] as DateTime?;
  if (from != null && to != null && to.isBefore(from)) {
    throw const AiToolFailure('`to` must not be before `from`.');
  }
  final tagNames = (args['tags'] as List?)?.cast<String>() ?? const <String>[];
  final tagIds = <int>[];
  if (tagNames.isNotEmpty) {
    final tags = await database.watchAllTags().first;
    for (final name in tagNames) {
      final match = tags.where(
        (tag) => tag.name.toLowerCase() == name.trim().toLowerCase(),
      );
      if (match.isEmpty) {
        throw AiToolFailure(
          'No tag named "$name". Call list_tags to see the tags.',
        );
      }
      tagIds.add(match.first.id);
    }
  }
  var scope = DiaryListScope.all;
  final notebookId = args['notebook_id'] as String?;
  if (notebookId != null) {
    final tree = await context.notebookTree();
    final notebook = tree[notebookId];
    if (notebook == null ||
        notebook.isPrivate ||
        privacy.excludedNotebookIds.contains(notebookId)) {
      throw const AiToolFailure(
        'No such notebook. Call list_notebooks to see the notebooks.',
      );
    }
    scope = notebookStatsScope(notebook, tree: tree);
  }
  return database.getAiContextDiaries(
    start: from,
    end: to == null ? null : DateTime(to.year, to.month, to.day + 1),
    scope: scope,
    requiredTagIds: tagIds,
    keywords: keywords,
    excludedNotebookIds: privacy.excludedNotebookIds,
    excludedTagNames: privacy.excludedTagNames,
    includeArchived:
        includeArchived ??
        args['include_archived'] as bool? ??
        privacy.includeArchived,
    newestFirst: true,
    limit: limit,
    now: context.now,
  );
}
