import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/feature_tips.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/controllers/tag_filter_pull_hint_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tip = FeatureTip.tagFilterPull;
  const showDelay = TagFilterPullHintController.showDelay;
  const visibleDuration = TagFilterPullHintController.visibleDuration;

  late SettingsService settings;
  late TagFilterPullHintController controller;
  final controllers = <TagFilterPullHintController>[];

  Future<void> setUpController(
    WidgetTester tester, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    settings = await SettingsService.create();
    controller = TagFilterPullHintController(vsync: const TestVSync());
    controllers.add(controller);
  }

  /// Disposes inside the test body: the pending-timer check runs before
  /// tear-downs, and no widget tree owns these controllers.
  void hintTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        for (final controller in controllers) {
          controller.dispose();
        }
        controllers.clear();
      }
    });
  }

  /// `sync` only evaluates at the end of a frame, as it does from build.
  Future<void> sync(
    WidgetTester tester, {
    Animation<double>? reveal = kAlwaysCompleteAnimation,
    bool pageActive = true,
    bool reduceMotion = false,
  }) async {
    controller.sync(
      settings: settings,
      reveal: reveal,
      pageActive: pageActive,
      reduceMotion: reduceMotion,
    );
    await tester.pump();
  }

  FeatureTipRecord storedRecord() =>
      FeatureTips.decode(settings.featureTipsRaw).recordOf(tip);

  hintTest('shows after a pause, records the show and hides by itself', (
    tester,
  ) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester);

    await tester.pump(showDelay - const Duration(milliseconds: 1));
    expect(controller.visible, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.visible, isTrue);
    expect(storedRecord(), const FeatureTipRecord(shown: 1));

    await tester.pump(visibleDuration);
    expect(controller.visible, isFalse);

    // Once per page lifetime: later syncs never bring it back.
    await sync(tester);
    await tester.pump(showDelay * 2);
    expect(controller.visible, isFalse);
    expect(storedRecord().shown, 1);
  });

  hintTest('the peek dips once and settles back; reduced motion skips it', (
    tester,
  ) async {
    for (final reduceMotion in <bool>[false, true]) {
      await setUpController(tester);
      controller.reportHiddenTags(true);
      await sync(tester, reduceMotion: reduceMotion);
      await tester.pump(showDelay);
      expect(controller.visible, isTrue);

      var maxPeek = 0.0;
      for (var frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (controller.peek.value > maxPeek) maxPeek = controller.peek.value;
      }
      expect(maxPeek, reduceMotion ? 0 : greaterThan(0.9));
      expect(controller.peek.value, closeTo(0, 0.01));
      expect(controller.visible, isTrue);
    }
  });

  hintTest('waits for the launch reveal, and never shows outside Home', (
    tester,
  ) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester, reveal: null);
    await tester.pump(showDelay * 2);
    expect(controller.visible, isFalse);

    // The App lock holds the reveal at its start until it is unlocked.
    final reveal = AnimationController(vsync: const TestVSync());
    addTearDown(reveal.dispose);
    await sync(tester, reveal: reveal);
    await tester.pump(showDelay * 2);
    expect(controller.visible, isFalse);

    reveal.value = 1;
    await tester.pump(showDelay);
    expect(controller.visible, isTrue);
  });

  hintTest('needs hidden tags and an active page for the whole wait', (
    tester,
  ) async {
    await setUpController(tester);
    await sync(tester);
    await tester.pump(showDelay * 2);
    expect(controller.visible, isFalse, reason: 'every tag fits in one row');

    controller.reportHiddenTags(true);
    await tester.pump(showDelay ~/ 2);
    await sync(tester, pageActive: false);
    await tester.pump(showDelay);
    expect(controller.visible, isFalse, reason: 'left the page mid-wait');

    await sync(tester);
    await tester.pump(showDelay);
    expect(controller.visible, isTrue);

    controller.reportHiddenTags(false);
    expect(controller.visible, isFalse);
    expect(storedRecord().shown, 1);
  });

  hintTest('hides at once when the page stops being active', (tester) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester);
    await tester.pump(showDelay);
    expect(controller.visible, isTrue);

    await sync(tester, pageActive: false);
    expect(controller.visible, isFalse);
  });

  hintTest('expanding the bar is learned for good, even before any hint', (
    tester,
  ) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester);
    controller.handleExpanded();
    await tester.pump(showDelay * 2);

    expect(controller.visible, isFalse);
    expect(storedRecord(), const FeatureTipRecord(learned: true));
  });

  hintTest('expanding while the hint shows hides it and records it', (
    tester,
  ) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester);
    await tester.pump(showDelay);
    expect(controller.visible, isTrue);

    controller.handleExpanded();
    expect(controller.visible, isFalse);
    expect(storedRecord(), const FeatureTipRecord(learned: true, shown: 1));
  });

  for (final prefs in <String, String>{
    'learned': '{"tagFilterPull":{"learned":true,"shown":0}}',
    'shown three times': '{"tagFilterPull":{"learned":false,"shown":3}}',
  }.entries) {
    hintTest('stays away once ${prefs.key}', (tester) async {
      await setUpController(
        tester,
        prefs: <String, Object>{'app.settings.feature_tips': prefs.value},
      );
      controller.reportHiddenTags(true);
      await sync(tester);
      await tester.pump(showDelay * 2);
      expect(controller.visible, isFalse);
    });
  }

  hintTest('interaction postpones a pending hint and dismisses a shown one', (
    tester,
  ) async {
    await setUpController(tester);
    controller.reportHiddenTags(true);
    await sync(tester);

    await tester.pump(showDelay - const Duration(milliseconds: 100));
    controller.handleUserInteraction();
    await tester.pump(showDelay - const Duration(milliseconds: 100));
    expect(controller.visible, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.visible, isTrue);

    controller.handleUserInteraction();
    expect(controller.visible, isFalse);
    await sync(tester);
    await tester.pump(showDelay * 2);
    expect(controller.visible, isFalse);
  });

  testWidgets('disposing cancels pending timers', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    settings = await SettingsService.create();
    final disposable = TagFilterPullHintController(vsync: const TestVSync());
    var notified = false;
    disposable.addListener(() => notified = true);
    disposable.reportHiddenTags(true);
    disposable.sync(
      settings: settings,
      reveal: kAlwaysCompleteAnimation,
      pageActive: true,
      reduceMotion: false,
    );
    await tester.pump();
    disposable.dispose();

    await tester.pump(showDelay * 2);
    expect(notified, isFalse);
    expect(settings.featureTipsRaw, isNull);
  });
}
