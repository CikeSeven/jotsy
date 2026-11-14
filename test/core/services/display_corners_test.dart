import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/display_corners.dart';

// DisplayCorners：读屏幕自带的圆角并换算成逻辑像素；读不到时保持直角或上次
// 的值；只在窗口尺寸变化时重读。

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Object?> replies;
  late int calls;

  void mockChannel(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DisplayCorners.channel,
      (call) async {
        expect(call.method, 'radii');
        calls++;
        final reply = replies.isEmpty ? null : replies.removeAt(0);
        if (reply is PlatformException) {
          throw reply;
        }
        return reply;
      },
    );
  }

  setUp(() {
    replies = <Object?>[];
    calls = 0;
    DisplayCorners.debugReset();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DisplayCorners.channel, null);
    DisplayCorners.debugReset();
  });

  testWidgets('reads the window corners in logical pixels', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    mockChannel(tester.binding);
    replies.add(<double>[170, 170, 150, 150]);

    await DisplayCorners.refresh();

    expect(
      DisplayCorners.radii,
      const BorderRadius.only(
        topLeft: Radius.circular(170 / 3),
        topRight: Radius.circular(170 / 3),
        bottomRight: Radius.circular(50),
        bottomLeft: Radius.circular(50),
      ),
    );
  });

  testWidgets('keeps square corners when the window reports none', (
    tester,
  ) async {
    mockChannel(tester.binding);
    replies.add(null);

    await DisplayCorners.refresh();

    expect(DisplayCorners.radii, BorderRadius.zero);
  });

  testWidgets('a failing read keeps the last known corners', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    mockChannel(tester.binding);
    replies
      ..add(<double>[80, 80, 80, 80])
      ..add(PlatformException(code: 'boom'));

    await DisplayCorners.refresh();
    await DisplayCorners.refresh();

    expect(DisplayCorners.radii, BorderRadius.circular(40));
  });

  testWidgets('only a window size change reads the corners again', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mockChannel(tester.binding);
    replies.add(<double>[10, 10, 10, 10]);

    DisplayCorners.start();
    DisplayCorners.start();
    await tester.pump();
    expect(calls, 1);
    expect(DisplayCorners.radii, BorderRadius.circular(10));

    // 键盘升降只改 viewInsets：不重读。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(calls, 1);

    // 旋转 / 分屏改了窗口尺寸：重读。
    replies.add(<double>[0, 0, 10, 10]);
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pump();
    expect(calls, 2);
    expect(
      DisplayCorners.radii,
      const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    );
  });

  testWidgets('other platforms never ask for the corners', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    mockChannel(tester.binding);

    DisplayCorners.start();
    await tester.pump();

    expect(calls, 0);
    expect(DisplayCorners.radii, BorderRadius.zero);
    debugDefaultTargetPlatformOverride = null;
  });
}
