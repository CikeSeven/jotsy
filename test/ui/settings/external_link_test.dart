import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/external_link.dart';

/// 应用外链统一入口（#346）：直接外部打开而不预查 `canLaunchUrl`、缺协议补
/// `https://`、打不开或抛 `PlatformException` 时复制并提示，以及 Android 清单
/// 的 `<queries>` 与源码防回归检查。
void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  List<MethodCall> mockUrlLauncher({
    bool result = true,
    PlatformException? error,
  }) {
    final calls = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'launch' && error != null) {
        throw error;
      }
      return result;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  List<String?> mockClipboard() {
    final copied = <String?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return copied;
  }

  testWidgets('launches external URLs directly without calling canLaunch', (
    tester,
  ) async {
    final calls = mockUrlLauncher();
    final copied = mockClipboard();
    final context = await pumpHost(tester);

    await openExternalLink(
      context,
      '  https://mp.weixin.qq.com/s/AbC_123?mid=1#rd  ',
    );
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    final args = calls.single.arguments as Map;
    expect(args['url'], 'https://mp.weixin.qq.com/s/AbC_123?mid=1#rd');
    expect(args['useWebView'], isFalse);
    expect(args['useSafariVC'], isFalse);
    expect(copied, isEmpty);
  });

  testWidgets('prepends https:// for scheme-less and protocol-relative links', (
    tester,
  ) async {
    final calls = mockUrlLauncher();
    final context = await pumpHost(tester);

    await openExternalLink(context, 'mp.weixin.qq.com/s/abc');
    await openExternalLink(context, '//mp.weixin.qq.com/s/def');
    await tester.pump();

    expect(
      [for (final call in calls) (call.arguments as Map)['url']],
      ['https://mp.weixin.qq.com/s/abc', 'https://mp.weixin.qq.com/s/def'],
    );
  });

  testWidgets('ignores blank input without launching or copying', (
    tester,
  ) async {
    final calls = mockUrlLauncher();
    final copied = mockClipboard();
    final context = await pumpHost(tester);

    await openExternalLink(context, '   ');
    await tester.pump();

    expect(calls, isEmpty);
    expect(copied, isEmpty);
  });

  testWidgets('copies link and shows snackbar when launch throws '
      'PlatformException', (tester) async {
    mockUrlLauncher(
      error: PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'No Activity found to handle intent',
      ),
    );
    final copied = mockClipboard();
    final context = await pumpHost(tester);

    final pending = openExternalLink(context, 'https://mp.weixin.qq.com/s/abc');
    await tester.pumpAndSettle();

    expect(copied, ['https://mp.weixin.qq.com/s/abc']);
    expect(find.text('无法直接打开链接，已复制到剪贴板。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await pending;
  });

  testWidgets('copies link and shows snackbar when launch returns false or '
      'URL is malformed', (tester) async {
    mockUrlLauncher(result: false);
    final copied = mockClipboard();
    final context = await pumpHost(tester);

    final first = openExternalLink(context, 'https://example.com');
    await tester.pumpAndSettle();
    expect(copied, ['https://example.com']);
    expect(find.text('无法直接打开链接，已复制到剪贴板。'), findsOneWidget);

    final second = openExternalLink(context, 'http://[::1');
    await tester.pumpAndSettle();
    expect(copied, ['https://example.com', 'http://[::1']);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await first;
    await second;
  });

  test(
    'AndroidManifest declares ACTION_VIEW queries for external link schemes',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final queries = RegExp(
        r'<queries>[\s\S]*?</queries>',
      ).firstMatch(manifest)?.group(0);
      expect(queries, isNotNull);
      for (final scheme in const ['https', 'http', 'mailto', 'tel']) {
        expect(
          queries,
          matches(
            RegExp(
              r'<intent>\s*<action android:name="android\.intent\.action\.VIEW"\s*/>\s*'
              '<data android:scheme="$scheme"\\s*/>\\s*</intent>',
            ),
          ),
          reason:
              'AndroidManifest <queries> should declare ACTION_VIEW for $scheme',
        );
      }
    },
  );

  test('lib does not call upstream editorLaunchUrl directly', () {
    final call = RegExp(r'\beditorLaunchUrl\s*\(');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(
        call.hasMatch(source),
        isFalse,
        reason: '${file.path} calls upstream editorLaunchUrl directly',
      );
    }
  });
}
