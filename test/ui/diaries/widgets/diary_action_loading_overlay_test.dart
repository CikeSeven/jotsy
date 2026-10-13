import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_action_loading_overlay.dart';

void main() {
  Widget buildOverlay({required bool visible}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiaryActionLoadingOverlay(visible: visible, label: 'Exporting'),
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
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
