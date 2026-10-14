import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_live_voiceprint.dart';

void main() {
  group('layoutVoiceprintBars', () {
    const size = Size(200, 48);
    // 柱宽 3.5 + 间距 3 = 6.5/槽，200 宽放得下 30 个整槽。
    const slots = 30;

    List<VoiceprintBar> layout(
      List<double> samples, {
      int? count,
      double offset = 0,
    }) => layoutVoiceprintBars(
      samples: samples,
      count: count ?? samples.length,
      size: size,
      scrollOffset: offset,
    );

    test('draws one extra bar so scrolling never reveals an empty slot', () {
      expect(layout(const []), hasLength(slots + 1));
    });

    test('empty history is a row of baseline dots', () {
      final bars = layout(const []);
      expect(bars.any((bar) => bar.hasSample), isFalse);
      for (final bar in bars) {
        expect(bar.rect.width, bar.rect.height);
      }
    });

    test(
      'newest sample hugs the right edge and older ones sit to its left',
      () {
        final bars = layout(const [0.2, 0.5, 0.9]);
        final withSample = bars.where((bar) => bar.hasSample).toList();
        expect(withSample, hasLength(3));
        expect(bars.last.hasSample, isTrue);
        expect(bars.last.rect.right, lessThanOrEqualTo(size.width));
        expect(bars.last.rect.right, greaterThan(size.width - 13));
        // 自左向右 x 递增，样本顺序为旧→新。
        for (var i = 1; i < bars.length; i++) {
          expect(bars[i].rect.left, greaterThan(bars[i - 1].rect.left));
        }
        expect(
          withSample[2].rect.height,
          greaterThan(withSample[1].rect.height),
        );
        expect(
          withSample[1].rect.height,
          greaterThan(withSample[0].rect.height),
        );
      },
    );

    test('bars are vertically centered within the strip', () {
      for (final bar in layout(const [0.1, 0.6, 1.0])) {
        expect(bar.rect.center.dy, closeTo(size.height / 2, 1e-9));
      }
    });

    test('out-of-range amplitudes are clamped into the strip height', () {
      final bars = layout(const [-1, 2, 0.3]);
      for (final bar in bars.where((bar) => bar.hasSample)) {
        expect(bar.rect.height, inInclusiveRange(5.0, size.height));
      }
    });

    test('only the first `count` samples are used', () {
      // 实时列表在构建与绘制之间可能又长出新样本；画笔按构造时的快照绘制。
      final bars = layout(const [0.1, 0.2, 0.9], count: 2);
      expect(bars.where((bar) => bar.hasSample), hasLength(2));
      expect(
        bars.last.rect.height,
        lessThan(layout(const [0.1, 0.2, 0.9]).last.rect.height),
      );
    });

    test('scroll offset shifts every bar right by that many slots', () {
      final rest = layout(const [0.3, 0.6]);
      final scrolling = layout(const [0.3, 0.6], offset: 0.5);
      for (var i = 0; i < rest.length; i++) {
        expect(scrolling[i].rect.left - rest[i].rect.left, closeTo(3.25, 1e-9));
      }
    });

    test('the newest bar grows in while it slides into place', () {
      final entering = layout(const [0.8], offset: 1).last.rect.height;
      final half = layout(const [0.8], offset: 0.5).last.rect.height;
      final settled = layout(const [0.8]).last.rect.height;
      expect(entering, 5.0);
      expect(half, inExclusiveRange(entering, settled));
    });
  });

  group('LiveVoiceprintVisualizer', () {
    Widget host(List<double> samples, {bool active = true}) => MaterialApp(
      home: Scaffold(
        body: LiveVoiceprintVisualizer(samples: samples, active: active),
      ),
    );

    testWidgets('is calm when no new samples arrive', (tester) async {
      final samples = <double>[0.4, 0.5, 0.6];
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 300));
      // 没有新采样（暂停/安静）就不应持续出帧。
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a new sample scrolls in over one sample period', (
      tester,
    ) async {
      final samples = <double>[0.4, 0.5, 0.6];
      await tester.pumpWidget(host(samples));

      samples.add(0.7);
      await tester.pumpWidget(host(samples));
      await tester.pump(recordingAmplitudeSamplePeriod ~/ 4);
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump(recordingAmplitudeSamplePeriod * 2);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a burst of samples scrolls a bounded distance and settles', (
      tester,
    ) async {
      final samples = <double>[0.4];
      await tester.pumpWidget(host(samples));

      // 界面卡顿后一次到达很多采样：积压有上限，很快追平，不会长时间滑动。
      samples.addAll(List.filled(20, 0.5));
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduce motion never starts the scroll ticker', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final samples = <double>[0.4, 0.5];
      await tester.pumpWidget(host(samples));

      samples.add(0.9);
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a cleared history (new session) resets without errors', (
      tester,
    ) async {
      final samples = <double>[0.4, 0.5, 0.6];
      await tester.pumpWidget(host(samples));
      samples.add(0.8);
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 20));

      samples.clear();
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);

      // 清空后重新采样仍能正常滚动。
      samples.add(0.5);
      await tester.pumpWidget(host(samples));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('active bars use the primary color, inactive ones are muted', (
      tester,
    ) async {
      // 40 个采样、100dp 宽：每个槽位都有采样，画出来的全是柱子而不是基线圆点。
      final samples = List<double>.filled(40, 0.6);
      Widget narrow({required bool active}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: LiveVoiceprintVisualizer(samples: samples, active: active),
            ),
          ),
        ),
      );
      final paint = find.descendant(
        of: find.byType(LiveVoiceprintVisualizer),
        matching: find.byType(CustomPaint),
      );
      List<Color> drawnColors() {
        final drawn = <Color>[];
        expect(
          tester.renderObject(paint),
          paints..everything((method, arguments) {
            if (method == #drawRRect) drawn.add((arguments[1] as Paint).color);
            return true;
          }),
        );
        return drawn;
      }

      // 左缘的淡出只改透明度，色相必须保持；Paint.color 以 32 位浮点存储，
      // 与主题色逐位比较会有 1e-8 量级的舍入差，所以按通道容差比较。
      Matcher sameHue(Color expected) => predicate<Color>(
        (actual) =>
            (actual.r - expected.r).abs() < 1e-6 &&
            (actual.g - expected.g).abs() < 1e-6 &&
            (actual.b - expected.b).abs() < 1e-6,
        'has the same RGB as $expected',
      );

      await tester.pumpWidget(narrow(active: true));
      final colors = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme;
      final live = drawnColors();
      expect(live, isNotEmpty);
      expect(live, everyElement(sameHue(colors.primary)));
      expect(live.map((c) => c.a).reduce((a, b) => a > b ? a : b), 1.0);

      await tester.pumpWidget(narrow(active: false));
      await tester.pumpAndSettle();
      final frozen = drawnColors();
      expect(
        frozen,
        everyElement(sameHue(colors.onSurfaceVariant)),
        reason: 'paused bars stay visible but muted',
      );
      expect(
        frozen.map((c) => c.a).reduce((a, b) => a > b ? a : b),
        lessThan(0.5),
      );
    });
  });
}
