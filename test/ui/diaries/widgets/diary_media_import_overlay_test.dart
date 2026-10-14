import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_import_overlay.dart';

Widget _host({required bool copying, required VoidCallback onTap}) =>
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: TextButton(onPressed: onTap, child: const Text('editor')),
            ),
            DiaryMediaImportOverlay(copying: copying),
          ],
        ),
      ),
    );

double _veilOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(DiaryMediaImportOverlay),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('a fast copy blocks input but never shows the veil', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(copying: true, onTap: () => taps++));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('editor'), warnIfMissed: false);
    expect(taps, 0);
    expect(_veilOpacity(tester), 0);

    await tester.pumpWidget(_host(copying: false, onTap: () => taps++));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_veilOpacity(tester), 0);
    // 复制结束：拦截层随即移除（常驻会屏蔽下层读屏语义），编辑区恢复可点。
    expect(
      find.descendant(
        of: find.byType(DiaryMediaImportOverlay),
        matching: find.byType(ModalBarrier),
      ),
      findsNothing,
    );
    await tester.tap(find.text('editor'));
    expect(taps, 1);
  });

  testWidgets('a slow copy fades the veil in and out', (tester) async {
    await tester.pumpWidget(_host(copying: true, onTap: () {}));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_veilOpacity(tester), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_veilOpacity(tester), 1);

    await tester.pumpWidget(_host(copying: false, onTap: () {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 结束时淡出，而不是一帧消失。
    expect(_veilOpacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_veilOpacity(tester), 0);
  });
}
