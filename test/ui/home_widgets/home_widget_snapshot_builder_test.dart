import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_content.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_style.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_data_source.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_palette.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_snapshot_builder.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_today_section.dart';

/// 假数据源：字数、待办截止日与能写的日记本由测试设定。
class _FakeData implements HomeWidgetDataSource {
  _FakeData({
    this.words = 0,
    this.dueDates = const <String?>[],
    this.notebooks = const <String, String>{},
  });

  final int words;
  final List<String?> dueDates;
  final Map<String, String> notebooks;

  @override
  Future<int> wordsOn(DateTime day) async => words;

  @override
  Future<List<String?>> openTodoDueDates() async => dueDates;

  @override
  Future<Map<String, String>> writableNotebooks() async => notebooks;
}

/// Kotlin 渲染测试读的快照样例（与 Dart 构建结果逐字一致，见下方测试）。
const String _fixturePath =
    'android/app/src/test/resources/widget_snapshot_fixture.json';

final DateTime _now = DateTime(2026, 11, 15, 14, 30);

HomeWidgetSnapshotInput _input({
  String language = 'zh',
  AppFeatures features = const AppFeatures(todos: true),
  bool appLocked = false,
  HomeWidgetSettings settings = HomeWidgetSettings.empty,
  List<InstalledHomeWidget> installed = const <InstalledHomeWidget>[
    InstalledHomeWidget(widgetId: 1, kind: HomeWidgetKind.today),
  ],
  Set<HomeWidgetKind>? kinds,
}) => HomeWidgetSnapshotInput(
  now: _now,
  l10n: lookupAppLocalizations(Locale(language)),
  appSeed: const Color(0xFF1E6586),
  features: features,
  appLocked: appLocked,
  settings: settings,
  installed: installed,
  kinds: kinds ?? installed.map((widget) => widget.kind).toSet(),
);

Map<String, Object?> _config(Map<String, Object?> snapshot, int id) =>
    ((snapshot['instances']! as Map)['$id']! as Map).cast<String, Object?>();

