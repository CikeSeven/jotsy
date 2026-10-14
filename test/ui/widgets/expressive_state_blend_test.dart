import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player_controls.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

import '../../support/expressive_test_theme.dart';

Widget _blend(bool active, List<double> seen) => MaterialApp(
  home: ExpressiveStateBlend(
    active: active,
    builder: (context, t, child) {
      seen.add(t);
      return const SizedBox();
    },
  ),
);

void main() {
  testWidgets('starts settled and blends when the state flips', (tester) async {
    final seen = <double>[];
    await tester.pumpWidget(_blend(true, seen));
    // 首帧直接落在终点，不从 0 播一遍。
    expect(seen.single, 1);

    await tester.pumpWidget(_blend(false, seen));
    await tester.pump(const Duration(milliseconds: 90));
    expect(seen.last, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(seen.last, 0);
  });

  testWidgets('jumps straight to the new state under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final seen = <double>[];
    await tester.pumpWidget(_blend(false, seen));
    await tester.pumpWidget(_blend(true, seen));
    await tester.pump();
    expect(seen.last, 1);
  });

  testWidgets('play button blends its colour along with the morph', (
    tester,
  ) async {
    final theme = expressiveTestTheme(Brightness.light);
    Widget button(bool playing) => MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: DiaryAudioPlayButton(
            playing: playing,
            loading: false,
            failed: false,
            onPressed: () {},
          ),
        ),
      ),
    );
    Color background() => tester
        .widget<IconButton>(find.byType(IconButton))
        .style!
        .backgroundColor!
        .resolve(<WidgetState>{})!;

    await tester.pumpWidget(button(false));
    expect(background(), theme.colorScheme.secondaryContainer);

    await tester.pumpWidget(button(true));
    await tester.pump(const Duration(milliseconds: 100));
    // 换色与形变同步过渡，而不是一帧跳成实心主色。
    expect(background(), isNot(theme.colorScheme.secondaryContainer));
    expect(background(), isNot(theme.colorScheme.primary));

    await tester.pumpAndSettle();
    expect(background(), theme.colorScheme.primary);
  });
}
