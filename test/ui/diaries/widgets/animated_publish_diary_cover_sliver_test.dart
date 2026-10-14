import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/animated_publish_diary_cover_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';

Widget _host(String? cover) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: CustomScrollView(
      slivers: <Widget>[
        AnimatedPublishDiaryCoverSliver(cover: cover),
        const SliverToBoxAdapter(child: Text('Body')),
      ],
    ),
  ),
);

double _bodyTop(WidgetTester tester) => tester.getTopLeft(find.text('Body')).dy;

void main() {
  testWidgets('picked cover grows in and pushes the body down smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));
    final top = _bodyTop(tester);

    await tester.pumpWidget(_host('/missing-cover.png'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 过渡途中：正文在原位与完整头图高度之间，而不是一帧被推到底。
    expect(_bodyTop(tester), greaterThan(top));
    expect(_bodyTop(tester), lessThan(top + 220));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.opacity!.value, inExclusiveRange(0, 1));
    // 过渡期间解码尺寸按完整头图高度，不随可见高度逐帧变化。
    final decodeKey = image.image;

    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<Image>(find.byType(Image)).image, decodeKey);

    await tester.pumpAndSettle();
    expect(_bodyTop(tester), top + 220);

    // 清除封面：反向收起，期间仍绘制最后一张封面。
    await tester.pumpWidget(_host(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(PublishDiaryCoverSliver), findsOneWidget);
    expect(_bodyTop(tester), inExclusiveRange(top, top + 220));
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);
    expect(_bodyTop(tester), top);
  });

  testWidgets('cover present on entry shows at full height at once', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));
    final top = _bodyTop(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host('/missing-cover.png'));
    expect(_bodyTop(tester), top + 220);
  });

  testWidgets('cover appears without transition under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(null));
    final top = _bodyTop(tester);
    await tester.pumpWidget(_host('/missing-cover.png'));
    await tester.pump();
    expect(_bodyTop(tester), top + 220);
  });
}
