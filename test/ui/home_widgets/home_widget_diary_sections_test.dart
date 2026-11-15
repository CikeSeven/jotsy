import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_diary_sections.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_snapshot_builder.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_today_section.dart';

import '../../support/fake_home_widget_data.dart';

final DateTime _now = DateTime(2026, 11, 15, 14, 30);

HomeWidgetSnapshotInput _input({
  bool appLocked = false,
  AppFeatures features = const AppFeatures(),
  HomeWidgetSettings settings = HomeWidgetSettings.empty,
  List<InstalledHomeWidget> installed = const <InstalledHomeWidget>[
    InstalledHomeWidget(widgetId: 1, kind: HomeWidgetKind.onThisDay),
    InstalledHomeWidget(widgetId: 2, kind: HomeWidgetKind.recentDiaries),
  ],
  List<HomeWidgetContent> previewContents = const <HomeWidgetContent>[],
}) => HomeWidgetSnapshotInput(
  now: _now,
  l10n: lookupAppLocalizations(const Locale('zh')),
  appSeed: const Color(0xFF1E6586),
  features: features,
  appLocked: appLocked,
  settings: settings,
  installed: installed,
  kinds: installed.map((widget) => widget.kind).toSet(),
  previewContents: previewContents,
);

FakeHomeWidgetData _data() => FakeHomeWidgetData(
  diaries: [
    fakeWidgetDiary(
      'sea',
      DateTime(2023, 11, 15, 20),
      title: '第一次去海边',
      text: '风很大。\n浪一层一层地扑过来。',
      cover: '/fixture/sea.jpg',
      mood: '😊',
    ),
    fakeWidgetDiary(
      'start',
      DateTime(2021, 11, 15, 9),
      text: '今天开始写日记。',
      images: <String>['https://example.com/remote.jpg', '/fixture/desk.jpg'],
    ),
    fakeWidgetDiary('ginkgo', DateTime(2024, 11, 17, 8), title: '银杏'),
    fakeWidgetDiary('this-year', DateTime(2026, 11, 15, 8), title: '今天'),
    fakeWidgetDiary(
      'pinned',
      DateTime(2026, 11, 1),
      title: '置顶的',
      pinned: true,
      tags: <String>['旅行'],
    ),
    // 未到期的胶囊：发表时间就是解封日。
    fakeWidgetDiary(
      'capsule',
      DateTime(2027, 1, 1),
      title: '给明年的信',
      capsuleUnlockAt: DateTime(2027, 1, 1),
    ),
  ],
  readable: const <String, String>{'nb-trip': '旅行'},
  notebookMembers: const <String, Set<String>>{
    'nb-trip': <String>{'ginkgo'},
  },
);

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();

