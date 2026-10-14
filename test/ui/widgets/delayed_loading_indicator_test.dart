import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('fast loads finish without ever showing the indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DelayedLoadingIndicator()));
    for (var elapsed = 0; elapsed < 240; elapsed += 16) {
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 数据就绪：加载分支被替换，计时器随之取消，之后也不会再冒出指示器。
    await tester.pumpWidget(_host(const Text('content')));
    await tester.pump(DelayedLoadingGate.defaultDelay);
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('slow loads fade the indicator in after the delay', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DelayedLoadingIndicator(size: 32)));
    await tester.pump(DelayedLoadingGate.defaultDelay);
    await tester.pump();

    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(ExpressiveEntrance),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacity(), lessThan(1));

    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(), 1);
    expect(
      tester
          .widget<ExpressiveLoadingIndicator>(
            find.byType(ExpressiveLoadingIndicator),
          )
          .size,
      32,
    );
  });
}
