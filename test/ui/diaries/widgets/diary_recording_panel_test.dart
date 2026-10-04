import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

void main() {
  testWidgets('centered microphone starts local recording', (tester) async {
    var started = false;
    await tester.pumpWidget(_app(onStart: () => started = true));
    final microphone = find.byTooltip('开始录音');
    final button = find.byType(FilledButton);
    expect(tester.getSize(button), const Size(88, 88));
    expect(
      tester.getCenter(button).dx,
      tester.getSize(find.byType(Scaffold)).width / 2,
    );
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
    await tester.tap(find.byTooltip('暂停录音'));
    await tester.tap(find.byTooltip('结束录音'));
    expect(pauses, 1);
    expect(finishes, 1);

    await tester.pumpWidget(
      _app(phase: DiaryRecordingPhase.paused, onResume: () => resumes++),
    );
    await tester.tap(find.byTooltip('继续录音'));
    expect(resumes, 1);
    expect(find.text('已暂停'), findsOneWidget);
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
        final indicator = tester.getRect(
          find.byType(ExpressiveLoadingIndicator),
        );
        final counter = tester.getRect(find.text('00:12'));
        expect(indicator.width, lessThanOrEqualTo(40));
        expect(indicator.bottom, lessThan(counter.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    expect(find.text('录音失败，请重试'), findsOneWidget);
    expect(find.text('未允许使用麦克风'), findsNothing);
  });
}

Widget _app({
  DiaryRecordingPhase phase = DiaryRecordingPhase.idle,
  DiaryRecordingFailure? failure,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  VoidCallback onStart = _noop,
  VoidCallback onPause = _noop,
  VoidCallback onResume = _noop,
  VoidCallback onFinish = _noop,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff526a95),
      brightness: brightness,
    ),
  ),
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
      onStart: onStart,
      onPause: onPause,
      onResume: onResume,
      onFinish: onFinish,
      onClose: _noop,
    ),
  ),
);

void _noop() {}
