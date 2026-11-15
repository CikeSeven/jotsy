import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_launch.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/home_widgets/controllers/home_widget_launch_router.dart';

import '../../support/diary_drafts_harness.dart';

Future<void> _insertDiary(AppDatabase database, String diaryId) async {
  final at = DateTime(2023, 11, 15, 20);
  await database
      .into(database.diaries)
      .insert(
        DiariesCompanion.insert(
          diaryId: diaryId,
          title: Value<String>(diaryId),
          content: '[{"insert":"body\\n"}]',
          contentText: 'body',
          createdAt: at,
          updatedAt: at,
        ),
      );
}

void main() {
  testWidgets('a diary link opens the entry unless it has become private', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await tester.runAsync(() async {
      await _insertDiary(h.database, 'open-me');
      await _insertDiary(h.database, 'secret');
      // 小组件上次刷新后，这篇被收进了隐藏的日记本：桌面上还留着它的链接。
      final hidden = await h.database.createNotebook(
        name: 'Hidden',
        visibility: NotebookVisibility.hidden,
      );
      await h.database.addDiariesToNotebook(hidden, <String>['secret']);
    });
    late BuildContext context;
    late WidgetRef ref;
    await h.pump(
      Consumer(
        builder: (BuildContext innerContext, WidgetRef innerRef, _) {
          context = innerContext;
          ref = innerRef;
          return const Scaffold();
        },
      ),
    );
    Future<void> open(String diaryId) async {
      unawaited(
        openHomeWidgetLaunch(
          context,
          ref,
          HomeWidgetDiaryLaunch(diaryId: diaryId),
          switchToTab: (_) async => true,
        ),
      );
      await h.settle();
    }

    await open('secret');
    expect(find.byType(DiaryPreviewPage), findsNothing);

    await open('open-me');
    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    await h.unmount();
  });
}
