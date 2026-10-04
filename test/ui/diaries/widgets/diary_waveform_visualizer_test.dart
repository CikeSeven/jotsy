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

  testWidgets('DiaryWaveformBarVisualizer renders and triggers seek callback', (
    tester,
  ) async {
    double? soughtProgress;
    final waveform = [0.2, 0.5, 0.8, 0.4, 0.6];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 40,
              child: DiaryWaveformBarVisualizer(
                waveform: waveform,
                progress: 0.3,
                onSeek: (val) => soughtProgress = val,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DiaryWaveformBarVisualizer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Tap the center of the waveform (progress ~ 0.5)
    await tester.tap(find.byType(DiaryWaveformBarVisualizer));
    expect(soughtProgress, isNotNull);
    expect(soughtProgress!, closeTo(0.5, 0.1));
  });

  testWidgets(
    'LiveVoiceprintVisualizer renders in recording and paused states',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveVoiceprintVisualizer(
              amplitude: 0.7,
              isRecording: true,
              isPaused: false,
            ),
          ),
        ),
      );

      expect(find.byType(LiveVoiceprintVisualizer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));

      // Update to paused
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveVoiceprintVisualizer(
              amplitude: 0.0,
              isRecording: false,
              isPaused: true,
            ),
          ),
        ),
      );
      expect(find.byType(LiveVoiceprintVisualizer), findsOneWidget);
    },
  );
}
