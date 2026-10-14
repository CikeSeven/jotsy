import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

import '../../../support/expressive_test_theme.dart';

/// 写一张 2:1 的真实 PNG 到临时目录，作为日记封面。
Future<String> _writeCover() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 200, 100),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(200, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = await Directory.systemTemp.createTemp('cover_hero_test');
  final file = File('${dir.path}/cover.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

DiaryWithTags _diary(String cover) {
  final now = DateTime(2026, 10, 14, 9);
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'hero-1',
      title: 'Harbour at dusk',
      content: '[{"insert":"Lights on the water\\n"}]',
      contentText: 'Lights on the water',
      metadata: '{}',
      cover: cover,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

class _DetailDatabase extends AppDatabase {
  _DetailDatabase(this.detail) : super.forTesting(NativeDatabase.memory());

  final DiaryWithTags detail;

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) async =>
      detail;
}

/// 飞行中的画面：圆角严格介于列表封面（16）与预览头图（0）之间的裁切层。
Iterable<ClipRRect> _flyingShuttles(WidgetTester tester) =>
    tester.widgetList<ClipRRect>(find.byType(ClipRRect)).where((clip) {
      final radius = (clip.borderRadius as BorderRadius).topLeft.x;
      return radius > 0.01 && radius < 15.99;
    });

/// 等真实文件读取与解码完成（离开假时钟）。
Future<void> _settleImages(WidgetTester tester, Finder images) async {
  for (var i = 0; i < 40; i++) {
    final decoded = images.evaluate().every((element) {
      final render = element.renderObject;
      return render is RenderImage && render.image != null;
    });
    if (decoded) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('list cover expands into the preview header and flies back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cover = (await tester.runAsync(_writeCover))!;
    final diary = _diary(cover);
    final database = _DetailDatabase(diary);
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: CustomScrollView(
                slivers: <Widget>[
                  DiariesListSection(
                    diaries: <DiaryWithTags>[diary],
                    layoutMode: DiaryLayoutMode.list,
                    selectedDiaryIds: const <String>{},
                    isSelectionMode: false,
                    maxVisibleTags: 3,
                    onCreate: () {},
                    onToggleSelection: (_, _) {},
                    onOpenEditor: (detail, coverHero) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DiaryPreviewPage(
                            diaryId: detail.diary.diaryId,
                            initialDetail: detail,
                            coverHero: coverHero,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester, find.byType(RawImage));
    expect(find.byType(ImageHero), findsOneWidget);

    // 按压墨水层叠在卡片内容之上，点击落在它身上（点文字会被前景层挡住）。
    await tester.tap(
      find.descendant(
        of: find.byType(DiariesListSection),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 封面从卡片原位展开，圆角从 16 补间到 0。
    expect(_flyingShuttles(tester), isNotEmpty);

    await tester.pumpAndSettle();
    expect(_flyingShuttles(tester), isEmpty);
    // 落地的头图盒子就是原图比例（2:1），入口画面垫底。
    final header = find.descendant(
      of: find.byType(DiaryPreviewPage),
      matching: find.byType(ImageHero),
    );
    final box = tester.getSize(header);
    expect(box.width / box.height, closeTo(2, 0.02));
    expect(
      find.descendant(of: header, matching: find.byType(RawImage)),
      findsWidgets,
    );

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_flyingShuttles(tester), isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('waterfall cover keeps the card rounded top corners at takeoff', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cover = (await tester.runAsync(_writeCover))!;
    final diary = _diary(cover);

    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              DiariesListSection(
                diaries: <DiaryWithTags>[diary],
                layoutMode: DiaryLayoutMode.waterfall,
                selectedDiaryIds: const <String>{},
                isSelectionMode: false,
                maxVisibleTags: 3,
                onCreate: () {},
                onToggleSelection: (_, _) {},
                onOpenEditor: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );
    await _settleImages(tester, find.byType(RawImage));

    // 封面贴着卡片顶边：上方两角被卡片裁圆、下方是直角，飞行从同样的形状起步。
    expect(
      tester.widget<ImageHero>(find.byType(ImageHero)).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
  });
}
