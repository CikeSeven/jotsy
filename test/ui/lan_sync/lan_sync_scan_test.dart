import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_qr_payload.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_preview_style_provider.dart';
import 'package:node_diary/ui/lan_sync/controllers/lan_sync_scan_detector.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_scan_page.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_scan_view.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

final String _jotsyCode = LanSyncQrPayload(
  hosts: <String>['192.168.1.23'],
  port: 24562,
  deviceId: 'dev-1',
  fingerprint: List<String>.filled(64, 'a').join(),
  token: List<String>.filled(22, 'Q').join(),
  name: 'ThinkPad',
).encode();

Widget _app(Widget home) {
  return ProviderScope(
    overrides: [
      appThemeSeedColorProvider.overrideWithValue(const Color(0xff1e6586)),
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
      home: home,
    ),
  );
}

/// 一个假相机：两个按钮分别送出 Jotsy 码与别的码。
Widget _fakeCamera(
  BuildContext context,
  void Function(Iterable<String?> values) onDetect,
) {
  return Align(
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: () => onDetect(<String?>[_jotsyCode]),
          child: const Text('fake-jotsy'),
        ),
        TextButton(
          onPressed: () => onDetect(<String?>['https://example.com']),
          child: const Text('fake-other'),
        ),
      ],
    ),
  );
}

void main() {
  group('LanSyncScanDetector', () {
    test('a Jotsy code is reported once and later frames are ignored', () {
      final found = <String>[];
      final detector = LanSyncScanDetector(
        onJotsy: found.add,
        onOther: (_) => fail('not expected'),
      );
      detector.handle(<String?>[null, '', _jotsyCode]);
      detector.handle(<String?>[_jotsyCode]);
      expect(found, <String>[_jotsyCode]);
      expect(detector.done, isTrue);
    });

    test('other codes are hinted once per value with their reason', () {
      final errors = <LanSyncQrError>[];
      final detector = LanSyncScanDetector(
        onJotsy: (_) => fail('not expected'),
        onOther: errors.add,
      );
      detector.handle(<String?>['https://example.com']);
      detector.handle(<String?>['https://example.com']);
      detector.handle(<String?>['jotsy-lan:v9:abc']);
      detector.handle(<String?>['jotsy-lan:v1:@@@']);
      expect(errors, <LanSyncQrError>[
        LanSyncQrError.notLanSync,
        LanSyncQrError.unsupportedVersion,
        LanSyncQrError.malformed,
      ]);
    });
  });

  testWidgets('scanning a Jotsy code closes the page with the payload', (
    tester,
  ) async {
    LanSyncScanResult? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push(
                  MaterialPageRoute<LanSyncScanResult>(
                    builder: (_) =>
                        const LanSyncScanPage(cameraBuilder: _fakeCamera),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('对准另一台设备上的 Jotsy 二维码'), findsOneWidget);
    expect(find.text('扫码连接'), findsOneWidget);

    await tester.tap(find.text('fake-other'));
    await tester.pump();
    expect(find.text('这不是 Jotsy 的配对二维码'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('这不是 Jotsy 的配对二维码'), findsNothing);

    await tester.tap(find.text('fake-jotsy'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncScanPage), findsNothing);
    expect(result?.payload, _jotsyCode);
  });

  testWidgets('“手动输入地址” on the scan page returns the manual choice', (
    tester,
  ) async {
    LanSyncScanResult? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push(
                  MaterialPageRoute<LanSyncScanResult>(
                    builder: (_) =>
                        const LanSyncScanPage(cameraBuilder: _fakeCamera),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('没有二维码？手动输入地址'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.payload, isNull);
  });

  testWidgets('permission denied explains and offers 去设置', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: LanSyncScanView(
            camera: const SizedBox.expand(),
            failure: LanSyncScanFailure.permissionDenied,
            torch: LanSyncTorch.unavailable,
            hint: null,
            onClose: () {},
            onToggleTorch: () {},
            onManualAddress: () {},
            onOpenSettings: () => opened++,
          ),
        ),
      ),
    );
    expect(find.text('需要相机权限'), findsOneWidget);
    expect(find.byTooltip('打开手电筒'), findsNothing);
    await tester.tap(find.text('去设置'));
    expect(opened, 1);
    expect(find.text('没有二维码？手动输入地址'), findsOneWidget);
  });

  testWidgets('an unavailable camera explains without 去设置', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: LanSyncScanView(
            camera: const SizedBox.expand(),
            failure: LanSyncScanFailure.unavailable,
            torch: LanSyncTorch.unavailable,
            hint: null,
            onClose: () {},
            onToggleTorch: () {},
            onManualAddress: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    expect(find.text('相机暂时无法使用'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
  });

  testWidgets('the torch button toggles and shows its state', (tester) async {
    var toggled = 0;
    Widget view(LanSyncTorch torch) => _app(
      Scaffold(
        body: LanSyncScanView(
          camera: const SizedBox.expand(),
          failure: null,
          torch: torch,
          hint: null,
          onClose: () {},
          onToggleTorch: () => toggled++,
          onManualAddress: () {},
        ),
      ),
    );
    await tester.pumpWidget(view(LanSyncTorch.off));
    await tester.tap(find.byTooltip('打开手电筒'));
    expect(toggled, 1);
    await tester.pumpWidget(view(LanSyncTorch.on));
    expect(find.byTooltip('关闭手电筒'), findsOneWidget);
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.linux,
    TargetPlatform.windows,
  ]) {
    testWidgets('扫码连接 is hidden on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpLanSyncPage(tester, FakeLanSyncController());
      expect(find.text('显示二维码'), findsOneWidget);
      expect(find.text('扫码连接'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('扫码连接 is offered on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpLanSyncPage(tester, FakeLanSyncController());
    expect(find.text('扫码连接'), findsOneWidget);
    expect(find.text('显示二维码'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
