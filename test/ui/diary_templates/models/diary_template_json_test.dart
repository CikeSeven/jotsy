import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_recommend.dart';

void main() {
  final full = DiaryTemplate(
    id: 'tpl-1',
    name: '晨间日记',
    description: '给今天定个方向',
    icon: DiaryTemplateIcon.sun,
    accent: 0xFFFB8C00,
    category: DiaryTemplateCategory.daily,
    titlePattern: '晨间 · {{日期}}',
    bodyJson: encodeDiaryTemplateBody([
      {
        'insert': '今天\n',
        'attributes': {'header': 2},
      },
    ]),
    tags: [
      DiaryTemplateTagRef(name: '晨间', color: 0xFF43A047),
      DiaryTemplateTagRef(name: 'morning', color: 0xFF1E88E5),
    ],
    mood: '🙂',
    energy: 4,
    capsule: TimeCapsulePreset.month,
    recommend: DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.morning},
    ),
  );

  test('payload round-trips every field', () {
    final payload = DiaryTemplateJson.toPayload(full);
    expect(DiaryTemplateJson.fromPayload(payload, id: 'tpl-1'), full);
  });

  test('a default template writes a sparse payload', () {
    final json = DiaryTemplateJson.toJson(
      const DiaryTemplate(id: 'x', name: '空白'),
    );
    expect(json, {
      'v': 2,
      'name': '空白',
      'body': jsonDecode(DiaryTemplate.emptyBodyJson),
    });
  });

  test('each broken field falls back on its own', () {
    final template = DiaryTemplateJson.fromJson({
      'name': '  一个   很长很长很长很长很长很长很长很长很长很长很长很长的名字  ',
      'description': 42,
      'icon': 'rocket',
      'accent': 'not a color',
      'category': 'life',
      'title': ['x'],
      'body': 'not json',
      'tags': [
        {'name': ' 旅行 ', 'color': '#00FF00'},
        {'name': '旅行', 'color': '#FF0000'},
        {'name': '', 'color': '#FF0000'},
        {'name': 'x' * 41},
        {'name': '无色'},
        'bad',
      ],
      'mood': '   ',
      'energy': 9.4,
      'capsule': 'decade',
      'recommend': {
        'weekdays': [8, 2],
      },
    }, id: 'tpl-2');

    expect(template.name.length, DiaryTemplate.maxNameLength);
    expect(template.name.startsWith('一个 很长'), isTrue);
    expect(template.description, '');
    expect(template.icon, DiaryTemplateIcon.penNib);
    expect(template.accent, isNull);
    expect(template.category, DiaryTemplateCategory.life);
    expect(template.titlePattern, '');
    expect(template.bodyJson, DiaryTemplate.emptyBodyJson);
    expect(template.tags, const [
      DiaryTemplateTagRef(name: '旅行', color: 0xFF00FF00),
      DiaryTemplateTagRef(
        name: '无色',
        color: DiaryTemplateJson.fallbackTagColor,
      ),
    ]);
    expect(template.mood, isNull);
    expect(template.energy, 5);
    expect(template.capsule, isNull);
    expect(template.recommend.weekdays, {2});
  });

  test('media embeds in a stored payload are stripped on read', () {
    final payload = jsonEncode({
      'name': '带图',
      'body': [
        {'insert': '文字\n'},
        {
          'insert': {'image': '/data/user/0/app/diary_images/a.jpg'},
        },
        {'insert': '\n'},
      ],
    });
    final template = DiaryTemplateJson.fromPayload(payload, id: 'x')!;
    expect(
      template.bodyJson,
      encodeDiaryTemplateBody([
        {'insert': '文字\n'},
      ]),
    );
  });

  test('an unreadable payload is null', () {
    expect(DiaryTemplateJson.fromPayload('{', id: 'x'), isNull);
    expect(DiaryTemplateJson.fromPayload('[1]', id: 'x'), isNull);
  });

  group('template code', () {
    test('round-trips and leaves the id to the importer', () {
      final code = encodeDiaryTemplateCode(full)!;
      expect(code, startsWith('jotsy-template:v2:'));
      final result = diaryTemplateCodeFormat.decode('看看这个模板 $code 好用');
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, full.copyWith(id: ''));
    });

    test('a card style code is not a template code', () {
      final result = diaryTemplateCodeFormat.decode(
        'jotsy-card:v1:eyJ2IjoxLCJzIjp7fX0',
      );
      expect(result.status, StyleCodeStatus.invalid);
    });

    test('a newer version is still read', () {
      final code = encodeDiaryTemplateCode(full)!.replaceFirst(':v2:', ':v9:');
      final result = diaryTemplateCodeFormat.decode(code);
      expect(result.status, StyleCodeStatus.newerVersion);
      expect(result.style?.name, '晨间日记');
    });

    test('a template too long for a code gives null', () {
      final long = full.copyWith(
        bodyJson: jsonEncode([
          {'insert': '${'很长的正文' * 3000}\n'},
        ]),
      );
      expect(encodeDiaryTemplateCode(long), isNull);
    });
  });
}
