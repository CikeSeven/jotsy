import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/app_surface/app_surface_focus_viewfinder.dart';

import '../../support/expressive_test_theme.dart';

/// 焦点取景器：框按原图比例、限高；按下即接管手势（在纵向列表里拖动也
/// 不会被滚动抢走），拖动中只预览、松手提交一次，点按直接提交。
void main() {
  late List<Offset> previews;
  late List<Offset> commits;

  Future<void> pump(
    WidgetTester tester, {
    Size imageSize = const Size(400, 200),
  }) {
    previews = <Offset>[];
    commits = <Offset>[];
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              const SizedBox(height: 100),
              AppSurfaceFocusViewfinder(
                // 文件不存在：图片走 errorBuilder，手势与圆环照常。
                file: File('/nonexistent/app_surface_focus.png'),
                imageSize: imageSize,
                alignX: 0,
                alignY: 0,
                onPreview: (double x, double y) => previews.add(Offset(x, y)),
                onCommit: (double x, double y) => commits.add(Offset(x, y)),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
  }

  Finder box() => find.byType(ClipRRect).first;

  testWidgets('frame keeps the image ratio within the max height', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.getSize(box()), const Size(400, 200));
    await pump(tester, imageSize: const Size(100, 400));
    expect(
      tester.getSize(box()),
      const Size(50, AppSurfaceFocusViewfinder.maxHeight),
    );
  });

  testWidgets('tap commits the tapped point', (tester) async {
    await pump(tester);
    final rect = tester.getRect(box());
    await tester.tapAt(rect.topLeft + const Offset(100, 150));
    await tester.pump();
    expect(commits, <Offset>[const Offset(-0.5, 0.5)]);
  });

  testWidgets('vertical drag previews, release commits, list stays put', (
    tester,
  ) async {
    await pump(tester);
    final rect = tester.getRect(box());
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(commits, isEmpty, reason: '拖动中只预览');
    expect(previews.last, const Offset(0, -0.8));
    await gesture.up();
    await tester.pump();
    expect(commits, <Offset>[const Offset(0, -0.8)]);
    // 列表没有被拖动。
    expect(tester.getRect(box()), rect);
    // 拖出框外夹在边缘。
    final again = await tester.startGesture(rect.center);
    await again.moveBy(const Offset(-500, 0));
    await again.up();
    await tester.pump();
    expect(commits.last, const Offset(-1, 0));
  });
}