void main() {
  group('on this day', () {
    test('lists past years on the same day, latest year first', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(_data()).build(_input());
      final days = _map(_map(snapshot['onThisDay'])['days']);
      expect(days.length, kHomeWidgetDayHorizon);
      final today = _map(days['2026-11-15']);
      // 只算了默认的同月同日：桌面上的实例没有改口径。
      expect(today.keys, <String>['sameDay']);
      final entries = (today['sameDay']! as List).cast<Map>();
      expect(entries.map((entry) => entry['id']), <String>['sea', 'start']);
      expect(entries.first['label'], '3年前的今天');
      // 前后 3 天的不算同月同日；两天后才轮到它。
      expect(
        (_map(days['2026-11-17'])['sameDay']! as List).single['id'],
        'ginkgo',
      );
    });

    test('adds the match modes that instances and drafts use', () async {
      final settings = HomeWidgetSettings.empty.withInstance(
        1,
        HomeWidgetInstance(
          kind: HomeWidgetKind.onThisDay,
          content: const OnThisDayContent(match: OnThisDayMatch.nearby),
        ),
      );
      final snapshot = await HomeWidgetSnapshotBuilder(_data()).build(
        _input(
          settings: settings,
          previewContents: const <HomeWidgetContent>[
            OnThisDayContent(match: OnThisDayMatch.sameMonth),
          ],
        ),
      );
      final today = _map(
        _map(_map(snapshot['onThisDay'])['days'])['2026-11-15'],
      );
      expect(
        today.keys,
        unorderedEquals(<String>['sameDay', 'nearby', 'sameMonth']),
      );
      final nearby = (today['nearby']! as List).cast<Map>();
      expect(nearby.map((entry) => entry['id']), <String>[
        'ginkgo',
        'sea',
        'start',
      ]);
      // 不是同一天的写日期而不是“几年前的今天”。
      expect(nearby.first['label'], isNot(contains('今天')));
    });

    test('queries a few merged ranges, not one per day and year', () async {
      final data = _data();
      await HomeWidgetSnapshotBuilder(data).build(_input());
      // 往前 30 年，每年连续的 14 天合成一段。
      expect(data.queriedRanges.length, 30);
      expect(data.queriedRanges.first.$1, DateTime(1996, 11, 15));
      expect(data.queriedRanges.last.$2, DateTime(2025, 11, 29));
    });

    test('merges overlapping ranges into contiguous spans', () {
      final ranges = homeWidgetOnThisDayRanges(_now, <OnThisDayMatch>{
        OnThisDayMatch.sameDay,
        OnThisDayMatch.sameMonth,
      });
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1.isAfter(ranges[i - 1].$2), isTrue);
      }
      // 同月覆盖了同日：每年一段，11 月 1 日到 12 月 1 日（第 14 天是 11 月 28 日，
      // 不跨月）。
      expect(ranges.first, (DateTime(1996, 11), DateTime(1996, 12)));
    });
  });

  group('diaries', () {
    test('keep title, excerpt, mood and the first local photo', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(_data()).build(_input());
      final diaries = _map(snapshot['diaries']);
      final sea = _map(diaries['sea']);
      expect(sea['title'], '第一次去海边');
      expect(sea['excerpt'], '风很大。 浪一层一层地扑过来。');
      expect(sea['mood'], '😊');
      expect(sea['photo'], '/fixture/sea.jpg');
      expect(sea['created'], '2023-11-15');
      expect(sea['day'], 15);
      // 网络图片不交给小组件，取下一张本机图片。
      expect(_map(diaries['start'])['photo'], '/fixture/desk.jpg');
      expect(_map(diaries['ginkgo']).containsKey('photo'), isFalse);
    });

    test('leave out sealed time capsules', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(_data()).build(_input());
      expect(_map(snapshot['diaries']).containsKey('capsule'), isFalse);
      expect(_map(snapshot['recent'])['all'], isNot(contains('capsule')));
    });

    test('are not written at all when the app lock is on', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _data(),
      ).build(_input(appLocked: true));
      expect(snapshot['redacted'], isTrue);
      expect(snapshot.containsKey('diaries'), isFalse);
      expect(snapshot.containsKey('onThisDay'), isFalse);
      expect(snapshot.containsKey('recent'), isFalse);
      expect(snapshot.toString(), isNot(contains('第一次去海边')));
      expect(snapshot.toString(), isNot(contains('/fixture/')));
    });
  });

  group('recent entries', () {
    Future<Map<String, Object?>> build(
      RecentDiariesContent content, {
      AppFeatures features = const AppFeatures(),
    }) => HomeWidgetSnapshotBuilder(_data()).build(
      _input(
        features: features,
        settings: HomeWidgetSettings.empty.withInstance(
          2,
          HomeWidgetInstance(
            kind: HomeWidgetKind.recentDiaries,
            content: content,
          ),
        ),
      ),
    );

    Map<String, Object?> config(Map<String, Object?> snapshot) =>
        _map(_map(_map(snapshot['instances'])['2'])['content']);

    test(
      'list all entries from newest, with sealed capsules left out',
      () async {
        final snapshot = await build(RecentDiariesContent.defaults);
        expect(config(snapshot)['source'], 'all');
        expect(_map(snapshot['recent'])['all'], <String>[
          'this-year',
          'pinned',
          'ginkgo',
          'sea',
          'start',
        ]);
      },
    );

    test('read from a readable notebook, a tag or the pinned ones', () async {
      final notebook = await build(
        const RecentDiariesContent(
          source: RecentDiariesSource.notebook,
          notebookId: 'nb-trip',
        ),
      );
      expect(config(notebook)['source'], 'notebook:nb-trip');
      expect(config(notebook)['title'], '旅行');
      expect(_map(notebook['recent'])['notebook:nb-trip'], <String>['ginkgo']);

      final tag = await build(
        const RecentDiariesContent(
          source: RecentDiariesSource.tag,
          tagName: '旅行',
        ),
      );
      expect(config(tag)['source'], 'tag:旅行');
      expect(config(tag)['title'], '#旅行');
      expect(_map(tag['recent'])['tag:旅行'], <String>['pinned']);

      final pinned = await build(
        const RecentDiariesContent(source: RecentDiariesSource.pinned),
      );
      expect(_map(pinned['recent'])['pinned'], <String>['pinned']);
    });

    test('fall back to all entries when the source is gone', () async {
      // 本子已变成私密（不在能看的列表里）、标签已删除、日记本功能关闭。
      for (final (content, features) in <(RecentDiariesContent, AppFeatures)>[
        (
          const RecentDiariesContent(
            source: RecentDiariesSource.notebook,
            notebookId: 'nb-private',
          ),
          const AppFeatures(),
        ),
        (
          const RecentDiariesContent(
            source: RecentDiariesSource.tag,
            tagName: 'gone',
          ),
          const AppFeatures(),
        ),
        (
          const RecentDiariesContent(
            source: RecentDiariesSource.notebook,
            notebookId: 'nb-trip',
          ),
          const AppFeatures(notebooks: false),
        ),
      ]) {
        final snapshot = await build(content, features: features);
        expect(config(snapshot)['source'], 'all');
        expect(_map(snapshot['recent']).keys, <String>['all']);
      }
    });
  });

  test(
    'quick capture keeps camera and voice where capture is supported',
    () async {
      final settings = HomeWidgetSettings.empty.withInstance(
        3,
        HomeWidgetInstance(
          kind: HomeWidgetKind.quickCapture,
          content: const QuickCaptureContent(
            actions: <QuickCaptureAction>[
              QuickCaptureAction.camera,
              QuickCaptureAction.voice,
            ],
          ),
        ),
      );
      final snapshot = await HomeWidgetSnapshotBuilder(_data()).build(
        _input(
          settings: settings,
          installed: const <InstalledHomeWidget>[
            InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.quickCapture),
          ],
        ),
      );
      final content = _map(_map(_map(snapshot['instances'])['3'])['content']);
      // 测试的目标平台是 Android：能拍照也能录音。
      expect(content['actions'], <String>['camera', 'voice']);
    },
  );
}
