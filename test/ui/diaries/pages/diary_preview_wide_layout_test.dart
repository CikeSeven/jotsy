import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

DiaryWithTags _diary({String? cover}) {
  final created = DateTime(2025, 3, 2, 9, 30);
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'wide-preview',
      title: '海边的一天',
      content: '[{"insert":"晚霞把整片海都染成了橘色\\n"}]',
      contentText: '晚霞把整片海都染成了橘色',
      metadata: '{"context":{"moodEmoji":"😊","location":"西湖"}}',
      cover: cover,
      createdAt: created,
      updatedAt: created.add(const Duration(days: 1)),
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[Tag(id: 1, name: '旅行', color: 0xFF4CAF50)],
  );
}

class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

/// 在 [size] 的窗口里打开预览页；[leading] 不为 0 时左侧先占掉这么宽（模拟
/// 预览嵌在双栏里、可用宽度比窗口窄）。
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  DiaryPreviewStyle style = DiaryPreviewStyle.defaults,
  String? cover,
  double leading = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final encoded = DiaryPreviewSettings(current: style).encode();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.diary_preview_style': ?encoded,
  });
  final settings = await SettingsService.create();
  final database = _PendingDetailDatabase();
  addTearDown(database.close);
  final entry = _diary(cover: cover);
  final page = DiaryPreviewPage(
    diaryId: entry.diary.diaryId,
    initialDetail: entry,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: leading == 0
            ? page
            : Row(
                children: <Widget>[
                  SizedBox(width: leading),
                  Expanded(child: page),
                ],
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 头图画面（裁切圆角的那一层）在屏幕上的位置。
Rect _coverRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(PublishDiaryCoverSliver),
        matching: find.byType(ClipRRect),
      )
      .first,
);

void main() {
  testWidgets('the reading column is at most 720 wide and centred at 1280', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1280, 900));
    final body = tester.getRect(find.byType(DiaryEditor));
    // 列宽 720 含左右各 16 的边距。
    expect(body.width, closeTo(720 - 32, 0.5));
    expect(body.center.dx, closeTo(640, 0.5));
    final title = tester.getRect(find.text('海边的一天'));
    expect(title.left, closeTo(body.left, 0.5));
    final meta = tester.getRect(find.text('西湖'));
    expect(meta.left, greaterThanOrEqualTo(body.left - 0.5));
    expect(meta.right, lessThanOrEqualTo(body.right + 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone width keeps the full-width text and banner cover', (
    tester,
  ) async {
    await _pump(tester, size: const Size(400, 800), cover: '/missing/a.png');
    final body = tester.getRect(find.byType(DiaryEditor));
    expect(body.left, closeTo(16, 0.5));
    expect(body.width, closeTo(400 - 32, 0.5));
    final sliver = tester.widget<PublishDiaryCoverSliver>(
      find.byType(PublishDiaryCoverSliver),
    );
    expect(sliver.padding, EdgeInsets.zero);
    expect(sliver.borderRadius, BorderRadius.zero);
    expect(sliver.maxExtentHeight, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the user text width still wins on wide windows', (tester) async {
    await _pump(
      tester,
      size: const Size(1280, 900),
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(limitWidth: true, contentWidth: 880),
      ),
    );
    final body = tester.getRect(find.byType(DiaryEditor));
    expect(body.width, closeTo(880 - 32, 0.5));
    expect(body.center.dx, closeTo(640, 0.5));
  });

  testWidgets('the cover sits inside the reading column on wide windows', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1280, 900), cover: '/missing/a.png');
    final sliver = tester.widget<PublishDiaryCoverSliver>(
      find.byType(PublishDiaryCoverSliver),
    );
    expect(sliver.fillFrame, isTrue);
    expect(sliver.borderRadius, BorderRadius.circular(24));
    // 画面高 min(420, 688 × 0.6)，再加 16 的上边距。
    expect(sliver.maxExtentHeight, closeTo(688 * 0.6 + 16, 0.01));
    final cover = _coverRect(tester);
    final body = tester.getRect(find.byType(DiaryEditor));
    expect(cover.left, closeTo(body.left, 0.5));
    expect(cover.width, closeTo(body.width, 0.5));
    expect(cover.height, closeTo(688 * 0.6, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the layout follows the available width, not the window', (
    tester,
  ) async {
    // 1280 的窗口里只给预览 700：不收窄正文列，但头图已放进列里。
    await _pump(
      tester,
      size: const Size(1280, 900),
      cover: '/missing/a.png',
      leading: 580,
    );
    final body = tester.getRect(find.byType(DiaryEditor));
    expect(body.left, closeTo(580 + 16, 0.5));
    expect(body.width, closeTo(700 - 32, 0.5));
    final cover = _coverRect(tester);
    expect(cover.left, closeTo(body.left, 0.5));
    expect(cover.width, closeTo(body.width, 0.5));
    expect(cover.height, closeTo(668 * 0.6, 0.5));
  });

  testWidgets('a wide window without a cover starts with the title', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1280, 900));
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);
    expect(find.text('海边的一天'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
