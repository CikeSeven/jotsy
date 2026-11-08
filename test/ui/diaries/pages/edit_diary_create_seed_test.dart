import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/ui/ai/controllers/ai_save_as_diary_flow.dart';
import 'package:node_diary/ui/diaries/models/edit_diary_create_seed.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../../support/fake_day_photo_library.dart';

/// 带着初始内容新建（AI 的“另存为日记”）：原样未动不算草稿——返回不留
/// 草稿，开着“返回时直接发表”也不发表；改过才照常存成草稿。
void main() {
  Finder titleField() => find.byType(TextField).first;

  final seed = EditDiaryCreateSeed(
    title: '海边的一天',
    contentDocJson: jsonEncode(aiMarkdownDiaryDocument('傍晚去海边散步，风很大。')),
  );

  /// 从一个按钮推入编辑页，返回键才有上一页可回。
  Future<DiaryDraftsHarness> openSeeded(
    WidgetTester tester, {
    String? createPrefsRaw,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    if (createPrefsRaw != null) {
      await h.settings.setDiaryCreatePrefsRaw(createPrefsRaw);
    }
    await h.pump(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<Object?>(
            MaterialPageRoute<Object?>(
              builder: (_) => EditDiaryPage(
                entryMode: EditDiaryEntryMode.create,
                createSeed: seed,
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [
        dayPhotoLibraryProvider.overrideWithValue(
          FakeDayPhotoLibrary(access: DayPhotoAccess.denied),
        ),
      ],
    );
    await tester.tap(find.text('open'));
    await h.settle();
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> waitForDebouncedSave(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(milliseconds: 1400));
    await h.settle();
  }

  Future<void> back(DiaryDraftsHarness h) async {
    await h.tester.binding.handlePopRoute();
    await h.settle();
    await h.tester.pumpAndSettle();
    await h.settle();
  }

  testWidgets('the seed fills the page and leaving untouched keeps nothing', (
    tester,
  ) async {
    final h = await openSeeded(tester);
    expect(
      tester.widget<TextField>(titleField()).controller!.text,
      '海边的一天',
    );
    await waitForDebouncedSave(h);
    expect(await h.drafts(), isEmpty);

    await back(h);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(await h.drafts(), isEmpty);
    await h.unmount();
  });

  testWidgets('editing the seed makes it a draft like any new entry', (
    tester,
  ) async {
    final h = await openSeeded(tester);
    await tester.enterText(titleField(), '改过的标题');
    await waitForDebouncedSave(h);
    expect((await h.drafts()).map((row) => row.title), ['改过的标题']);

    await back(h);
    expect((await h.drafts()).map((row) => row.title), ['改过的标题']);
    await h.unmount();
  });

  testWidgets('publish on leave does not publish an untouched seed', (
    tester,
  ) async {
    final h = await openSeeded(tester, createPrefsRaw: '{"leave":"publish"}');
    await back(h);
    expect(find.byType(EditDiaryPage), findsNothing);
    final diaries = (await tester.runAsync(
      () => h.database.select(h.database.diaries).get(),
    ))!;
    expect(diaries, isEmpty);
    expect(await h.drafts(), isEmpty);
    await h.unmount();
  });
}
