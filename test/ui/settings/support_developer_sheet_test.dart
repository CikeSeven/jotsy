import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/controllers/support_developer_controller.dart';
import 'package:node_diary/ui/settings/models/support_channel.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/widgets/support_developer_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_app_update_service.dart';

class _FakeExportService extends ImageExportService {
  _FakeExportService();

  final List<String> savedNames = <String>[];

  @override
  Future<void> saveBytesToGallery(
    Uint8List bytes, {
    required String name,
  }) async {
    savedNames.add(name);
  }
}

void main() {
  late _FakeExportService service;
  late List<Uri> launched;
  late bool launchSucceeds;

  setUp(() {
    service = _FakeExportService();
    launched = <Uri>[];
    launchSucceeds = true;
  });

  SupportDeveloperController createController() => SupportDeveloperController(
    service: service,
    launcher: (Uri uri) async {
      launched.add(uri);
      return launchSucceeds;
    },
  );

  Widget app({
    required Widget home,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );
  }

  /// 放一个按钮打开打赏面板（注入假的相册服务与应用拉起）。
  Future<void> openSheet(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 860),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        brightness: brightness,
        textScale: textScale,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSupportDeveloperSheet(
                context,
                createController: createController,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder codeImage(String label) => find.byWidgetPredicate(
    (widget) => widget is Image && widget.semanticLabel == label,
  );

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('the About page opens the support sheet from its entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PackageInfo.setMockInitialValues(
      appName: 'Jotsy',
      packageName: 'com.jotsy.diary',
      version: '0.7.0',
      buildNumber: '20',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          appUpdateServiceProvider.overrideWithValue(FakeAppUpdateService()),
        ],
        child: app(home: const AboutPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('微信、支付宝自愿打赏'), findsOneWidget);
    await tester.tap(find.text('支持开发者'));
    await tester.pumpAndSettle();

    expect(find.textContaining('打赏完全自愿，不会解锁任何功能'), findsOneWidget);
    expect(codeImage('微信赞赏码'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'shows both channels without overflow at 320dp (${brightness.name})',
      (tester) async {
        await openSheet(
          tester,
          brightness: brightness,
          size: const Size(320, 640),
          textScale: 1.3,
        );

        expect(codeImage('微信赞赏码'), findsOneWidget);
        expect(find.text('保存到相册'), findsOneWidget);
        expect(find.text('打开微信'), findsOneWidget);

        await tester.tap(find.text('支付宝'));
        await tester.pumpAndSettle();

        expect(codeImage('支付宝收款码'), findsOneWidget);
        expect(codeImage('微信赞赏码'), findsNothing);
        expect(find.text('打开支付宝付款'), findsOneWidget);
        expect(find.text('保存到相册'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('paying in Alipay hands the payment code to Alipay', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('支付宝'));
    await tester.pumpAndSettle();

    await tapButton(tester, '打开支付宝付款');

    expect(launched, <Uri>[alipayLaunchUri]);
    expect(find.textContaining('没能打开'), findsNothing);
  });

  testWidgets(
    'a missing Alipay is explained under the buttons until the tab changes',
    (tester) async {
      launchSucceeds = false;
      await openSheet(tester);
      await tester.tap(find.text('支付宝'));
      await tester.pumpAndSettle();

      await tapButton(tester, '打开支付宝付款');
      expect(find.text('没能打开支付宝。可以保存收款码，用装有支付宝的手机扫码。'), findsOneWidget);

      await tester.tap(find.text('微信'));
      await tester.pumpAndSettle();
      expect(find.textContaining('没能打开支付宝'), findsNothing);
    },
  );

  testWidgets('saving the WeChat code confirms it under the buttons', (
    tester,
  ) async {
    await openSheet(tester);

    await tapButton(tester, '保存到相册');

    expect(service.savedNames, <String>['jotsy_support_wechat']);
    expect(find.text('已保存到相册'), findsOneWidget);
    expect(launched, isEmpty);
  });
}
