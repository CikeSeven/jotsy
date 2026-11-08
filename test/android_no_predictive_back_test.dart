import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';

/// 侧滑返回不预览上一页：手势过程中当前页不缩小、上一页不露出，松手才返回。
///
/// 系统级预览由 AndroidManifest 关闭（源码检查），页面级预览由主题的 Android
/// 转场关闭（经 `flutter/backgesture` 通道模拟系统送来的侧滑进度验证）。
void main() {
  ThemeData appTheme() => MaterialTheme(
    Typography.material2021().black,
  ).theme(ColorScheme.fromSeed(seedColor: Colors.blue));

  test('Android activity opts out of predictive back callbacks', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:enableOnBackInvokedCallback="false"'));
    expect(
      manifest,
      isNot(contains('android:enableOnBackInvokedCallback="true"')),
    );
  });

  test('MainActivity no longer forwards back gesture progress', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/jotsy/diary/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, isNot(contains('OnBackAnimationCallback')));
    expect(mainActivity, isNot(contains('startBackGesture')));
    expect(mainActivity, isNot(contains('updateBackGestureProgress')));
    // 启动页品牌图形的入口参数仍要带给 Dart。
    expect(mainActivity, contains('override fun getDartEntrypointArgs()'));
    expect(mainActivity, contains('launchEntrypointArgs()'));
  });

  // #196：第一个路由上返回只退到桌面（与主屏键相同），不结束 Activity：
  // 引擎、Dart 状态与首页所在的日记本都留着。回调须在 super.onCreate 之前
  // 注册，排在 FlutterFragment 的回调之下，只接 SystemNavigator.pop 的转发。
  test('root back sends the task to the background instead of finishing', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/jotsy/diary/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('moveTaskToBack(true)'));
    expect(mainActivity, contains('isTaskRoot'));
    final register = mainActivity.indexOf(
      'onBackPressedDispatcher.addCallback(leaveToHomeScreen)',
    );
    final superOnCreate = mainActivity.indexOf(
      'super.onCreate(savedInstanceState)',
    );
    expect(register, greaterThan(0));
    expect(register, lessThan(superOnCreate));

    // Dart 不自己“退出应用”：根路由的返回一律交给上面的原生回调。
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(
        source.contains('SystemNavigator.pop'),
        isFalse,
        reason: '${file.path} calls SystemNavigator.pop',
      );
    }
  });

  test('Android page transition keeps the fade-forwards motion only', () {
    final builder =
        appTheme().pageTransitionsTheme.builders[TargetPlatform.android];

    expect(builder, isA<NoPredictiveBackPageTransitionsBuilder>());
    expect(builder, isNot(isA<PredictiveBackPageTransitionsBuilder>()));
    // 与框架默认转场一样没有委托转场，自定义路由上推入页面时下层不跟着动。
    expect(builder!.delegatedTransition, isNull);
    expect(
      builder.transitionDuration,
      const PredictiveBackPageTransitionsBuilder().transitionDuration,
    );
  });

  testWidgets(
    'back gesture does not preview the previous page and pops on commit',
    (tester) async {
      await _pumpSecondPage(tester, appTheme());

      await _sendBackGesture(tester, 'startBackGesture', progress: 0);
      await _sendBackGesture(
        tester,
        'updateBackGestureProgress',
        progress: 0.5,
      );
      await tester.pumpAndSettle();

      expect(find.text('first'), findsNothing);
      expect(tester.getRect(find.byKey(_secondPageKey)), _screenRect(tester));

      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('canceled back gesture stays on the current page', (
    tester,
  ) async {
    await _pumpSecondPage(tester, appTheme());

    await _sendBackGesture(tester, 'startBackGesture', progress: 0);
    await _sendBackGesture(tester, 'updateBackGestureProgress', progress: 0.5);
    await _sendBackGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  // 对照：框架默认转场在同样的手势下会露出上一页，证明上面的检查确实有效。
  testWidgets('framework default transition would preview the previous page', (
    tester,
  ) async {
    await _pumpSecondPage(tester, ThemeData());

    await _sendBackGesture(tester, 'startBackGesture', progress: 0);
    await _sendBackGesture(tester, 'updateBackGestureProgress', progress: 0.5);
    await tester.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(_secondPageKey)),
      isNot(_screenRect(tester)),
    );

    await _sendBackGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

const Key _secondPageKey = ValueKey<String>('second-page');

Rect _screenRect(WidgetTester tester) =>
    Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

/// 打开首页后用普通 MaterialPageRoute 推入第二页，停在第二页上。
Future<void> _pumpSecondPage(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    key: _secondPageKey,
                    body: Center(child: Text('second')),
                  ),
                ),
              ),
              child: const Text('first'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('first'));
  await tester.pumpAndSettle();
  expect(find.text('second'), findsOneWidget);
  expect(find.text('first'), findsNothing);
}

/// 模拟系统经 `flutter/backgesture` 送来的侧滑返回事件（从左缘滑入）。
///
/// 开始事件带触点 `touchOffset`，进度事件带 `x` / `y`，与引擎的
/// BackGestureChannel 一致；提交与取消不带参数。
Future<void> _sendBackGesture(
  WidgetTester tester,
  String method, {
  double? progress,
}) async {
  final Map<String, Object>? arguments = switch (progress) {
    null => null,
    final value when method == 'startBackGesture' => <String, Object>{
      'touchOffset': <double>[5.0, 300.0],
      'progress': value,
      'swipeEdge': 0,
    },
    final value => <String, Object>{
      'x': 100.0,
      'y': 300.0,
      'progress': value,
      'swipeEdge': 0,
    },
  };
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
  await tester.pump();
}
