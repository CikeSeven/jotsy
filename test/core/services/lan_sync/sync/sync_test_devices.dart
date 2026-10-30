import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_diary.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_misc.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_notebook.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:path/path.dart' as p;

/// 一台测试用的“设备”：内存数据库 + 独立的数据根目录与状态目录。
///
/// 不依赖全局的 path_provider 模拟：同步引擎的目录一律注入，同一个测试里
/// 可以有两台互不相干的设备。
class SyncTestDevice {
  SyncTestDevice._(this.root, this.dataRoot, this.stateDir, this.db);

  static Future<SyncTestDevice> create(String name) async {
    final root = await Directory.systemTemp.createTemp('jotsy_sync_${name}_');
    final dataRoot = await Directory(p.join(root.path, 'data')).create();
    return SyncTestDevice._(
      root,
      dataRoot,
      Directory(p.join(root.path, 'state')),
      AppDatabase.forTesting(NativeDatabase.memory()),
    );
  }

  final Directory root;
  final Directory dataRoot;
  final Directory stateDir;
  final AppDatabase db;

  Future<void> dispose() async {
    await db.close();
    await root.delete(recursive: true);
  }

  /// 托管媒体键在这台设备上的绝对路径。
  String media(String key) =>
      p.joinAll(<String>[dataRoot.path, ...key.split('/')]);

  Future<List<SyncRecord>> records({SyncSettingsCapture? settings}) async =>
      syncBuildRecords(await db.readSyncRows(), settings: settings);
}

/// 记录按键排序后的规范 JSON，便于逐字节比较两台设备。
Map<String, String> canonicalByKey(Iterable<SyncRecord> records) {
  final sorted = records.toList()..sort((a, b) => a.key.compareTo(b.key));
  return <String, String>{
    for (final record in sorted)
      record.key.toString(): syncCanonicalJson(record.facets),
  };
}

