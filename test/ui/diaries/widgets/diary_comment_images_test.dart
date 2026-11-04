import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_comment_images_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_image_strip.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_images.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_item.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comments_section.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../support/expressive_test_theme.dart';

/// 留言图片的界面：写留言面板里选图、移除与“只有图片也能保存”，时间线上
/// 的拼贴、点开看图，以及只有图片的留言没有“复制”。
void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_comment_images_');
  });
  tearDown(() => root.delete(recursive: true));

  Widget app(Widget home) => MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  AppLocalizations l10nOf(WidgetTester tester, Type type) =>
      tester.element(find.byType(type)).l10n;

  group('writing', () {
    late List<String> discarded;
    late DiaryCommentImagesController images;
    setUp(() {
      discarded = <String>[];
      images = DiaryCommentImagesController(
        picker: () async => <PlatformFile>[
          for (final name in <String>['a', 'b'])
            PlatformFile(name: '$name.jpg', size: 1, path: '/picked/$name.jpg'),
        ],
        importer: (file) async => '${root.path}/diary_images/m/${file.name}',
        discarder: (path) async => discarded.add(path),
      );
    });
    tearDown(() => images.dispose());

    Future<DiaryCommentDraft?> Function() openSheet(WidgetTester tester) {
      DiaryCommentDraft? result;
      var done = false;
      final context = tester.element(find.byType(Scaffold));
      showDiaryCommentSheet(
        context,
        title: 'Write',
        moodOptions: const <String>['🙂'],
        imagesController: images,
      ).then((draft) {
        result = draft;
        done = true;
      });
      return () async {
        expect(done, isTrue, reason: 'the sheet should have closed');
        return result;
      };
    }

    testWidgets('a photo-only comment can be saved with its photos', (
      tester,
    ) async {
      await tester.pumpWidget(app(const Scaffold()));
      final result = openSheet(tester);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester, DiaryCommentSheet);

      FilledButton save() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.commonSave),
      );
      expect(save().onPressed, isNull);
      expect(find.byType(DiaryCommentImageStrip), findsNothing);

      await tester.tap(find.text(l10n.diaryCommentAddImages));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryCommentImageStrip), findsOneWidget);
      expect(find.text('${l10n.diaryCommentAddImages} 2/9'), findsOneWidget);
      expect(save().onPressed, isNotNull);

      // 移除一张：本次新复制的立即删掉文件。
      await tester.tap(find.byTooltip(l10n.diaryCommentImageRemove).first);
      await tester.pumpAndSettle();
      expect(discarded, <String>['${root.path}/diary_images/m/a.jpg']);
      expect(find.text('${l10n.diaryCommentAddImages} 1/9'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
      await tester.pumpAndSettle();
      final draft = await result();
      expect(draft!.content, '');
      expect(draft.images, <String>['${root.path}/diary_images/m/b.jpg']);
      expect(draft.freshImages, draft.images);
    });

    testWidgets('picking more than fits says the extra ones were skipped', (
      tester,
    ) async {
      images.dispose();
      images = DiaryCommentImagesController(
        initial: <String>[
          for (var i = 0; i < 8; i++) '/m/diary_images/o$i.jpg',
        ],
        picker: () async => <PlatformFile>[
          for (var i = 0; i < 3; i++)
            PlatformFile(name: 'n$i.jpg', size: 1, path: '/picked/n$i.jpg'),
        ],
        importer: (file) async => '${root.path}/diary_images/m/${file.name}',
        discarder: (path) async => discarded.add(path),
      );
      await tester.pumpWidget(app(const Scaffold()));
      openSheet(tester);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester, DiaryCommentSheet);

      await tester.tap(find.text('${l10n.diaryCommentAddImages} 8/9'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.diaryCommentImagesTruncated(9)), findsOneWidget);
      final add = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('${l10n.diaryCommentAddImages} 9/9'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(add.onPressed, isNull);
    });
  });

  group('reading', () {
    DiaryCommentRow comment({String content = '', int photos = 3}) =>
        DiaryCommentRow(
          id: 1,
          commentId: 'c1',
          diaryId: 'd1',
          content: content,
          createdAt: DateTime(2026, 5, 2, 21),
          images: encodeDiaryCommentImages(<String>[
            for (var i = 0; i < photos; i++) '${root.path}/missing_$i.jpg',
          ]),
        );

    Future<List<String>> pumpItem(
      WidgetTester tester,
      DiaryCommentRow row,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: DiaryCommentItem(
                  comment: row,
                  diaryCreatedAt: DateTime(2026, 5, 1),
                  actions: DiaryCommentActions(
                    onWrite: () {},
                    onEdit: (_) => calls.add('edit'),
                    onCopy: (_) => calls.add('copy'),
                    onDelete: (_) => calls.add('delete'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('photos sit under the text as an album', (tester) async {
      await pumpItem(tester, comment(content: 'Back again', photos: 3));
      final l10n = l10nOf(tester, DiaryCommentItem);
      expect(find.text('Back again'), findsOneWidget);
      expect(find.byType(DiaryCommentImages), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.diaryCommentImageLabel(1, 3)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.diaryCommentImageLabel(3, 3)),
        findsOneWidget,
      );
    });

    testWidgets('tapping a photo opens the viewer on it', (tester) async {
      await pumpItem(tester, comment(photos: 2));
      final l10n = l10nOf(tester, DiaryCommentItem);
      await tester.tap(
        find.bySemanticsLabel(l10n.diaryCommentImageLabel(2, 2)),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      expect(viewer.initialIndex, 1);
      expect(viewer.items.map((item) => item.source), <String>[
        '${root.path}/missing_0.jpg',
        '${root.path}/missing_1.jpg',
      ]);
    });

    testWidgets('a photo-only comment has no Copy in its menu', (tester) async {
      await pumpItem(tester, comment(photos: 1));
      final l10n = l10nOf(tester, DiaryCommentItem);
      await tester.longPress(find.byType(DiaryCommentItem));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonEdit), findsOneWidget);
      expect(find.text(l10n.diaryCommentCopy), findsNothing);
      expect(find.text(l10n.commonDelete), findsOneWidget);
    });
  });
}
