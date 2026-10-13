import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';

void main() {
  testWidgets('cover decodes at a stable bounded size while collapsing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: const <Widget>[
              PublishDiaryCoverSliver(cover: '/missing-cover.png'),
              SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );

    ResizeImage currentProvider() =>
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final before = currentProvider();
    expect(before.policy, ResizeImagePolicy.fit);
    expect(before.width, isNotNull);
    expect(before.height, isNotNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
    await tester.pump();
    final during = currentProvider();
    // 收起过程中解码尺寸不变，ImageCache 命中而不是逐帧重新解码。
    expect(during, before);
    // 透明度作用在图片绘制上，不再整块 saveLayer。
    expect(
      find.descendant(
        of: find.byType(PublishDiaryCoverSliver),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(
      tester.widget<Image>(find.byType(Image)).opacity!.value,
      lessThan(1),
    );
  });
}
