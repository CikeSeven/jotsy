import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import 'backup_constants.dart';
import 'backup_media_paths.dart';
import 'backup_settings.dart';
import 'diary_draft_legacy.dart';
import 'settings_service.dart';

/// 强类型备份数据及表结构/关联校验；解析、媒体重绑阶段不修改现有数据。
/// writeDatabase 只在外层恢复事务内写表，文件换入和设置回滚交由归档服务。
class BackupPayload {
  const BackupPayload({
    required this.diaries,
    required this.tags,
    required this.diaryTags,
    this.anniversaries = const <Anniversary>[],
    this.diaryDrafts = const <DiaryDraftRow>[],
    this.diaryTemplates = const <DiaryTemplateRow>[],
    this.notebooks = const <NotebookRow>[],
    this.diaryNotebooks = const <DiaryNotebookRow>[],
    this.dayMoods = const <DayMoodRow>[],
    this.diaryComments = const <DiaryCommentRow>[],
    this.settings,
  });

  final List<Diary> diaries;
  final List<Tag> tags;
  final List<DiaryTag> diaryTags;

  /// 纪念日（schema v9 起）。旧备份与日记包没有这张表，解析为空列表。
  final List<Anniversary> anniversaries;

  /// 草稿箱（schema v11 起）。更早的完整备份只在设置里带一份新建草稿
  /// （`createDiaryDraftRaw`），解析时转成一行；日记包没有草稿。
  final List<DiaryDraftRow> diaryDrafts;

  /// 用户自建的日记模板（schema v12 起）。旧备份没有这张表，解析为空列表；
  /// 日记包不带模板。内置模板不落库，id 以 `builtin.` 开头的行一律丢弃。
  final List<DiaryTemplateRow> diaryTemplates;

  /// 日记本定义（schema v13 起）。旧备份没有这张表，解析为空列表；日记包只带
  /// 包内日记所在的手动日记本。
  final List<NotebookRow> notebooks;

  /// 日记-日记本关联，两端都是**文件里的**本地 id（覆盖恢复原样保留，合并时
  /// 经日记与日记本的 id 映射改写）。解析后只剩两端都在载荷里、且日记本为
  /// 手动类型的行（见 [_withRestorableRelations]）。
  final List<DiaryNotebookRow> diaryNotebooks;

  /// 这天的心情（schema v14 起）。旧备份没有这张表，解析为空列表；日记包不带
  /// （心情属于日子本身，不属于哪几篇日记）。认不出的心情名原样保留。
  final List<DayMoodRow> dayMoods;

  /// 日记留言（schema v16 起），按日记的**业务 id** 关联。旧备份没有这张表，
  /// 解析为空列表；日记包带包内日记的留言。解析后只剩所属日记在载荷里的行
  /// （见 [_withRestorableRelations]）。
  final List<DiaryCommentRow> diaryComments;
  final Map<String, dynamic>? settings;

