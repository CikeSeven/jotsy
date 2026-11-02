// 回顾的材料（纯函数，不碰数据库与网络）。
//
// - [AiRecapStats]：本地先算好的篇数、字数、心情分布与常用标签，既作为
//   结构化上下文发给模型，也显示在结果顶部；
// - [aiPlanRecap]：按字数预算决定一次写完还是“先分块总结、再汇总”。日记
//   按时间顺序编号 `[D1]…`（全局编号，分块总结里保留编号，汇总时仍能
//   引用）；篇数多到分块也装不下时按比例压低每篇的字数，最多
//   [kAiRecapMaxChunks] 块；
// - [aiRecapChunkRequest] / [aiRecapRequest]：两步各自的请求。

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../utils/text_stats.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import 'ai_context_budget.dart';
import 'ai_labels.dart';
import 'ai_prompt_builder.dart';

/// 分块总结最多几块（再多就压低每篇的字数）。
const int kAiRecapMaxChunks = 16;

/// 一段时间的本地统计。
@immutable
class AiRecapStats {
  const AiRecapStats({
    required this.entries,
    required this.words,
    this.moods = const <(String, int)>[],
    this.tags = const <(String, int)>[],
  });

  factory AiRecapStats.of(List<AiContextDiary> diaries) {
    var words = 0;
    final moods = <String, int>{};
    final tags = <String, int>{};
    for (final diary in diaries) {
      words += TextStats.countWords(diary.contentText);
      final mood = diary.mood?.trim();
      if (mood != null && mood.isNotEmpty) {
        moods[mood] = (moods[mood] ?? 0) + 1;
      }
      for (final tag in diary.tags) {
        tags[tag] = (tags[tag] ?? 0) + 1;
      }
    }
    List<(String, int)> ranked(Map<String, int> counts, int max) {
      final entries = counts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : a.key.compareTo(b.key);
        });
      return [for (final entry in entries.take(max)) (entry.key, entry.value)];
    }

    return AiRecapStats(
      entries: diaries.length,
      words: words,
      moods: ranked(moods, 8),
      tags: ranked(tags, 8),
    );
  }

  /// 篇数。
  final int entries;
  final int words;

  /// 心情（emoji 原文）与篇数，多 → 少。
  final List<(String, int)> moods;

  /// 标签名与篇数，多 → 少。
  final List<(String, int)> tags;

  Map<String, Object?> toJson() => <String, Object?>{
    'entries': entries,
    'words': words,
    if (moods.isNotEmpty)
      'moods': [
        for (final (m, c) in moods) <Object>[m, c],
      ],
    if (tags.isNotEmpty)
      'tags': [
        for (final (t, c) in tags) <Object>[t, c],
      ],
  };

  static AiRecapStats? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final entries = raw['entries'];
    final words = raw['words'];
    if (entries is! int || words is! int) return null;
    List<(String, int)> pairs(Object? list) => [
      if (list is List)
        for (final item in list)
          if (item is List &&
              item.length == 2 &&
              item[0] is String &&
              item[1] is int)
            (item[0] as String, item[1] as int),
    ];
    return AiRecapStats(
      entries: entries,
      words: words,
      moods: pairs(raw['moods']),
      tags: pairs(raw['tags']),
    );
  }
}

/// 回顾怎么写：所有编号过的日记与按块的划分（只有一块即一次写完）。
@immutable
class AiRecapPlan {
  const AiRecapPlan({required this.diaries, required this.chunks});

  /// 全部放进上下文的日记（按时间顺序，编号连续）。
  final List<AiBudgetedDiary> diaries;
  final List<List<AiBudgetedDiary>> chunks;

  bool get chunked => chunks.length > 1;

  /// 发送的总字数（确认面板用）。
  int get words => diaries.fold<int>(0, (sum, d) => sum + d.maxWords);
}

