import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_live_voiceprint.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  testWidgets('centered microphone starts local recording', (tester) async {
    var started = false;
    await tester.pumpWidget(_app(onStart: () => started = true));
    final microphone = find.byTooltip('开始录音');
    final button = find.byType(FilledButton);
    expect(tester.getSize(button), const Size(72, 72));
    expect(
      tester.getCenter(button).dx,
      tester.getSize(find.byType(Scaffold)).width / 2,
    );
    expect(find.text('点按麦克风开始录音'), findsOneWidget);
    await tester.tap(microphone);
    expect(started, isTrue);
    expect(find.text('插入正文'), findsNothing);
    expect(find.text('通过系统语音服务识别'), findsNothing);
  });

  testWidgets('recording exposes pause and finish, paused exposes resume', (
    tester,
  ) async {
    var pauses = 0;
    var finishes = 0;
    var resumes = 0;
    await tester.pumpWidget(
      _app(
        phase: DiaryRecordingPhase.recording,
        onPause: () => pauses++,
        onFinish: () => finishes++,
      ),
    );
    // 主按钮在会话中就是“结束”，不再是一个灰掉的麦克风。
    expect(find.byTooltip('开始录音'), findsNothing);
    expect(find.text('录音中'), findsOneWidget);
    await tester.tap(find.byTooltip('暂停录音'));
    await tester.tap(find.byTooltip('结束录音'));
    expect(pauses, 1);
    expect(finishes, 1);

    await tester.pumpWidget(
      _app(phase: DiaryRecordingPhase.paused, onResume: () => resumes++),
    );
    await tester.pumpAndSettleBounded();
    await tester.tap(find.byTooltip('继续录音'));
    expect(resumes, 1);
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('录音中'), findsNothing);
  });

  testWidgets('pause and resume transitions keep the session layout', (
    tester,
  ) async {
    var pauses = 0;
    var finishes = 0;
    await tester.pumpWidget(
      _app(
        phase: DiaryRecordingPhase.recording,
        onPause: () => pauses++,
        onFinish: () => finishes++,
      ),
    );
    await tester.pumpAndSettleBounded();
    final heightBefore = tester
        .getSize(find.byType(DiaryRecordingPanel))
        .height;

    // 暂停的原生调用返回前控制器处于 preparing：版面不能塌回待机，只是暂时不可点。
    await tester.pumpWidget(
      _app(
        phase: DiaryRecordingPhase.preparing,
        onPause: () => pauses++,
        onFinish: () => finishes++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byTooltip('暂停录音'), findsOneWidget);
    expect(find.byTooltip('结束录音'), findsOneWidget);
    expect(find.byTooltip('开始录音'), findsNothing);
    expect(find.text('录音中'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DiaryRecordingPanel)).height,
      heightBefore,
    );
    await tester.tap(find.byTooltip('暂停录音'), warnIfMissed: false);
    await tester.tap(find.byTooltip('结束录音'), warnIfMissed: false);
    expect(pauses, 0);
    expect(finishes, 0);

    // 暂停很短，不值得出等待指示。
    await tester.pump(DelayedLoadingGate.defaultDelay * 2);
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
  });

  testWidgets('panel height stays constant across idle, recording and paused', (
    tester,
  ) async {
    final heights = <DiaryRecordingPhase, double>{};
    for (final phase in [
      DiaryRecordingPhase.idle,
      DiaryRecordingPhase.recording,
      DiaryRecordingPhase.paused,
    ]) {
      await tester.pumpWidget(_app(phase: phase));
      await tester.pumpAndSettleBounded();
      heights[phase] = tester.getSize(find.byType(DiaryRecordingPanel)).height;
    }
    expect(heights.values.toSet(), hasLength(1), reason: '$heights');
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'loading stays in its own slot in $brightness on a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            phase: DiaryRecordingPhase.preparing,
            brightness: brightness,
            textScale: 1.8,
          ),
        );
        // 等待指示延迟出现，避免权限/初始化只花几十毫秒时闪一下。
        expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
        await tester.pump(DelayedLoadingGate.defaultDelay);
        await tester.pump(const Duration(milliseconds: 400));
        final indicator = tester.getRect(
          find.byType(ExpressiveLoadingIndicator),
        );
        final counter = tester.getRect(find.text('00:12'));
        expect(indicator.width, lessThanOrEqualTo(40));
        // 计时器在上、主按钮在下：指示器不得压到计时器。
        expect(indicator.top, greaterThanOrEqualTo(counter.bottom));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('finishing shows the loader only after the loading delay', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: DiaryRecordingPhase.recording));
    await tester.pumpAndSettleBounded();
    await tester.pumpWidget(_app(phase: DiaryRecordingPhase.finishing));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    // 结束时版面仍是会话版面，计时与声纹不消失。
    expect(find.byType(LiveVoiceprintVisualizer), findsOneWidget);

    await tester.pump(DelayedLoadingGate.defaultDelay);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    expect(find.byType(LiveVoiceprintVisualizer), findsOneWidget);
  });

  testWidgets('true microphone denial is different from capture failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(failure: DiaryRecordingFailure.permissionDenied),
    );
    expect(find.text('未允许使用麦克风'), findsOneWidget);
    await tester.pumpWidget(
      _app(failure: DiaryRecordingFailure.recordingFailed),
    );
    // 状态文案是淡出再淡入：旧文案要等动画走完才会移除。
    await tester.pumpAndSettle();
    expect(find.text('录音失败，请重试'), findsOneWidget);
    expect(find.text('未允许使用麦克风'), findsNothing);
  });

  testWidgets('tapping recording title opens rename dialog and updates name', (
    tester,
  ) async {
    String? updatedName;
    await tester.pumpWidget(
      _app(recordingName: '默认语音', onNameChanged: (val) => updatedName = val),
    );

    expect(find.text('默认语音'), findsOneWidget);
    await tester.tap(find.text('默认语音'));
    await tester.pumpAndSettle();

    expect(find.text('重命名录音'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '晨间反思');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(updatedName, '晨间反思');
  });

  testWidgets('clearing the name in the rename dialog restores the default', (
    tester,
  ) async {
    String? updatedName;
    await tester.pumpWidget(
      _app(recordingName: '旧名字', onNameChanged: (val) => updatedName = val),
    );
    await tester.tap(find.text('旧名字'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(updatedName, '语音备注');
  });

  testWidgets('cancelling the rename dialog leaves the name untouched', (
    tester,
  ) async {
    String? updatedName;
    await tester.pumpWidget(
      _app(recordingName: '旧名字', onNameChanged: (val) => updatedName = val),
    );
    await tester.tap(find.text('旧名字'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(updatedName, isNull);
  });

  testWidgets('idle panel and reduce motion schedule no endless frames', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(phase: DiaryRecordingPhase.recording));
    // 减少动画时 REC 圆点不呼吸、计时不闪烁：面板在切换完成后必须能静止下来
    // （存在循环动画时 pumpAndSettle 会一直等不到静止而超时）。
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recording breathes only while a session is active', (
    tester,
  ) async {
    await tester.pumpWidget(_app(phase: DiaryRecordingPhase.recording));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

extension on WidgetTester {
  /// 会话中的面板带有循环的呼吸动画，`pumpAndSettle` 永远等不到静止；这里改为
  /// 固定推进一段时间，足够让入场与阶段切换动画（最长 250ms）全部走完。
  Future<void> pumpAndSettleBounded() async {
    await pump();
    await pump(const Duration(milliseconds: 400));
  }
}

Widget _app({
  DiaryRecordingPhase phase = DiaryRecordingPhase.idle,
  DiaryRecordingFailure? failure,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  String? recordingName,
  ValueChanged<String>? onNameChanged,
  VoidCallback onStart = _noop,
  VoidCallback onPause = _noop,
  VoidCallback onResume = _noop,
  VoidCallback onFinish = _noop,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: expressiveTestTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: DiaryRecordingPanel(
      phase: phase,
      elapsed: const Duration(seconds: 12),
      failure: failure,
      waveform: const [0.2, 0.5, 0.8, 0.4],
      recordingName: recordingName,
      onNameChanged: onNameChanged,
      onStart: onStart,
      onPause: onPause,
      onResume: onResume,
      onFinish: onFinish,
      onClose: _noop,
    ),
  ),
);

void _noop() {}
