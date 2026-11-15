import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_snapshot_builder.dart';

import '../../support/fake_home_widget_data.dart';

final DateTime _now = DateTime(2026, 11, 15, 14, 30);

HomeWidgetSnapshotInput _input({
  required List<InstalledHomeWidget> installed,
  bool appLocked = false,
  AppFeatures features = const AppFeatures(),
  HomeWidgetSettings settings = HomeWidgetSettings.empty,
}) => HomeWidgetSnapshotInput(
  now: _now,
  l10n: lookupAppLocalizations(const Locale('zh')),
  appSeed: const Color(0xFF1E6586),
  features: features,
  appLocked: appLocked,
  settings: settings,
  installed: installed,
  kinds: installed.map((widget) => widget.kind).toSet(),
  weekStart: CalendarWeekStart.monday,
);

const List<InstalledHomeWidget> _stats = <InstalledHomeWidget>[
  InstalledHomeWidget(widgetId: 1, kind: HomeWidgetKind.writingStats),
];

const List<InstalledHomeWidget> _photos = <InstalledHomeWidget>[
  InstalledHomeWidget(widgetId: 2, kind: HomeWidgetKind.photoMemories),
];

DiaryCalendarMarker _marker(DateTime at, {int words = 100, DateTime? unlock}) =>
    DiaryCalendarMarker(
      diaryId: 'd-${at.toIso8601String()}',
      createdAt: at,
      wordCount: words,
      capsuleUnlockAt: unlock,
    );

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();

void main() {
  group('writing stats', () {
    test('count the streak, this month and this year', () async {
      final data = FakeHomeWidgetData(
        markers: <DiaryCalendarMarker>[
          // 昨天、前天、大前天连着写；今天还没写，连续没断。
          for (final day in <int>[12, 13, 14])
            _marker(DateTime(2026, 11, day, 21), words: 700),
          _marker(DateTime(2026, 11, 14, 8), words: 50),
          _marker(DateTime(2026, 11, 2, 9), words: 2000),
          _marker(DateTime(2026, 3, 1, 9)),
          _marker(DateTime(2025, 12, 31, 9)),
          // 还没解封的胶囊（今天晚些时候才解封）不算。
          _marker(
            DateTime(2026, 11, 15, 23),
            unlock: DateTime(2026, 11, 15, 23),
          ),
        ],
      );
      final snapshot = await HomeWidgetSnapshotBuilder(
        data,
      ).build(_input(installed: _stats));
      final stats = _map(snapshot['stats']);
      expect(stats['streak'], 3);
      expect(stats['streakEnd'], '2026-11-14');
      expect(stats['month'], '2026-11');
      expect(stats['monthEntries'], '5');
      expect(stats['monthWords'], '4,150');
      expect(stats['year'], 2026);
      expect(stats['yearEntries'], '6');
      final heat = _map(stats['heat']);
      // 53 周，从周一起，到今天（周日）为止。
      expect(heat['start'], '2025-11-10');
      final entries = heat['entries']! as String;
      final words = heat['words']! as String;
      expect(entries.length, 53 * 7);
      expect(words.length, entries.length);
      // 最后一天是今天（没写），往前一天两篇（篇数 2 档）、750 字（字数 3 档）。
      expect(entries.substring(entries.length - 2), '20');
      expect(words.substring(words.length - 2), '30');
    });

    test('a streak longer than the query looks further back', () async {
      final data = FakeHomeWidgetData(
        markers: <DiaryCalendarMarker>[
          for (var i = 0; i < 800; i++) _marker(DateTime(2026, 11, 15 - i, 20)),
        ],
      );
      final snapshot = await HomeWidgetSnapshotBuilder(
        data,
      ).build(_input(installed: _stats));
      expect(_map(snapshot['stats'])['streak'], 800);
    });

    test('stay visible with the app lock on, gone with explore off', () async {
      final data = FakeHomeWidgetData(
        markers: <DiaryCalendarMarker>[_marker(DateTime(2026, 11, 15, 8))],
      );
      final locked = await HomeWidgetSnapshotBuilder(
        data,
      ).build(_input(installed: _stats, appLocked: true));
      expect(_map(locked['stats'])['streak'], 1);
      final off = await HomeWidgetSnapshotBuilder(data).build(
        _input(installed: _stats, features: const AppFeatures(explore: false)),
      );
      expect(off.containsKey('stats'), isFalse);
      expect(_map(_map(off['instances'])['1'])['disabled'], isTrue);
    });
  });

  group('photo memories', () {
    FakeHomeWidgetData data() => FakeHomeWidgetData(
      diaries: [
        fakeWidgetDiary(
          'beach',
          DateTime(2024, 11, 16, 9),
          title: '海边',
          cover: '/fixture/beach.png',
        ),
        fakeWidgetDiary(
          'remote',
          DateTime(2026, 11, 1, 9),
          images: <String>['https://example.com/a.jpg'],
        ),
        fakeWidgetDiary(
          'trip',
          DateTime(2026, 10, 1, 9),
          images: <String>['/fixture/trip.png'],
        ),
        fakeWidgetDiary('text', DateTime(2026, 9, 1, 9), text: '没有照片'),
      ],
      readable: const <String, String>{'nb': '旅行'},
      notebookMembers: const <String, Set<String>>{
        'nb': <String>{'trip'},
      },
    );

    test('keep entries with a local photo, newest first', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        data(),
      ).build(_input(installed: _photos));
      expect(_map(snapshot['photos'])['all'], <String>['trip', 'beach']);
      expect(
        _map(_map(snapshot['diaries'])['trip'])['photo'],
        '/fixture/trip.png',
      );
      // “那年今日”来源按前后 3 天取：后天的海边照片也算。
      final today = _map(
        _map(_map(snapshot['onThisDay'])['days'])['2026-11-15'],
      );
      expect((today['nearby']! as List).single['id'], 'beach');
    });

    test('read a readable notebook, and fall back to all', () async {
      Future<Map<String, Object?>> build(String notebookId) =>
          HomeWidgetSnapshotBuilder(data()).build(
            _input(
              installed: _photos,
              settings: HomeWidgetSettings.empty.withInstance(
                2,
                HomeWidgetInstance(
                  kind: HomeWidgetKind.photoMemories,
                  content: PhotoMemoriesContent(
                    source: PhotoMemorySource.notebook,
                    notebookId: notebookId,
                  ),
                ),
              ),
            ),
          );
      final readable = await build('nb');
      expect(_map(readable['photos'])['notebook:nb'], <String>['trip']);
      expect(
        _map(_map(_map(readable['instances'])['2'])['content'])['source'],
        'notebook:nb',
      );
      final gone = await build('private-one');
      expect(_map(gone['photos']).keys, <String>['all']);
      expect(
        _map(_map(_map(gone['instances'])['2'])['content'])['source'],
        'all',
      );
    });

    test('are not written when the app lock is on', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        data(),
      ).build(_input(installed: _photos, appLocked: true));
      expect(snapshot.containsKey('photos'), isFalse);
      expect(snapshot.containsKey('diaries'), isFalse);
      expect(snapshot.toString(), isNot(contains('/fixture/')));
    });
  });
}
