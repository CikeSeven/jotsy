import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_page_frame.dart';

class _Visibility extends ValueNotifier<DiaryPagerVisibility> {
  _Visibility() : super(DiaryPagerVisibility.at(0));
  bool get observed => hasListeners;
}

void main() {
  late ScrollController scroll;
  late _Visibility visibility;

  setUp(() {
    scroll = ScrollController();
    visibility = _Visibility();
  });
  tearDown(() {
    scroll.dispose();
    visibility.dispose();
  });

  Widget host() => MaterialApp(
    home: Scrollable(
      controller: scroll,
      viewportBuilder: (context, offset) {
        (offset as ScrollPosition).isScrollingNotifier.value = true;
        return DiaryPagerDeferredPage(
          index: 2,
          visibility: visibility,
          child: const Text('Page contents'),
        );
      },
    ),
  );

  testWidgets('an unseen cache page waits until the scroll stops', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.text('Page contents'), findsNothing);
    scroll.position.isScrollingNotifier.value = false;
    await tester.pump();
    expect(find.text('Page contents'), findsOneWidget);
    expect(visibility.observed, isFalse);
  });

  testWidgets('a page that becomes visible builds before scrolling stops', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    visibility.value = DiaryPagerVisibility.at(1.2);
    await tester.pump();
    expect(scroll.position.isScrollingNotifier.value, isTrue);
    expect(find.text('Page contents'), findsOneWidget);
    visibility.value = DiaryPagerVisibility.at(0);
    await tester.pump();
    expect(find.text('Page contents'), findsOneWidget);
  });

  testWidgets('disposing a deferred page detaches its pending listeners', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(visibility.observed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(visibility.observed, isFalse);
    visibility.value = DiaryPagerVisibility.at(2);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
