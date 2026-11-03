import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_recap_range.dart';
import 'package:node_diary/ui/ai/pages/ai_recap_page.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_citations.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_labels.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_recap_material.dart';

AiContextDiary _diary(
  int day, {
  String text = '今天写了一些字',
  String? mood,
  List<String> tags = const <String>[],
}) => AiContextDiary(
  diaryId: 'd$day',
  title: '',
  contentText: text,
  createdAt: DateTime(2026, 3, day, 9),
  isArchived: false,
  mood: mood,
  tags: tags,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  group('AiRecapRange', () {
    // 2026-11-04 是星期三。
    final now = DateTime(2026, 11, 4, 15, 30);

    test('weeks start on the configured weekday', () {
      final monday = AiRecapRange.preset(AiRecapPreset.thisWeek, now: now);
      expect(monday.start, DateTime(2026, 11, 2));
      expect(monday.end, DateTime(2026, 11, 9));
      final sunday = AiRecapRange.preset(
        AiRecapPreset.thisWeek,
        now: now,
        firstWeekday: DateTime.sunday,
      );
      expect(sunday.start, DateTime(2026, 11, 1));
      final last = AiRecapRange.preset(AiRecapPreset.lastWeek, now: now);
      expect(last.start, DateTime(2026, 10, 26));
      expect(last.end, DateTime(2026, 11, 2));
    });

    test('months and years are calendar periods, across year ends', () {
      final january = DateTime(2026, 1, 10);
      final lastMonth = AiRecapRange.preset(
        AiRecapPreset.lastMonth,
        now: january,
      );
      expect(lastMonth.start, DateTime(2025, 12));
      expect(lastMonth.end, DateTime(2026, 1));
      final year = AiRecapRange.preset(AiRecapPreset.thisYear, now: now);
      expect(year.start, DateTime(2026));
      expect(year.end, DateTime(2027));
      expect(year.dayCount, 365);
    });

    test('custom ranges include both days in either order', () {
      final range = AiRecapRange.days(
        DateTime(2026, 3, 9, 20),
        DateTime(2026, 3, 1),
      );
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 3, 10));
      expect(range.lastDay, DateTime(2026, 3, 9));
      expect(range.dayCount, 9);
    });

    test('range text collapses the year and single days', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(
        aiRecapRangeText(
          l10n,
          AiRecapRange.days(DateTime(2026, 3, 1), DateTime(2026, 3, 9)),
        ),
        '2026年3月1日 – 3月9日',
      );
      expect(
        aiRecapRangeText(
          l10n,
          AiRecapRange.days(DateTime(2026, 3, 1), DateTime(2026, 3, 1)),
        ),
        '2026年3月1日',
      );
    });

    test('scope round-trips and tolerates junk', () {
      const scope = AiRecapScope.notebook(notebookId: 'nb', notebookName: '旅行');
      final decoded = AiRecapScope.decode(
        scope.encode(AiRecapPreset.lastMonth),
      );
      expect(decoded.scope.notebookId, 'nb');
      expect(decoded.scope.notebookName, '旅行');
      expect(decoded.preset, AiRecapPreset.lastMonth);
      final junk = AiRecapScope.decode('not json');
      expect(junk.scope.isAll, isTrue);
      expect(junk.preset, isNull);
    });
  });

  group('recap material', () {
    test('stats count entries, words, moods and tags', () {
      final stats = AiRecapStats.of(<AiContextDiary>[
        _diary(1, text: '一二三', mood: '😊', tags: ['工作']),
        _diary(2, text: '四五', mood: '😊', tags: ['工作', '跑步']),
        _diary(3, text: 'hello world', mood: '😢'),
      ]);
      expect(stats.entries, 3);
      expect(stats.words, 7);
      expect(stats.moods.first, ('😊', 2));
      expect(stats.tags.first, ('工作', 2));
      final again = AiRecapStats.fromJson(stats.toJson())!;
      expect(again.moods, stats.moods);
      expect(again.tags, stats.tags);
    });

    test('everything fits: one chunk, numbered in time order', () {
      final plan = aiPlanRecap([_diary(1), _diary(2), _diary(3)], budget: 1000);
      expect(plan.chunked, isFalse);
      expect([for (final d in plan.diaries) d.ref], ['D1', 'D2', 'D3']);
    });

    test('long entries go in whole when the budget allows', () {
      final plan = aiPlanRecap([
        _diary(1, text: '字' * 9000),
        _diary(2, text: '字' * 6000),
      ], budget: 100000);
      expect(plan.chunked, isFalse);
      expect(plan.diaries.map((d) => d.maxWords), [9000, 6000]);
    });

    test('too much: chunks stay within the budget, numbering is global', () {
      final long = '字' * 300;
      final diaries = [for (var i = 1; i <= 6; i++) _diary(i, text: long)];
      final plan = aiPlanRecap(diaries, budget: 700);
      expect(plan.chunked, isTrue);
      expect(plan.chunks, hasLength(3));
      for (final chunk in plan.chunks) {
        expect(
          chunk.fold<int>(0, (s, d) => s + d.maxWords),
          lessThanOrEqualTo(700),
        );
      }
      expect(plan.chunks.last.last.ref, 'D6');
    });

    test('far too much: diaries shrink so the chunk count is capped', () {
      final long = '字' * 2000;
      final diaries = [for (var i = 1; i <= 28; i++) _diary(i, text: long)];
      final plan = aiPlanRecap(diaries, budget: 1000, maxChunks: 4);
      expect(plan.chunks.length, lessThanOrEqualTo(4));
      expect(plan.diaries, hasLength(28));
      expect(plan.diaries.first.maxWords, lessThan(2000));
    });

    test('whole-diary packing respects the exact chunk cap', () {
      final diaries = [
        for (var i = 1; i <= 50; i++) _diary(i, text: '字' * 3500),
      ];
      final plan = aiPlanRecap(diaries, budget: 8000);
      expect(plan.chunks.length, lessThanOrEqualTo(16));
      expect(plan.diaries, hasLength(50));
      expect(plan.diaries.last.ref, 'D50');
      for (final chunk in plan.chunks) {
        expect(
          chunk.fold<int>(0, (sum, d) => sum + d.maxWords),
          lessThanOrEqualTo(8000),
        );
      }
    });

    test(
      'extreme entry counts still respect both caps and span the period',
      () {
        final diaries = [
          for (var i = 1; i <= 501; i++) _diary(i, text: '字' * 80),
        ];
        final plan = aiPlanRecap(diaries, budget: 200, maxChunks: 2);
        expect(plan.chunks, hasLength(2));
        expect(plan.diaries.length, lessThanOrEqualTo(400));
        expect(plan.diaries.first.diary.diaryId, 'd1');
        expect(plan.diaries.last.diary.diaryId, 'd501');
        for (final chunk in plan.chunks) {
          expect(
            chunk.fold<int>(0, (sum, d) => sum + d.maxWords),
            lessThanOrEqualTo(200),
          );
        }
      },
    );

    test('a diary larger than the budget fits in a single allowed chunk', () {
      final plan = aiPlanRecap(
        [_diary(1, text: '字' * 1000)],
        budget: 200,
        maxChunks: 1,
      );
      expect(plan.chunks, hasLength(1));
      expect(plan.words, 200);
    });

    test('outbound stats obey mood and tag privacy independently', () {
      final stats = AiRecapStats.of([
        _diary(1, mood: '😊', tags: ['私密标签']),
      ]);
      for (final sendMood in [false, true]) {
        for (final sendTags in [false, true]) {
          final prefs = AiPreferences.defaults.copyWith(
            privacy: AiPreferences.defaults.privacy.copyWith(
              sendMood: sendMood,
              sendTags: sendTags,
            ),
          );
          final kit = AiPromptKit.resolve(
            prefs: prefs,
            appLocale: const Locale('zh'),
          );
          for (final summaries in [
            <String>[],
            ['摘要'],
          ]) {
            final request = aiRecapRequest(
              kit,
              period: '本周',
              sections: [AiRecapSection.mood],
              stats: stats,
              persona: aiPersonaFor(kit.l10n, prefs, AiPersonaUse.recap),
              summaries: summaries,
            );
            expect(request.messages.single.text.contains('😊'), sendMood);
            expect(request.messages.single.text.contains('私密标签'), sendTags);
          }
        }
      }
      // 发送过滤不能删去本地展示与已保存结果的完整统计。
      expect(stats.moods, [('😊', 1)]);
      expect(stats.tags, [('私密标签', 1)]);
    });

    test(
      'the final request lists sections, stats and either text or summaries',
      () {
        final kit = AiPromptKit.resolve(
          prefs: AiPreferences.defaults,
          appLocale: const Locale('zh'),
        );
        final l10n = kit.l10n;
        final persona = aiPersonaFor(
          l10n,
          AiPreferences.defaults,
          AiPersonaUse.recap,
        );
        final stats = AiRecapStats.of([_diary(1, mood: '😊')]);
        final plan = aiPlanRecap([_diary(1, text: '去了海边')], budget: 1000);
        final direct = aiRecapRequest(
          kit,
          period: '本周',
          sections: [AiRecapSection.mood, AiRecapSection.growth],
          stats: stats,
          persona: persona,
          diaries: plan.diaries,
        );
        final text = (direct.messages.single.parts.single as AiTextPart).text;
        expect(text, contains(l10n.aiPromptRecapInstruction('本周')));
        expect(text, contains('- ${l10n.aiRecapSectionGrowth}'));
        expect(text, isNot(contains('- ${l10n.aiRecapSectionGratitude}')));
        expect(text, contains(l10n.aiPromptRecapStats(1, stats.words)));
        expect(text, contains('[D1]'));
        expect(text, contains('去了海边'));

        final merged = aiRecapRequest(
          kit,
          period: '本周',
          sections: [AiRecapSection.mood],
          stats: stats,
          persona: persona,
          summaries: ['第一段摘要', '第二段摘要'],
        );
        final mergedText =
            (merged.messages.single.parts.single as AiTextPart).text;
        expect(mergedText, contains(l10n.aiPromptRecapFromSummaries));
        expect(mergedText, contains('### 2\n第二段摘要'));
        expect(mergedText, isNot(contains('去了海边')));
      },
    );
  });

  group('citations', () {
    test('grouped refs are split, collected in order and stripped', () {
      const text = '周一很累 [D2, D5]，周三好多了[D1]。又提到 [D2]。';
      expect(aiCitedRefs(text), ['D2', 'D5', 'D1']);
      expect(aiNormalizeCitations(text), contains('[D2][D5]'));
      expect(aiStripCitations(text), '周一很累，周三好多了。又提到。');
    });

    test('excerpts drop markdown marks and citations', () {
      expect(aiRecapExcerpt('## 心情\n- **整体**平稳 [D1]\n> 一句话'), '心情 整体平稳 一句话');
    });
  });
}
