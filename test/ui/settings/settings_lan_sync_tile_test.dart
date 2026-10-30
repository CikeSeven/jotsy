import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_page.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:node_diary/ui/settings/sections/settings_lan_sync_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_lan_sync_controller.dart';
import '../lan_sync/lan_sync_test_harness.dart';
import '../notebooks/notebook_test_support.dart' show FakeDeviceAuth;

Future<void> _pumpDataPrivacy(
  WidgetTester tester,
  FakeLanSyncController controller,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
        lanSyncControllerProvider.overrideWithValue(controller),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const DataPrivacyPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTile(
  WidgetTester tester,
  FakeLanSyncController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lanSyncControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsLanSyncTile(clock: () => lanSyncTestNow)),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'data & privacy lists LAN sync below data management where supported',
    (tester) async {
      final controller = FakeLanSyncController(
        const LanSyncViewState(local: lanSyncTestLocal),
      );
      await _pumpDataPrivacy(tester, controller);

      expect(find.text('局域网同步'), findsOneWidget);
      final management = tester.getTopLeft(find.text('数据管理'));
      final lanSync = tester.getTopLeft(find.text('局域网同步'));
      expect(lanSync.dy, greaterThan(management.dy));
      expect(lanSync.dy, lessThan(tester.getTopLeft(find.text('草稿箱')).dy));

      await tester.tap(find.text('局域网同步'));
      await tester.pumpAndSettle();
      expect(find.byType(LanSyncPage), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'LAN sync entry also shows on desktop',
    (tester) async {
      await _pumpDataPrivacy(
        tester,
        FakeLanSyncController(const LanSyncViewState(local: lanSyncTestLocal)),
      );
      expect(find.byType(SettingsLanSyncTile), findsOneWidget);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );

  testWidgets('LAN sync entry is hidden on iOS', (tester) async {
    await _pumpDataPrivacy(
      tester,
      FakeLanSyncController(const LanSyncViewState(local: lanSyncTestLocal)),
    );
    expect(find.byType(SettingsLanSyncTile), findsNothing);
    expect(find.text('局域网同步'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('subtitle follows pairing, last sync and attention', (
    tester,
  ) async {
    final controller = FakeLanSyncController(
      const LanSyncViewState(local: lanSyncTestLocal),
    );
    await _pumpTile(tester, controller);
    expect(find.text('在同一 Wi-Fi 下的设备之间同步日记'), findsOneWidget);

    controller.stateNotifier.value = LanSyncViewState(
      local: lanSyncTestLocal,
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(),
        lanSyncTestPeer(id: 'p2'),
      ],
    );
    await tester.pump();
    expect(find.text('已配对 2 台 · 还没有同步过'), findsOneWidget);

    controller.stateNotifier.value = LanSyncViewState(
      local: lanSyncTestLocal,
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(
          lastSyncAt: lanSyncTestNow.subtract(const Duration(hours: 3)),
        ),
        lanSyncTestPeer(
          id: 'p2',
          lastSyncAt: lanSyncTestNow.subtract(const Duration(minutes: 10)),
        ),
      ],
    );
    await tester.pump();
    expect(find.text('已配对 2 台 · 10分钟前已同步'), findsOneWidget);

    controller.stateNotifier.value = LanSyncViewState(
      local: lanSyncTestLocal,
      peers: <LanSyncPeerView>[lanSyncTestPeer(needsAttention: true)],
    );
    await tester.pump();
    final attention = find.text('有一次同步需要你确认');
    expect(attention, findsOneWidget);
    final context = tester.element(attention);
    expect(
      tester.widget<Text>(attention).style?.color,
      Theme.of(context).colorScheme.error,
    );
  });
}
