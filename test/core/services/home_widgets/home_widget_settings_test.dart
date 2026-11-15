import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_launch.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_style.dart';

void main() {
  group('HomeWidgetSettings.decode', () {
    test('empty, broken or non-object raw text gives empty settings', () {
      for (final raw in <String?>[null, '', '  ', '{', '[1]', '"x"']) {
        final settings = HomeWidgetSettings.decode(raw);
        expect(settings.instances, isEmpty, reason: '$raw');
        expect(settings.pending, isEmpty, reason: '$raw');
      }
    });

    test('drops instances of unknown kinds and keeps the rest', () {
      final settings = HomeWidgetSettings.decode(
        jsonEncode(<String, Object?>{
          'instances': <String, Object?>{
            '7': <String, Object?>{'kind': 'today'},
            '8': <String, Object?>{'kind': 'from_the_future'},
            'not-a-number': <String, Object?>{'kind': 'today'},
          },
        }),
      );
      expect(settings.instances.keys, <int>[7]);
      expect(settings.instances[7]!.kind, HomeWidgetKind.today);
    });

    test('a bad style field only resets that field', () {
      final settings = HomeWidgetSettings.decode(
        jsonEncode(<String, Object?>{
          'instances': <String, Object?>{
            '1': <String, Object?>{
              'kind': 'today',
              'style': <String, Object?>{
                'background': 'vivid',
                'opacity': 'very',
                'textScale': 9,
                'radius': 12,
              },
            },
          },
        }),
      );
      final style = settings.instances[1]!.style;
      expect(style.background, HomeWidgetBackground.vivid);
      expect(style.opacity, 1);
      expect(style.textScale, HomeWidgetStyle.maxTextScale);
      expect(style.cornerRadius, 12);
    });

    test('round-trips through encode', () {
      final original = HomeWidgetSettings.empty
          .withInstance(
            3,
            HomeWidgetInstance.defaultsFor(
              HomeWidgetKind.quickCapture,
            ).copyWith(
              style: const HomeWidgetStyle(
                palette: HomeWidgetPalette.seed,
                seed: 0xFF2E9488,
                cornerRadius: 24,
              ),
              content: const QuickCaptureContent(
                actions: <QuickCaptureAction>[QuickCaptureAction.search],
                notebookId: 'nb-1',
              ),
            ),
          )
          .withPending(
            HomeWidgetInstance.defaultsFor(HomeWidgetKind.today),
            DateTime(2026, 11, 15, 9),
          );
      final decoded = HomeWidgetSettings.decode(original.encode());
      expect(decoded.instances, original.instances);
      expect(decoded.pending.single.instance.kind, HomeWidgetKind.today);
      expect(decoded.pending.single.requestedAt, DateTime(2026, 11, 15, 9));
    });
  });

  group('HomeWidgetSettings.reconcile', () {
    final now = DateTime(2026, 11, 15, 12);
    final designed = HomeWidgetInstance.defaultsFor(
      HomeWidgetKind.today,
    ).copyWith(style: const HomeWidgetStyle(accent: HomeWidgetAccent.tertiary));

    test('nothing to change returns null', () {
      final settings = HomeWidgetSettings.empty.withInstance(
        1,
        HomeWidgetInstance.defaultsFor(HomeWidgetKind.today),
      );
      expect(settings.reconcile({1: HomeWidgetKind.today}, now), isNull);
    });

    test('forgets widgets that left the home screen', () {
      final settings = HomeWidgetSettings.empty
          .withInstance(1, HomeWidgetInstance.defaultsFor(HomeWidgetKind.today))
          .withInstance(
            2,
            HomeWidgetInstance.defaultsFor(HomeWidgetKind.quickCapture),
          );
      final next = settings.reconcile({2: HomeWidgetKind.quickCapture}, now)!;
      expect(next.instances.keys, <int>[2]);
    });

    test('a new widget of the same kind claims the pending design', () {
      final settings = HomeWidgetSettings.empty.withPending(
        designed,
        now.subtract(const Duration(minutes: 2)),
      );
      final next = settings.reconcile(<int, HomeWidgetKind>{
        5: HomeWidgetKind.quickCapture,
        9: HomeWidgetKind.today,
      }, now)!;
      expect(next.instances[9], designed);
      expect(next.instances.containsKey(5), isFalse);
      expect(next.pending, isEmpty);
    });

    test('an expired pending design is dropped, not claimed', () {
      final settings = HomeWidgetSettings.empty.withPending(
        designed,
        now.subtract(
          HomeWidgetSettings.pendingLifetime + const Duration(minutes: 1),
        ),
      );
      final next = settings.reconcile({9: HomeWidgetKind.today}, now)!;
      expect(next.instances, isEmpty);
      expect(next.pending, isEmpty);
    });

    test('designing the same kind again replaces the pending design', () {
      final first = HomeWidgetSettings.empty.withPending(
        HomeWidgetInstance.defaultsFor(HomeWidgetKind.today),
        now,
      );
      final second = first.withPending(designed, now);
      expect(second.pending.single.instance, designed);
    });
  });

  group('content parsing', () {
    test(
      'quick capture drops unknown and repeated actions, keeps at most 4',
      () {
        final content =
            HomeWidgetContent.fromJson(
                  HomeWidgetKind.quickCapture,
                  <String, Object?>{
                    'actions': <Object?>[
                      'todo',
                      'todo',
                      'teleport',
                      'write',
                      'search',
                      'calendar',
                    ],
                    'notebook': '',
                  },
                )
                as QuickCaptureContent;
        expect(content.actions, <QuickCaptureAction>[
          QuickCaptureAction.todo,
          QuickCaptureAction.write,
          QuickCaptureAction.search,
          QuickCaptureAction.calendar,
        ]);
        expect(content.notebookId, isNull);
      },
    );

    test('quick capture with no valid action falls back to the defaults', () {
      final content =
          HomeWidgetContent.fromJson(
                HomeWidgetKind.quickCapture,
                <String, Object?>{
                  'actions': <Object?>['nope'],
                },
              )
              as QuickCaptureContent;
      expect(content.actions, QuickCaptureContent.defaults.actions);
    });

    test('today content keeps valid fields and resets broken ones', () {
      final content =
          HomeWidgetContent.fromJson(HomeWidgetKind.today, <String, Object?>{
                'lunar': 'never',
                'holiday': 42,
                'yearProgress': true,
                'tap': 'write',
              })
              as TodayContent;
      expect(content.lunar, HomeWidgetAlmanacMode.never);
      expect(content.holiday, TodayContent.defaults.holiday);
      expect(content.showYearProgress, isTrue);
      expect(content.tapAction, TodayTapAction.write);
    });

    test('on this day keeps a known match and resets broken fields', () {
      final content =
          HomeWidgetContent.fromJson(
                HomeWidgetKind.onThisDay,
                <String, Object?>{
                  'match': 'sameMonth',
                  'photo': 'yes',
                  'excerpt': false,
                },
              )
              as OnThisDayContent;
      expect(content.match, OnThisDayMatch.sameMonth);
      expect(content.showPhoto, OnThisDayContent.defaults.showPhoto);
      expect(content.showExcerpt, isFalse);
      expect(
        HomeWidgetContent.fromJson(HomeWidgetKind.onThisDay, content.toJson()),
        content,
      );
    });

    test('writing stats and photo memories reset broken fields', () {
      final stats =
          HomeWidgetContent.fromJson(
                HomeWidgetKind.writingStats,
                <String, Object?>{'basis': 'words', 'heatmap': 'no'},
              )
              as WritingStatsContent;
      expect(stats.basis, WritingHeatBasis.words);
      expect(stats.showHeatmap, WritingStatsContent.defaults.showHeatmap);
      final photos =
          HomeWidgetContent.fromJson(
                HomeWidgetKind.photoMemories,
                <String, Object?>{
                  'source': 'notebook',
                  'notebook': 'nb',
                  'date': false,
                },
              )
              as PhotoMemoriesContent;
      expect(photos.source, PhotoMemorySource.notebook);
      expect(photos.notebookId, 'nb');
      expect(photos.showDate, isFalse);
      expect(
        HomeWidgetContent.fromJson(
          HomeWidgetKind.photoMemories,
          photos.toJson(),
        ),
        photos,
      );
    });

    test('recent entries keep the source and drop empty ids', () {
      final content =
          HomeWidgetContent.fromJson(
                HomeWidgetKind.recentDiaries,
                <String, Object?>{
                  'source': 'tag',
                  'tag': '旅行',
                  'notebook': '',
                  'photos': false,
                },
              )
              as RecentDiariesContent;
      expect(content.source, RecentDiariesSource.tag);
      expect(content.tagName, '旅行');
      expect(content.notebookId, isNull);
      expect(content.showPhotos, isFalse);
      expect(content.showExcerpt, isTrue);
      expect(
        HomeWidgetContent.fromJson(
          HomeWidgetKind.recentDiaries,
          <String, Object?>{'source': 'everything'},
        ),
        RecentDiariesContent.defaults,
      );
    });
  });

  group('HomeWidgetStyle', () {
    test('seed palette key is the ARGB in hex', () {
      const style = HomeWidgetStyle(
        palette: HomeWidgetPalette.seed,
        seed: 0xFF2E9488,
      );
      expect(style.paletteKey, 'seed:FF2E9488');
      expect(style.toNative()['palette'], 'seed:FF2E9488');
    });

    test('seed palette without a seed falls back to the app palette', () {
      const style = HomeWidgetStyle(palette: HomeWidgetPalette.seed);
      expect(style.paletteKey, 'app');
    });

    test('opacity is clamped to the minimum', () {
      final style = HomeWidgetStyle.fromJson(<String, Object?>{'opacity': 0});
      expect(style.opacity, HomeWidgetStyle.minOpacity);
    });

    test('system corners are sent to native as -1', () {
      expect(HomeWidgetStyle.defaults.toNative()['radius'], -1);
    });
  });

  group('HomeWidgetLaunch.parse', () {
    test('ignores links that are not widget links', () {
      expect(HomeWidgetLaunch.parse(null), isNull);
      expect(HomeWidgetLaunch.parse(Uri.parse('https://widget/write')), isNull);
      expect(HomeWidgetLaunch.parse(Uri.parse('jotsy://other/write')), isNull);
    });

    test('write carries the notebook', () {
      final launch = HomeWidgetLaunch.parse(
        Uri.parse('jotsy://widget/write?notebook=nb-1'),
      );
      expect(launch, isA<HomeWidgetWriteLaunch>());
      expect((launch! as HomeWidgetWriteLaunch).notebookId, 'nb-1');
      expect((launch as HomeWidgetWriteLaunch).capture, isNull);
    });

    test('write can start with the camera or a recording', () {
      HomeWidgetCapture? capture(String query) =>
          (HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/write?$query'))!
                  as HomeWidgetWriteLaunch)
              .capture;
      expect(capture('with=camera'), HomeWidgetCapture.camera);
      expect(capture('with=voice&notebook=nb'), HomeWidgetCapture.voice);
      expect(capture('with=video'), isNull);
    });

    test('explore opens the explore tab', () {
      expect(
        HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/explore')),
        isA<HomeWidgetExploreLaunch>(),
      );
    });

    test('diary needs an id', () {
      final launch =
          HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/diary?id=d-1'))!
              as HomeWidgetDiaryLaunch;
      expect(launch.diaryId, 'd-1');
      expect(
        HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/diary')),
        isA<HomeWidgetOpenAppLaunch>(),
      );
    });

    test('calendar rejects impossible dates', () {
      final good =
          HomeWidgetLaunch.parse(
                Uri.parse('jotsy://widget/calendar?day=2026-11-15'),
              )!
              as HomeWidgetCalendarLaunch;
      expect(good.day, DateTime(2026, 11, 15));
      final bad =
          HomeWidgetLaunch.parse(
                Uri.parse('jotsy://widget/calendar?day=2026-02-31'),
              )!
              as HomeWidgetCalendarLaunch;
      expect(bad.day, isNull);
    });

    test('configure needs an id and keeps a known kind', () {
      final launch =
          HomeWidgetLaunch.parse(
                Uri.parse('jotsy://widget/configure?id=12&kind=today'),
              )!
              as HomeWidgetConfigureLaunch;
      expect(launch.widgetId, 12);
      expect(launch.kind, HomeWidgetKind.today);
      expect(
        HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/configure?id=x')),
        isA<HomeWidgetOpenAppLaunch>(),
      );
    });

    test('unknown targets just open the app', () {
      expect(
        HomeWidgetLaunch.parse(Uri.parse('jotsy://widget/somewhere')),
        isA<HomeWidgetOpenAppLaunch>(),
      );
    });
  });

  test('every kind maps back from its Android receiver class name', () {
    for (final kind in HomeWidgetKind.values) {
      expect(
        HomeWidgetKind.byAndroidClassName(kind.qualifiedAndroidName),
        kind,
      );
      expect(HomeWidgetKind.byId(kind.id), kind);
    }
    expect(HomeWidgetKind.byAndroidClassName('com.other.Widget'), isNull);
  });
}
