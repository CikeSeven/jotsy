import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_timeline_section.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

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
  final dir = await Directory.systemTemp.createTemp('timeline_hero_test');
  final file = File('${dir.path}/cover.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

void main() {
  testWidgets('calendar timeline hides locked capsule content', (tester) async {
    final now = DateTime.now();
    final diary = DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: 'capsule-calendar-1',
        title: 'Future letter',
        content: '[{"insert":"secret capsule words\\n"}]',
        contentText: 'secret capsule words',
        metadata: '{}',
        createdAt: now.add(const Duration(days: 30)),
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        capsuleLockedAt: now,
        capsuleUnlockAt: now.add(const Duration(days: 30)),
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CalendarTimelineSection(
            selectedDay: diary.diary.createdAt,
            diaries: <DiaryWithTags>[diary],
            onOpenDiary: (_, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('secret capsule words'), findsNothing);
    expect(find.text('30 天后解封'), findsOneWidget);
  });

  testWidgets(
    'calendar timeline cover thumbnail keeps source aspect ratio on decode',
    (tester) async {
      final now = DateTime(2026, 10, 5, 9);
      final diary = DiaryWithTags(
        diary: Diary(
          id: 2,
          diaryId: 'calendar-cover-1',
          title: 'With cover',
          content: '[{"insert":"body\\n"}]',
          contentText: 'body',
          metadata: '{}',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          isPinned: false,
          isDeleted: false,
          cover: '/calendar-cover.jpg',
        ),
        tags: const <Tag>[],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarTimelineSection(
              selectedDay: now,
              diaries: <DiaryWithTags>[diary],
              onOpenDiary: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 同时限定宽高会按 ResizeImagePolicy.exact 把非方形图压成正方形。
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, isNotNull);
      expect(resized.height, isNull);
    },
  );
  testWidgets('tapping an entry hands the thumbnail frame to the preview', (
    tester,
  ) async {
    final cover = (await tester.runAsync(_writeCover))!;
    final now = DateTime(2026, 10, 5, 9);
    final diary = DiaryWithTags(
      diary: Diary(
        id: 3,
        diaryId: 'calendar-hero-1',
        title: 'With hero',
        content: '[{"insert":"body\\n"}]',
        contentText: 'body',
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        isDeleted: false,
        cover: cover,
      ),
      tags: const <Tag>[],
    );
    ImageViewerHero? received;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CalendarTimelineSection(
            selectedDay: now,
            diaries: <DiaryWithTags>[diary],
            onOpenDiary: (_, hero) => received = hero,
          ),
        ),
      ),
    );
    // 等真实文件读取与解码完成（离开假时钟）。
    for (var i = 0; i < 40; i++) {
      final render = tester.renderObject<RenderImage>(find.byType(RawImage));
      if (render.image != null) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ImageHero), findsOneWidget);

    await tester.tap(find.text('body'));
    // 点按整张卡片也能从缩略图抓到画面：标签对应预览页头图，比例是原图比例。
    expect(received, isNotNull);
    expect(received!.tag, diaryCoverHeroTag('calendar-hero-1'));
    expect(received!.aspectRatio, closeTo(2, 0.05));
    received!.dispose();
  });
}
