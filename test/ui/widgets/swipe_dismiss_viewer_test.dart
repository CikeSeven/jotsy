import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';

const _contentKey = ValueKey<String>('content');
const _viewport = Size(400, 800);

List<Object?> _recordHaptics(WidgetTester tester) {
  final calls = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments);
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
  return calls;
}

class _Host extends StatelessWidget {
  const _Host({
    required this.enabled,
    required this.onDismiss,
    required this.chromeOpacities,
  });

  final bool enabled;
  final VoidCallback onDismiss;
  final List<double> chromeOpacities;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _viewport,
          child: SwipeDismissViewer(
            enabled: enabled,
            onDismiss: onDismiss,
            child: const ColoredBox(key: _contentKey, color: Color(0xFF3366CC)),
            builder: (context, chromeOpacity, content) {
              chromeOpacities.add(chromeOpacity);
              return content;
            },
          ),
        ),
      ),
    );
  }
}

Offset _contentCenter(WidgetTester tester) =>
    tester.getCenter(find.byKey(_contentKey));

void main() {
  testWidgets('content follows the finger, shrinks and fades the chrome', (
    tester,
  ) async {
    final opacities = <double>[];
    await tester.pumpWidget(
      _Host(enabled: true, onDismiss: () {}, chromeOpacities: opacities),
    );
    final resting = _contentCenter(tester);

    final gesture = await tester.startGesture(resting);
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();

    expect(_contentCenter(tester).dy, greaterThan(resting.dy + 50));
    expect(tester.getSize(find.byKey(_contentKey)).width, _viewport.width);
    final box = tester.renderObject<RenderBox>(find.byKey(_contentKey));
    final scaledWidth =
        box.localToGlobal(Offset(_viewport.width, 0)).dx -
        box.localToGlobal(Offset.zero).dx;
    expect(scaledWidth, lessThan(_viewport.width));
    expect(opacities.last, inExclusiveRange(0, 1));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a short drag springs back without dismissing', (tester) async {
    final haptics = _recordHaptics(tester);
    var dismissed = 0;
    await tester.pumpWidget(
      _Host(
        enabled: true,
        onDismiss: () => dismissed++,
        chromeOpacities: <double>[],
      ),
    );
    final resting = _contentCenter(tester);

    final gesture = await tester.startGesture(resting);
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 500));
    final releaseY = _contentCenter(tester).dy;
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // 回弹是补间（spatial 弹簧，末段允许轻微越过原位），不是一帧跳回。
    expect(_contentCenter(tester).dy, inExclusiveRange(resting.dy, releaseY));

    await tester.pumpAndSettle();
    expect(_contentCenter(tester), resting);
    expect(dismissed, 0);
    expect(haptics, isEmpty);
  });

  testWidgets('dragging past the threshold dismisses once with a haptic', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    var dismissed = 0;
    await tester.pumpWidget(
      _Host(
        enabled: true,
        onDismiss: () => dismissed++,
        chromeOpacities: <double>[],
      ),
    );

    final gesture = await tester.startGesture(_contentCenter(tester));
    await gesture.moveBy(const Offset(0, 20));
    // 阈值为视口高度的 15%（120）。
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump(const Duration(milliseconds: 500));
    expect(haptics, <Object?>['HapticFeedbackType.lightImpact']);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 500));
    expect(haptics, hasLength(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('a quick downward fling dismisses before the threshold', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      _Host(
        enabled: true,
        onDismiss: () => dismissed++,
        chromeOpacities: <double>[],
      ),
    );

    await tester.fling(find.byKey(_contentKey), const Offset(0, 80), 1500);
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('disabled viewer leaves vertical drags alone', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      _Host(
        enabled: false,
        onDismiss: () => dismissed++,
        chromeOpacities: <double>[],
      ),
    );
    final resting = _contentCenter(tester);

    await tester.drag(find.byKey(_contentKey), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_contentCenter(tester), resting);
    expect(dismissed, 0);
  });
}
