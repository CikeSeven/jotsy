import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_morph.dart';
import 'package:node_diary/ui/diaries/widgets/draft_count_badge.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_anchor.dart';
import 'package:node_diary/ui/widgets/container_transform/morph_landing.dart';

/// 草稿箱份数角标：逐位滚动、弹性出现，整页落进来之前扣住旧份数。
void main() {
  const badgeKey = ValueKey<String>('badge');
  const iconKey = ValueKey<String>('icon');
  late ModalRoute<Object?> route;

  Future<void> pumpBadge(WidgetTester tester, int count) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          route = ModalRoute.of(context)!;
          return Scaffold(
            body: Center(
              child: DraftCountBadge(
                key: badgeKey,
                count: count,
                child: const SizedBox(key: iconKey, width: 18, height: 18),
              ),
            ),
          );
        },
      ),
    ),
  );

  Finder label(String text) =>
      find.descendant(of: find.byKey(badgeKey), matching: find.text(text));

  MorphLandingSession beginLanding() => MorphLandingSession.begin(
    candidates: const <MorphLanding>[
      MorphAnchorLanding(DiaryCreateMorph.draftsBadge),
    ],
    originRoute: route,
  );

  testWidgets('labels hide zero and cap at 99+', (tester) async {
    expect(DraftCountBadge.labelFor(0), '');
    expect(DraftCountBadge.labelFor(7), '7');
    expect(DraftCountBadge.labelFor(100), '99+');
  });

  testWidgets('a changed count rolls only the digits that changed', (
    tester,
  ) async {
    await pumpBadge(tester, 12);
    expect(label('12'), findsOneWidget);

    await pumpBadge(tester, 13);
    await tester.pump(const Duration(milliseconds: 40));
    // 十位的“1”不动，个位的“2”滑出、“3”滑入。
    expect(label('1'), findsOneWidget);
    expect(label('2'), findsOneWidget);
    expect(label('3'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(label('13'), findsOneWidget);
    expect(label('2'), findsNothing);
  });

  testWidgets('the empty badge sits where the first count will show', (
    tester,
  ) async {
    await pumpBadge(tester, 0);
    final target = MorphAnchor.locate(
      DiaryCreateMorph.draftsBadge,
      route: route,
    )!;
    final icon = tester.getRect(find.byKey(iconKey));
    // 与 Material 3 大号 Badge 同一位置：左缘距图标右缘 12，高出图标 4。
    expect(target.rect.size, const Size(16, 16));
    expect(target.rect.left, icon.right - 12);
    expect(target.rect.top, icon.top - 4);
  });

  testWidgets('a landing holds the old count until it lands, then rolls', (
    tester,
  ) async {
    await pumpBadge(tester, 0);
    final session = beginLanding();
    await pumpBadge(tester, 1);
    await tester.pumpAndSettle();
    // 草稿已经写进去了，但整页还没落下：角标仍是空的。
    expect(label('1'), findsNothing);

    session.startLanding(
      const MorphAnchorLanding(DiaryCreateMorph.draftsBadge),
    );
    session.finish(landed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // 胶囊已由整页收成，直接在；“1”正从下面滚进来。
    final pill = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(badgeKey),
            matching: find.byType(Transform),
          )
          .last,
    );
    expect(pill.transform.getMaxScaleOnAxis(), greaterThan(0.9));
    expect(label('1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(label('1'), findsOneWidget);
  });

  testWidgets('a landing elsewhere releases the held count normally', (
    tester,
  ) async {
    await pumpBadge(tester, 2);
    final session = beginLanding();
    await pumpBadge(tester, 3);
    await tester.pumpAndSettle();
    expect(label('2'), findsOneWidget);

    session.finish(landed: false);
    await tester.pumpAndSettle();
    expect(label('3'), findsOneWidget);
  });

  testWidgets('dropping to zero shrinks the badge away', (tester) async {
    await pumpBadge(tester, 1);
    await pumpBadge(tester, 0);
    await tester.pumpAndSettle();
    final visibility = tester.widget<Visibility>(
      find.descendant(
        of: find.byKey(badgeKey),
        matching: find.byType(Visibility),
      ),
    );
    expect(visibility.visible, isFalse);
  });
}
