import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_switcher_controller.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_deck_entries.dart';

/// 卡组状态机：拉动距离 → 武装（只震一次）→ 松手打开 / 收回，往回甩取消，
/// 选中时先验证再提交并收进切换胶囊，验证未通过时卡组留着。
void main() {
  late _FakeHost host;
  late _FakeDeck deck;
  late NotebookSwitcherController controller;
  late List<Object?> haptics;

  Future<void> setUpController(WidgetTester tester, {Rect? chip}) async {
    haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            host = _FakeHost(context, chip: chip);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    controller = NotebookSwitcherController(vsync: tester, host: host);
    deck = _FakeDeck();
    controller.attachDeck(deck);
    addTearDown(controller.dispose);
  }

  /// 从 x = 60 处按下，往右拉 [distance]（逐步，跟手）。
  void pull(double distance) {
    controller.dragStart(
      const Offset(60, 400),
      textDirection: TextDirection.ltr,
    );
    var moved = 0.0;
    while (moved < distance) {
      final step = (distance - moved).clamp(0.0, 8.0);
      moved += step;
      controller.dragUpdate(Offset(60 + moved, 400), step);
    }
  }

  testWidgets('crossing the threshold arms once and opens on release', (
    tester,
  ) async {
    await setUpController(tester);
    pull(NotebookSwitcherController.armDistance - 8);
    expect(haptics, isEmpty);
    expect(controller.stage.value, lessThan(1));
    controller.dragUpdate(const Offset(130, 400), 16);
    expect(haptics, hasLength(1));
    // 拉回阈值以内不再震，再拉过去才震第二次。
    controller.dragUpdate(const Offset(110, 400), -20);
    controller.dragUpdate(const Offset(130, 400), 20);
    expect(haptics, hasLength(2));

    controller.dragEnd(0);
    expect(controller.phase, NotebookSwitcherPhase.open);
    await tester.pumpAndSettle();
    expect(controller.stage.value, 2);
    expect(controller.portal.isShowing, isTrue);
  });

  testWidgets('releasing before the threshold springs back and hides', (
    tester,
  ) async {
    await setUpController(tester);
    pull(40);
    expect(controller.isVisible, isTrue);
    controller.dragEnd(0);
    await tester.pumpAndSettle();
    expect(controller.phase, NotebookSwitcherPhase.idle);
    expect(controller.portal.isShowing, isFalse);
  });

  testWidgets('a fling back cancels even when armed', (tester) async {
    await setUpController(tester);
    pull(120);
    controller.dragEnd(-800);
    await tester.pumpAndSettle();
    expect(controller.phase, NotebookSwitcherPhase.idle);
  });

  testWidgets('a short room on the right shortens the growing stretch', (
    tester,
  ) async {
    await setUpController(tester);
    // 列表栏 400 宽，从 300 处起手：剩下的距离不够默认的 160。
    controller.dragStart(
      const Offset(300, 400),
      textDirection: TextDirection.ltr,
    );
    controller.dragUpdate(const Offset(380, 400), 80);
    expect(controller.stage.value, greaterThan(1));
    controller.dragUpdate(
      const Offset(460, 400),
      NotebookSwitcherController.shortestSpan,
    );
    expect(controller.stage.value, greaterThanOrEqualTo(2));
    controller.dragCancel();
    await tester.pumpAndSettle();
  });

  testWidgets('selecting authorizes, commits and lands in the chip', (
    tester,
  ) async {
    await setUpController(tester, chip: const Rect.fromLTWH(16, 60, 90, 28));
    pull(260);
    controller.dragEnd(0);
    await tester.pumpAndSettle();
    final entry = const NotebookDeckEntry.unfiled();
    final selecting = controller.select(entry);
    expect(deck.pulled, entry.key);
    await selecting;
    expect(host.authorized, <String>[entry.key]);
    expect(host.committed, <String>[entry.key]);
    expect(controller.origin, NotebookSwitcherOrigin.chip);
    expect(controller.chipHidden.value, isTrue);
    await tester.pumpAndSettle();
    expect(controller.phase, NotebookSwitcherPhase.idle);
    expect(controller.chipHidden.value, isFalse);
    expect(controller.chipBounce.value, closeTo(1, 1e-3));
  });

  testWidgets('a denied selection shakes the card and keeps the deck', (
    tester,
  ) async {
    await setUpController(tester);
    host.allow = false;
    pull(260);
    controller.dragEnd(0);
    await tester.pumpAndSettle();
    await controller.select(const NotebookDeckEntry.unfiled());
    expect(host.committed, isEmpty);
    expect(deck.shaken, <String>[NotebookDeckEntry.unfiledKey]);
    expect(deck.pulled, isNull);
    expect(controller.phase, NotebookSwitcherPhase.open);
  });

  testWidgets('picking the current scope only closes', (tester) async {
    await setUpController(tester);
    pull(260);
    controller.dragEnd(0);
    await tester.pumpAndSettle();
    await controller.select(const NotebookDeckEntry.all());
    expect(host.authorized, isEmpty);
    await tester.pumpAndSettle();
    expect(controller.phase, NotebookSwitcherPhase.idle);
    expect(host.committed, isEmpty);
  });
}

class _FakeHost implements NotebookSwitcherHost {
  _FakeHost(this.context, {this.chip});

  @override
  final BuildContext context;
  final Rect? chip;
  bool allow = true;
  final List<String> authorized = <String>[];
  final List<String> committed = <String>[];

  @override
  Rect? get paneRect => const Rect.fromLTWH(0, 0, 400, 800);

  @override
  double? get searchBarBottom => 50;

  @override
  Rect? get chipRect => chip;

  @override
  bool isCurrent(NotebookDeckEntry entry) =>
      entry.kind == NotebookDeckEntryKind.all;

  @override
  Future<bool> authorize(NotebookDeckEntry entry) async {
    authorized.add(entry.key);
    return allow;
  }

  @override
  void commit(NotebookDeckEntry entry) => committed.add(entry.key);
}

class _FakeDeck implements NotebookDeckHandle {
  String? pulled;
  final List<String> shaken = <String>[];

  @override
  NotebookDeckEntry? entryAt(Offset position) => null;

  @override
  void autoScroll(Offset? position) {}

  @override
  void lift(String? key) {}

  @override
  void pullOut(String? key) => pulled = key;

  @override
  void shake(String key) => shaken.add(key);

  @override
  bool closeMenu() => false;
}
