import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
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
      for (final op in jsonDecode(bodyJson) as List)
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
          jsonEncode(applied.ops),
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