void main() {
  group('today section', () {
    test('covers the horizon from today and counts overdue to-dos', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _FakeData(
          words: 1234,
          dueDates: <String?>['2026-11-10', '2026-11-15', '2026-11-17', null],
        ),
      ).build(_input());
      final today = (snapshot['today']! as Map).cast<String, Object?>();
      final days = (today['days']! as Map).cast<String, Object?>();
      expect(days.length, kHomeWidgetDayHorizon);
      expect(days.keys.first, '2026-11-15');
      int todos(String key) => (days[key]! as Map)['todos']! as int;
      // 逾期的一项与今天的一项；后天再多一项；没有截止日的不计。
      expect(todos('2026-11-15'), 2);
      expect(todos('2026-11-16'), 2);
      expect(todos('2026-11-17'), 3);
      expect((today['words']! as Map)['2026-11-15'], 1234);
      expect((today['wordsLabel']! as Map).keys, <String>['2026-11-15']);
    });

    test('skips to-do due dates when to-dos are turned off', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _FakeData(dueDates: <String?>['2026-11-15']),
      ).build(_input(features: const AppFeatures()));
      final days = ((snapshot['today']! as Map)['days']! as Map);
      expect((days['2026-11-15']! as Map)['todos'], 0);
    });

    test('is left out when no widget needs it', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _FakeData(),
      ).build(_input(installed: const <InstalledHomeWidget>[]));
      expect(snapshot.containsKey('today'), isFalse);
    });
  });

  group('native config', () {
    test('drops actions whose feature is off and stale notebooks', () async {
      final settings = HomeWidgetSettings.empty.withInstance(
        4,
        HomeWidgetInstance(
          kind: HomeWidgetKind.quickCapture,
          content: const QuickCaptureContent(
            actions: <QuickCaptureAction>[
              QuickCaptureAction.todo,
              QuickCaptureAction.calendar,
            ],
            notebookId: 'gone',
          ),
        ),
      );
      final snapshot =
          await HomeWidgetSnapshotBuilder(
            _FakeData(notebooks: <String, String>{'nb': 'Travel'}),
          ).build(
            _input(
              features: const AppFeatures(calendar: false),
              settings: settings,
              installed: const <InstalledHomeWidget>[
                InstalledHomeWidget(
                  widgetId: 4,
                  kind: HomeWidgetKind.quickCapture,
                ),
              ],
            ),
          );
      final content = (_config(snapshot, 4)['content']! as Map);
      // 待办与日历都关了：剔完只剩写日记。
      expect(content['actions'], <String>['write']);
      expect(content.containsKey('notebook'), isFalse);
    });

    test('keeps a notebook that can still be written into', () async {
      final settings = HomeWidgetSettings.empty.withInstance(
        4,
        HomeWidgetInstance(
          kind: HomeWidgetKind.quickCapture,
          content: const QuickCaptureContent(notebookId: 'nb'),
        ),
      );
      final snapshot =
          await HomeWidgetSnapshotBuilder(
            _FakeData(notebooks: <String, String>{'nb': 'Travel'}),
          ).build(
            _input(
              settings: settings,
              installed: const <InstalledHomeWidget>[
                InstalledHomeWidget(
                  widgetId: 4,
                  kind: HomeWidgetKind.quickCapture,
                ),
              ],
            ),
          );
      expect((_config(snapshot, 4)['content']! as Map)['notebook'], 'nb');
    });

    test('lunar "follow language" shows only in Chinese', () async {
      Future<bool> lunarFor(String language) async {
        final snapshot = await HomeWidgetSnapshotBuilder(
          _FakeData(),
        ).build(_input(language: language));
        return (_config(snapshot, 1)['content']! as Map)['lunar']! as bool;
      }

      expect(await lunarFor('zh'), isTrue);
      expect(await lunarFor('en'), isFalse);
    });

    test('today taps open the app when the calendar is off', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _FakeData(),
      ).build(_input(features: const AppFeatures(calendar: false)));
      expect((_config(snapshot, 1)['content']! as Map)['tap'], 'app');
    });

    test('an unconfigured widget uses the kind defaults', () async {
      final snapshot = await HomeWidgetSnapshotBuilder(
        _FakeData(),
      ).build(_input());
      expect(_config(snapshot, 1)['kind'], 'today');
      expect((_config(snapshot, 1)['style']! as Map)['palette'], 'app');
    });
  });

  test('exports the app palette plus every chosen seed once', () async {
    const seedStyle = HomeWidgetStyle(
      palette: HomeWidgetPalette.seed,
      seed: 0xFF7A9A5B,
    );
    final settings = HomeWidgetSettings.empty
        .withInstance(
          1,
          HomeWidgetInstance.defaultsFor(
            HomeWidgetKind.today,
          ).copyWith(style: seedStyle),
        )
        .withPending(
          HomeWidgetInstance.defaultsFor(
            HomeWidgetKind.quickCapture,
          ).copyWith(style: seedStyle),
          _now,
        );
    final snapshot = await HomeWidgetSnapshotBuilder(
      _FakeData(),
    ).build(_input(settings: settings));
    final palettes = (snapshot['palettes']! as Map).cast<String, Object?>();
    expect(palettes.keys, unorderedEquals(<String>['app', 'seed:FF7A9A5B']));
    final light = ((palettes['app']! as Map)['light']! as Map);
    expect(light.keys, unorderedEquals(kHomeWidgetPaletteRoles));
  });

  test('marks the snapshot redacted when the app lock is on', () async {
    final snapshot = await HomeWidgetSnapshotBuilder(
      _FakeData(),
    ).build(_input(appLocked: true));
    expect(snapshot['redacted'], isTrue);
  });

  test('the native render fixture matches the builder output', () async {
    // Kotlin 的渲染测试（WidgetRenderTest.kt）读这份快照；格式一变这里就失败，
    // 用 UPDATE_WIDGET_FIXTURE=1 重新生成。
    final settings = HomeWidgetSettings.empty.withPending(
      HomeWidgetInstance.defaultsFor(HomeWidgetKind.today).copyWith(
        style: const HomeWidgetStyle(
          palette: HomeWidgetPalette.seed,
          seed: 0xFFD98BA0,
        ),
      ),
      _now,
    );
    final snapshot =
        await HomeWidgetSnapshotBuilder(
          _FakeData(
            words: 1284,
            dueDates: <String?>['2026-11-14', '2026-11-15', '2026-11-15'],
            notebooks: <String, String>{'nb-travel': '旅行'},
          ),
        ).build(
          _input(
            settings: settings,
            installed: const <InstalledHomeWidget>[
              InstalledHomeWidget(widgetId: 1, kind: HomeWidgetKind.today),
              InstalledHomeWidget(
                widgetId: 2,
                kind: HomeWidgetKind.quickCapture,
              ),
            ],
          ),
        );
    final encoded = '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n';
    final file = File(_fixturePath);
    if (Platform.environment['UPDATE_WIDGET_FIXTURE'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(encoded);
    }
    expect(file.readAsStringSync(), encoded);
  });
}
