import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_templates_controller.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
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
    expect(saved.bodyJson, '[{"insert":"正文\\n"}]');
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

  test(
    'hiding the auto built-in clears it and unhiding brings it back',
    () async {
      await controller.setAutoTemplate('builtin.daily');
      final wasAuto = await controller.setHidden('builtin.daily', true);
      expect(wasAuto, isTrue);
      expect(prefs().hiddenBuiltIns, {'builtin.daily'});
      expect(prefs().autoTemplateId, isNull);

      await controller.unhide('builtin.daily', wasAuto: wasAuto);
      expect(prefs().hiddenBuiltIns, isEmpty);
      expect(prefs().autoTemplateId, 'builtin.daily');
    },
  );

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
