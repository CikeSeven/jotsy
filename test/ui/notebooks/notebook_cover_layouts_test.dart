import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/models/notebook_icon.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover/notebook_cover_classic.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover/notebook_cover_texture.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover_tile.dart';

import 'notebook_test_support.dart';

/// 封面版式、纹理与取景：每种版式有图 / 无图在窄宽度下都能排下，默认样式
/// 保持改版前的组件树，纹理不盖在封面图上，自定义取景按对齐点与放大裁切。
void main() {
  final cover = File(
    'assets/img/diary_card_samples/seaside.webp',
  ).absolute.path;
  const longName = '一个名字很长很长很长很长很长的日记本';

  Widget tile(
    NotebookCoverStyle style, {
    double width = 132,
    String? coverPath,
    String name = longName,
    NotebookVisibility visibility = NotebookVisibility.locked,
  }) {
    return Center(
      child: SizedBox(
        width: width,
        child: NotebookCoverTile(
          name: name,
          icon: NotebookIcon.plane,
          count: 1234,
          coverPath: coverPath,
          style: style,
          visibility: visibility,
          onTap: () {},
        ),
      ),
    );
  }

  Finder texturePaint() => find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint && widget.painter is NotebookCoverTexturePainter,
  );

  for (final layout in NotebookCoverLayout.values) {
    for (final withImage in <bool>[false, true]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${layout.name} renders ${withImage ? 'with' : 'without'} an image '
          'at narrow widths in ${brightness.name}',
          (tester) async {
            for (final width in <double>[112, 132, 160]) {
              await tester.pumpWidget(
                notebookTestApp(
                  tile(
                    NotebookCoverStyle(
                      layout: layout,
                      texture: NotebookCoverTexture.grid,
                      focusX: 0.4,
                      zoom: 1.5,
                    ),
                    width: width,
                    coverPath: withImage ? cover : null,
                  ),
                  brightness: brightness,
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull, reason: 'width $width');
              expect(
                tester.getSize(find.byType(NotebookCoverTile)),
                Size(width, width / NotebookCoverTile.aspectRatio),
              );
              // 右上角角标在所有版式下都保留。
              expect(find.byIcon(FontAwesomeIcons.lock.data), findsOneWidget);
            }
            // 名称总在封面上（被截断时以省略号结尾）。
            expect(find.textContaining('一个名字'), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('default style keeps the classic tree without extras', (
    tester,
  ) async {
    await tester.pumpWidget(
      notebookTestApp(tile(NotebookCoverStyle.defaults, coverPath: cover)),
    );
    expect(find.byType(NotebookCoverBody), findsOneWidget);
    expect(find.byType(NotebookCoverSpine), findsNothing);
    expect(texturePaint(), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
    // 与改版前同样按显示宽度解码。
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    final dpr = tester.view.devicePixelRatio;
    expect(provider.width, (132 * dpr).round());
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('textures paint the cover color, never the image', (
    tester,
  ) async {
    await tester.pumpWidget(
      notebookTestApp(
        tile(
          NotebookCoverStyle(texture: NotebookCoverTexture.dots),
          coverPath: cover,
        ),
      ),
    );
    final paints = texturePaint();
    expect(paints, findsOneWidget);
    // 经典有图：纹理在下方文字区，不是封面图的祖先。
    expect(
      find.descendant(of: paints, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(of: paints, matching: find.textContaining('一个名字')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      notebookTestApp(
        tile(NotebookCoverStyle(texture: NotebookCoverTexture.diagonal)),
      ),
    );
    final painter =
        tester.widget<CustomPaint>(texturePaint()).painter!
            as NotebookCoverTexturePainter;
    expect(painter.texture, NotebookCoverTexture.diagonal);
  });

  testWidgets('custom crop zooms and aligns the image by the focus point', (
    tester,
  ) async {
    await tester.pumpWidget(
      notebookTestApp(
        tile(
          NotebookCoverStyle(focusX: -0.5, focusY: 0.25, zoom: 2),
          coverPath: cover,
        ),
      ),
    );
    final box = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(box.widthFactor, 2);
    expect(box.heightFactor, 2);
    expect(box.alignment, const Alignment(-0.5, 0.25));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, const Alignment(-0.5, 0.25));
    expect(image.fit, BoxFit.cover);
    expect(image.frameBuilder, isNotNull);
  });

  testWidgets('layouts keep their distinguishing parts', (tester) async {
    Future<void> pump(NotebookCoverLayout layout, {String? image}) =>
        tester.pumpWidget(
          notebookTestApp(
            tile(
              NotebookCoverStyle(layout: layout),
              coverPath: image,
              name: '旅行',
              visibility: NotebookVisibility.normal,
            ),
          ),
        );
    final plane = find.byIcon(FontAwesomeIcons.plane.data);

    await pump(NotebookCoverLayout.spine);
    expect(find.byType(NotebookCoverSpine), findsOneWidget);
    expect(plane, findsOneWidget);

    await pump(NotebookCoverLayout.minimal);
    expect(plane, findsNothing);
    expect(find.text('旅行'), findsOneWidget);

    await pump(NotebookCoverLayout.minimal, image: cover);
    expect(plane, findsNothing);
    expect(find.text('1234 篇'), findsOneWidget);

    await pump(NotebookCoverLayout.label, image: cover);
    expect(plane, findsOneWidget);
    final name = tester.widget<Text>(find.text('旅行'));
    expect(name.textAlign, TextAlign.center);

    await pump(NotebookCoverLayout.fullBleed, image: cover);
    // 满版：封面图铺满整张封面。
    expect(
      tester.getSize(find.byType(Image)),
      tester.getSize(find.byType(NotebookCoverTile)),
    );
  });

  testWidgets('mini covers render every layout at 44 by 56', (tester) async {
    for (final withImage in <bool>[false, true]) {
      await tester.pumpWidget(
        notebookTestApp(
          Wrap(
            children: <Widget>[
              for (final layout in NotebookCoverLayout.values)
                NotebookCoverTile.mini(
                  icon: NotebookIcon.plane,
                  coverPath: withImage ? cover : null,
                  style: NotebookCoverStyle(
                    layout: layout,
                    texture: NotebookCoverTexture.lines,
                    zoom: 2,
                  ),
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final element in find.byType(NotebookCoverTile).evaluate()) {
        expect(element.size, const Size(44, 56));
      }
      expect(find.byType(NotebookCoverSpine), findsOneWidget);
      // 极简不画图标；满版有图时图片铺满、只留底部实色条。
      expect(
        find.byIcon(FontAwesomeIcons.plane.data),
        findsNWidgets(withImage ? 3 : 4),
      );
    }
  });

  testWidgets('a default mini cover keeps the original icon-and-image tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      notebookTestApp(
        NotebookCoverTile.mini(icon: NotebookIcon.plane, coverPath: cover),
      ),
    );
    expect(texturePaint(), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(
      (provider as ResizeImage).width,
      (44 * tester.view.devicePixelRatio).round(),
    );
  });
}
