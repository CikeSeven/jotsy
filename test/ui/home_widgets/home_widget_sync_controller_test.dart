import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_style.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/home_widgets/controllers/home_widget_sync_controller.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_data_source.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_snapshot_builder.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_today_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_home_widget_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SettingsService settings;
  late FakeHomeWidgetGateway gateway;
  final now = DateTime(2026, 11, 15, 9, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    gateway = FakeHomeWidgetGateway();
  });

  tearDown(() => database.close());

  HomeWidgetSyncController controller({bool previewing = false}) {
    final created = HomeWidgetSyncController(
      gateway: gateway,
      settingsService: settings,
      database: database,
      builder: HomeWidgetSnapshotBuilder(
        DatabaseHomeWidgetDataSource(database),
      ),
      readFeatures: () => AppFeatures.defaults,
      readSettings: () =>
          HomeWidgetSettings.decode(settings.homeWidgetsRawNotifier.value),
      previewing: () => previewing,
      onInstalledChanged: () {},
      now: () => now,
    );
    addTearDown(created.dispose);
    return created;
  }

  test('does nothing while no widget is on the home screen', () async {
    await controller().syncNow();
    expect(gateway.snapshots, isEmpty);
    expect(gateway.refreshed, isEmpty);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'writes the snapshot, redraws the kinds on the home screen and schedules midnights',
    () async {
      gateway.installedWidgets = const <InstalledHomeWidget>[
        InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.today),
      ];
      await controller().syncNow();
      expect(gateway.snapshots, hasLength(1));
      expect(gateway.lastSnapshot!['builtAt'], now.millisecondsSinceEpoch);
      expect(gateway.refreshed, <HomeWidgetKind>[HomeWidgetKind.today]);
      final times = gateway.scheduled[HomeWidgetKind.today]!;
      expect(times, hasLength(kHomeWidgetDayHorizon));
      expect(times.first, DateTime(2026, 11, 16, 0, 0, 5));
    },
  );

  test('an unchanged snapshot is neither written nor redrawn again', () async {
    gateway.installedWidgets = const <InstalledHomeWidget>[
      InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.today),
    ];
    final sync = controller();
    await sync.syncNow();
    await sync.syncNow();
    expect(gateway.snapshots, hasLength(1));
    expect(gateway.refreshed, hasLength(1));
  });

  test('a widget placed from the studio takes the pending design', () async {
    const style = HomeWidgetStyle(
      background: HomeWidgetBackground.vivid,
      accent: HomeWidgetAccent.tertiary,
    );
    await settings.setHomeWidgetsRaw(
      HomeWidgetSettings.empty
          .withPending(
            HomeWidgetInstance.defaultsFor(
              HomeWidgetKind.today,
            ).copyWith(style: style),
            now.subtract(const Duration(minutes: 1)),
          )
          .encode(),
    );
    gateway.installedWidgets = const <InstalledHomeWidget>[
      InstalledHomeWidget(widgetId: 7, kind: HomeWidgetKind.today),
    ];
    await controller().syncNow();
    final stored = HomeWidgetSettings.decode(
      settings.homeWidgetsRawNotifier.value,
    );
    expect(stored.instances[7]!.style, style);
    expect(stored.pending, isEmpty);
    final instance = (gateway.lastSnapshot!['instances']! as Map)['7']! as Map;
    expect((instance['style']! as Map)['background'], 'vivid');
  });

  test(
    'while previewing every kind has data even with nothing installed',
    () async {
      await controller(previewing: true).syncNow();
      expect(gateway.lastSnapshot!.containsKey('today'), isTrue);
      expect(gateway.refreshed, isEmpty);
    },
  );

  test('today counts the words written today', () async {
    gateway.installedWidgets = const <InstalledHomeWidget>[
      InstalledHomeWidget(widgetId: 3, kind: HomeWidgetKind.today),
    ];
    await database.createDiary(
      title: '',
      contentDocJson: '[{"insert":"今天去海边走了走\\n"}]',
      contentText: '今天去海边走了走',
      metadataJson: '{}',
      createdAtOverride: DateTime(2026, 11, 15, 8),
    );
    await controller().syncNow();
    final words =
        ((gateway.lastSnapshot!['today']! as Map)['words']!
            as Map)['2026-11-15'];
    expect(words, 8);
  });

  test('quick capture also redraws when the greeting changes', () {
    final times = homeWidgetRedrawTimes(HomeWidgetKind.quickCapture, now);
    expect(times, contains(DateTime(2026, 11, 15, 11, 0, 5)));
    expect(times, isNot(contains(DateTime(2026, 11, 15, 5, 0, 5))));
    expect(times, contains(DateTime(2026, 11, 16, 0, 0, 5)));
    expect(times, orderedEquals(List<DateTime>.of(times)..sort()));
    expect(
      homeWidgetRedrawTimes(HomeWidgetKind.today, now),
      hasLength(kHomeWidgetDayHorizon),
    );
  });
}
