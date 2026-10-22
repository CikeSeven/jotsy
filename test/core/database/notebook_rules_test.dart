import '../../support/diary_content_test_helpers.dart';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';

/// 智能日记本规则：JSON 编解码（含保留未知规则）与编译出的 SQL 在真实
/// 数据库上的匹配结果。
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 18, 15, 30);
  final day = DateTime(2026, 10, 10, 9);

  /// 业务 id → 标题，断言时按标题比较更直观。
  final titles = <String, String>{};

  setUp(() async {
    titles.clear();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.batch((batch) {
      batch.insertAll(db.tags, <TagsCompanion>[
        TagsCompanion.insert(id: const Value(1), name: '旅行', color: 1),
        TagsCompanion.insert(id: const Value(2), name: '出差', color: 2),
        TagsCompanion.insert(id: const Value(3), name: '美食', color: 3),
      ]);
    });
  });
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    String content = '',
    String text = '',
    List<int> tagIds = const <int>[],
    Map<String, Object?>? context,
    DateTime? createdAt,
    String? cover,
    DateTime? capsuleUnlockAt,
    List<String>? notebookIds,
  }) async {
    final id = await db.createDiary(
      title: title,
      contentDocJson: content.isEmpty
          ? jsonEncode(<Object?>[
              <String, Object?>{'insert': '$text\n'},
            ])
          : content,
      contentText: text,
      metadataJson: jsonEncode(<String, Object?>{'context': ?context}),
      cover: cover,
      tagIds: tagIds,
      createdAtOverride: createdAt ?? day,
      capsuleUnlockAt: capsuleUnlockAt,
      capsuleLockedAt: capsuleUnlockAt == null ? null : day,
      notebookIds: notebookIds,
    );
    titles[id] = title;
    return id;
  }

  Future<Set<String>> matching(
    List<NotebookRule> rules, {
    NotebookRuleMatch match = NotebookRuleMatch.all,
  }) async {
    final ids = await db.getActiveDiaryIds(
      scope: DiarySmartScope(
        notebookId: 'smart',
        predicate: compileNotebookRules(
          NotebookRuleSet(match: match, rules: rules),
          now: now,
        ),
      ),
    );
    return <String>{for (final id in ids) titles[id]!};
  }

  String documentWith(Map<String, Object?> embed) => encodeDiaryDocumentToJson(
    documentFromLegacyDelta([
      {'insert': embed},
      {'insert': '\n说 "image": "video": 不算\n'},
    ]),
  );

  group('JSON', () {
    test('every rule kind round-trips through encode / decode', () {
      final set = NotebookRuleSet(
        match: NotebookRuleMatch.any,
        rules: <NotebookRule>[
          NotebookTagsRule(
            mode: NotebookTagMatch.none,
            names: <String>[' 旅行 ', '旅行', '', '出差'],
          ),
          NotebookMoodRule(emojis: <String>['😀', '😢']),
          NotebookTextRule(field: NotebookTextField.weather, text: ' 雨 '),
          NotebookTextRule(field: NotebookTextField.location, text: '京都'),
          NotebookTextRule(field: NotebookTextField.keyword, text: '樱花'),
          NotebookDateRule.between(
            DateTime(2026, 10, 18),
            DateTime(2026, 10, 6),
          ),
          NotebookDateRule.lastDays(30),
          const NotebookDateRule.thisYear(),
          NotebookDateRule.monthEveryYear(10),
          const NotebookDateRule.dayEveryYear(),
          const NotebookMediaRule(NotebookMediaKind.audio),
          const NotebookFlagRule(NotebookFlagKind.hasCover),
        ],
      );
      final encoded = set.encode();
      final rules = encoded['rules']! as List<Object?>;
      expect(encoded['match'], 'any');
      expect(rules.first, <String, Object?>{
        'type': 'tags',
        'mode': 'none',
        'names': <String>['旅行', '出差'],
      });
      expect(rules[2], <String, Object?>{'type': 'weather', 'contains': '雨'});
      expect(rules[4], <String, Object?>{'type': 'keyword', 'text': '樱花'});
      expect(rules[5], <String, Object?>{
        'type': 'date',
        'kind': 'between',
        'from': '2026-10-06',
        'to': '2026-10-18',
      });
      // 经过一次 JSON 文本（与 payload 落库相同）再解码，得到相等的规则集。
      final decoded = NotebookRuleSet.decode(
        jsonDecode(jsonEncode(encoded)) as Map<String, Object?>,
      );
      expect(decoded, set);
      expect(decoded.rules.whereType<NotebookUnknownRule>(), isEmpty);
    });

    test('bad and unknown rules are kept verbatim and saved back', () {
      final raw = <String, Object?>{
        'match': 'all',
        'rules': <Object?>[
          <String, Object?>{'type': 'wordCount', 'min': 500},
          <String, Object?>{
            'type': 'tags',
            'mode': 'any',
            'names': <Object?>[],
          },
          <String, Object?>{
            'type': 'date',
            'kind': 'monthEveryYear',
            'month': 13,
          },
          <String, Object?>{
            'type': 'date',
            'kind': 'between',
            'from': '2026-02-30',
            'to': '2026-03-01',
          },
          <String, Object?>{'type': 'flag', 'kind': 'starred'},
          'not a map',
          <String, Object?>{'type': 'flag', 'kind': 'pinned'},
        ],
      };
      final set = NotebookRuleSet.decode(raw);
      expect(set.rules, hasLength(7));
      expect(set.rules.take(6), everyElement(isA<NotebookUnknownRule>()));
      expect(set.rules.last, const NotebookFlagRule(NotebookFlagKind.pinned));
      final encoded = set.encode()['rules']! as List<Object?>;
      expect(encoded.first, <String, Object?>{'type': 'wordCount', 'min': 500});
      expect(encoded[2], (raw['rules']! as List<Object?>)[2]);
    });

    test('decoding tolerates missing data and caps the rule count', () {
      expect(NotebookRuleSet.decode(null).isEmpty, isTrue);
      expect(
        NotebookRuleSet.decode(const <String, Object?>{'match': 'nope'}).match,
        NotebookRuleMatch.all,
      );
      final many = NotebookRuleSet.decode(<String, Object?>{
        'rules': <Object?>[
          for (var i = 0; i < 20; i++)
            <String, Object?>{'type': 'flag', 'kind': 'pinned'},
        ],
      });
      expect(many.rules, hasLength(NotebookRuleSet.maxRules));
      final days = NotebookRuleSet.decode(<String, Object?>{
        'rules': <Object?>[
          <String, Object?>{'type': 'date', 'kind': 'lastDays', 'days': 9999},
          <String, Object?>{'type': 'date', 'kind': 'lastDays', 'days': 7.0},
        ],
      });
      expect(days.rules, <NotebookRule>[
        NotebookDateRule.lastDays(NotebookDateRule.maxDays),
        NotebookDateRule.lastDays(7),
      ]);
    });

    test('the same rules compile to an equal predicate all day long', () {
      final set = NotebookRuleSet(
        rules: <NotebookRule>[
          NotebookDateRule.lastDays(30),
          const NotebookDateRule.dayEveryYear(),
          NotebookTextRule(field: NotebookTextField.keyword, text: 'x'),
        ],
      );
      expect(
        compileNotebookRules(set, now: DateTime(2026, 10, 18, 0, 1)),
        compileNotebookRules(set, now: DateTime(2026, 10, 18, 23, 59)),
      );
      expect(
        compileNotebookRules(set, now: DateTime(2026, 10, 18)),
        isNot(compileNotebookRules(set, now: DateTime(2026, 10, 19))),
      );
    });
  });

  group('matching', () {
    test('an empty set and unknown rules match nothing', () async {
      await diary('a');
      expect(compileNotebookRules(NotebookRuleSet()).sql, '0');
      expect(await matching(const <NotebookRule>[]), isEmpty);
      expect(
        await matching(<NotebookRule>[
          NotebookUnknownRule(const <String, Object?>{'type': 'future'}),
        ]),
        isEmpty,
      );
    });

    test('tags: any, all and none by name', () async {
      await diary('travel', tagIds: <int>[1]);
      await diary('both', tagIds: <int>[1, 2]);
      await diary('food', tagIds: <int>[3]);
      await diary('none');
      Future<Set<String>> tags(NotebookTagMatch mode) =>
          matching(<NotebookRule>[
            NotebookTagsRule(mode: mode, names: <String>['旅行', '出差']),
          ]);
      expect(await tags(NotebookTagMatch.any), <String>{'travel', 'both'});
      expect(await tags(NotebookTagMatch.all), <String>{'both'});
      expect(await tags(NotebookTagMatch.none), <String>{'food', 'none'});
      // 不存在的标签名：任一不中，“都不含”全中。
      expect(
        await matching(<NotebookRule>[
          NotebookTagsRule(mode: NotebookTagMatch.any, names: <String>['没有']),
        ]),
        isEmpty,
      );
    });

    test('mood, weather and location (case-insensitive)', () async {
      await diary(
        'happy',
        context: <String, Object?>{'moodEmoji': '😀', 'weather': 'Light Rain'},
      );
      await diary(
        'sad',
        context: <String, Object?>{'moodEmoji': '😢', 'location': '日本京都市'},
      );
      await diary('plain');
      expect(
        await matching(<NotebookRule>[
          NotebookMoodRule(emojis: <String>['😀', '😡']),
        ]),
        <String>{'happy'},
      );
      expect(
        await matching(<NotebookRule>[
          NotebookTextRule(field: NotebookTextField.weather, text: 'rain'),
        ]),
        <String>{'happy'},
      );
      expect(
        await matching(<NotebookRule>[
          NotebookTextRule(field: NotebookTextField.location, text: '京都'),
        ]),
        <String>{'sad'},
      );
      // LIKE 的通配符按字面匹配。
      expect(
        await matching(<NotebookRule>[
          NotebookTextRule(field: NotebookTextField.weather, text: '%'),
        ]),
        isEmpty,
      );
    });

    test('keyword matches titles always and bodies once unsealed', () async {
      await diary('樱花之旅', text: '正文');
      await diary('普通', text: '看了樱花');
      await diary('胶囊标题', text: '樱花在胶囊里', capsuleUnlockAt: DateTime(2099));
      await diary('樱花胶囊', text: '…', capsuleUnlockAt: DateTime(2099));
      await diary('已解封', text: '樱花', capsuleUnlockAt: DateTime(2020));
      expect(
        await matching(<NotebookRule>[
          NotebookTextRule(field: NotebookTextField.keyword, text: '樱花'),
        ]),
        <String>{'樱花之旅', '普通', '樱花胶囊', '已解封'},
      );
    });

    test('sealed capsules keep tags, mood and cover private', () async {
      await diary(
        'sealed',
        tagIds: <int>[1],
        context: <String, Object?>{'moodEmoji': '😀'},
        cover: '/c.jpg',
        capsuleUnlockAt: DateTime(2099),
      );
      for (final rule in <NotebookRule>[
        NotebookTagsRule(mode: NotebookTagMatch.any, names: <String>['旅行']),
        NotebookTagsRule(mode: NotebookTagMatch.none, names: <String>['美食']),
        NotebookMoodRule(emojis: <String>['😀']),
        const NotebookFlagRule(NotebookFlagKind.hasCover),
      ]) {
        expect(await matching(<NotebookRule>[rule]), isEmpty, reason: '$rule');
      }
    });

    test('media kinds read the codec-encoded embeds', () async {
      await diary('image', content: documentWith({'image': '/m/a.png'}));
      await diary('video', content: documentWith({'video': '/m/a.mp4'}));
      await diary(
        'audio',
        content: documentWith({
          diaryAudioEmbedType: const DiaryAudioAttachment(
            path: '/m/a.m4a',
            duration: Duration(seconds: 3),
            name: 'image',
            waveform: <double>[0.1, 0.5],
          ).encode(),
        }),
      );
      await diary(
        'attachment',
        content: documentWith({
          diaryAttachmentEmbedType: const DiaryFileAttachment(
            path: '/m/a.pdf',
            name: 'video.pdf',
            sizeBytes: 10,
          ).encode(),
        }),
      );
      await diary(
        'legacy file',
        content: jsonEncode(<Object?>[
          <String, Object?>{
            'insert': <String, Object?>{'file': '/m/old.zip'},
          },
          <String, Object?>{'insert': '\n'},
        ]),
      );
      await diary(
        'legacy delta audio',
        content: jsonEncode([
          {
            'insert': {
              'audio': jsonEncode({'path': '/m/old.m4a', 'durationMs': 100}),
            },
          },
          {'insert': '\n'},
        ]),
      );
      await diary(
        'legacy appflowy image',
        content: jsonEncode(<String, Object?>{
          'document': <String, Object?>{
            'type': 'page',
            'children': <Object?>[
              <String, Object?>{
                'type': 'image',
                'data': <String, Object?>{'url': '/m/b.png'},
              },
            ],
          },
        }),
      );
      await diary('text only', text: '"image": "audio": "attachment":');
      await diary(
        'sealed image',
        content: documentWith({'image': '/m/s.png'}),
        capsuleUnlockAt: DateTime(2099),
      );
      Future<Set<String>> media(NotebookMediaKind kind) =>
          matching(<NotebookRule>[NotebookMediaRule(kind)]);
      expect(await media(NotebookMediaKind.image), <String>{
        'image',
        'legacy appflowy image',
      });
      expect(await media(NotebookMediaKind.video), <String>{'video'});
      expect(await media(NotebookMediaKind.audio), <String>{
        'audio',
        'legacy delta audio',
      });
      expect(await media(NotebookMediaKind.attachment), <String>{
        'attachment',
        'legacy file',
      });
    });

    test('flags: cover and pinned', () async {
      await diary('cover', cover: '/c.jpg');
      await diary('blank cover', cover: '  ');
      final pinned = await diary('pinned');
      await db.pinDiary(pinned);
      expect(
        await matching(const <NotebookRule>[
          NotebookFlagRule(NotebookFlagKind.hasCover),
        ]),
        <String>{'cover'},
      );
      expect(
        await matching(const <NotebookRule>[
          NotebookFlagRule(NotebookFlagKind.pinned),
        ]),
        <String>{'pinned'},
      );
    });

    test('date kinds and their boundaries', () async {
      await diary('09-18 23:59', createdAt: DateTime(2026, 9, 18, 23, 59));
      await diary('09-19 00:00', createdAt: DateTime(2026, 9, 19));
      await diary('10-05 23:59', createdAt: DateTime(2026, 10, 5, 23, 59));
      await diary('10-06 00:00', createdAt: DateTime(2026, 10, 6));
      await diary('10-18 23:59', createdAt: DateTime(2026, 10, 18, 23, 59));
      await diary('10-19 00:00', createdAt: DateTime(2026, 10, 19));
      await diary('2026-01-01', createdAt: DateTime(2026));
      await diary('2025-12-31', createdAt: DateTime(2025, 12, 31, 23, 59));
      await diary('2020-10-18', createdAt: DateTime(2020, 10, 18, 8));
      await diary('2020-10-17', createdAt: DateTime(2020, 10, 17, 8));
      await diary('2023-11-01', createdAt: DateTime(2023, 11));

      Future<Set<String>> date(NotebookDateRule rule) =>
          matching(<NotebookRule>[rule]);
      expect(
        await date(
          NotebookDateRule.between(
            DateTime(2026, 10, 6),
            DateTime(2026, 10, 18),
          ),
        ),
        <String>{'10-06 00:00', '10-18 23:59'},
      );
      expect(await date(NotebookDateRule.lastDays(30)), <String>{
        '09-19 00:00',
        '10-05 23:59',
        '10-06 00:00',
        '10-18 23:59',
      });
      expect(await date(NotebookDateRule.lastDays(1)), <String>{'10-18 23:59'});
      expect(await date(const NotebookDateRule.thisYear()), <String>{
        '09-18 23:59',
        '09-19 00:00',
        '10-05 23:59',
        '10-06 00:00',
        '10-18 23:59',
        '10-19 00:00',
        '2026-01-01',
      });
      expect(await date(NotebookDateRule.monthEveryYear(10)), <String>{
        '10-05 23:59',
        '10-06 00:00',
        '10-18 23:59',
        '10-19 00:00',
        '2020-10-18',
        '2020-10-17',
      });
      expect(await date(const NotebookDateRule.dayEveryYear()), <String>{
        '10-18 23:59',
        '2020-10-18',
      });
    });

    test('all joins with AND, any with OR', () async {
      await diary('travel photo', tagIds: <int>[1], cover: '/c.jpg');
      await diary('travel', tagIds: <int>[1]);
      await diary('photo', cover: '/c.jpg');
      await diary('neither');
      final rules = <NotebookRule>[
        NotebookTagsRule(mode: NotebookTagMatch.any, names: <String>['旅行']),
        const NotebookFlagRule(NotebookFlagKind.hasCover),
      ];
      expect(await matching(rules), <String>{'travel photo'});
      expect(await matching(rules, match: NotebookRuleMatch.any), <String>{
        'travel photo',
        'travel',
        'photo',
      });
      // 认不出的规则在“任一”里只是不贡献匹配，在“全部”里让整体不匹配。
      final withUnknown = <NotebookRule>[
        ...rules,
        NotebookUnknownRule(const <String, Object?>{'type': 'future'}),
      ];
      expect(await matching(withUnknown), isEmpty);
      expect(
        await matching(withUnknown, match: NotebookRuleMatch.any),
        hasLength(3),
      );
    });

    test('archived, deleted and private diaries stay out', () async {
      final hidden = await db.createNotebook(
        name: '私密',
        visibility: NotebookVisibility.hidden,
      );
      await diary('visible', tagIds: <int>[1]);
      await diary('private', tagIds: <int>[1], notebookIds: <String>[hidden]);
      final archived = await diary('archived', tagIds: <int>[1]);
      await db.archiveDiary(archived);
      final deleted = await diary('deleted', tagIds: <int>[1]);
      await db.softDeleteDiary(deleted);
      expect(
        await matching(<NotebookRule>[
          NotebookTagsRule(mode: NotebookTagMatch.any, names: <String>['旅行']),
        ]),
        <String>{'visible'},
      );
    });

    test('a smart notebook scope recompiles from its payload', () async {
      await diary('travel', tagIds: <int>[1]);
      await diary('other');
      final rules = NotebookRuleSet(
        rules: <NotebookRule>[
          NotebookTagsRule(mode: NotebookTagMatch.any, names: <String>['旅行']),
        ],
      );
      final id = await db.createNotebook(
        name: '旅行',
        kind: NotebookKind.smart,
        payload: NotebookPayload(rules: rules.encode()),
      );
      final row = (await db.getNotebook(id))!;
      final decoded = NotebookRuleSet.decode(row.parsedPayload.rules);
      expect(decoded, rules);
      final count = await db
          .watchScopedDiaryCount(
            DiarySmartScope(
              notebookId: id,
              predicate: compileNotebookRules(decoded, now: now),
            ),
          )
          .first;
      expect(count, 1);
    });
  });
}
