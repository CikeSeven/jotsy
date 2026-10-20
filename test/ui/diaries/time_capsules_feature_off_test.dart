import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_entry_tiles.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_summary_bar.dart';
import 'package:node_diary/ui/diaries/widgets/time_capsule_seal_overlay.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/publish_panel_driver.dart';

/// 功能管理关闭“时间胶囊”：发布页没有胶囊行与摘要；草稿里留下的胶囊在
/// 发布时被忽略、按普通日记发布；模板编辑页没有胶囊预设一行；新建入口带来
/// 的解封日不生效。已有胶囊的展示与解封不在这里改动。
void main() {
  const capsulesOff = '{"timeCapsules":false}';

  group('publish controller', () {
    late AppDatabase database;
    late DiaryMetaDraftController meta;
    final now = DateTime(2026, 10, 19, 9);

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      meta = DiaryMetaDraftController();
    });
    tearDown(() async {
      meta.dispose();
      await database.close();
    });

    PublishDiaryController publisher({required bool capsules}) =>
        PublishDiaryController(
          initialDraft: const NewDiaryDraft(
            title: '写给以后',
            contentDocJson: '[{"insert":"写给以后\\n"}]',
            contentText: '写给以后',
          ),
          meta: meta,
          timeCapsulesEnabled: () => capsules,
          clock: () => now,
        );

    test('capsules off: a draft holding a capsule publishes as a normal '
        'diary', () async {
      meta.setCapsule(
        TimeCapsuleSchedule(
          unlockAt: DateTime(2027, 1, 1),
          precision: TimeCapsulePrecision.date,
        ),
      );
      final controller = publisher(capsules: false);
      addTearDown(controller.dispose);
      final id = await controller.submit(database);

      final diary = (await database.getDiaryWithTagsByDiaryId(id))!.diary;
      expect(diary.capsuleUnlockAt, isNull);
      expect(diary.capsuleLockedAt, isNull);
      expect(diary.createdAt, now, reason: '按发表时刻，而不是解封日');
      expect((jsonDecode(diary.metadata) as Map).containsKey('capsule'), false);
      expect(controller.phase.value, PublishPhase.done, reason: '不播封存卡片');
      // 面板草稿原样保留。
      expect(meta.value.capsule, isNotNull);
    });

    test('capsules off: an expired capsule left in the draft does not block '
        'publishing', () {
      meta.setCapsule(
        TimeCapsuleSchedule(
          unlockAt: DateTime(2026, 10, 1),
          precision: TimeCapsulePrecision.date,
        ),
      );
      final off = publisher(capsules: false);
      final on = publisher(capsules: true);
      addTearDown(off.dispose);
      addTearDown(on.dispose);
      expect(off.validate(), PublishValidation.ok);
      expect(on.validate(), PublishValidation.capsuleUnlockPassed);
    });

    test('capsules off: going back to the editor keeps the capsule in the '
        'draft', () {
      meta.setCapsule(
        TimeCapsuleSchedule(
          unlockAt: DateTime(2027, 1, 1),
          precision: TimeCapsulePrecision.date,
        ),
      );
      final controller = publisher(capsules: false);
      addTearDown(controller.dispose);
      expect(controller.returnDraft().capsuleUnlockAt, DateTime(2027, 1, 1));
    });
  });

  group('publish page', () {
    final draft = NewDiaryDraft(
      title: '写给以后',
      contentDocJson: '[{"insert":"写给以后\\n"}]',
      contentText: '写给以后',
      capsuleUnlockAt: DateTime(2030, 1, 1),
      capsulePrecision: 'date',
    );

    /// 打开者先订阅设置（与真实链路一样，发布页打开时设置早已就绪）。
    Future<DiaryDraftsHarness> openPublishPage(
      WidgetTester tester, {
      String? featuresRaw,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      if (featuresRaw != null) await h.settings.setAppFeaturesRaw(featuresRaw);
      await h.pump(
        Consumer(
          builder: (context, ref, _) {
            ref.watch(settingsServiceProvider);
            return Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => PublishDiaryPage(initialDraft: draft),
                  ),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return h;
    }

    Finder summaryLock() => find.descendant(
      of: find.byKey(PublishPanelSummaryBar.summaryKey),
      matching: find.byIcon(FontAwesomeIcons.lock.data),
    );

    String collapsedActionLabel(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(PublishPanelSummaryBar.actionKey),
            matching: find.byType(Text),
          ),
        )
        .data!;

    Future<void> unmount(DiaryDraftsHarness h) async {
      await h.tester.pump(const Duration(seconds: 5));
      await h.tester.pumpAndSettle();
      await h.unmount();
    }

    testWidgets('capsules on: the capsule shows in the summary, tile and '
        'seal button', (tester) async {
      final h = await openPublishPage(tester);

      expect(summaryLock(), findsOneWidget);
      expect(collapsedActionLabel(tester), h.l10n.publishPanelSealShort);
      await PublishPanelDriver(tester).expand();
      expect(find.byType(PublishCapsuleTile), findsOneWidget);
      await unmount(h);
    });

    testWidgets('capsules off: no capsule tile, summary item or seal label, '
        'and publishing does not seal', (tester) async {
      final h = await openPublishPage(tester, featuresRaw: capsulesOff);

      expect(summaryLock(), findsNothing);
      expect(collapsedActionLabel(tester), h.l10n.publishPanelPublishShort);
      final panel = PublishPanelDriver(tester);
      await panel.expand();
      expect(find.byType(PublishCapsuleTile), findsNothing);
      // 发表时间行不显示“跟随定时锁”，照常可选。
      expect(find.byIcon(FontAwesomeIcons.lock.data), findsNothing);
      expect(find.byIcon(FontAwesomeIcons.calendarDays.data), findsOneWidget);

      panel.triggerPublish();
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TimeCapsuleSealOverlay), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(PublishDiaryPage), findsNothing);

      final diaries = (await tester.runAsync(
        () => h.database.getActiveDiaryIds(),
      ))!;
      final diary = (await tester.runAsync(
        () => h.database.getDiaryWithTagsByDiaryId(diaries.single),
      ))!.diary;
      expect(diary.capsuleUnlockAt, isNull);
      expect(diary.capsuleLockedAt, isNull);
      await unmount(h);
    });
  });

  testWidgets('capsules off: an entry preset unlock day does not reach the '
      'editor', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setAppFeaturesRaw(capsulesOff);
    await h.pump(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => runDiaryCreateEntryFlow(
              context,
              ref,
              capsuleUnlockAt: DateTime(2030, 1, 1),
            ),
            child: const Text('New'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New'));
    await h.settle();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditDiaryPage>(find.byType(EditDiaryPage))
          .createCapsuleUnlockAt,
      isNull,
    );
    await h.unmount();
  });

  group('template editor', () {
    Future<DiaryDraftsHarness> openTemplateEditor(
      WidgetTester tester, {
      String? featuresRaw,
    }) async {
      final h = await DiaryDraftsHarness.create(tester);
      if (featuresRaw != null) await h.settings.setAppFeaturesRaw(featuresRaw);
      await h.pump(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DiaryTemplateEditorPage(
                    template: DiaryTemplate(
                      id: 'user.sealed',
                      name: '给未来',
                      titlePattern: '写给以后',
                      bodyJson: '[{"insert":"\\n"}]',
                      capsule: TimeCapsulePreset.month,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(h.l10n.diaryTemplateEditorTabSettings));
      await tester.pumpAndSettle();
      // 胶囊一行紧挨在“推荐时间”分组之前：滚到那里时它也已构建。
      await tester.scrollUntilVisible(
        find.text(h.l10n.diaryTemplateEditorRecommend),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('capsules on: the capsule preset row is shown', (tester) async {
      final h = await openTemplateEditor(tester);
      expect(find.text(h.l10n.diaryTemplateEditorCapsule), findsOneWidget);
      await h.unmount();
    });

    testWidgets('capsules off: no capsule preset row', (tester) async {
      final h = await openTemplateEditor(tester, featuresRaw: capsulesOff);
      expect(find.text(h.l10n.diaryTemplateEditorCapsule), findsNothing);
      expect(find.text(h.l10n.diaryTemplateEditorCapsuleHint), findsNothing);
      await h.unmount();
    });
  });
}