DateTime at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// 在设备 A 上铺满每一种实体（含历史格式正文、媒体、胶囊、归档 / 回收站、
/// 嵌套与智能日记本、悬空关联、内置模板、认不出的心情）。
Future<void> seedEveryEntity(SyncTestDevice device) async {
  final db = device.db;
  final media = device.media;
  final travel = await db
      .into(db.tags)
      .insert(
        const TagsCompanion(name: Value('travel'), color: Value(0xFF2196F3)),
      );
  final work = await db
      .into(db.tags)
      .insert(
        const TagsCompanion(name: Value('work'), color: Value(0xFFFF9800)),
      );
  await db
      .into(db.tags)
      .insert(
        const TagsCompanion(name: Value('unused'), color: Value(0xFF9E9E9E)),
      );

  Future<int> diary(
    String id, {
    required String content,
    String title = '',
    String? cover,
    String metadata = '{}',
    int created = 1700000000,
    int updated = 1700000100,
    bool pinned = false,
    bool archived = false,
    bool deleted = false,
    int? unlockAt,
    int? lockedAt,
  }) => db
      .into(db.diaries)
      .insert(
        DiariesCompanion.insert(
          diaryId: id,
          title: Value(title),
          content: content,
          contentText: 'stale text',
          cover: Value(cover),
          metadata: Value(metadata),
          createdAt: at(created),
          updatedAt: at(updated),
          isPinned: Value(pinned),
          isArchived: Value(archived),
          archivedAt: Value(archived ? at(1700000200) : null),
          isDeleted: Value(deleted),
          deletedAt: Value(deleted ? at(1700000300) : null),
          capsuleUnlockAt: Value(unlockAt == null ? null : at(unlockAt)),
          capsuleLockedAt: Value(lockedAt == null ? null : at(lockedAt)),
        ),
      );

  final rich = await diary(
    'diary-rich',
    title: 'Rich',
    pinned: true,
    cover: media('diary_covers/cover.jpg'),
    metadata: jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'generatedAt': '2026-01-01T10:00:00.000',
      'stats': <String, Object?>{'wordCount': 2, 'charCount': 10},
      'tagIds': <int>[travel, work],
      'hasCover': true,
      'device': <String, Object?>{'platform': 'android'},
      'context': <String, Object?>{
        'moodEmoji': '😀',
        'geo': <String, Object?>{'latitude': 31.2, 'longitude': 121.5},
      },
    }),
    content: jsonEncode(<String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': <Object?>[
          <String, Object?>{
            'type': 'paragraph',
            'data': <String, Object?>{
              'delta': <Object?>[
                <String, Object?>{'insert': 'Hello '},
                <String, Object?>{
                  'insert': 'world',
                  'attributes': <String, Object?>{'bold': true},
                },
              ],
            },
          },
          <String, Object?>{
            'type': 'image',
            'data': <String, Object?>{
              'url': media('diary_images/media_1/a.jpg'),
              'width': 320.0,
              'align': 'center',
            },
          },
          <String, Object?>{
            'type': 'audio',
            'data': <String, Object?>{
              'path': media('diary_recordings/r.m4a'),
              'durationMs': 1200,
              'waveform': <double>[0.2, 0.8],
            },
          },
          <String, Object?>{
            'type': 'video',
            'data': <String, Object?>{'url': media('diary_videos/v.mp4')},
          },
          <String, Object?>{
            'type': 'attachment',
            'data': <String, Object?>{
              'path': media('diary_attachments/report.pdf'),
              'name': 'report.pdf',
              'sizeBytes': 12,
            },
          },
          <String, Object?>{
            'type': 'image',
            'data': <String, Object?>{
              'url': 'https://example.com/diary_images/remote.png',
            },
          },
          <String, Object?>{
            'type': 'quote',
            'data': <String, Object?>{
              'delta': <Object?>[
                <String, Object?>{'insert': 'quoted'},
              ],
            },
            'children': <Object?>[
              <String, Object?>{
                'type': 'paragraph',
                'data': <String, Object?>{
                  'delta': <Object?>[
                    <String, Object?>{'insert': 'hidden child'},
                  ],
                },
              },
            ],
          },
        ],
      },
    }),
  );
  final delta = await diary(
    'diary-delta',
    title: 'Delta',
    archived: true,
    content: jsonEncode(<Object?>[
      <String, Object?>{'insert': 'Delta text\n'},
      <String, Object?>{
        'insert': <String, Object?>{'image': media('diary_images/b.png')},
      },
      <String, Object?>{'insert': '\n'},
      <String, Object?>{
        'insert': <String, Object?>{
          'audio': jsonEncode(<String, Object?>{
            'path': media('diary_recordings/old.m4a'),
            'durationMs': 500,
          }),
        },
      },
      <String, Object?>{'insert': '\n'},
    ]),
  );
  await diary(
    'diary-legacy',
    title: 'Legacy',
    deleted: true,
    metadata: 'not a json object {',
    content: jsonEncode(<String, Object?>{
      'root': <String, Object?>{
        'children': <Object?>[
          <String, Object?>{
            'type': 'paragraph',
            'attributes': <String, Object?>{
              'delta': <Object?>[
                <String, Object?>{'insert': 'legacy node'},
              ],
            },
          },
          <String, Object?>{
            'type': 'image',
            'attributes': <String, Object?>{
              'url': media('diary_images/legacy.jpg'),
            },
          },
        ],
      },
    }),
  );
  await diary(
    'diary-capsule',
    title: 'Capsule',
    content: 'plain line one\nline two',
    unlockAt: 1900000000,
    lockedAt: 1700000000,
    metadata: jsonEncode(<String, Object?>{
      'tagIds': <int>[],
      'capsule': <String, Object?>{
        'lockedAt': '2023-11-14T22:13:20.000',
        'unlockAt': '2030-03-17T17:46:40.000',
        'precision': 'date',
      },
    }),
  );
  final uri = await diary(
    'diary-uri',
    title: 'Uri',
    content: jsonEncode(<String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': <Object?>[
          <String, Object?>{
            'type': 'image',
            'data': <String, Object?>{
              'url': Uri.file(media('diary_images/c.jpg')).toString(),
            },
          },
        ],
      },
    }),
    metadata: jsonEncode(<String, Object?>{
      'import': <String, Object?>{
        'source': 'dayone',
        // 再编码一层的 JSON 字符串里也有托管路径。
        'attachments': jsonEncode(<Object?>[
          <String, Object?>{
            'path': media('diary_attachments/imp.pdf'),
            'name': 'imp.pdf',
          },
        ]),
      },
    }),
  );
  for (final (diaryId, tagId) in <(int, int)>[
    (rich, travel),
    (rich, work),
    (delta, work),
  ]) {
    await db
        .into(db.diaryTags)
        .insert(DiaryTagsCompanion.insert(diaryId: diaryId, tagId: tagId));
  }

  Future<int> notebook(
    String id, {
    required String name,
    String kind = 'manual',
    String visibility = 'normal',
    String payload = '{}',
    int sortOrder = 0,
    bool pinned = false,
    bool closed = false,
    String? parentId,
  }) => db
      .into(db.notebooks)
      .insert(
        NotebooksCompanion.insert(
          notebookId: id,
          name: name,
          kind: Value(kind),
          visibility: Value(visibility),
          payload: Value(payload),
          sortOrder: Value(sortOrder),
          isPinned: Value(pinned),
          isClosed: Value(closed),
          parentId: Value(parentId),
          createdAt: at(1700000000),
          updatedAt: at(1700000500),
        ),
      );

  final parent = await notebook(
    'nb-parent',
    name: 'Parent',
    visibility: 'hidden',
    sortOrder: 1,
    pinned: true,
    payload: jsonEncode(<String, Object?>{
      'desc': 'A notebook',
      'icon': 'book',
      'cover': media('diary_covers/nb.jpg'),
      'coverStyle': <String, Object?>{'layout': 'spine'},
      'chapters': <Object?>[
        <String, Object?>{'id': 'ch1', 'title': 'Chapter 1'},
      ],
      'sort': 'book',
      // 更新版本写入的键：同步必须原样保留。
      'futureKey': <String, Object?>{'x': 1},
    }),
  );
  final child = await notebook(
    'nb-child',
    name: 'Child',
    parentId: 'nb-parent',
  );
  final smart = await notebook(
    'nb-smart',
    name: 'Smart',
    kind: 'smart',
    sortOrder: 2,
    payload: jsonEncode(<String, Object?>{
      'rules': <String, Object?>{
        'match': 'all',
        'items': <Object?>[
          <String, Object?>{'type': 'tag', 'name': 'travel'},
        ],
      },
    }),
  );
  await notebook('nb-empty', name: 'Empty', sortOrder: 3, closed: true);
  for (final (diaryId, notebookId, chapter, position, added)
      in <(int, int, String?, int, int)>[
        (rich, parent, 'ch1', 1, 1700001000),
        (delta, parent, null, 0, 1700001000),
        (uri, parent, null, 1, 1700000900),
        (rich, child, null, 0, 1700001000),
        // 智能日记本不该有关联行：读规范记录时必须忽略。
        (rich, smart, null, 0, 1700001000),
        // 悬空：日记已不在。
        (9999, parent, null, 5, 1700001000),
      ]) {
    await db
        .into(db.diaryNotebooks)
        .insert(
          DiaryNotebooksCompanion.insert(
            diaryId: diaryId,
            notebookId: notebookId,
            chapterId: Value(chapter),
            position: Value(position),
            addedAt: at(added),
          ),
        );
  }

  await db
      .into(db.diaryComments)
      .insert(
        DiaryCommentsCompanion.insert(
          commentId: 'comment-1',
          diaryId: 'diary-rich',
          content: 'Rereading this',
          mood: const Value('😀'),
          createdAt: at(1700002000),
        ),
      );
  await db
      .into(db.diaryComments)
      .insert(
        DiaryCommentsCompanion.insert(
          commentId: 'comment-2',
          diaryId: 'diary-delta',
          content: 'Edited note',
          createdAt: at(1700002100),
          editedAt: Value(at(1700002200)),
        ),
      );

  Future<void> template(String id, int sortOrder) => db
      .into(db.diaryTemplates)
      .insert(
        DiaryTemplatesCompanion.insert(
          templateId: id,
          name: Value('Template $id'),
          payload: jsonEncode(<String, Object?>{
            'name': 'Template $id',
            'icon': 'pen',
            'body': <Object?>[
              <String, Object?>{'insert': 'Body\n'},
            ],
            'unknownField': true,
          }),
          sortOrder: Value(sortOrder),
          createdAt: at(1700003000),
          updatedAt: at(1700003100),
        ),
      );
  await template('tpl-1', 1);
  await template('tpl-2', 0);
  await template('builtin.daily', 5);

  await db
      .into(db.anniversaries)
      .insert(
        AnniversariesCompanion.insert(
          anniversaryId: 'ann-1',
          title: 'Birthday',
          baseDate: '2000-05-01',
          recurrence: const Value('lunarYearly'),
          lunarYear: const Value(2000),
          lunarMonth: const Value(-4),
          lunarDay: const Value(28),
          linkedDiaryId: const Value('diary-rich'),
          note: const Value('note'),
          isPinned: const Value(true),
          metadata: const Value('{"icon":"cake","color":4283215696}'),
          createdAt: at(1700004000),
          updatedAt: at(1700004100),
        ),
      );
  await db
      .into(db.anniversaries)
      .insert(
        AnniversariesCompanion.insert(
          anniversaryId: 'ann-2',
          title: 'Broken metadata',
          baseDate: '2020-02-29',
          recurrence: const Value('once'),
          metadata: const Value('not json'),
          createdAt: at(1700004000),
          updatedAt: at(1700004100),
        ),
      );

  await db
      .into(db.dayMoods)
      .insert(
        DayMoodsCompanion.insert(
          day: '2026-01-01',
          mood: 'good',
          updatedAt: at(1700005000),
        ),
      );
  await db
      .into(db.dayMoods)
      .insert(
        DayMoodsCompanion.insert(
          day: '2026-01-02',
          mood: 'ecstatic',
          updatedAt: at(1700005100),
        ),
      );
}

