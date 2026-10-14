import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_audio_waveform.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';

void main() {
  test(
    'generateEffectiveWaveform synthesizes consistent deterministic bars',
    () {
      final waveformA = generateEffectiveWaveform(
        samples: const [],
        seedKey: 'audio_1.m4a',
        duration: const Duration(seconds: 15),
        barCount: 30,
      );
      final waveformB = generateEffectiveWaveform(
        samples: const [],
        seedKey: 'audio_1.m4a',
        duration: const Duration(seconds: 15),
        barCount: 30,
      );

      expect(waveformA, hasLength(30));
      expect(waveformA, equals(waveformB));
      for (final val in waveformA) {
        expect(val, inInclusiveRange(0.05, 1.0));
      }
    },
  );

  test('generateEffectiveWaveform resamples provided amplitude samples', () {
    final original = List.generate(100, (i) => i / 100.0);
    final resampled = generateEffectiveWaveform(
      samples: original,
      seedKey: 'ignored',
      duration: const Duration(seconds: 5),
      barCount: 20,
    );

    expect(resampled, hasLength(20));
    for (final val in resampled) {
      expect(val, inInclusiveRange(0.05, 1.0));
    }
  });

  Widget host({
    required double progress,
    ValueChanged<double>? onSeek,
    List<double> waveform = const [0.2, 0.5, 0.8, 0.4, 0.6],
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 40,
          child: DiaryWaveformBarVisualizer(
            waveform: waveform,
            progress: progress,
            onSeek: onSeek,
          ),
        ),
      ),
    ),
  );

  testWidgets('DiaryWaveformBarVisualizer renders and triggers seek callback', (
    tester,
  ) async {
    double? soughtProgress;
    await tester.pumpWidget(
      host(progress: 0.3, onSeek: (val) => soughtProgress = val),
    );

    expect(find.byType(DiaryWaveformBarVisualizer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Tap the center of the waveform (progress ~ 0.5)
    await tester.tap(find.byType(DiaryWaveformBarVisualizer));
    expect(soughtProgress, isNotNull);
    expect(soughtProgress!, closeTo(0.5, 0.1));
  });

  testWidgets('dragging scrubs continuously and stays within 0..1', (
    tester,
  ) async {
    final seeks = <double>[];
    await tester.pumpWidget(host(progress: 0.1, onSeek: seeks.add));

    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(DiaryWaveformBarVisualizer)) +
          const Offset(20, 20),
    );
    // 第一段位移只用来越过拖动阈值、确认手势归属，之后每次移动才产生 seek。
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(400, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(seeks.length, greaterThanOrEqualTo(2));
    expect(seeks, everyElement(inInclusiveRange(0.0, 1.0)));
    // 拖出控件右缘后被夹在 1.0，而不是越界。
    expect(seeks.last, 1.0);
    expect(seeks.first, lessThan(seeks.last));
  });

  testWidgets('without onSeek the waveform ignores touches', (tester) async {
    await tester.pumpWidget(host(progress: 0.4));
    await tester.tap(find.byType(DiaryWaveformBarVisualizer));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress sweeps smoothly and then stops scheduling frames', (
    tester,
  ) async {
    await tester.pumpWidget(host(progress: 0.1));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // 位置事件到达：补间启动，期间持续出帧。
    await tester.pumpWidget(host(progress: 0.6));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // 补间走完后静止，不会空转。
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduce motion jumps progress without animating', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(host(progress: 0.1));
    await tester.pumpWidget(host(progress: 0.6));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('semantics expose progress as a percentage slider', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(progress: 0.5));
    expect(
      tester.getSemantics(find.byType(DiaryWaveformBarVisualizer)),
      matchesSemantics(isSlider: true, value: '50%'),
    );
    handle.dispose();
  });

  testWidgets('playback rewinding to the start does not sweep backwards', (
    tester,
  ) async {
    Widget waveform(double progress) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: DiaryWaveformBarVisualizer(
            waveform: List<double>.filled(24, 0.6),
            progress: progress,
          ),
        ),
      ),
    );
    double paintedProgress() => tester
        .widget<TweenAnimationBuilder<double>>(
          find.descendant(
            of: find.byType(DiaryWaveformBarVisualizer),
            matching: find.byType(TweenAnimationBuilder<double>),
          ),
        )
        .duration
        .inMicroseconds
        .toDouble();

    await tester.pumpWidget(waveform(0.4));
    await tester.pumpWidget(waveform(0.9));
    // 正向播放：用补间抹平步进。
    expect(paintedProgress(), greaterThan(0));
    await tester.pumpAndSettle();

    // 播放结束复位到 0：直接落位，不再让播放头倒扫回起点。
    await tester.pumpWidget(waveform(0));
    expect(paintedProgress(), 0);
    await tester.pumpAndSettle();
  });
}
