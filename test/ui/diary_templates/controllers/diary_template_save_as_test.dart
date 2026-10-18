import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_template_save_as.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';

import '../../../support/diary_drafts_harness.dart';

void main() {
  test('a diary becomes a template without its media', () {
    final draft = diaryTemplateFromEntry(
      title: '周末爬山',
      contentDocJson: jsonEncode([
        {'insert': '出发\n'},
        {
          'insert': {'image': '/data/user/0/app/diary_images/a.jpg'},
        },
        {'insert': '\n'},
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n山顶\n'},
      ]),
      tags: const [Tag(id: 3, name: '户外', color: 0xFF43A047)],
      mood: '😄',
      energy: 4.4,
    );

    expect(draft.droppedMedia, isTrue);
    final template = draft.template;
    expect(template.id, isEmpty);
    expect(template.name, '周末爬山');
    expect(template.titlePattern, '周末爬山');
    expect(template.bodyJson, isNot(contains('image')));
    expect(template.bodyJson, contains('divider'));
    expect(template.bodyJson, contains('山顶'));
    expect(template.tags, const [
      DiaryTemplateTagRef(name: '户外', color: 0xFF43A047),
    ]);
    expect(template.mood, '😄');
    expect(template.energy, 4);
    expect(template.capsule, isNull);
  });

  test('a text-only diary drops nothing', () {
    final draft = diaryTemplateFromEntry(
      title: '',
      contentDocJson: jsonEncode([
        {'insert': '只有文字\n'},
      ]),
      tags: const [],
    );
    expect(draft.droppedMedia, isFalse);
    expect(draft.template.name, isEmpty);
    expect(draft.template.mood, isNull);
  });

  testWidgets('the editor menu saves the entry being written as a template', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const EditDiaryPage(entryMode: EditDiaryEntryMode.create));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '散步');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(h.l10n.diaryEditorMoreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(h.l10n.diaryTemplateSaveAs));
    await tester.pumpAndSettle();
    await h.settle();
    await tester.pumpAndSettle();

    expect(find.byType(DiaryTemplateEditorPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '散步',
    );
    await h.unmount();
  });
}
