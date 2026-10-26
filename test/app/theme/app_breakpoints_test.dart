import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_breakpoints.dart';
import 'package:node_diary/app/theme/theme.dart';

void main() {
  group('AppBreakpoints.classOf', () {
    test('widths below 600 are compact', () {
      expect(AppBreakpoints.classOf(0), AppWindowClass.compact);
      expect(AppBreakpoints.classOf(320), AppWindowClass.compact);
      expect(AppBreakpoints.classOf(599.9), AppWindowClass.compact);
    });

    test(
      '600 up to 1024 is medium and boundaries belong to the wider class',
      () {
        expect(AppBreakpoints.classOf(600), AppWindowClass.medium);
        expect(AppBreakpoints.classOf(800), AppWindowClass.medium);
        expect(AppBreakpoints.classOf(1023.9), AppWindowClass.medium);
        expect(AppBreakpoints.classOf(1024), AppWindowClass.expanded);
        expect(AppBreakpoints.classOf(1920), AppWindowClass.expanded);
      },
    );

    test('only compact is not wide', () {
      expect(AppWindowClass.compact.isWide, isFalse);
      expect(AppWindowClass.medium.isWide, isTrue);
      expect(AppWindowClass.expanded.isWide, isTrue);
    });
  });

  testWidgets('AppBreakpoints.of reads the logical window width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppWindowClass windowClass;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          windowClass = AppBreakpoints.of(context);
          return const SizedBox();
        },
      ),
    );
    // 1280 物理像素 / 2 = 640 逻辑像素。
    expect(windowClass, AppWindowClass.medium);
  });

  group('AppContentWidth.gutter', () {
    test('centres the content when the area is wider than the max width', () {
      expect(AppContentWidth.gutter(1200, 720), 240);
    });

    test('never goes below the minimum gutter', () {
      expect(AppContentWidth.gutter(400, 720), 16);
      expect(AppContentWidth.gutter(740, 720), 16);
      expect(AppContentWidth.gutter(400, 720, minGutter: 0), 0);
      expect(AppContentWidth.gutter(800, 720, minGutter: 24), 40);
    });
  });

  group('CenteredContent', () {
    const childKey = Key('child');

    Future<Size> pumpWithin(WidgetTester tester, double width) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: width,
            height: 300,
            child: const CenteredContent(
              maxWidth: 720,
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );
      return tester.getSize(find.byKey(childKey));
    }

    testWidgets('caps the width, centres it and keeps the parent height', (
      tester,
    ) async {
      expect(await pumpWithin(tester, 1200), const Size(720, 300));
      // 窗口 1400 中居中放 1200 的区域（左 100），内容再居中（左 +240）。
      expect(tester.getTopLeft(find.byKey(childKey)).dx, 340);
    });

    testWidgets('fills areas narrower than the max width', (tester) async {
      expect(await pumpWithin(tester, 500), const Size(500, 300));
    });
  });

  test('the app theme uses standard visual density on every platform', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final theme = buildSeededAppTheme(
          const Color(0xff1e6586),
          Brightness.light,
        );
        expect(
          theme.visualDensity,
          VisualDensity.standard,
          reason: '$platform',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });
}
