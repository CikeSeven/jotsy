import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';

void main() {
  Widget buildOverlay({required bool visible}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ActionLoadingOverlay(visible: visible, label: 'Exporting'),
      ),
    );
  }

  double overlayOpacity(WidgetTester tester) {
    return tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
  }

  testWidgets('hidden overlay stops scheduling frames', (tester) async {
    await tester.pumpWidget(buildOverlay(visible: false));
    await tester.pump(const Duration(milliseconds: 500));

    // 指示器 ticker 被静音后，空闲时不应再有待绘制帧。
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('visible overlay keeps animating and fade-out completes', (
    tester,
  ) async {
    await tester.pumpWidget(buildOverlay(visible: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(overlayOpacity(tester), 1);

    await tester.pumpWidget(buildOverlay(visible: false));
    await tester.pump(const Duration(milliseconds: 500));

    expect(overlayOpacity(tester), 0);
    // 淡出期间指示器照常在转，淡出结束的那一帧才卸下；它在那一帧的 tick
    // 里已排好下一帧，所以再泵一帧之后才完全静止。
    expect(find.byType(LoadingIndicatorM3E), findsNothing);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('hidden overlay unmounts the indicator and its morph timer', (
    tester,
  ) async {
    // 第三方指示器的形变由 Timer.periodic 驱动、不受 TickerMode 管：隐藏时
    // 仍挂着就会每约 650ms 触发一次重建与整屏光栅。隐藏的遮罩里不应有它。
    await tester.pumpWidget(buildOverlay(visible: false));
    expect(find.byType(LoadingIndicatorM3E), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('delayed reveal', () {
    Widget host({required bool visible, required VoidCallback onTap}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Center(
                child: TextButton(onPressed: onTap, child: const Text('under')),
              ),
              Positioned.fill(
                child: ActionLoadingOverlay(
                  visible: visible,
                  label: 'Saving',
                  revealDelay: const Duration(milliseconds: 300),
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('blocks taps at once but stays invisible for fast work', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(host(visible: true, onTap: () => taps++));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('under'), warnIfMissed: false);
      expect(taps, 0);
      expect(overlayOpacity(tester), 0);

      // 动作在延迟内结束：画面从未出现，下层恢复可点。
      await tester.pumpWidget(host(visible: false, onTap: () => taps++));
      await tester.pump(const Duration(milliseconds: 400));
      expect(overlayOpacity(tester), 0);
      await tester.tap(find.text('under'));
      expect(taps, 1);
    });

    testWidgets('slow work fades the veil in after the delay', (tester) async {
      await tester.pumpWidget(host(visible: true, onTap: () {}));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(overlayOpacity(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(overlayOpacity(tester), 1);
    });
  });
}
