import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/widgets/ai_stream_reveal.dart';

/// 流式正文的匀速释放：积压按固定时间量级放完、不低于最低速度；逐帧只多
/// 显示一点，最后放完；落库的回答接着进行中那一项放；减少动画时不做节奏。
void main() {
  group('AiRevealPace', () {
    test('a small backlog drains at the minimum rate', () {
      // 积压 4 字：按 0.35 秒放完只有约 11 字 / 秒，取最低的 40 字 / 秒。
      expect(AiRevealPace.advance(0, 4, 0.05), closeTo(2, 1e-9));
      expect(AiRevealPace.advance(0, 4, 1), 4);
    });

    test('a large backlog speeds up so the lag stays bounded', () {
      // 积压 700 字：每秒 2000 字。
      expect(AiRevealPace.advance(0, 700, 0.016), closeTo(32, 1e-9));
      var shown = 0.0;
      var frames = 0;
      while (shown < 699 && frames < 1000) {
        shown = AiRevealPace.advance(shown, 700, 1 / 60);
        frames++;
      }
      // 指数追赶：两秒以内放完（最后一小段按最低速度）。
      expect(frames, lessThan(120));
    });

    test('never passes the end and never cuts a surrogate pair', () {
      expect(AiRevealPace.advance(9.5, 10, 5), 10);
      expect(AiRevealPace.advance(12, 10, 0.1), 10);
      const text = 'a😀b';
      expect(AiRevealPace.safeCut(text, 1), 1);
      expect(AiRevealPace.safeCut(text, 2), 3);
      expect(AiRevealPace.safeCut(text, 99), text.length);
    });
  });

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );

  final long = List<String>.generate(40, (i) => '第$i句话写在这里。').join();

  testWidgets('live text comes out gradually and ends complete', (
    tester,
  ) async {
    await tester.pumpWidget(host(AiRevealedMarkdown(text: long, live: true)));
    expect(find.textContaining('第39句话', findRichText: true), findsNothing);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('第0句话', findRichText: true), findsOneWidget);
    expect(find.textContaining('第39句话', findRichText: true), findsNothing);

    await tester.pumpAndSettle();
    expect(find.textContaining('第39句话', findRichText: true), findsOneWidget);
  });

  testWidgets('a saved answer shows in full unless it takes over a reveal', (
    tester,
  ) async {
    await tester.pumpWidget(host(AiRevealedMarkdown(text: long, live: false)));
    expect(find.textContaining('第39句话', findRichText: true), findsOneWidget);

    // 进行中的一项放到一半，换成落库的回答：从同一个位置接着放。
    final handoff = AiRevealHandoff();
    await tester.pumpWidget(
      host(
        AiRevealedMarkdown(
          key: const ValueKey<String>('pending'),
          text: long,
          live: true,
          handoff: handoff,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(handoff.shown, greaterThan(0));
    expect(handoff.shown, lessThan(long.length));
    final carried = handoff.shown;

    await tester.pumpWidget(
      host(
        AiRevealedMarkdown(
          key: const ValueKey<String>('saved'),
          text: long,
          live: false,
          handoff: handoff,
        ),
      ),
    );
    expect(handoff.shown, greaterThanOrEqualTo(carried));
    expect(find.textContaining('第39句话', findRichText: true), findsNothing);
    await tester.pumpAndSettle();
    expect(find.textContaining('第39句话', findRichText: true), findsOneWidget);
  });

  testWidgets('with reduced motion text is shown as it arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(AiRevealedMarkdown(text: long, live: true), reduceMotion: true),
    );
    expect(find.textContaining('第39句话', findRichText: true), findsOneWidget);
  });
}
