import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_audio_player.dart';

void main() {
  const recording = DiaryAudioAttachment(
    path: '/diary_recordings/entry.m4a',
    duration: Duration(seconds: 12),
    name: '晨间反思',
    waveform: [0.2, 0.5, 0.8, 0.4, 0.6, 0.3],
  );

  Future<void> pumpPlayer(
    WidgetTester tester,
    FakeAudioPlayer player, {
    Brightness brightness = Brightness.light,
    ValueChanged<String>? onRename,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: DiaryAudioPlayer(
                recording: recording,
                player: player,
                onRename: onRename,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color cardColor(WidgetTester tester) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.byType(DiaryAudioPlayer),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  double progress(WidgetTester tester) => tester
      .widget<DiaryWaveformBarVisualizer>(
        find.byType(DiaryWaveformBarVisualizer),
      )
      .progress;

  testWidgets('shows the name and elapsed / total time', (tester) async {
    await pumpPlayer(tester, FakeAudioPlayer());
    expect(find.text('晨间反思'), findsOneWidget);
    expect(find.text('00:00 / 00:12'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness playing tints the card and pausing restores it', (
      tester,
    ) async {
      final player = FakeAudioPlayer();
      await pumpPlayer(tester, player, brightness: brightness);
      final resting = cardColor(tester);

      await tester.tap(find.byTooltip('播放录音'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停播放'), findsOneWidget);
      expect(cardColor(tester), isNot(resting));

      await tester.tap(find.byTooltip('暂停播放'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('播放录音'), findsOneWidget);
      expect(cardColor(tester), resting);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('waveform progress and time follow playback position', (
    tester,
  ) async {
    final player = FakeAudioPlayer();
    await pumpPlayer(tester, player);
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pump();

    player.positionController.add(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('00:06 / 00:12'), findsOneWidget);
    expect(progress(tester), closeTo(0.5, 1e-9));

    // 补间走完后波形停止出帧。
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('tapping the waveform seeks to that fraction of the clip', (
    tester,
  ) async {
    final player = FakeAudioPlayer();
    await pumpPlayer(tester, player);
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DiaryWaveformBarVisualizer));
    await tester.pumpAndSettle();
    // 点在波形正中：约 6 秒处。
    expect(find.textContaining('00:06 / 00:12'), findsOneWidget);
  });

  testWidgets('a slow start shows the loader only after the loading delay', (
    tester,
  ) async {
    final player = _SlowStartPlayer();
    await pumpPlayer(tester, player);
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);

    await tester.pump(DelayedLoadingGate.defaultDelay);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);

    player.release.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    expect(find.byTooltip('暂停播放'), findsOneWidget);
  });

  testWidgets('failed playback disables the button and explains why', (
    tester,
  ) async {
    final player = FakeAudioPlayer()..fail = true;
    await pumpPlayer(tester, player);
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pumpAndSettle();

    expect(find.text('录音无法播放'), findsWidgets);
    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
    // 失败后不再提供重命名入口。
    expect(find.byTooltip('重命名录音'), findsNothing);
  });

  testWidgets('rename entry only exists when a rename handler is provided', (
    tester,
  ) async {
    await pumpPlayer(tester, FakeAudioPlayer());
    expect(find.byTooltip('重命名录音'), findsNothing);

    String? renamed;
    await pumpPlayer(tester, FakeAudioPlayer(), onRename: (n) => renamed = n);
    await tester.tap(find.byTooltip('重命名录音'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新名称');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(renamed, '新名称');
  });
}

/// `play` 一直挂起直到 [release] 完成，用来观察“正在启动”的等待态。
class _SlowStartPlayer extends FakeAudioPlayer {
  final release = Completer<void>();

  @override
  Future<void> play(String path) async {
    await release.future;
    await super.play(path);
  }
}
