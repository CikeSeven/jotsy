import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/models/notebook_icon.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover_tile.dart';

import 'notebook_test_support.dart';

/// 日记本封面：角标随状态变化、封面文件缺失时照常显示、小封面与新建格子。
void main() {
  Widget tile({
    NotebookKind kind = NotebookKind.manual,
    NotebookVisibility visibility = NotebookVisibility.normal,
    String? coverPath,
    int? count = 23,
    bool closed = false,
  }) {
    return Center(
      child: SizedBox(
        width: 132,
        child: NotebookCoverTile(
          name: '旅行',
          icon: NotebookIcon.plane,
          count: count,
          kind: kind,
          visibility: visibility,
          coverPath: coverPath,
          closed: closed,
          onTap: () {},
        ),
      ),
    );
  }

  Finder icon(FaIconData data) => find.byIcon(data.data);

  testWidgets('shows name, count and the notebook icon', (tester) async {
    await tester.pumpWidget(notebookTestApp(tile()));
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('23 篇'), findsOneWidget);
    expect(icon(FontAwesomeIcons.plane), findsOneWidget);
    expect(icon(FontAwesomeIcons.lock), findsNothing);
    expect(icon(FontAwesomeIcons.eyeSlash), findsNothing);
    expect(icon(FontAwesomeIcons.wandMagicSparkles), findsNothing);
  });

  testWidgets('hides the count line when the count is null', (tester) async {
    await tester.pumpWidget(notebookTestApp(tile(count: null)));
    expect(find.textContaining('篇'), findsNothing);
  });

  testWidgets('shows one badge per state', (tester) async {
    await tester.pumpWidget(
      notebookTestApp(tile(visibility: NotebookVisibility.locked)),
    );
    expect(icon(FontAwesomeIcons.lock), findsOneWidget);

    await tester.pumpWidget(
      notebookTestApp(tile(visibility: NotebookVisibility.hidden)),
    );
    expect(icon(FontAwesomeIcons.lock), findsNothing);
    expect(icon(FontAwesomeIcons.eyeSlash), findsOneWidget);

    await tester.pumpWidget(notebookTestApp(tile(kind: NotebookKind.smart)));
    expect(icon(FontAwesomeIcons.eyeSlash), findsNothing);
    expect(icon(FontAwesomeIcons.wandMagicSparkles), findsOneWidget);
  });

  testWidgets('renders without crashing when the cover file is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      notebookTestApp(tile(coverPath: '/nonexistent/notebook_cover.jpg')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('旅行'), findsOneWidget);
    expect(icon(FontAwesomeIcons.plane), findsOneWidget);
  });

  testWidgets('closed notebooks are dimmed', (tester) async {
    await tester.pumpWidget(notebookTestApp(tile(closed: true)));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('旅行'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0.6);
  });

  testWidgets('semantics label reads name, count and state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      notebookTestApp(tile(visibility: NotebookVisibility.locked)),
    );
    expect(find.bySemanticsLabel('旅行，23 篇，上锁'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('mini and create variants render', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      notebookTestApp(
        Column(
          children: <Widget>[
            const NotebookCoverTile.mini(icon: NotebookIcon.heart),
            SizedBox(
              width: 120,
              child: NotebookCoverTile.create(onTap: () => tapped = true),
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(NotebookCoverTile).first),
      const Size(44, 56),
    );
    expect(icon(FontAwesomeIcons.solidHeart), findsOneWidget);
    await tester.tap(find.text('新建日记本'));
    expect(tapped, isTrue);
  });

  testWidgets('dark theme renders the tile', (tester) async {
    await tester.pumpWidget(
      notebookTestApp(tile(), brightness: Brightness.dark),
    );
    expect(find.text('旅行'), findsOneWidget);
  });
}