/// 规划回顾：[diaries] 按时间旧 → 新。每篇最多 [perDiary] 字；总数不超过
/// [budget] 时一块，否则按顺序切成每块不超过 [budget] 的若干块。
AiRecapPlan aiPlanRecap(
  List<AiContextDiary> diaries, {
  required int budget,
  required int perDiary,
  int maxChunks = kAiRecapMaxChunks,
}) {
  final safeBudget = budget < 200 ? 200 : budget;
  final allowed = <int>[
    for (final diary in diaries)
      _min(
        TextStats.countWords(diary.contentText) +
            TextStats.countWords(diary.title),
        perDiary,
      ),
  ];
  final total = allowed.fold<int>(0, (sum, value) => sum + value);
  final capacity = safeBudget * maxChunks;
  if (total > capacity) {
    // 篇数太多：按比例压低每篇，至少留 40 字（一两句话）。
    final factor = capacity / total;
    for (var i = 0; i < allowed.length; i++) {
      final scaled = (allowed[i] * factor).floor();
      allowed[i] = _min(allowed[i], scaled < 40 ? 40 : scaled);
    }
  }
  final numbered = <AiBudgetedDiary>[
    for (var i = 0; i < diaries.length; i++)
      if (allowed[i] > 0)
        AiBudgetedDiary(
          diary: diaries[i],
          ref: 'D${i + 1}',
          maxWords: allowed[i],
        ),
  ];
  final chunks = <List<AiBudgetedDiary>>[];
  var current = <AiBudgetedDiary>[];
  var used = 0;
  for (final diary in numbered) {
    if (current.isNotEmpty && used + diary.maxWords > safeBudget) {
      chunks.add(current);
      current = <AiBudgetedDiary>[];
      used = 0;
    }
    current.add(diary);
    used += diary.maxWords;
  }
  if (current.isNotEmpty) chunks.add(current);
  return AiRecapPlan(diaries: numbered, chunks: chunks);
}

int _min(int a, int b) => a < b ? a : b;

String _diaries(AiPromptKit kit, List<AiBudgetedDiary> diaries) => [
  for (final item in diaries)
    kit.diary(item.diary, ref: item.marker, maxWords: item.maxWords),
].join('\n\n---\n\n');

/// 分块总结：把一块日记概括成要点（保留日期、细节与 `[Dn]` 编号）。
AiRequest aiRecapChunkRequest(AiPromptKit kit, List<AiBudgetedDiary> chunk) {
  final l10n = kit.l10n;
  return AiRequest(
    model: '',
    system: kit.system(),
    temperature: kit.temperature(AiTaskKind.utility),
    maxOutputTokens: 1500,
    messages: [
      AiMessage.text(
        AiRole.user,
        '${l10n.aiPromptRecapChunk}\n${l10n.aiPromptRecapRules}\n\n'
        '${_diaries(kit, chunk)}',
      ),
    ],
  );
}

/// 最终的回顾：给出这段时间的说法、要写的部分、本地统计，以及日记原文
/// （一次写完）或分块摘要（[summaries]，按时间先后）。
AiRequest aiRecapRequest(
  AiPromptKit kit, {
  required String period,
  required List<AiRecapSection> sections,
  required AiRecapStats stats,
  required AiPersonaInfo persona,
  List<AiBudgetedDiary> diaries = const <AiBudgetedDiary>[],
  List<String> summaries = const <String>[],
}) {
  final l10n = kit.l10n;
  final parts = <String>[
    [
      l10n.aiPromptRecapInstruction(period),
      for (final section in sections) '- ${aiRecapSectionLabel(l10n, section)}',
    ].join('\n'),
    l10n.aiPromptRecapRules,
    [
      l10n.aiPromptRecapStats(stats.entries, stats.words),
      if (stats.moods.isNotEmpty)
        l10n.aiPromptRecapMoods(
          [for (final (mood, count) in stats.moods) '$mood×$count'].join(', '),
        ),
      if (stats.tags.isNotEmpty)
        l10n.aiPromptRecapTopTags(
          [for (final (tag, count) in stats.tags) '$tag×$count'].join(', '),
        ),
    ].join('\n'),
    if (summaries.isNotEmpty) ...[
      l10n.aiPromptRecapFromSummaries,
      [
        for (var i = 0; i < summaries.length; i++)
          '### ${i + 1}\n${summaries[i].trim()}',
      ].join('\n\n'),
    ] else
      _diaries(kit, diaries),
  ];
  return AiRequest(
    model: '',
    system: kit.system(persona: persona, withLength: true),
    temperature: kit.temperature(AiTaskKind.recap),
    messages: [AiMessage.text(AiRole.user, parts.join('\n\n'))],
  );
}
