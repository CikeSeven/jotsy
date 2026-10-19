import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/notebook_payload.dart';

void main() {
  group('decode tolerance', () {
    test('missing, blank and malformed input fall back to defaults', () {
      for (final raw in <String?>[null, '', '  ', '{bad', '[]', '"x"', '3']) {
        expect(NotebookPayload.decode(raw), NotebookPayload.defaults);
      }
    });

    test('a field of the wrong type is dropped without losing the rest', () {
      final payload = NotebookPayload.decode(
        jsonEncode(<String, Object?>{
          'desc': 42,
          'icon': 'book',
          'color': '0xFF000000',
          'cover': '/covers/a.jpg',
          'sort': 'sideways',
          'goal': <String, Object?>{'period': 'week', 'target': 'three'},
          'template': <String>[],
          'rules': 'not a map',
        }),
      );
      expect(payload.description, '');
      expect(payload.icon, 'book');
      expect(payload.color, isNull);
      expect(payload.coverPath, '/covers/a.jpg');
      expect(payload.sort, NotebookSort.createdDesc);
      expect(payload.goal, isNull);
      expect(payload.templateId, isNull);
      expect(payload.rules, isNull);
    });

    test('broken and duplicate chapters are dropped individually', () {
      final payload = NotebookPayload.decode(
        jsonEncode(<String, Object?>{
          'chapters': <Object?>[
            <String, Object?>{'id': 'a', 'title': ' 第一章 '},
            <String, Object?>{'id': 'a', 'title': '重复'},
            <String, Object?>{'id': 'b', 'title': '   '},
            <String, Object?>{'id': 3, 'title': '坏 id'},
            'not a chapter',
            <String, Object?>{'id': 'c', 'title': '长' * 50},
          ],
        }),
      );
      expect(payload.chapters.map((c) => c.id), <String>['a', 'c']);
      expect(payload.chapters.first.title, '第一章');
      expect(
        payload.chapters.last.title.length,
        NotebookChapter.maxTitleLength,
      );
    });

    test('goal targets are clamped and whole doubles are accepted', () {
      NotebookGoal? goal(Object target) => NotebookPayload.decode(
        jsonEncode(<String, Object?>{
          'goal': <String, Object?>{'period': 'day', 'target': target},
        }),
      ).goal;
      expect(goal(0)!.target, 1);
      expect(goal(99)!.target, 20);
      expect(goal(3.0)!.target, 3);
      expect(goal(2.5), isNull);
    });

    test('description is trimmed and capped without splitting emoji', () {
      final payload = NotebookPayload(description: '  ${'😀' * 130}  ');
      expect(payload.description.runes.length, 120);
      expect(payload.description, '😀' * 120);
    });

    test('unknown kind falls back to manual, unknown visibility to locked', () {
      expect(NotebookKind.fromName('folder'), NotebookKind.manual);
      expect(NotebookKind.fromName('smart'), NotebookKind.smart);
      expect(NotebookVisibility.fromName(null), NotebookVisibility.normal);
      expect(NotebookVisibility.fromName('locked'), NotebookVisibility.locked);
      expect(NotebookVisibility.fromName('secret'), NotebookVisibility.locked);
    });
  });

  group('encode', () {
    test('defaults encode to an empty object', () {
      expect(NotebookPayload.defaults.encode(), '{}');
      expect(NotebookPayload().encode(), '{}');
    });

    test('a full payload survives a round trip', () {
      final payload = NotebookPayload(
        description: '旅行记录',
        icon: 'plane',
        color: 0xFF3366CC,
        coverPath: '/covers/trip.jpg',
        chapters: <NotebookChapter>[
          NotebookChapter(id: 'c1', title: '出发'),
          NotebookChapter.create('归来'),
        ],
        sort: NotebookSort.book,
        goal: NotebookGoal(period: NotebookGoalPeriod.week, target: 3),
        templateId: 'builtin.travel',
        rules: <String, Object?>{
          'match': 'all',
          'conditions': <Object?>[
            <String, Object?>{'tag': '旅行'},
          ],
          'future': <String, Object?>{'kept': true},
        },
      );
      final decoded = NotebookPayload.decode(payload.encode());
      expect(decoded, payload);
      expect(decoded.hashCode, payload.hashCode);
      expect(decoded.rules!['future'], <String, Object?>{'kept': true});
    });

    test('equal rules compare equal regardless of key order', () {
      final a = NotebookPayload(rules: <String, Object?>{'x': 1, 'y': 2});
      final b = NotebookPayload(rules: <String, Object?>{'y': 2, 'x': 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('copyWith', () {
    final full = NotebookPayload(
      icon: 'book',
      color: 0xFF000000,
      coverPath: '/c.jpg',
      goal: NotebookGoal(period: NotebookGoalPeriod.month, target: 5),
      templateId: 't',
      rules: const <String, Object?>{'a': 1},
    );

    test('null keeps values and clear flags remove them', () {
      expect(full.copyWith(), full);
      final cleared = full.copyWith(
        clearIcon: true,
        clearColor: true,
        clearCoverPath: true,
        clearGoal: true,
        clearTemplateId: true,
        clearRules: true,
      );
      expect(cleared, NotebookPayload.defaults);
    });

    test('duplicate chapter ids keep the first one', () {
      final payload = full.copyWith(
        chapters: <NotebookChapter>[
          NotebookChapter(id: 'a', title: '一'),
          NotebookChapter(id: 'a', title: '二'),
        ],
      );
      expect(payload.chapters.single.title, '一');
    });
  });

  test('chapters reject empty ids and titles', () {
    expect(() => NotebookChapter(id: 'a', title: '  '), throwsArgumentError);
    expect(() => NotebookChapter(id: '', title: '标题'), throwsArgumentError);
    expect(NotebookChapter.newId(), matches(RegExp(r'^[a-z0-9]{8}$')));
  });
}
