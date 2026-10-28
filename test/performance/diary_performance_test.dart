import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/explore/controllers/explore_data_builder.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_presets.dart';
import 'package:node_diary/ui/explore/viewmodels/explore_entry.dart';
import 'package:node_diary/utils/text_stats.dart';

/// 可选的本机微基准：固定合成数据、预热后报告中位数，不以墙钟时间作为门禁。
///
/// flutter test test/performance/diary_performance_test.dart \
///   --dart-define=PERFORMANCE_BENCHMARK=true --reporter expanded
///
/// 内存 SQLite 与测试 VM 的结果仅用于同环境前后比较，不能代替真机 profile。
void main() {
  const enabled = bool.fromEnvironment('PERFORMANCE_BENCHMARK');
  test('reports diary-library query and aggregation costs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 10, 17, 12);
    final body = '今天阳光明媚，hello 世界。\n' * 100;
    final content = jsonEncode([
      {'insert': '$body\n'},
    ]);
    final metadata = jsonEncode({
      'context': {'moodEmoji': '😊', 'energyLevel': 3},
      'other': 'metadata ' * 40,
    });
    await db.batch((batch) {
      batch.insertAll(db.tags, [
        for (var id = 1; id <= 12; id++)
          TagsCompanion.insert(
            id: Value(id),
            name: 'tag-$id',
            color: 0xff448855 + id,
          ),
      ]);
      batch.insertAll(db.diaries, [
        for (var id = 1; id <= 10000; id++)
          DiariesCompanion.insert(
            id: Value(id),
            diaryId: 'benchmark-$id',
            title: Value('Entry ${id % 251}'),
            content: content,
            contentText: id % 71 == 0 ? 'needle $body' : body,
            metadata: Value(metadata),
            cover: id.isEven ? Value('/covers/$id.jpg') : const Value.absent(),
            createdAt: now.subtract(Duration(days: id % 3650)),
            updatedAt: now.subtract(Duration(minutes: id * 7919 % 10000)),
            isPinned: Value(id % 997 == 0),
            isArchived: Value(id % 17 == 0),
            isDeleted: Value(id % 29 == 0),
          ),
      ]);
      batch.insertAll(db.diaryTags, [
        for (var id = 1; id <= 10000; id++)
          for (var tag = 0; tag < 3; tag++)
            DiaryTagsCompanion.insert(diaryId: id, tagId: (id + tag) % 12 + 1),
      ]);
    });

    for (final mode in DiarySortMode.values) {
      await _report('list ${mode.name}, 21 rows / 10000', (iteration) async {
        final rows = await db
            .watchDiaries(limit: 21, offset: iteration, sortMode: mode)
            .first;
        expect(rows, hasLength(21));
        expect(rows.first.tags, hasLength(3));
      });
    }
    await _report('AND tags, 21 rows / 10000', (iteration) async {
      final rows = await db
          .watchDiaries(limit: 21, offset: iteration, requiredTagIds: [1, 2])
          .first;
      expect(rows, hasLength(21));
    });
    await _report('keyword, 21 rows / 10000', (iteration) async {
      final rows = await db
          .watchDiaries(limit: 21, offset: iteration, keyword: 'needle')
          .first;
      expect(rows, hasLength(21));
    });

    final diaries = await db.watchExploreDiaryOverviews().first;
    final l10n = AppLocalizationsEn();
    // 全部卡片都显示时的整页聚合；每轮新建条目缓存，计入首次解析的开销。
    await _report('explore aggregation, ${diaries.length} rows', (_) {
      final data = ExploreDataBuilder.build(
        ExploreDataRequest(
          index: ExploreEntryCache().index(diaries),
          layout: ExplorePreset.everything.applyTo(ExploreLayout.defaults),
          modules: ExploreModuleId.values.toSet(),
          period: ExplorePeriod.all,
          now: now,
          firstWeekday: DateTime.monday,
          moodOptions: SettingsService.defaultMoodOptions,
          l10n: l10n,
        ),
      );
      expect(data.totalEntries, diaries.length);
      expect(data.moodTrend, hasLength(30));
    });

    await _report('word count, mixed ${body.length * 50} UTF-16 units', (_) {
      expect(TextStats.countWords(body * 50), 55000);
    });
    final punctuation = '${'—' * 12000} hello';
    await _report('word count, 12000 shared punctuation marks', (_) {
      expect(TextStats.countWords(punctuation), 1);
    });
  }, skip: !enabled);
}

Future<void> _report(
  String label,
  FutureOr<void> Function(int iteration) action,
) async {
  await action(0);
  final samples = <int>[];
  for (var iteration = 1; iteration <= 7; iteration++) {
    final watch = Stopwatch()..start();
    await action(iteration);
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  stdout.writeln(
    'BENCH $label: ${(samples[samples.length ~/ 2] / 1000).toStringAsFixed(3)} ms',
  );
}
