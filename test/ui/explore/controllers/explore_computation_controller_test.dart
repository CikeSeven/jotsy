import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations_gen_ru.dart';
import 'package:node_diary/ui/explore/controllers/explore_computation_controller.dart';
import 'package:node_diary/ui/explore/models/explore_computation_input.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_module_options.dart';
import 'package:node_diary/ui/explore/viewmodels/explore_entry.dart';

ExploreComputationInput input(
  int count, {
  ExplorePeriod period = ExplorePeriod.all,
  ExploreLayout? layout,
  List<ExploreDiaryOverview>? diaries,
}) {
  final now = DateTime(2026, 11, 7);
  return ExploreComputationInput(
    diaries:
        diaries ??
        List.generate(
          count,
          (i) => ExploreDiaryOverview(
            diaryId: 'diary-$i',
            title: 'title',
            contentText: 'hello 世界',
            metadata: i.isEven ? '{}' : '{broken',
            createdAt: DateTime(2025, 11, 7),
            updatedAt: now,
            tags: const [],
          ),
        ),
    layout: layout ?? ExploreLayout.defaults,
    modules: ExploreModuleId.values.toSet(),
    period: period,
    now: now,
    firstWeekday: DateTime.monday,
    moodOptions: const [],
    l10n: AppLocalizationsRu(),
  );
}

void main() {
  test(
    'appearance, card width and ordering reuse aggregation while data options recompute',
    () {
      final controller = ExploreComputationController();
      addTearDown(controller.dispose);
      final request = input(2);
      final data = controller.resolve(request);
      final layout = request.layout
          .moveModule(0, 2)
          .copyWith(
            showPeriodBar: false,
            appearance: request.layout.appearance.copyWith(radius: 8),
          );
      final restyled = layout.withModule(
        layout
            .module(ExploreModuleId.overview)
            .copyWith(span: ExploreModuleSpan.half),
      );
      expect(
        controller.resolve(
          input(0, diaries: request.diaries, layout: restyled),
        ),
        same(data),
      );
      final changed = restyled.withModule(
        restyled
            .module(ExploreModuleId.onThisDay)
            .withOption(
              ExploreOptions.onThisDayCount,
              ExploreOptions.onThisDayCount.values.first,
            ),
      );
      expect(
        controller.resolve(input(0, diaries: request.diaries, layout: changed)),
        isNot(same(data)),
      );
    },
  );

  test(
    'large libraries compute off isolate with localized dates and corrupt metadata',
    () async {
      final controller = ExploreComputationController();
      addTearDown(controller.dispose);
      final request = input(300);
      final ready = Completer<void>();
      controller.addListener(() => ready.complete());
      expect(controller.resolve(request), isNull);
      await ready.future;
      final data = controller.resolve(request)!;
      expect(data.totalEntries, 300);
      expect(data.greeting!.totalEntries, 300);
      expect(data.onThisDay, isNotEmpty);
      expect(identical(controller.resolve(request), data), isTrue);
      expect(controller.error, isNull);
    },
  );

  test(
    'rapid changes run serially and only publish the latest input',
    () async {
      final jobs =
          <
            (
              ExploreComputationInput,
              ExploreEntryCache,
              Completer<ExploreComputationResult>,
            )
          >[];
      final controller = ExploreComputationController(
        runner: (request, cache) {
          final done = Completer<ExploreComputationResult>();
          jobs.add((request, cache, done));
          return done.future;
        },
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final first = input(300);
      final skipped = input(301);
      final latest = input(302);
      controller.resolve(first);
      controller.resolve(skipped);
      controller.resolve(latest);
      expect(jobs, hasLength(1));
      jobs.first.$3.complete((
        data: first.build(jobs.first.$2),
        cache: jobs.first.$2,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
      expect(jobs, hasLength(2));
      expect(jobs.last.$1, same(latest));
      expect(controller.resolve(latest), isNull);
      jobs.last.$3.complete((
        data: latest.build(jobs.last.$2),
        cache: jobs.last.$2,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(controller.resolve(latest)!.totalEntries, 302);
    },
  );

  test(
    'worker failure can recover on new input and completion after disposal is ignored',
    () async {
      final done = Completer<ExploreComputationResult>();
      final controller = ExploreComputationController(
        runner: (_, _) => done.future,
      );
      final request = input(300);
      controller.resolve(request);
      done.completeError(StateError('worker failed'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.error, isA<StateError>());
      expect(controller.resolve(input(1))!.totalEntries, 1);
      expect(controller.error, isNull);
      controller.dispose();

      final pending = Completer<ExploreComputationResult>();
      final disposed = ExploreComputationController(
        runner: (_, _) => pending.future,
      );
      var notifications = 0;
      disposed.addListener(() => notifications++);
      disposed.resolve(request);
      disposed.dispose();
      final cache = ExploreEntryCache();
      pending.complete((data: request.build(cache), cache: cache));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
    },
  );
}
