import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_open_flow.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';

import '../../../support/diary_drafts_harness.dart';

/// 点开日记：默认进预览页；“打开日记时直接编辑”开启时直接进编辑页，未解封
/// 的时间胶囊与找不到的日记仍交给预览页；编辑页里删除时按预览页的结果返回。
void main() {
  final results = <DiaryPreviewResult?>[];
  setUp(results.clear);

  Future<String> seedDiary(
    DiaryDraftsHarness h, {
    DateTime? capsuleUnlockAt,
  }) async {
    return (await h.tester.runAsync(
      () => h.database.createDiary(
        title: 'Seeded diary',
        contentDocJson: '[{"insert":"Body\\n"}]',
        contentText: 'Body',
        metadataJson: '{}',
        createdAtOverride: DateTime(2026, 10, 1),
        capsuleUnlockAt: capsuleUnlockAt,
        capsuleLockedAt: capsuleUnlockAt == null ? null : DateTime(2026, 10, 1),
      ),
    ))!;
  }

  Future<void> setOpenInEditor(DiaryDraftsHarness h) {
    return h.settings.setDiaryPreviewStyleRaw(
      const DiaryPreviewSettings(
        behavior: DiaryPreviewBehavior(openInEditor: true),
      ).encode(),
    );
  }

  /// 一个按钮：按入口的方式打开 [diaryId]。[withDetail] 为 true 时像列表一样
  /// 带上已有的数据，否则像探索页一样只给 id。
  Future<void> pumpOpener(
    DiaryDraftsHarness h,
    String diaryId, {
    bool withDetail = true,
  }) async {
    final detail = withDetail
        ? await h.tester.runAsync(
            () => h.database.getDiaryWithTagsByDiaryId(diaryId),
          )
        : null;
    await h.pump(
      Consumer(
        builder: (context, ref, _) {
          // 应用外壳一直订阅设置服务（`NodeDiaryApp`），入口能点开日记时它
          // 早已就绪；这里同样订阅，阅读行为才读得到存储值。
          ref.watch(settingsServiceProvider);
          return Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await openDiaryPage(
                  context,
                  ref,
                  diaryId: diaryId,
                  initialDetail: detail,
                ),
              ),
              child: const Text('Open'),
            ),
          );
        },
      ),
    );
  }

  Future<void> tapOpen(WidgetTester tester, DiaryDraftsHarness h) async {
    await tester.tap(find.text('Open'));
    await h.settle();
    // 编辑器获得焦点后光标闪烁，pumpAndSettle 不会结束：固定出帧。
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('by default a tapped diary opens the preview page', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final diaryId = await seedDiary(h);
    await pumpOpener(h, diaryId);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    expect(find.byType(EditDiaryPage), findsNothing);
    await h.unmount();
  });

  testWidgets('with open-in-editor on the editor opens directly', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    final diaryId = await seedDiary(h);
    await pumpOpener(h, diaryId);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsNothing);
    final editor = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(editor.diaryId, diaryId);
    expect(editor.entryMode, EditDiaryEntryMode.edit);

    // 没改动直接返回：回到入口，不算删除。
    await tester.binding.handlePopRoute();
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(results, <DiaryPreviewResult?>[null]);
    await h.unmount();
  });

  testWidgets('entries without data look the diary up before editing', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    final diaryId = await seedDiary(h);
    await pumpOpener(h, diaryId, withDetail: false);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(
      tester.widget<EditDiaryPage>(find.byType(EditDiaryPage)).diaryId,
      diaryId,
    );
    await h.unmount();
  });

  testWidgets('deleting in the editor reports the diary like the preview', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    final diaryId = await seedDiary(h);
    await pumpOpener(h, diaryId);
    await tapOpen(tester, h);

    // 编辑页删除后以 true 结束。
    Navigator.of(tester.element(find.byType(EditDiaryPage))).pop(true);
    await h.settle();
    await tester.pumpAndSettle();

    expect(results, <DiaryPreviewResult?>[DiaryPreviewResult.deleted(diaryId)]);
    await h.unmount();
  });

  testWidgets('a sealed time capsule still opens on the preview page', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    final diaryId = await seedDiary(
      h,
      capsuleUnlockAt: DateTime.now().add(const Duration(days: 30)),
    );
    await pumpOpener(h, diaryId);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    expect(find.byType(LockedDiaryPage), findsOneWidget);
    expect(find.byType(EditDiaryPage), findsNothing);
    await h.unmount();
  });

  testWidgets('an opened time capsule goes straight to the editor', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    final diaryId = await seedDiary(
      h,
      capsuleUnlockAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await pumpOpener(h, diaryId);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('a diary that no longer exists falls back to the preview', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await setOpenInEditor(h);
    await pumpOpener(h, 'missing-diary', withDetail: false);

    await tapOpen(tester, h);

    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    expect(find.byType(EditDiaryPage), findsNothing);
    await h.unmount();
  });

  test(
    'only existing diaries outside a sealed capsule can skip the preview',
    () {
      expect(canOpenDiaryInEditor(null, now: DateTime(2026, 10, 27)), isFalse);
    },
  );
}
