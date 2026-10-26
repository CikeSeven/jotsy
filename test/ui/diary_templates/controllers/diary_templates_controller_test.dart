import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_templates_controller.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SettingsService settings;
  late DiaryTemplatesController controller;
  var changes = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    changes = 0;
    controller = DiaryTemplatesController(
      database: database,
      settings: settings,
      onTemplatesChanged: () => changes++,
    );
  });
  tearDown(() => database.close());

  DiaryTemplatePrefs prefs() =>
      DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);

  Future<List<DiaryTemplate>> stored() async => [
    for (final row in await database.getDiaryTemplates())
      DiaryTemplateJson.fromPayload(row.payload, id: row.templateId)!,
  ];

  const daily = DiaryTemplate(
    id: 'builtin.daily',
    name: '每日记录',
    bodyJson:
        '[{"insert":"正文\\n"},{"insert":{"image":"/private/a.jpg"}},{"insert":"\\n"}]',
  );

  test('copying a built-in saves a new user template without media', () async {
    final id = await controller.duplicate(daily, name: '我的每日');
    final saved = (await stored()).single;
    expect(saved.id, id);
    expect(saved.id, isNot(startsWith('builtin.')));
    expect(saved.name, '我的每日');
    expect(
      saved.bodyJson,
      encodeDiaryTemplateBody([
        {'insert': '正文\n'},
      ]),
    );
    expect(changes, 1);
  });

  test('saving an existing template updates it in place', () async {
    final id = await controller.save(const DiaryTemplate(id: '', name: '旧名'));
    await controller.save(DiaryTemplate(id: id, name: '新名'));
    expect((await stored()).map((t) => (t.id, t.name)), [(id, '新名')]);
  });

  test(
    'deleting the auto template clears it, and undo restores both',
    () async {
      final id = await controller.save(const DiaryTemplate(id: '', name: '甲'));
      await controller.setAutoTemplate(id);

      final deletion = (await controller.delete(id))!;
      expect(await stored(), isEmpty);
      expect(prefs().autoTemplateId, isNull);

      await controller.restore(deletion);
      expect((await stored()).single.id, id);
      expect(prefs().autoTemplateId, id);
    },
  );

  test('undoing a delete keeps an auto template chosen meanwhile', () async {
    final id = await controller.save(const DiaryTemplate(id: '', name: '甲'));
    await controller.setAutoTemplate(id);
    final deletion = (await controller.delete(id))!;
    await controller.setAutoTemplate('builtin.daily');

    await controller.restore(deletion);
    expect(prefs().autoTemplateId, 'builtin.daily');
  });

  test('editing a built-in saves it in place under the same id', () async {
    final id = await controller.save(daily.copyWith(name: '我的每日'));
    expect(id, 'builtin.daily');
    expect((await stored()).map((t) => (t.id, t.name)), [
      ('builtin.daily', '我的每日'),
    ]);
    // 再次保存仍是同一行。
    await controller.save(daily.copyWith(name: '又改了'));
    expect((await stored()).map((t) => t.name), ['又改了']);
    expect(changes, 2);
  });

  test('restoring the original removes the edited row and undo puts it '
      'back', () async {
    expect(await controller.resetBuiltIn('builtin.daily'), isNull);
    await controller.save(daily.copyWith(name: '我的每日'));
    await controller.setAutoTemplate('builtin.daily');

    final reset = (await controller.resetBuiltIn('builtin.daily'))!;
    expect(await stored(), isEmpty);
    expect(prefs().autoTemplateId, 'builtin.daily', reason: '指向的仍是同一个模板');

    await controller.restore(reset);
    expect((await stored()).single.name, '我的每日');
    expect(prefs().autoTemplateId, 'builtin.daily');
  });

  test(
    'deleting the auto built-in clears it and undo brings it back',
    () async {
      await controller.setAutoTemplate('builtin.daily');
      final removed = await controller.deleteBuiltIn('builtin.daily');
      expect(removed.wasAuto, isTrue);
      expect(prefs().hiddenBuiltIns, {'builtin.daily'});
      expect(prefs().autoTemplateId, isNull);

      await controller.undoDeleteBuiltIn('builtin.daily', removed: removed);
      expect(prefs().hiddenBuiltIns, isEmpty);
      expect(prefs().autoTemplateId, 'builtin.daily');
    },
  );

  test(
    'deleting an edited built-in keeps its edits for a later restore',
    () async {
      await controller.save(daily.copyWith(name: '我的每日'));
      await controller.deleteBuiltIn('builtin.daily');
      await controller.deleteBuiltIn('builtin.reading');
      expect((await stored()).single.name, '我的每日');

      await controller.restoreBuiltIns(['builtin.daily', 'builtin.reading']);
      expect(prefs().hiddenBuiltIns, isEmpty);
      expect((await stored()).single.name, '我的每日');
    },
  );

  DiaryTemplateAutoRule rule(String id, {int from = 420, int to = 600}) =>
      DiaryTemplateAutoRule(startMinute: from, endMinute: to, templateId: id);

  test(
    'time range rules are saved, replaced, deleted and restored once',
    () async {
      final morning = rule('builtin.morning');
      expect(await controller.saveAutoRule(morning), isTrue);
      expect(await controller.saveAutoRule(morning), isTrue);
      expect(prefs().autoRules, [morning], reason: '一模一样的规则不重复添加');

      final later = rule('builtin.morning', from: 480);
      await controller.saveAutoRule(later, replacing: morning);
      expect(prefs().autoRules, [later]);

      final deleted = await controller.deleteAutoRule(later);
      expect(deleted, later);
      expect(prefs().autoRules, isEmpty);
      expect(await controller.deleteAutoRule(later), isNull);

      await controller.restoreAutoRule(later);
      await controller.restoreAutoRule(later);
      expect(prefs().autoRules, [later]);
    },
  );

  test('a new rule is refused once twelve exist', () async {
    for (var i = 0; i < DiaryTemplatePrefs.maxAutoRules; i++) {
      expect(
        await controller.saveAutoRule(
          rule('t$i', from: i * 60, to: i * 60 + 30),
        ),
        isTrue,
      );
    }
    expect(
      await controller.saveAutoRule(rule('extra', from: 1300, to: 1400)),
      isFalse,
    );
    expect(prefs().autoRules, hasLength(DiaryTemplatePrefs.maxAutoRules));
    // 编辑已有的一条不受上限影响。
    final first = prefs().autoRules.first;
    expect(
      await controller.saveAutoRule(
        first.copyWith(templateId: 'edited'),
        replacing: first,
      ),
      isTrue,
    );
  });

  test(
    'deleting a template removes its rules and undo puts them back',
    () async {
      final id = await controller.save(const DiaryTemplate(id: '', name: '甲'));
      final mine = rule(id);
      final other = rule('builtin.daily', from: 1200, to: 1260);
      await controller.saveAutoRule(mine);
      await controller.saveAutoRule(other);
      await controller.setAutoTemplate(id);

      final deletion = (await controller.delete(id))!;
      expect(deletion.auto.rules, [mine]);
      expect(prefs().autoRules, [other]);
      expect(prefs().autoTemplateId, isNull);

      // 撤销前用户又加回了同一条：撤销不重复添加。
      await controller.saveAutoRule(mine);
      await controller.restore(deletion);
      expect(prefs().autoRules, [mine, other]);
      expect(prefs().autoTemplateId, id);
    },
  );

  test(
    'deleting a built-in removes its rules and undo restores them',
    () async {
      final dream = rule('builtin.dream', from: 300, to: 420);
      final daily = rule('builtin.daily');
      await controller.saveAutoRule(dream);
      await controller.saveAutoRule(daily);

      final removed = await controller.deleteBuiltIn('builtin.dream');
      expect(removed.wasAuto, isFalse);
      expect(removed.rules, [dream]);
      expect(prefs().autoRules, [daily]);

      await controller.undoDeleteBuiltIn('builtin.dream', removed: removed);
      expect(prefs().hiddenBuiltIns, isEmpty);
      expect(prefs().autoRules, [dream, daily]);
    },
  );

  test('restoring from the deleted list brings no rules back', () async {
    final dream = rule('builtin.dream', from: 300, to: 420);
    await controller.saveAutoRule(dream);
    await controller.deleteBuiltIn('builtin.dream');

    await controller.restoreBuiltIns(['builtin.dream']);
    expect(prefs().hiddenBuiltIns, isEmpty);
    expect(prefs().autoRules, isEmpty);
  });

  test('template codes import as new templates and can be undone', () async {
    final code = encodeDiaryTemplateCode(daily)!;
    final result = await controller.importCode('分享给你：$code');
    expect(result.status, StyleCodeStatus.ok);
    expect(result.name, '每日记录');
    final imported = (await stored()).single;
    expect(imported.id, result.templateId);
    expect(imported.isBuiltIn, isFalse);

    await controller.removeImported(result.templateId!);
    expect(await stored(), isEmpty);
  });

  test('invalid or empty codes import nothing', () async {
    expect((await controller.importCode(null)).status, StyleCodeStatus.empty);
    expect(
      (await controller.importCode('jotsy-card:v1:eyJ2IjoxLCJzIjp7fX0')).status,
      StyleCodeStatus.invalid,
    );
    expect(await stored(), isEmpty);
  });

  test('reordering follows the given order', () async {
    final a = await controller.save(const DiaryTemplate(id: '', name: 'A'));
    final b = await controller.save(const DiaryTemplate(id: '', name: 'B'));
    await controller.reorder([b, a]);
    expect((await stored()).map((t) => t.name), ['B', 'A']);
  });
}
