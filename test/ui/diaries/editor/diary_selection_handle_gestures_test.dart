import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_selection_gestures.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_view.dart';

import '../../../support/expressive_test_theme.dart';

const _start = ValueKey('selection_start');
const _end = ValueKey('selection_end');

class _Harness {
  final scroll = ScrollController();
  final starts = <DiarySelectionHandleSide>[];
  final updates = <DiarySelectionHandleSide>[];
  int ends = 0;
  int cancels = 0;
  int nativePans = 0;
  int longPresses = 0;
}

Future<_Harness> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiaryPagerView(
          itemCount: 3,
          initialPage: 1,
          itemBuilder: (_, page) => page.index != 1
              ? Center(child: Text('page ${page.index}'))
              : SingleChildScrollView(
                  controller: harness.scroll,
                  child: DiarySelectionHandleGestureRegion(
                    resolveHandle: (point) {
                      if (tester.getRect(find.byKey(_start)).contains(point)) {
                        return DiarySelectionHandleSide.start;
                      }
                      if (tester.getRect(find.byKey(_end)).contains(point)) {
                        return DiarySelectionHandleSide.end;
                      }
                      return null;
                    },
                    onStart: (_, side) => harness.starts.add(side),
                    onUpdate: (_, side) => harness.updates.add(side),
                    onEnd: (_, _) => harness.ends++,
                    onCancel: (_) => harness.cancels++,
                    // 模拟原生把手的 pan 与长按：祖先还有真实的纵向滚动和
                    // DiaryPagerView。小步移动才能暴露各识别器阈值不同的问题。
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (_) => harness.nativePans++,
                      onLongPress: () => harness.longPresses++,
                      child: const SizedBox(
                        height: 1400,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 80,
                              top: 240,
                              child: SizedBox(
                                key: _start,
                                width: 48,
                                height: 48,
                              ),
                            ),
                            Positioned(
                              left: 176,
                              top: 240,
                              child: SizedBox(key: _end, width: 48, height: 48),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _smallDrag(
  WidgetTester tester,
  Offset start,
  Offset step, {
  int steps = 70,
}) async {
  final gesture = await tester.startGesture(start);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 8));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

double _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

Future<void> _close(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.scroll.dispose();
}

void main() {
  testWidgets(
    'slow handle drags win over horizontal paging in both directions',
    (tester) async {
      for (final (key, side, dx) in [
        (_start, DiarySelectionHandleSide.start, -1.0),
        (_end, DiarySelectionHandleSide.end, 1.0),
      ]) {
        final harness = await _pump(tester);
        await _smallDrag(
          tester,
          tester.getCenter(find.byKey(key)),
          Offset(dx, 0),
        );
        expect(harness.starts, [side]);
        expect(harness.updates, isNotEmpty);
        expect(harness.updates.every((value) => value == side), isTrue);
        expect(harness.ends, 1);
        expect(harness.nativePans, 0);
        expect(_page(tester), closeTo(1, 0.001));
        await _close(tester, harness);
      }
    },
  );

  testWidgets('slow vertical handle drags win over reading page scrolling', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _smallDrag(
      tester,
      tester.getCenter(find.byKey(_end)),
      const Offset(0, -1),
    );
    expect(harness.starts, [DiarySelectionHandleSide.end]);
    expect(harness.updates, isNotEmpty);
    expect(harness.ends, 1);
    expect(harness.scroll.offset, 0);
    await _close(tester, harness);
  });

  testWidgets('dragging outside handles still scrolls and turns pages', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _smallDrag(tester, const Offset(300, 500), const Offset(0, -1));
    expect(harness.scroll.offset, greaterThan(0));
    expect(harness.starts, isEmpty);
    await _smallDrag(
      tester,
      const Offset(300, 500),
      const Offset(-1, 0),
      steps: 280,
    );
    expect(_page(tester), closeTo(2, 0.001));
    expect(harness.starts, isEmpty);
    await _close(tester, harness);
  });

  testWidgets('long pressing outside handles still reaches native selection', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await tester.longPressAt(const Offset(300, 500));
    expect(harness.longPresses, 1);
    expect(harness.starts, isEmpty);
    await _close(tester, harness);
  });

  testWidgets('removing the editor during a handle drag ends the native drag', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_end)),
    );
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(harness.starts, [DiarySelectionHandleSide.end]);
    await _close(tester, harness);
    expect(harness.cancels, 1);
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