  factory BackupPayload.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份数据格式错误');
    }
    final version = decoded['formatVersion'];
    // 无版本标记时仍严格校验 v1 表结构；明确标记的未知版本不能按空库导入。
    if (version != null && version != backupFormatVersion) {
      throw const FormatException('不支持的备份版本');
    }
    final database = decoded['database'];
    if (database is! Map<String, dynamic>) {
      throw const FormatException('备份数据缺少 database 节点');
    }
    final settings = decoded['settings'];
    if (settings != null && settings is! Map<String, dynamic>) {
      throw const FormatException('备份设置格式错误');
    }

    try {
      final payload = BackupPayload(
        diaries: _rows(database, 'diaries')
            .map((row) {
              return Diary.fromJson({
                // 这些字段随 schema 演进新增，旧备份省略时采用数据库默认值。
                'isArchived': false,
                'isPinned': false,
                'isDeleted': false,
                ...row,
              });
            })
            .toList(growable: false),
        tags: _rows(database, 'tags').map(Tag.fromJson).toList(growable: false),
        diaryTags: _rows(
          database,
          'diaryTags',
        ).map(DiaryTag.fromJson).toList(growable: false),
        anniversaries: _optionalRows(database, 'anniversaries')
            .map((row) {
              return Anniversary.fromJson({
                // 可省略的列按数据库默认值补齐，必填列缺失照常报错。
                'recurrence': AnniversaryRecurrence.solarYearly.name,
                'note': '',
                'isPinned': false,
                'metadata': '{}',
                ...row,
              });
            })
            .toList(growable: false),
        diaryDrafts: database.containsKey('diaryDrafts')
            ? _rows(database, 'diaryDrafts')
                  .map((row) {
                    return DiaryDraftRow.fromJson({
                      'title': '',
                      'contentText': '',
                      ...row,
                    });
                  })
                  .toList(growable: false)
            : _legacyDraftRows(settings as Map<String, dynamic>?),
        diaryTemplates: _optionalRows(database, 'diaryTemplates')
            .map((row) {
              return DiaryTemplateRow.fromJson({
                'name': '',
                'sortOrder': 0,
                ...row,
              });
            })
            .toList(growable: false),
        notebooks: _optionalRows(database, 'notebooks')
            .map((row) {
              return NotebookRow.fromJson({
                // 有列默认值的字段省略时按默认值补齐，必填列缺失照常报错。
                'kind': NotebookKind.manual.name,
                'visibility': NotebookVisibility.normal.name,
                'payload': '{}',
                'sortOrder': 0,
                'isPinned': false,
                'isClosed': false,
                ...row,
              });
            })
            .toList(growable: false),
        diaryNotebooks: _optionalRows(database, 'diaryNotebooks')
            .map((row) => DiaryNotebookRow.fromJson({'position': 0, ...row}))
            .toList(growable: false),
        dayMoods: _optionalRows(
          database,
          'dayMoods',
        ).map(DayMoodRow.fromJson).toList(growable: false),
        diaryComments: _optionalRows(
          database,
          'diaryComments',
        ).map(DiaryCommentRow.fromJson).toList(growable: false),
        settings: settings as Map<String, dynamic>?,
      );
      payload._validateKeys();
      return payload._withRestorableRelations();
    } on TypeError {
      throw const FormatException('备份数据字段格式错误');
    }
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> database,
    String name,
  ) {
    final rows = database[name];
    // 空表必须明确写为 []，不能把缺失、错误类型或坏行悄悄当作空表。
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw FormatException('备份表 $name 格式错误');
    }
    return rows.cast<Map<String, dynamic>>();
  }

  /// 草稿箱之前的完整备份：设置里那一份新建草稿转成草稿行，覆盖恢复后它
  /// 出现在草稿箱里。没有内容或 JSON 坏掉的草稿不转换（与启动迁移同一口径）。
  static List<DiaryDraftRow> _legacyDraftRows(Map<String, dynamic>? settings) {
    final raw = settings?['createDiaryDraftRaw'];
    final draft = parseLegacyCreateDraft(raw is String ? raw : null);
    if (draft == null) return const <DiaryDraftRow>[];
    final now = DateTime.now();
    return <DiaryDraftRow>[
      DiaryDraftRow(
        id: 1,
        draftId: AppDatabase.newBusinessId(),
        title: draft.title,
        contentText: draft.contentText,
        payload: draft.payload,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// 后来新增的表：旧版本导出的备份没有这个键，按空表处理；键存在时与
  /// [_rows] 同样严格，错误类型或坏行不能当作空表。
  static List<Map<String, dynamic>> _optionalRows(
    Map<String, dynamic> database,
    String name,
  ) {
    if (!database.containsKey(name)) {
      return const <Map<String, dynamic>>[];
    }
    return _rows(database, name);
  }

  void _validateKeys() {
    _unique(diaries.map((row) => row.id));
    _unique(tags.map((row) => row.id));
    _unique(diaries.map((row) => row.diaryId));
    _unique(tags.map((row) => row.name));
    _unique(diaryTags.map((row) => (row.diaryId, row.tagId)));
    _unique(anniversaries.map((row) => row.id));
    _unique(anniversaries.map((row) => row.anniversaryId));
    _unique(diaryDrafts.map((row) => row.id));
    _unique(diaryDrafts.map((row) => row.draftId));
    _unique(diaryTemplates.map((row) => row.id));
    _unique(diaryTemplates.map((row) => row.templateId));
    _unique(notebooks.map((row) => row.id));
    _unique(notebooks.map((row) => row.notebookId));
    _unique(diaryNotebooks.map((row) => (row.diaryId, row.notebookId)));
    _unique(dayMoods.map((row) => row.day));
    _unique(diaryComments.map((row) => row.id));
    _unique(diaryComments.map((row) => row.commentId));
    // 纪念日的日期与名称决定日历怎么画，坏行在写库前拒绝，而不是导入后
    // 才在页面上算不出日子。
    for (final row in anniversaries) {
      final title = row.title.trim();
      if (parseAnniversaryDate(row.baseDate) == null ||
          title.isEmpty ||
          title.length > 100) {
        throw const FormatException('备份中的纪念日数据无效');
      }
    }
    // 名称长度是表上的约束，坏行留到写库时才会以数据库异常失败；与纪念日
    // 一样在解析时就按“备份数据无效”拒绝。
    for (final row in notebooks) {
      final name = row.name.trim();
      if (name.isEmpty || name.length > 60) {
        throw const FormatException('备份中的日记本数据无效');
      }
    }
    // 日期是心情的主键，算不出是哪天的行写进去也画不到日历上；心情名不校验，
    // 更新版本写入的新心情原样保留（见 [DayMood.parse]）。
    for (final row in dayMoods) {
      if (parseAnniversaryDate(row.day) == null) {
        throw const FormatException('备份中的心情数据无效');
      }
    }
    // 空白留言写不进去（写库时同样拒绝），在解析时就按“备份数据无效”拒绝。
    for (final row in diaryComments) {
      if (row.content.trim().isEmpty) {
        throw const FormatException('备份中的留言数据无效');
      }
    }
  }

  BackupPayload _withRestorableRelations() {
    final diaryIds = diaries.map((row) => row.id).toSet();
    final diaryBusinessIds = diaries.map((row) => row.diaryId).toSet();
    final tagIds = tags.map((row) => row.id).toSet();
    // 只有手动日记本有成员关系；智能或认不出类型的日记本不接收关联行。
    final manualNotebookIds = {
      for (final row in notebooks)
        if (row.acceptsManualEntries) row.id,
    };
    // 历史连接没有一直开启 SQLite 外键，删除记录可能留下悬空关联。
    // 旧版本会把这些关联一起导出；它们不是整份备份损坏的证据。
    // 保留全部日记、标签及有效关联，只有已不存在的两端无法恢复为标签绑定。
    // 不对历史数据额外施加编辑器的长度或正数 ID 规则，避免拒绝旧库真实行。
    // 日记本关联同理：悬空或指向智能日记本的行丢弃，不拒绝整份备份；
    // 所属日记已不在载荷里的留言同样丢弃（导入后没有地方显示它）。
    return BackupPayload(
      diaries: diaries,
      tags: tags,
      diaryTags: diaryTags
          .where(
            (row) =>
                diaryIds.contains(row.diaryId) && tagIds.contains(row.tagId),
          )
          .toList(growable: false),
      anniversaries: anniversaries,
      diaryDrafts: diaryDrafts,
      diaryTemplates: diaryTemplates,
      notebooks: notebooks,
      diaryNotebooks: diaryNotebooks
          .where(
            (row) =>
                diaryIds.contains(row.diaryId) &&
                manualNotebookIds.contains(row.notebookId),
          )
          .toList(growable: false),
      dayMoods: dayMoods,
      diaryComments: diaryComments
          .where((row) => diaryBusinessIds.contains(row.diaryId))
          .toList(growable: false),
      settings: settings,
    );
  }

  static Set<T> _unique<T>(Iterable<T> values) {
    final result = <T>{};
    for (final value in values) {
      if (!result.add(value)) {
        throw const FormatException('备份数据包含重复记录');
      }
    }
    return result;
  }

  static Future<Map<String, Object?>> capture({
    required AppDatabase database,
    required SettingsService settingsService,
  }) async {
    // 所有表读取同一个事务快照，避免日记与标签在导出时不同步。
    final tables = await database.transaction(
      () async => <String, Object?>{
        'diaries': (await database.select(database.diaries).get())
            .map((row) => row.toJson())
            .toList(),
        'tags': (await database.select(database.tags).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryTags': (await database.select(database.diaryTags).get())
            .map((row) => row.toJson())
            .toList(),
        'anniversaries': (await database.select(database.anniversaries).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryDrafts': (await database.select(database.diaryDrafts).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryTemplates': (await database.select(database.diaryTemplates).get())
            .map((row) => row.toJson())
            .toList(),
        'notebooks': (await database.select(database.notebooks).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryNotebooks': (await database.select(database.diaryNotebooks).get())
            .map((row) => row.toJson())
            .toList(),
        'dayMoods': (await database.select(database.dayMoods).get())
            .map((row) => row.toJson())
            .toList(),
        'diaryComments': (await database.select(database.diaryComments).get())
            .map((row) => row.toJson())
            .toList(),
      },
    );
    return {
      'formatVersion': backupFormatVersion,
      'generatedAt': DateTime.now().toIso8601String(),
      'database': tables,
      'settings': BackupSettings.capture(settingsService),
    };
  }

  /// 日记包载荷：指定日记及其标签与关联、所在的手动日记本及成员关系、这些
  /// 日记的留言，不含应用设置。
  ///
  /// 日记本只带包内日记所在的手动日记本（定义与这些日记的成员行），不带无关
  /// 的日记本与智能日记本：导入端按 notebookId 合并，本机没有的本子随之新增，
  /// 日记仍落在原来的本子与章节里。
  ///
  /// 也不含纪念日、日记模板与这天的心情：日记包是“分享这几篇日记”，它们属于
  /// 整本日记，只随完整备份走；关联了这些日记的纪念日留在本机。
  ///
  /// 同样在一个事务快照内读取；只导出两端都存在的关联，避免把历史悬空绑定
  /// 带进包里。一篇都找不到时报错，调用方不应生成空包。同时返回日记行与
  /// 日记本行，导出方据此收集被引用的媒体文件（日记本封面）。
  static Future<
    ({
      Map<String, Object?> json,
      List<Diary> diaries,
      List<NotebookRow> notebooks,
    })
  >
  captureDiaries({
    required AppDatabase database,
    required Iterable<String> diaryIds,
  }) {
    final ids = diaryIds.toSet();
    return database.transaction(() async {
      final diaries = await (database.select(
        database.diaries,
      )..where((row) => row.diaryId.isIn(ids))).get();
      if (diaries.isEmpty) {
        throw StateError('未找到要导出的日记');
      }
      final relations = await (database.select(
        database.diaryTags,
      )..where((row) => row.diaryId.isIn(diaries.map((d) => d.id)))).get();
      final tags = relations.isEmpty
          ? const <Tag>[]
          : await (database.select(database.tags)..where(
                  (row) => row.id.isIn(relations.map((r) => r.tagId).toSet()),
                ))
                .get();
      final tagIds = tags.map((tag) => tag.id).toSet();
      final memberships = await (database.select(
        database.diaryNotebooks,
      )..where((row) => row.diaryId.isIn(diaries.map((d) => d.id)))).get();
      final notebooks = memberships.isEmpty
          ? const <NotebookRow>[]
          : (await (database.select(database.notebooks)..where(
                      (row) => row.id.isIn(
                        memberships.map((r) => r.notebookId).toSet(),
                      ),
                    ))
                    .get())
                .where((row) => row.acceptsManualEntries)
                .toList(growable: false);
      final notebookIds = notebooks.map((row) => row.id).toSet();
      // 留言是这篇日记的一部分（写给它的回应），随日记一起走。
      final comments = await (database.select(
        database.diaryComments,
      )..where((row) => row.diaryId.isIn(diaries.map((d) => d.diaryId)))).get();
      return (
        json: <String, Object?>{
          'formatVersion': backupFormatVersion,
          'generatedAt': DateTime.now().toIso8601String(),
          'database': <String, Object?>{
            'diaries': diaries.map((row) => row.toJson()).toList(),
            'tags': tags.map((row) => row.toJson()).toList(),
            'diaryTags': relations
                .where((row) => tagIds.contains(row.tagId))
                .map((row) => row.toJson())
                .toList(),
            'notebooks': notebooks.map((row) => row.toJson()).toList(),
            'diaryNotebooks': memberships
                .where((row) => notebookIds.contains(row.notebookId))
                .map((row) => row.toJson())
                .toList(),
            'diaryComments': comments.map((row) => row.toJson()).toList(),
          },
        },
        diaries: diaries,
        notebooks: notebooks,
      );
    });
  }

  Future<BackupPayload> rebindMedia(BackupMediaPaths paths) async {
    final restored = <Diary>[];
    for (final diary in diaries) {
      restored.add(
        diary.copyWith(
          content: await paths.rewriteContent(diary.content),
          cover: Value(
            await paths.rewritePath(
              diary.cover,
              directoryNames: const ['diary_covers', 'diary_images'],
            ),
          ),
        ),
      );
    }
    final restoredDrafts = <DiaryDraftRow>[
      for (final draft in diaryDrafts)
        draft.copyWith(
          payload: await _rebindDraftPayload(draft.payload, paths),
        ),
    ];
    final restoredNotebooks = <NotebookRow>[
      for (final notebook in notebooks)
        notebook.copyWith(
          payload: await rebindNotebookPayload(notebook.payload, paths),
        ),
    ];
    return BackupPayload(
      diaries: restored,
      tags: tags,
      diaryTags: diaryTags,
      anniversaries: anniversaries,
      diaryDrafts: restoredDrafts,
      // 模板正文只有文字与分隔线，没有媒体路径要改写。
      diaryTemplates: diaryTemplates,
      notebooks: restoredNotebooks,
      diaryNotebooks: diaryNotebooks,
      dayMoods: dayMoods,
      // 留言只有文字与心情，没有媒体路径要改写。
      diaryComments: diaryComments,
      settings: settings,
    );
  }

  /// 日记本载荷里只有封面（`cover`）指向托管媒体：按与日记封面相同的规则
  /// 改写，覆盖恢复与合并导入共用。
  ///
  /// 在 JSON 层面只改这一个字段、其余键原样保留，而不是经 [NotebookPayload]
  /// 解码再编码：那样会丢掉更新版本写入、本版本认不出的字段。载荷损坏或
  /// 没有封面时原样返回（日记本按默认设置显示，不因此拒绝整份备份）。
  static Future<String> rebindNotebookPayload(
    String payload,
    BackupMediaPaths paths,
  ) async {
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException {
      return payload;
    }
    if (json is! Map<String, dynamic>) return payload;
    final cover = json['cover'];
    if (cover is! String) return payload;
    final rebound = await paths.rewritePath(
      cover,
      directoryNames: const ['diary_covers', 'diary_images'],
    );
    if (rebound == cover) return payload;
    json['cover'] = rebound;
    return jsonEncode(json);
  }

  /// 草稿载荷是编辑页的草稿 JSON：改写其中正文与封面的媒体路径，其余字段
  /// 原样保留。载荷损坏时原样返回——草稿打开时会按空白处理，不因此拒绝
  /// 整份备份，也不覆盖或删除任何媒体。
  static Future<String> _rebindDraftPayload(
    String payload,
    BackupMediaPaths paths,
  ) async {
    final Object? draft;
    try {
      draft = jsonDecode(payload);
    } on FormatException {
      return payload;
    }
    if (draft is! Map<String, dynamic>) return payload;
    if (draft['contentDocJson'] is String) {
      draft['contentDocJson'] = await paths.rewriteContent(
        draft['contentDocJson'] as String,
      );
    }
    if (draft['cover'] is String) {
      draft['cover'] = await paths.rewritePath(
        draft['cover'] as String,
        directoryNames: const ['diary_covers', 'diary_images'],
      );
    }
    return jsonEncode(draft);
  }

  /// 调用方负责整个恢复事务；生成的 companion 自动包含所有 schema 字段。
  Future<void> writeDatabase(AppDatabase database) async {
    // 关联表先删：与两端表一起清空，不留指向旧本地 id 的行。
    await database.delete(database.diaryNotebooks).go();
    await database.delete(database.notebooks).go();
    await database.delete(database.diaryTags).go();
    await database.delete(database.diaries).go();
    await database.delete(database.tags).go();
    await database.delete(database.anniversaries).go();
    await database.delete(database.diaryDrafts).go();
    await database.delete(database.diaryTemplates).go();
    await database.delete(database.dayMoods).go();
    await database.delete(database.diaryComments).go();
    await database.batch((batch) {
      batch.insertAll(
        database.tags,
        tags.map((row) => row.toCompanion(false)).toList(),
      );
      batch.insertAll(
        database.diaries,
        diaries.map((row) => row.toCompanion(false)).toList(),
      );
      batch.insertAll(
        database.diaryTags,
        diaryTags.map((row) => row.toCompanion(false)).toList(),
      );
      // 纪念日只按业务 id 引用日记、没有外键，写入顺序无关。
      batch.insertAll(
        database.anniversaries,
        anniversaries.map((row) => row.toCompanion(false)).toList(),
      );
      // 草稿载荷里的标签记的是本地 id（覆盖恢复保留标签 id），没有外键。
      batch.insertAll(
        database.diaryDrafts,
        diaryDrafts.map((row) => row.toCompanion(false)).toList(),
      );
      // 模板只按名称引用标签，与其他表都没有外键。
      batch.insertAll(
        database.diaryTemplates,
        diaryTemplates.map((row) => row.toCompanion(false)).toList(),
      );
      // 日记本与关联都保留文件里的本地 id，关联两端随日记一起原样恢复。
      batch.insertAll(
        database.notebooks,
        notebooks.map((row) => row.toCompanion(false)).toList(),
      );
      batch.insertAll(
        database.diaryNotebooks,
        diaryNotebooks.map((row) => row.toCompanion(false)).toList(),
      );
      // 心情只以日期为键，与其他表都没有关联。
      batch.insertAll(
        database.dayMoods,
        dayMoods.map((row) => row.toCompanion(false)).toList(),
      );
      // 留言按日记业务 id 引用日记、没有外键，写入顺序无关。
      batch.insertAll(
        database.diaryComments,
        diaryComments.map((row) => row.toCompanion(false)).toList(),
      );
    });
    // 上级按业务 id 引用，文件里的层级可能指向不在文件里的本子（旧版本手改、
    // 损坏）：改回顶层，与合并导入同一口径。
    await database.repairNotebookHierarchy();
  }
}
