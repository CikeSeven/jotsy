import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_item.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页正文末尾的留言区：功能开关、写 / 改 / 删（撤销）、折叠与未解封的
/// 胶囊。用真实的内存数据库，写入经界面触发。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<DiaryWithTags> seed(WidgetTester tester, {DateTime? unlockAt}) async {
    return (await tester.runAsync(() async {
      final id = await db.createDiary(
        title: 'Beach day',
        contentDocJson: '[{"insert":"We went to the sea.\\n"}]',
        contentText: 'We went to the sea.',
        metadataJson: '{}',
        capsuleUnlockAt: unlockAt,
        capsuleLockedAt: unlockAt == null
            ? null
            : DateTime.now().subtract(const Duration(days: 1)),
      );
      return (await db.getDiaryWithTagsByDiaryId(id))!;
    }))!;
  }

  Future<AppLocalizations> pumpPreview(
    WidgetTester tester,
    DiaryWithTags diary, {
    required bool comments,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.app_features': AppFeatures(comments: comments).encode(),
    });
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewView(
            diaryId: diary.diary.diaryId,
            initialDetail: diary,
          ),
        ),
      ),
    );
    await settle(tester);
    return tester.element(find.byType(DiaryPreviewView)).l10n;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> writeInSheet(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(DiaryCommentSheet),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump();
    final l10n = tester.element(find.byType(DiaryCommentSheet)).l10n;
    await tester.tap(find.text(l10n.commonSave));
    await settle(tester);
  }

  Future<void> longPress(WidgetTester tester, String text) async {
    await tester.longPress(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('with comments off there is no section and no More entry', (
    tester,
  ) async {
    final diary = await seed(tester);
    final l10n = await pumpPreview(tester, diary, comments: false);

    expect(find.text(l10n.diaryCommentsWrite), findsNothing);
    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryCommentSheetNew), findsNothing);
    await unmount(tester);
  });

  testWidgets('write, edit, delete and undo a comment', (tester) async {
    final diary = await seed(tester);
    final l10n = await pumpPreview(tester, diary, comments: true);
    final diaryId = diary.diary.diaryId;

    await tester.tap(find.text(l10n.diaryCommentsWrite));
    await tester.pumpAndSettle();
    // 新写时标题带上距日记写下多久。
    expect(
      find.text('${l10n.diaryCommentSheetNew} · ${l10n.diaryCommentSameDay}'),
      findsOneWidget,
    );
    await writeInSheet(tester, '  Still remember the waves  ');

    expect(find.text('Still remember the waves'), findsOneWidget);
    expect(find.text(l10n.diaryCommentsHeading(1)), findsOneWidget);
    // 信息栏的留言数。
    expect(find.text(l10n.diaryCommentsCount(1)), findsOneWidget);
    expect(find.textContaining(l10n.diaryCommentEdited), findsNothing);

    await longPress(tester, 'Still remember the waves');
    await tester.tap(find.text(l10n.commonEdit));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryCommentSheetEdit), findsOneWidget);
    await writeInSheet(tester, 'Still remember the waves, and the gulls');
    expect(
      find.text('Still remember the waves, and the gulls'),
      findsOneWidget,
    );
    expect(find.textContaining(l10n.diaryCommentEdited), findsOneWidget);

    await longPress(tester, 'Still remember the waves, and the gulls');
    await tester.tap(find.text(l10n.commonDelete));
    await settle(tester);
    expect(find.byType(DiaryCommentItem), findsNothing);
    expect(
      await tester.runAsync(() => db.watchDiaryComments(diaryId).first),
      isEmpty,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester);
    expect(
      find.text('Still remember the waves, and the gulls'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('more than five comments fold until expanded', (tester) async {
    final diary = await seed(tester);
    await tester.runAsync(() async {
      for (var i = 1; i <= 7; i++) {
        await db.addDiaryComment(
          diaryId: diary.diary.diaryId,
          content: 'note $i',
        );
      }
    });
    final l10n = await pumpPreview(tester, diary, comments: true);

    expect(find.byType(DiaryCommentItem), findsNWidgets(4));
    expect(find.text('note 1'), findsOneWidget);
    expect(find.text('note 2'), findsNothing);
    expect(find.text('note 7'), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.diaryCommentsExpand(3)));
    await tester.tap(find.text(l10n.diaryCommentsExpand(3)));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCommentItem), findsNWidgets(7));
    expect(find.text(l10n.diaryCommentsCollapse), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a sealed capsule has no comment section', (tester) async {
    final diary = await seed(
      tester,
      unlockAt: DateTime.now().add(const Duration(days: 30)),
    );
    final l10n = await pumpPreview(tester, diary, comments: true);
    expect(find.byType(LockedDiaryPage), findsOneWidget);
    expect(find.text(l10n.diaryCommentsWrite), findsNothing);
    await unmount(tester);
  });
}
