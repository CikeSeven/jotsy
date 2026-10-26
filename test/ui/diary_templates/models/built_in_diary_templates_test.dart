import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_body.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_variables.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_application.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_variable_values.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  test('both languages have the same 8 built-in templates in order', () {
    final zhTemplates = buildBuiltInDiaryTemplates(zh);
    final enTemplates = buildBuiltInDiaryTemplates(en);
    expect(zhTemplates.map((t) => t.id), [
      'builtin.daily',
      'builtin.morning',
      'builtin.evening',
      'builtin.gratitude',
      'builtin.question',
      'builtin.weekly',
      'builtin.emotion',
      'builtin.reading',
    ]);
    expect(zhTemplates.map((t) => t.id), enTemplates.map((t) => t.id));
    for (final template in zhTemplates) {
      expect(template.id, startsWith('builtin.'));
      expect(template.isBuiltIn, isTrue);
      expect(template.name, isNotEmpty);
      expect(template.description, isNotEmpty);
    }
  });

  test('zh and en bodies have the same block structure', () {
    List<Object?> shape(String bodyJson) => [
      for (final op in diaryContentQuillOps(bodyJson))
        (op as Map)['attributes'] ?? (op['insert'] is Map ? 'embed' : null),
    ];
    final zhTemplates = buildBuiltInDiaryTemplates(zh);
    final enTemplates = buildBuiltInDiaryTemplates(en);
    for (var i = 0; i < zhTemplates.length; i++) {
      expect(
        shape(zhTemplates[i].bodyJson),
        shape(enTemplates[i].bodyJson),
        reason: zhTemplates[i].id,
      );
    }
  });

  List<Map<String, Object?>> body(String bodyJson) => [
    for (final op in diaryContentQuillOps(bodyJson))
      Map<String, Object?>.from(op as Map),
  ];

  test('bodies use the body text size: no heading levels', () {
    for (final l10n in [zh, en]) {
      for (final template in buildBuiltInDiaryTemplates(l10n)) {
        for (final op in body(template.bodyJson)) {
          final attributes = op['attributes'] as Map? ?? const {};
          expect(attributes, isNot(contains('header')), reason: template.id);
          expect(
            attributes['size'],
            anyOf(isNull, 'small'),
            reason: template.id,
          );
        }
      }
    }
  });

  test('headings are bold in a readable text color and end in a plain '
      'colon', () {
    // 纯白不守文字色预设的对比度约定（白纸上看不见），不能做小标题色。
    final readable = {
      for (final preset in DiaryColorPreset.values)
        if (preset != DiaryColorPreset.white)
          encodeDiaryColor(preset.colorFor(DiaryColorTarget.text)),
    };
    for (final l10n in [zh, en]) {
      for (final template in buildBuiltInDiaryTemplates(l10n)) {
        final ops = body(template.bodyJson);
        final headings = [
          for (var i = 0; i < ops.length; i++)
            if ((ops[i]['attributes'] as Map?)?['bold'] == true) i,
        ];
        expect(headings, isNotEmpty, reason: template.id);
        for (final i in headings) {
          final attributes = ops[i]['attributes'] as Map;
          expect(readable, contains(attributes['color']), reason: template.id);
          expect(ops[i + 1]['attributes'], isNull, reason: template.id);
          expect(
            (ops[i + 1]['insert'] as String).split('\n').first,
            matches(RegExp(r'^[:：]\s*$')),
            reason: '${template.id}: ${ops[i]['insert']}',
          );
        }
      }
    }
  });

  /// 在 [ops] 每个空行的行首打一个字，返回带了行内格式的那些行的偏移。
  /// 经 Document.insert 走 Quill 的插入规则，与在编辑器里打字一致。
  List<int> leakingEmptyLines(List<Map<String, Object?>> ops) {
    final text = documentFromLegacyDelta(ops).toPlainText();
    final leaking = <int>[];
    for (var i = 0; i < text.length; i++) {
      final empty =
          text.codeUnitAt(i) == 0x0A &&
          (i == 0 || text.codeUnitAt(i - 1) == 0x0A);
      if (!empty) continue;
      final controller = DiaryEditorController(
        document: documentFromLegacyDelta(ops),
      );
      controller.updateSelection(TextSelection.collapsed(offset: i));
      final inline = controller.selectionAttributes.keys;
      controller.dispose();
      if (inline.isNotEmpty) leaking.add(i);
    }
    return leaking;
  }

  test('text typed on any empty line starts without bold or color', () {
    for (final l10n in [zh, en]) {
      for (final template in buildBuiltInDiaryTemplates(l10n)) {
        expect(
          leakingEmptyLines(body(template.bodyJson)),
          isEmpty,
          reason: '${l10n.localeName} ${template.id}',
        );
      }
    }
  });

  test('a bold block does not leak its format into a separate empty block', () {
    // 对照：去掉末尾不带格式的冒号，Quill 会让下面空行里写的字沿用粗体，
    // 这正是小标题要以冒号结尾的原因（见 TplLabel）。
    final ops = compileDiaryTemplateBlocks(const <DiaryTemplateBlock>[
      TplLabel('小标题'),
      TplParagraph(),
    ]);
    expect(leakingEmptyLines(ops), isEmpty);
  });

  test('no variable is left unresolved after applying', () {
    for (final l10n in [zh, en]) {
      final values = DiaryTemplateVariableValues.compute(
        l10n: l10n,
        diaryDate: DateTime(2026, 10, 18),
        now: DateTime(2026, 10, 18, 8, 30),
      );
      for (final template in buildBuiltInDiaryTemplates(l10n)) {
        final applied = DiaryTemplateApplication.resolve(template, values);
        expect(applied.title, isNot(contains('{{')), reason: template.id);
        expect(
          jsonEncode(applied.document),
          isNot(contains('{{')),
          reason: template.id,
        );
      }
    }
  });

  test('every inserted variable token is a recognised alias', () {
    for (final l10n in [zh, en]) {
      final tokens = <String, DiaryTemplateVariable>{
        l10n.diaryTemplateVarDateToken: DiaryTemplateVariable.date,
        l10n.diaryTemplateVarWeekdayToken: DiaryTemplateVariable.weekday,
        l10n.diaryTemplateVarTimeToken: DiaryTemplateVariable.time,
        l10n.diaryTemplateVarYearToken: DiaryTemplateVariable.year,
        l10n.diaryTemplateVarMonthToken: DiaryTemplateVariable.month,
        l10n.diaryTemplateVarDayToken: DiaryTemplateVariable.day,
        l10n.diaryTemplateVarWeekToken: DiaryTemplateVariable.week,
        l10n.diaryTemplateVarDayOfYearToken: DiaryTemplateVariable.dayOfYear,
        l10n.diaryTemplateVarYearProgressToken:
            DiaryTemplateVariable.yearProgress,
        l10n.diaryTemplateVarLunarToken: DiaryTemplateVariable.lunar,
        l10n.diaryTemplateVarSolarTermToken: DiaryTemplateVariable.solarTerm,
        l10n.diaryTemplateVarQuestionToken: DiaryTemplateVariable.question,
      };
      expect(tokens, hasLength(DiaryTemplateVariable.values.length));
      tokens.forEach((token, variable) {
        expect(parseDiaryTemplateVariable(token), variable, reason: token);
      });
    }
  });

  test('the question bank has 30 questions in each language', () {
    for (final l10n in [zh, en]) {
      final questions = diaryTemplateQuestions(l10n);
      expect(questions, hasLength(30));
      expect(questions.toSet(), hasLength(30));
      expect(questions.every((q) => q.trim().isNotEmpty), isTrue);
    }
  });
}
