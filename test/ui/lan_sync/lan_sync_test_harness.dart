import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_page.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_lan_sync_controller.dart';

/// 测试里固定的“现在”。
final DateTime lanSyncTestNow = DateTime(2026, 10, 29, 12);

const LanSyncLocalDeviceView lanSyncTestLocal = LanSyncLocalDeviceView(
  name: 'Pixel 9',
  platform: LanSyncPlatform.android,
  addresses: <String>['192.168.1.23'],
  port: 47562,
);

LanSyncPeerView lanSyncTestPeer({
  String id = 'peer-1',
  String name = 'ThinkPad',
  bool online = true,
  DateTime? lastSyncAt,
  bool needsAttention = false,
  LanSyncSessionView? session,
}) {
  return LanSyncPeerView(
    deviceId: id,
    name: name,
    platform: LanSyncPlatform.linux,
    pairedAt: DateTime(2026, 10, 1),
    online: online,
    address: online ? '192.168.1.40' : null,
    lastSyncAt: lastSyncAt,
    needsAttention: needsAttention,
    session: session,
  );
}

const LanSyncNearbyView lanSyncTestNearby = LanSyncNearbyView(
  deviceId: 'near-1',
  name: 'Office PC',
  platform: LanSyncPlatform.windows,
  address: '192.168.1.50',
);

/// 挂上同步页。[reduceMotion] 默认开：雷达与“正在寻找…”不循环，
/// pumpAndSettle 可以收尾；测雷达播放的用例单独关掉。
Future<void> pumpLanSyncPage(
  WidgetTester tester,
  FakeLanSyncController controller, {
  Brightness brightness = Brightness.light,
  double width = 390,
  double height = 844,
  bool reduceMotion = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lanSyncControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: LanSyncPage(clock: () => lanSyncTestNow),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
