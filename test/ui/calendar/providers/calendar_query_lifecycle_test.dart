import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';
import 'package:node_diary/utils/provider_retention.dart';

void main() {
  List<StreamProvider<Object?>> queries(DateTime day) => [
    calendarMonthMarkersProvider(day),
    calendarYearMarkersProvider(day.year),
    calendarDayDiariesProvider(day),
    calendarOnThisDayProvider(day),
    calendarMonthInlineImagesProvider(day),
    archivedDiariesProvider,
    deletedDiariesProvider,
  ];

  testWidgets('recent queries stay warm and live queries never expire', (
    tester,
  ) async {
    final db = _EmptyDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final providers = queries(DateTime(2026, 10, 17));
    var subscriptions = [
      for (final provider in providers) container.listen(provider, (_, _) {}),
    ];
    await tester.pump();
    final states = [for (final provider in providers) container.read(provider)];
    for (final subscription in subscriptions) {
      subscription.close();
    }
    await tester.pump(const Duration(seconds: 20));
    subscriptions = [
      for (final provider in providers) container.listen(provider, (_, _) {}),
    ];
    for (var i = 0; i < providers.length; i++) {
      expect(identical(container.read(providers[i]), states[i]), isTrue);
    }
    // 恢复监听后原释放计时器必须取消；活跃页面始终保留其查询。
    await tester.pump(queryIdleRetention * 3);
    for (final provider in providers) {
      expect(container.exists(provider), isTrue);
    }
    for (final subscription in subscriptions) {
      subscription.close();
    }
    await tester.pump(queryIdleRetention);
    for (final provider in providers) {
      expect(container.exists(provider), isFalse);
    }
  });

  testWidgets('visiting many dates releases every idle family instance', (
    tester,
  ) async {
    final db = _EmptyDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final providers = [
      for (var i = 1; i <= 60; i++) ...queries(DateTime(2026, 1, i)),
    ];
    for (final provider in providers) {
      container.listen(provider, (_, _) {}).close();
    }
    await tester.pump();
    expect(providers.every(container.exists), isTrue);
    await tester.pump(queryIdleRetention);
    expect(providers.any(container.exists), isFalse);
  });

  testWidgets('disposing the container cancels idle release timers', (
    tester,
  ) async {
    final db = _EmptyDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    for (final provider in queries(DateTime(2026, 10, 17))) {
      container.listen(provider, (_, _) {}).close();
    }
    container.dispose();
    await tester.pump(queryIdleRetention);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyDatabase extends AppDatabase {
  _EmptyDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Stream<List<DiaryCalendarMarker>> watchDiaryMarkersInRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([]);

  @override
  Stream<List<DiaryWithTags>> watchDiariesCreatedOnDay(DateTime day) =>
      Stream.value([]);

  @override
  Stream<List<DiaryWithTags>> watchDiariesCreatedInRanges(
    List<(DateTime, DateTime)> ranges,
  ) => Stream.value([]);

  @override
  Stream<List<DiaryImageCandidate>> watchDiaryImageCandidatesInRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([]);

  @override
  Stream<List<DiaryWithTags>> watchArchivedDiaries() => Stream.value([]);

  @override
  Stream<List<DiaryWithTags>> watchDeletedDiaries() => Stream.value([]);
}