/// 测试里的最小写入：按反向列值把规范记录逐条插进一个空库（顺序列表的位置
/// 按列表下标写，与写入层“按列表重排为 0..n-1”的口径一致）。真正的写入层
/// （`SyncApplier`）带前置条件、更新与删除；这里只验证列值本身。
Future<void> writeRecordsForTest(
  SyncTestDevice device,
  List<SyncRecord> records,
) async {
  final db = device.db;
  final dataRoot = device.dataRoot.path;
  Iterable<SyncRecord> of(SyncEntity entity) =>
      records.where((record) => record.key.entity == entity);
  List<String> order(String listId) {
    for (final record in of(SyncEntity.orderList)) {
      if (record.key.id == listId) return syncOrderListIdsOf(record);
    }
    return const <String>[];
  }

  await db.transaction(() async {
    final tagIds = <String, int>{};
    for (final record in of(SyncEntity.tag)) {
      final columns = SyncTagColumns.fromRecord(record);
      tagIds[columns.name] = await db
          .into(db.tags)
          .insert(columns.toCompanion());
    }
    final diaryIds = <String, int>{};
    for (final record in of(SyncEntity.diary)) {
      final columns = SyncDiaryColumns.fromRecord(record, dataRoot: dataRoot);
      final localId = await db.into(db.diaries).insert(columns.toCompanion());
      diaryIds[columns.diaryId] = localId;
      for (final name in columns.tagNames) {
        await db
            .into(db.diaryTags)
            .insert(
              DiaryTagsCompanion.insert(diaryId: localId, tagId: tagIds[name]!),
            );
      }
    }
    final shelf = order(SyncOrderListId.shelf);
    final notebookIds = <String, int>{};
    for (final record in of(SyncEntity.notebook)) {
      final columns = SyncNotebookColumns.fromRecord(
        record,
        dataRoot: dataRoot,
      );
      notebookIds[columns.notebookId] = await db
          .into(db.notebooks)
          .insert(
            columns.toCompanion(sortOrder: shelf.indexOf(columns.notebookId)),
          );
    }
    for (final record in of(SyncEntity.membership)) {
      final columns = SyncMembershipColumns.fromRecord(record);
      final book = order(SyncOrderListId.book(columns.notebookId));
      await db
          .into(db.diaryNotebooks)
          .insert(
            DiaryNotebooksCompanion.insert(
              diaryId: diaryIds[columns.diaryId]!,
              notebookId: notebookIds[columns.notebookId]!,
              chapterId: Value(columns.chapterId),
              position: Value(book.indexOf(columns.diaryId)),
              addedAt: columns.addedAt,
            ),
          );
    }
    for (final record in of(SyncEntity.comment)) {
      await db
          .into(db.diaryComments)
          .insert(SyncCommentColumns.fromRecord(record).toCompanion());
    }
    final templates = order(SyncOrderListId.templates);
    for (final record in of(SyncEntity.template)) {
      final columns = SyncTemplateColumns.fromRecord(
        record,
        dataRoot: dataRoot,
      );
      final index = templates.indexOf(columns.templateId);
      await db
          .into(db.diaryTemplates)
          .insert(columns.toCompanion(sortOrder: index < 0 ? 99 : index));
    }
    for (final record in of(SyncEntity.anniversary)) {
      await db
          .into(db.anniversaries)
          .insert(
            SyncAnniversaryColumns.fromRecord(
              record,
              dataRoot: dataRoot,
            ).toCompanion(),
          );
    }
    for (final record in of(SyncEntity.dayMood)) {
      await db
          .into(db.dayMoods)
          .insert(SyncDayMoodColumns.fromRecord(record).toCompanion());
    }
  });
}
