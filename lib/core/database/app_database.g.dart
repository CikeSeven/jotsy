// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DiariesTable extends Diaries with TableInfo<$DiariesTable, Diary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTextMeta = const VerificationMeta(
    'contentText',
  );
  @override
  late final GeneratedColumn<String> contentText = GeneratedColumn<String>(
    'content_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _capsuleUnlockAtMeta = const VerificationMeta(
    'capsuleUnlockAt',
  );
  @override
  late final GeneratedColumn<DateTime> capsuleUnlockAt =
      GeneratedColumn<DateTime>(
        'capsule_unlock_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capsuleLockedAtMeta = const VerificationMeta(
    'capsuleLockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capsuleLockedAt =
      GeneratedColumn<DateTime>(
        'capsule_locked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    diaryId,
    title,
    content,
    contentText,
    cover,
    metadata,
    createdAt,
    updatedAt,
    isArchived,
    archivedAt,
    isPinned,
    capsuleUnlockAt,
    capsuleLockedAt,
    isDeleted,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Diary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('content_text')) {
      context.handle(
        _contentTextMeta,
        contentText.isAcceptableOrUnknown(
          data['content_text']!,
          _contentTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTextMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('capsule_unlock_at')) {
      context.handle(
        _capsuleUnlockAtMeta,
        capsuleUnlockAt.isAcceptableOrUnknown(
          data['capsule_unlock_at']!,
          _capsuleUnlockAtMeta,
        ),
      );
    }
    if (data.containsKey('capsule_locked_at')) {
      context.handle(
        _capsuleLockedAtMeta,
        capsuleLockedAt.isAcceptableOrUnknown(
          data['capsule_locked_at']!,
          _capsuleLockedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Diary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Diary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      contentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_text'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      capsuleUnlockAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}capsule_unlock_at'],
      ),
      capsuleLockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}capsule_locked_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DiariesTable createAlias(String alias) {
    return $DiariesTable(attachedDatabase, alias);
  }
}

class Diary extends DataClass implements Insertable<Diary> {
  final int id;
  final String diaryId;
  final String title;
  final String content;
  final String contentText;
  final String? cover;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;

  /// 置顶标记：用于让重要日记固定出现在列表前部。
  final bool isPinned;
  final DateTime? capsuleUnlockAt;
  final DateTime? capsuleLockedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  const Diary({
    required this.id,
    required this.diaryId,
    required this.title,
    required this.content,
    required this.contentText,
    this.cover,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    this.archivedAt,
    required this.isPinned,
    this.capsuleUnlockAt,
    this.capsuleLockedAt,
    required this.isDeleted,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['diary_id'] = Variable<String>(diaryId);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['content_text'] = Variable<String>(contentText);
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    map['metadata'] = Variable<String>(metadata);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || capsuleUnlockAt != null) {
      map['capsule_unlock_at'] = Variable<DateTime>(capsuleUnlockAt);
    }
    if (!nullToAbsent || capsuleLockedAt != null) {
      map['capsule_locked_at'] = Variable<DateTime>(capsuleLockedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      id: Value(id),
      diaryId: Value(diaryId),
      title: Value(title),
      content: Value(content),
      contentText: Value(contentText),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      metadata: Value(metadata),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      isPinned: Value(isPinned),
      capsuleUnlockAt: capsuleUnlockAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capsuleUnlockAt),
      capsuleLockedAt: capsuleLockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capsuleLockedAt),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Diary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Diary(
      id: serializer.fromJson<int>(json['id']),
      diaryId: serializer.fromJson<String>(json['diaryId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      contentText: serializer.fromJson<String>(json['contentText']),
      cover: serializer.fromJson<String?>(json['cover']),
      metadata: serializer.fromJson<String>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      capsuleUnlockAt: serializer.fromJson<DateTime?>(json['capsuleUnlockAt']),
      capsuleLockedAt: serializer.fromJson<DateTime?>(json['capsuleLockedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'diaryId': serializer.toJson<String>(diaryId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'contentText': serializer.toJson<String>(contentText),
      'cover': serializer.toJson<String?>(cover),
      'metadata': serializer.toJson<String>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'capsuleUnlockAt': serializer.toJson<DateTime?>(capsuleUnlockAt),
      'capsuleLockedAt': serializer.toJson<DateTime?>(capsuleLockedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Diary copyWith({
    int? id,
    String? diaryId,
    String? title,
    String? content,
    String? contentText,
    Value<String?> cover = const Value.absent(),
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    Value<DateTime?> archivedAt = const Value.absent(),
    bool? isPinned,
    Value<DateTime?> capsuleUnlockAt = const Value.absent(),
    Value<DateTime?> capsuleLockedAt = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Diary(
    id: id ?? this.id,
    diaryId: diaryId ?? this.diaryId,
    title: title ?? this.title,
    content: content ?? this.content,
    contentText: contentText ?? this.contentText,
    cover: cover.present ? cover.value : this.cover,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    isPinned: isPinned ?? this.isPinned,
    capsuleUnlockAt: capsuleUnlockAt.present
        ? capsuleUnlockAt.value
        : this.capsuleUnlockAt,
    capsuleLockedAt: capsuleLockedAt.present
        ? capsuleLockedAt.value
        : this.capsuleLockedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Diary copyWithCompanion(DiariesCompanion data) {
    return Diary(
      id: data.id.present ? data.id.value : this.id,
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      contentText: data.contentText.present
          ? data.contentText.value
          : this.contentText,
      cover: data.cover.present ? data.cover.value : this.cover,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      capsuleUnlockAt: data.capsuleUnlockAt.present
          ? data.capsuleUnlockAt.value
          : this.capsuleUnlockAt,
      capsuleLockedAt: data.capsuleLockedAt.present
          ? data.capsuleLockedAt.value
          : this.capsuleLockedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Diary(')
          ..write('id: $id, ')
          ..write('diaryId: $diaryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('cover: $cover, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('capsuleUnlockAt: $capsuleUnlockAt, ')
          ..write('capsuleLockedAt: $capsuleLockedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    diaryId,
    title,
    content,
    contentText,
    cover,
    metadata,
    createdAt,
    updatedAt,
    isArchived,
    archivedAt,
    isPinned,
    capsuleUnlockAt,
    capsuleLockedAt,
    isDeleted,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Diary &&
          other.id == this.id &&
          other.diaryId == this.diaryId &&
          other.title == this.title &&
          other.content == this.content &&
          other.contentText == this.contentText &&
          other.cover == this.cover &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isArchived == this.isArchived &&
          other.archivedAt == this.archivedAt &&
          other.isPinned == this.isPinned &&
          other.capsuleUnlockAt == this.capsuleUnlockAt &&
          other.capsuleLockedAt == this.capsuleLockedAt &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class DiariesCompanion extends UpdateCompanion<Diary> {
  final Value<int> id;
  final Value<String> diaryId;
  final Value<String> title;
  final Value<String> content;
  final Value<String> contentText;
  final Value<String?> cover;
  final Value<String> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isArchived;
  final Value<DateTime?> archivedAt;
  final Value<bool> isPinned;
  final Value<DateTime?> capsuleUnlockAt;
  final Value<DateTime?> capsuleLockedAt;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  const DiariesCompanion({
    this.id = const Value.absent(),
    this.diaryId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentText = const Value.absent(),
    this.cover = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.capsuleUnlockAt = const Value.absent(),
    this.capsuleLockedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  DiariesCompanion.insert({
    this.id = const Value.absent(),
    required String diaryId,
    this.title = const Value.absent(),
    required String content,
    required String contentText,
    this.cover = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.capsuleUnlockAt = const Value.absent(),
    this.capsuleLockedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : diaryId = Value(diaryId),
       content = Value(content),
       contentText = Value(contentText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Diary> custom({
    Expression<int>? id,
    Expression<String>? diaryId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? contentText,
    Expression<String>? cover,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isArchived,
    Expression<DateTime>? archivedAt,
    Expression<bool>? isPinned,
    Expression<DateTime>? capsuleUnlockAt,
    Expression<DateTime>? capsuleLockedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (diaryId != null) 'diary_id': diaryId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentText != null) 'content_text': contentText,
      if (cover != null) 'cover': cover,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (capsuleUnlockAt != null) 'capsule_unlock_at': capsuleUnlockAt,
      if (capsuleLockedAt != null) 'capsule_locked_at': capsuleLockedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  DiariesCompanion copyWith({
    Value<int>? id,
    Value<String>? diaryId,
    Value<String>? title,
    Value<String>? content,
    Value<String>? contentText,
    Value<String?>? cover,
    Value<String>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isArchived,
    Value<DateTime?>? archivedAt,
    Value<bool>? isPinned,
    Value<DateTime?>? capsuleUnlockAt,
    Value<DateTime?>? capsuleLockedAt,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
  }) {
    return DiariesCompanion(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentText: contentText ?? this.contentText,
      cover: cover ?? this.cover,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      isPinned: isPinned ?? this.isPinned,
      capsuleUnlockAt: capsuleUnlockAt ?? this.capsuleUnlockAt,
      capsuleLockedAt: capsuleLockedAt ?? this.capsuleLockedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentText.present) {
      map['content_text'] = Variable<String>(contentText.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (capsuleUnlockAt.present) {
      map['capsule_unlock_at'] = Variable<DateTime>(capsuleUnlockAt.value);
    }
    if (capsuleLockedAt.present) {
      map['capsule_locked_at'] = Variable<DateTime>(capsuleLockedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('id: $id, ')
          ..write('diaryId: $diaryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('cover: $cover, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('capsuleUnlockAt: $capsuleUnlockAt, ')
          ..write('capsuleLockedAt: $capsuleLockedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final int color;
  const Tag({required this.id, required this.name, required this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name), color: Value(color));
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
    };
  }

  Tag copyWith({int? id, String? name, int? color}) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int color,
  }) : name = Value(name),
       color = Value(color);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? color,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $DiaryTagsTable extends DiaryTags
    with TableInfo<$DiaryTagsTable, DiaryTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<int> diaryId = GeneratedColumn<int>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES diaries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [diaryId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {diaryId, tagId};
  @override
  DiaryTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryTag(
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diary_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $DiaryTagsTable createAlias(String alias) {
    return $DiaryTagsTable(attachedDatabase, alias);
  }
}

class DiaryTag extends DataClass implements Insertable<DiaryTag> {
  final int diaryId;
  final int tagId;
  const DiaryTag({required this.diaryId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['diary_id'] = Variable<int>(diaryId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  DiaryTagsCompanion toCompanion(bool nullToAbsent) {
    return DiaryTagsCompanion(diaryId: Value(diaryId), tagId: Value(tagId));
  }

  factory DiaryTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryTag(
      diaryId: serializer.fromJson<int>(json['diaryId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'diaryId': serializer.toJson<int>(diaryId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  DiaryTag copyWith({int? diaryId, int? tagId}) =>
      DiaryTag(diaryId: diaryId ?? this.diaryId, tagId: tagId ?? this.tagId);
  DiaryTag copyWithCompanion(DiaryTagsCompanion data) {
    return DiaryTag(
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTag(')
          ..write('diaryId: $diaryId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(diaryId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryTag &&
          other.diaryId == this.diaryId &&
          other.tagId == this.tagId);
}

class DiaryTagsCompanion extends UpdateCompanion<DiaryTag> {
  final Value<int> diaryId;
  final Value<int> tagId;
  final Value<int> rowid;
  const DiaryTagsCompanion({
    this.diaryId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryTagsCompanion.insert({
    required int diaryId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : diaryId = Value(diaryId),
       tagId = Value(tagId);
  static Insertable<DiaryTag> custom({
    Expression<int>? diaryId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (diaryId != null) 'diary_id': diaryId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryTagsCompanion copyWith({
    Value<int>? diaryId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return DiaryTagsCompanion(
      diaryId: diaryId ?? this.diaryId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (diaryId.present) {
      map['diary_id'] = Variable<int>(diaryId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTagsCompanion(')
          ..write('diaryId: $diaryId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnniversariesTable extends Anniversaries
    with TableInfo<$AnniversariesTable, Anniversary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnniversariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _anniversaryIdMeta = const VerificationMeta(
    'anniversaryId',
  );
  @override
  late final GeneratedColumn<String> anniversaryId = GeneratedColumn<String>(
    'anniversary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseDateMeta = const VerificationMeta(
    'baseDate',
  );
  @override
  late final GeneratedColumn<String> baseDate = GeneratedColumn<String>(
    'base_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('solarYearly'),
  );
  static const VerificationMeta _lunarYearMeta = const VerificationMeta(
    'lunarYear',
  );
  @override
  late final GeneratedColumn<int> lunarYear = GeneratedColumn<int>(
    'lunar_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lunarMonthMeta = const VerificationMeta(
    'lunarMonth',
  );
  @override
  late final GeneratedColumn<int> lunarMonth = GeneratedColumn<int>(
    'lunar_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lunarDayMeta = const VerificationMeta(
    'lunarDay',
  );
  @override
  late final GeneratedColumn<int> lunarDay = GeneratedColumn<int>(
    'lunar_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedDiaryIdMeta = const VerificationMeta(
    'linkedDiaryId',
  );
  @override
  late final GeneratedColumn<String> linkedDiaryId = GeneratedColumn<String>(
    'linked_diary_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    anniversaryId,
    title,
    baseDate,
    recurrence,
    lunarYear,
    lunarMonth,
    lunarDay,
    linkedDiaryId,
    note,
    isPinned,
    metadata,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anniversaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Anniversary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('anniversary_id')) {
      context.handle(
        _anniversaryIdMeta,
        anniversaryId.isAcceptableOrUnknown(
          data['anniversary_id']!,
          _anniversaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_anniversaryIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('base_date')) {
      context.handle(
        _baseDateMeta,
        baseDate.isAcceptableOrUnknown(data['base_date']!, _baseDateMeta),
      );
    } else if (isInserting) {
      context.missing(_baseDateMeta);
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('lunar_year')) {
      context.handle(
        _lunarYearMeta,
        lunarYear.isAcceptableOrUnknown(data['lunar_year']!, _lunarYearMeta),
      );
    }
    if (data.containsKey('lunar_month')) {
      context.handle(
        _lunarMonthMeta,
        lunarMonth.isAcceptableOrUnknown(data['lunar_month']!, _lunarMonthMeta),
      );
    }
    if (data.containsKey('lunar_day')) {
      context.handle(
        _lunarDayMeta,
        lunarDay.isAcceptableOrUnknown(data['lunar_day']!, _lunarDayMeta),
      );
    }
    if (data.containsKey('linked_diary_id')) {
      context.handle(
        _linkedDiaryIdMeta,
        linkedDiaryId.isAcceptableOrUnknown(
          data['linked_diary_id']!,
          _linkedDiaryIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Anniversary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Anniversary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      anniversaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anniversary_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      baseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_date'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      )!,
      lunarYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lunar_year'],
      ),
      lunarMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lunar_month'],
      ),
      lunarDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lunar_day'],
      ),
      linkedDiaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_diary_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnniversariesTable createAlias(String alias) {
    return $AnniversariesTable(attachedDatabase, alias);
  }
}

class Anniversary extends DataClass implements Insertable<Anniversary> {
  final int id;
  final String anniversaryId;
  final String title;
  final String baseDate;
  final String recurrence;
  final int? lunarYear;
  final int? lunarMonth;
  final int? lunarDay;
  final String? linkedDiaryId;
  final String note;
  final bool isPinned;

  /// 扩展字段（JSON 对象字符串），预留给图标、颜色等以后的展示选项。
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Anniversary({
    required this.id,
    required this.anniversaryId,
    required this.title,
    required this.baseDate,
    required this.recurrence,
    this.lunarYear,
    this.lunarMonth,
    this.lunarDay,
    this.linkedDiaryId,
    required this.note,
    required this.isPinned,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['anniversary_id'] = Variable<String>(anniversaryId);
    map['title'] = Variable<String>(title);
    map['base_date'] = Variable<String>(baseDate);
    map['recurrence'] = Variable<String>(recurrence);
    if (!nullToAbsent || lunarYear != null) {
      map['lunar_year'] = Variable<int>(lunarYear);
    }
    if (!nullToAbsent || lunarMonth != null) {
      map['lunar_month'] = Variable<int>(lunarMonth);
    }
    if (!nullToAbsent || lunarDay != null) {
      map['lunar_day'] = Variable<int>(lunarDay);
    }
    if (!nullToAbsent || linkedDiaryId != null) {
      map['linked_diary_id'] = Variable<String>(linkedDiaryId);
    }
    map['note'] = Variable<String>(note);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['metadata'] = Variable<String>(metadata);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnniversariesCompanion toCompanion(bool nullToAbsent) {
    return AnniversariesCompanion(
      id: Value(id),
      anniversaryId: Value(anniversaryId),
      title: Value(title),
      baseDate: Value(baseDate),
      recurrence: Value(recurrence),
      lunarYear: lunarYear == null && nullToAbsent
          ? const Value.absent()
          : Value(lunarYear),
      lunarMonth: lunarMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(lunarMonth),
      lunarDay: lunarDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lunarDay),
      linkedDiaryId: linkedDiaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedDiaryId),
      note: Value(note),
      isPinned: Value(isPinned),
      metadata: Value(metadata),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Anniversary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Anniversary(
      id: serializer.fromJson<int>(json['id']),
      anniversaryId: serializer.fromJson<String>(json['anniversaryId']),
      title: serializer.fromJson<String>(json['title']),
      baseDate: serializer.fromJson<String>(json['baseDate']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      lunarYear: serializer.fromJson<int?>(json['lunarYear']),
      lunarMonth: serializer.fromJson<int?>(json['lunarMonth']),
      lunarDay: serializer.fromJson<int?>(json['lunarDay']),
      linkedDiaryId: serializer.fromJson<String?>(json['linkedDiaryId']),
      note: serializer.fromJson<String>(json['note']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      metadata: serializer.fromJson<String>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'anniversaryId': serializer.toJson<String>(anniversaryId),
      'title': serializer.toJson<String>(title),
      'baseDate': serializer.toJson<String>(baseDate),
      'recurrence': serializer.toJson<String>(recurrence),
      'lunarYear': serializer.toJson<int?>(lunarYear),
      'lunarMonth': serializer.toJson<int?>(lunarMonth),
      'lunarDay': serializer.toJson<int?>(lunarDay),
      'linkedDiaryId': serializer.toJson<String?>(linkedDiaryId),
      'note': serializer.toJson<String>(note),
      'isPinned': serializer.toJson<bool>(isPinned),
      'metadata': serializer.toJson<String>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Anniversary copyWith({
    int? id,
    String? anniversaryId,
    String? title,
    String? baseDate,
    String? recurrence,
    Value<int?> lunarYear = const Value.absent(),
    Value<int?> lunarMonth = const Value.absent(),
    Value<int?> lunarDay = const Value.absent(),
    Value<String?> linkedDiaryId = const Value.absent(),
    String? note,
    bool? isPinned,
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Anniversary(
    id: id ?? this.id,
    anniversaryId: anniversaryId ?? this.anniversaryId,
    title: title ?? this.title,
    baseDate: baseDate ?? this.baseDate,
    recurrence: recurrence ?? this.recurrence,
    lunarYear: lunarYear.present ? lunarYear.value : this.lunarYear,
    lunarMonth: lunarMonth.present ? lunarMonth.value : this.lunarMonth,
    lunarDay: lunarDay.present ? lunarDay.value : this.lunarDay,
    linkedDiaryId: linkedDiaryId.present
        ? linkedDiaryId.value
        : this.linkedDiaryId,
    note: note ?? this.note,
    isPinned: isPinned ?? this.isPinned,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Anniversary copyWithCompanion(AnniversariesCompanion data) {
    return Anniversary(
      id: data.id.present ? data.id.value : this.id,
      anniversaryId: data.anniversaryId.present
          ? data.anniversaryId.value
          : this.anniversaryId,
      title: data.title.present ? data.title.value : this.title,
      baseDate: data.baseDate.present ? data.baseDate.value : this.baseDate,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      lunarYear: data.lunarYear.present ? data.lunarYear.value : this.lunarYear,
      lunarMonth: data.lunarMonth.present
          ? data.lunarMonth.value
          : this.lunarMonth,
      lunarDay: data.lunarDay.present ? data.lunarDay.value : this.lunarDay,
      linkedDiaryId: data.linkedDiaryId.present
          ? data.linkedDiaryId.value
          : this.linkedDiaryId,
      note: data.note.present ? data.note.value : this.note,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Anniversary(')
          ..write('id: $id, ')
          ..write('anniversaryId: $anniversaryId, ')
          ..write('title: $title, ')
          ..write('baseDate: $baseDate, ')
          ..write('recurrence: $recurrence, ')
          ..write('lunarYear: $lunarYear, ')
          ..write('lunarMonth: $lunarMonth, ')
          ..write('lunarDay: $lunarDay, ')
          ..write('linkedDiaryId: $linkedDiaryId, ')
          ..write('note: $note, ')
          ..write('isPinned: $isPinned, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    anniversaryId,
    title,
    baseDate,
    recurrence,
    lunarYear,
    lunarMonth,
    lunarDay,
    linkedDiaryId,
    note,
    isPinned,
    metadata,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Anniversary &&
          other.id == this.id &&
          other.anniversaryId == this.anniversaryId &&
          other.title == this.title &&
          other.baseDate == this.baseDate &&
          other.recurrence == this.recurrence &&
          other.lunarYear == this.lunarYear &&
          other.lunarMonth == this.lunarMonth &&
          other.lunarDay == this.lunarDay &&
          other.linkedDiaryId == this.linkedDiaryId &&
          other.note == this.note &&
          other.isPinned == this.isPinned &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnniversariesCompanion extends UpdateCompanion<Anniversary> {
  final Value<int> id;
  final Value<String> anniversaryId;
  final Value<String> title;
  final Value<String> baseDate;
  final Value<String> recurrence;
  final Value<int?> lunarYear;
  final Value<int?> lunarMonth;
  final Value<int?> lunarDay;
  final Value<String?> linkedDiaryId;
  final Value<String> note;
  final Value<bool> isPinned;
  final Value<String> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AnniversariesCompanion({
    this.id = const Value.absent(),
    this.anniversaryId = const Value.absent(),
    this.title = const Value.absent(),
    this.baseDate = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.lunarYear = const Value.absent(),
    this.lunarMonth = const Value.absent(),
    this.lunarDay = const Value.absent(),
    this.linkedDiaryId = const Value.absent(),
    this.note = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnniversariesCompanion.insert({
    this.id = const Value.absent(),
    required String anniversaryId,
    required String title,
    required String baseDate,
    this.recurrence = const Value.absent(),
    this.lunarYear = const Value.absent(),
    this.lunarMonth = const Value.absent(),
    this.lunarDay = const Value.absent(),
    this.linkedDiaryId = const Value.absent(),
    this.note = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : anniversaryId = Value(anniversaryId),
       title = Value(title),
       baseDate = Value(baseDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Anniversary> custom({
    Expression<int>? id,
    Expression<String>? anniversaryId,
    Expression<String>? title,
    Expression<String>? baseDate,
    Expression<String>? recurrence,
    Expression<int>? lunarYear,
    Expression<int>? lunarMonth,
    Expression<int>? lunarDay,
    Expression<String>? linkedDiaryId,
    Expression<String>? note,
    Expression<bool>? isPinned,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (anniversaryId != null) 'anniversary_id': anniversaryId,
      if (title != null) 'title': title,
      if (baseDate != null) 'base_date': baseDate,
      if (recurrence != null) 'recurrence': recurrence,
      if (lunarYear != null) 'lunar_year': lunarYear,
      if (lunarMonth != null) 'lunar_month': lunarMonth,
      if (lunarDay != null) 'lunar_day': lunarDay,
      if (linkedDiaryId != null) 'linked_diary_id': linkedDiaryId,
      if (note != null) 'note': note,
      if (isPinned != null) 'is_pinned': isPinned,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnniversariesCompanion copyWith({
    Value<int>? id,
    Value<String>? anniversaryId,
    Value<String>? title,
    Value<String>? baseDate,
    Value<String>? recurrence,
    Value<int?>? lunarYear,
    Value<int?>? lunarMonth,
    Value<int?>? lunarDay,
    Value<String?>? linkedDiaryId,
    Value<String>? note,
    Value<bool>? isPinned,
    Value<String>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AnniversariesCompanion(
      id: id ?? this.id,
      anniversaryId: anniversaryId ?? this.anniversaryId,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      recurrence: recurrence ?? this.recurrence,
      lunarYear: lunarYear ?? this.lunarYear,
      lunarMonth: lunarMonth ?? this.lunarMonth,
      lunarDay: lunarDay ?? this.lunarDay,
      linkedDiaryId: linkedDiaryId ?? this.linkedDiaryId,
      note: note ?? this.note,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (anniversaryId.present) {
      map['anniversary_id'] = Variable<String>(anniversaryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (baseDate.present) {
      map['base_date'] = Variable<String>(baseDate.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (lunarYear.present) {
      map['lunar_year'] = Variable<int>(lunarYear.value);
    }
    if (lunarMonth.present) {
      map['lunar_month'] = Variable<int>(lunarMonth.value);
    }
    if (lunarDay.present) {
      map['lunar_day'] = Variable<int>(lunarDay.value);
    }
    if (linkedDiaryId.present) {
      map['linked_diary_id'] = Variable<String>(linkedDiaryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnniversariesCompanion(')
          ..write('id: $id, ')
          ..write('anniversaryId: $anniversaryId, ')
          ..write('title: $title, ')
          ..write('baseDate: $baseDate, ')
          ..write('recurrence: $recurrence, ')
          ..write('lunarYear: $lunarYear, ')
          ..write('lunarMonth: $lunarMonth, ')
          ..write('lunarDay: $lunarDay, ')
          ..write('linkedDiaryId: $linkedDiaryId, ')
          ..write('note: $note, ')
          ..write('isPinned: $isPinned, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DiaryDraftsTable extends DiaryDrafts
    with TableInfo<$DiaryDraftsTable, DiaryDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentTextMeta = const VerificationMeta(
    'contentText',
  );
  @override
  late final GeneratedColumn<String> contentText = GeneratedColumn<String>(
    'content_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftId,
    title,
    contentText,
    payload,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content_text')) {
      context.handle(
        _contentTextMeta,
        contentText.isAcceptableOrUnknown(
          data['content_text']!,
          _contentTextMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_text'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DiaryDraftsTable createAlias(String alias) {
    return $DiaryDraftsTable(attachedDatabase, alias);
  }
}

class DiaryDraftRow extends DataClass implements Insertable<DiaryDraftRow> {
  final int id;
  final String draftId;
  final String title;
  final String contentText;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DiaryDraftRow({
    required this.id,
    required this.draftId,
    required this.title,
    required this.contentText,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['draft_id'] = Variable<String>(draftId);
    map['title'] = Variable<String>(title);
    map['content_text'] = Variable<String>(contentText);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DiaryDraftsCompanion toCompanion(bool nullToAbsent) {
    return DiaryDraftsCompanion(
      id: Value(id),
      draftId: Value(draftId),
      title: Value(title),
      contentText: Value(contentText),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DiaryDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryDraftRow(
      id: serializer.fromJson<int>(json['id']),
      draftId: serializer.fromJson<String>(json['draftId']),
      title: serializer.fromJson<String>(json['title']),
      contentText: serializer.fromJson<String>(json['contentText']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'draftId': serializer.toJson<String>(draftId),
      'title': serializer.toJson<String>(title),
      'contentText': serializer.toJson<String>(contentText),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DiaryDraftRow copyWith({
    int? id,
    String? draftId,
    String? title,
    String? contentText,
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DiaryDraftRow(
    id: id ?? this.id,
    draftId: draftId ?? this.draftId,
    title: title ?? this.title,
    contentText: contentText ?? this.contentText,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DiaryDraftRow copyWithCompanion(DiaryDraftsCompanion data) {
    return DiaryDraftRow(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      title: data.title.present ? data.title.value : this.title,
      contentText: data.contentText.present
          ? data.contentText.value
          : this.contentText,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDraftRow(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('title: $title, ')
          ..write('contentText: $contentText, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    draftId,
    title,
    contentText,
    payload,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDraftRow &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.title == this.title &&
          other.contentText == this.contentText &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DiaryDraftsCompanion extends UpdateCompanion<DiaryDraftRow> {
  final Value<int> id;
  final Value<String> draftId;
  final Value<String> title;
  final Value<String> contentText;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DiaryDraftsCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.title = const Value.absent(),
    this.contentText = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DiaryDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String draftId,
    this.title = const Value.absent(),
    this.contentText = const Value.absent(),
    required String payload,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : draftId = Value(draftId),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryDraftRow> custom({
    Expression<int>? id,
    Expression<String>? draftId,
    Expression<String>? title,
    Expression<String>? contentText,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (title != null) 'title': title,
      if (contentText != null) 'content_text': contentText,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DiaryDraftsCompanion copyWith({
    Value<int>? id,
    Value<String>? draftId,
    Value<String>? title,
    Value<String>? contentText,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DiaryDraftsCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      title: title ?? this.title,
      contentText: contentText ?? this.contentText,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentText.present) {
      map['content_text'] = Variable<String>(contentText.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDraftsCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('title: $title, ')
          ..write('contentText: $contentText, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DiaryTemplatesTable extends DiaryTemplates
    with TableInfo<$DiaryTemplatesTable, DiaryTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    name,
    payload,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DiaryTemplatesTable createAlias(String alias) {
    return $DiaryTemplatesTable(attachedDatabase, alias);
  }
}

class DiaryTemplateRow extends DataClass
    implements Insertable<DiaryTemplateRow> {
  final int id;
  final String templateId;
  final String name;
  final String payload;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DiaryTemplateRow({
    required this.id,
    required this.templateId,
    required this.name,
    required this.payload,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<String>(templateId);
    map['name'] = Variable<String>(name);
    map['payload'] = Variable<String>(payload);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DiaryTemplatesCompanion toCompanion(bool nullToAbsent) {
    return DiaryTemplatesCompanion(
      id: Value(id),
      templateId: Value(templateId),
      name: Value(name),
      payload: Value(payload),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DiaryTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryTemplateRow(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      name: serializer.fromJson<String>(json['name']),
      payload: serializer.fromJson<String>(json['payload']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<String>(templateId),
      'name': serializer.toJson<String>(name),
      'payload': serializer.toJson<String>(payload),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DiaryTemplateRow copyWith({
    int? id,
    String? templateId,
    String? name,
    String? payload,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DiaryTemplateRow(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    name: name ?? this.name,
    payload: payload ?? this.payload,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DiaryTemplateRow copyWithCompanion(DiaryTemplatesCompanion data) {
    return DiaryTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      name: data.name.present ? data.name.value : this.name,
      payload: data.payload.present ? data.payload.value : this.payload,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTemplateRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('payload: $payload, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    name,
    payload,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryTemplateRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.name == this.name &&
          other.payload == this.payload &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DiaryTemplatesCompanion extends UpdateCompanion<DiaryTemplateRow> {
  final Value<int> id;
  final Value<String> templateId;
  final Value<String> name;
  final Value<String> payload;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DiaryTemplatesCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.name = const Value.absent(),
    this.payload = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DiaryTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String templateId,
    this.name = const Value.absent(),
    required String payload,
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : templateId = Value(templateId),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryTemplateRow> custom({
    Expression<int>? id,
    Expression<String>? templateId,
    Expression<String>? name,
    Expression<String>? payload,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (name != null) 'name': name,
      if (payload != null) 'payload': payload,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DiaryTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? templateId,
    Value<String>? name,
    Value<String>? payload,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DiaryTemplatesCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      payload: payload ?? this.payload,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('payload: $payload, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $NotebooksTable extends Notebooks
    with TableInfo<$NotebooksTable, NotebookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotebooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _notebookIdMeta = const VerificationMeta(
    'notebookId',
  );
  @override
  late final GeneratedColumn<String> notebookId = GeneratedColumn<String>(
    'notebook_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isClosedMeta = const VerificationMeta(
    'isClosed',
  );
  @override
  late final GeneratedColumn<bool> isClosed = GeneratedColumn<bool>(
    'is_closed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_closed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    notebookId,
    name,
    kind,
    visibility,
    payload,
    sortOrder,
    isPinned,
    isClosed,
    createdAt,
    updatedAt,
    parentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notebooks';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotebookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('notebook_id')) {
      context.handle(
        _notebookIdMeta,
        notebookId.isAcceptableOrUnknown(data['notebook_id']!, _notebookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_notebookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_closed')) {
      context.handle(
        _isClosedMeta,
        isClosed.isAcceptableOrUnknown(data['is_closed']!, _isClosedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotebookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotebookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      notebookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notebook_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isClosed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_closed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $NotebooksTable createAlias(String alias) {
    return $NotebooksTable(attachedDatabase, alias);
  }
}

class NotebookRow extends DataClass implements Insertable<NotebookRow> {
  final int id;
  final String notebookId;
  final String name;
  final String kind;
  final String visibility;
  final String payload;
  final int sortOrder;
  final bool isPinned;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 放在最后：v15 升级经 ADD COLUMN 追加在表尾，新建库与升级库的列顺序一致。
  final String? parentId;
  const NotebookRow({
    required this.id,
    required this.notebookId,
    required this.name,
    required this.kind,
    required this.visibility,
    required this.payload,
    required this.sortOrder,
    required this.isPinned,
    required this.isClosed,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['notebook_id'] = Variable<String>(notebookId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['visibility'] = Variable<String>(visibility);
    map['payload'] = Variable<String>(payload);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_closed'] = Variable<bool>(isClosed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    return map;
  }

  NotebooksCompanion toCompanion(bool nullToAbsent) {
    return NotebooksCompanion(
      id: Value(id),
      notebookId: Value(notebookId),
      name: Value(name),
      kind: Value(kind),
      visibility: Value(visibility),
      payload: Value(payload),
      sortOrder: Value(sortOrder),
      isPinned: Value(isPinned),
      isClosed: Value(isClosed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory NotebookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotebookRow(
      id: serializer.fromJson<int>(json['id']),
      notebookId: serializer.fromJson<String>(json['notebookId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      visibility: serializer.fromJson<String>(json['visibility']),
      payload: serializer.fromJson<String>(json['payload']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isClosed: serializer.fromJson<bool>(json['isClosed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      parentId: serializer.fromJson<String?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'notebookId': serializer.toJson<String>(notebookId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'visibility': serializer.toJson<String>(visibility),
      'payload': serializer.toJson<String>(payload),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isClosed': serializer.toJson<bool>(isClosed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'parentId': serializer.toJson<String?>(parentId),
    };
  }

  NotebookRow copyWith({
    int? id,
    String? notebookId,
    String? name,
    String? kind,
    String? visibility,
    String? payload,
    int? sortOrder,
    bool? isPinned,
    bool? isClosed,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> parentId = const Value.absent(),
  }) => NotebookRow(
    id: id ?? this.id,
    notebookId: notebookId ?? this.notebookId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    visibility: visibility ?? this.visibility,
    payload: payload ?? this.payload,
    sortOrder: sortOrder ?? this.sortOrder,
    isPinned: isPinned ?? this.isPinned,
    isClosed: isClosed ?? this.isClosed,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  NotebookRow copyWithCompanion(NotebooksCompanion data) {
    return NotebookRow(
      id: data.id.present ? data.id.value : this.id,
      notebookId: data.notebookId.present
          ? data.notebookId.value
          : this.notebookId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      payload: data.payload.present ? data.payload.value : this.payload,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isClosed: data.isClosed.present ? data.isClosed.value : this.isClosed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotebookRow(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('visibility: $visibility, ')
          ..write('payload: $payload, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isPinned: $isPinned, ')
          ..write('isClosed: $isClosed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    notebookId,
    name,
    kind,
    visibility,
    payload,
    sortOrder,
    isPinned,
    isClosed,
    createdAt,
    updatedAt,
    parentId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotebookRow &&
          other.id == this.id &&
          other.notebookId == this.notebookId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.visibility == this.visibility &&
          other.payload == this.payload &&
          other.sortOrder == this.sortOrder &&
          other.isPinned == this.isPinned &&
          other.isClosed == this.isClosed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.parentId == this.parentId);
}

class NotebooksCompanion extends UpdateCompanion<NotebookRow> {
  final Value<int> id;
  final Value<String> notebookId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> visibility;
  final Value<String> payload;
  final Value<int> sortOrder;
  final Value<bool> isPinned;
  final Value<bool> isClosed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> parentId;
  const NotebooksCompanion({
    this.id = const Value.absent(),
    this.notebookId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.visibility = const Value.absent(),
    this.payload = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isClosed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  NotebooksCompanion.insert({
    this.id = const Value.absent(),
    required String notebookId,
    required String name,
    this.kind = const Value.absent(),
    this.visibility = const Value.absent(),
    this.payload = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isClosed = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.parentId = const Value.absent(),
  }) : notebookId = Value(notebookId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NotebookRow> custom({
    Expression<int>? id,
    Expression<String>? notebookId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? visibility,
    Expression<String>? payload,
    Expression<int>? sortOrder,
    Expression<bool>? isPinned,
    Expression<bool>? isClosed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (notebookId != null) 'notebook_id': notebookId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (visibility != null) 'visibility': visibility,
      if (payload != null) 'payload': payload,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isClosed != null) 'is_closed': isClosed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  NotebooksCompanion copyWith({
    Value<int>? id,
    Value<String>? notebookId,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? visibility,
    Value<String>? payload,
    Value<int>? sortOrder,
    Value<bool>? isPinned,
    Value<bool>? isClosed,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? parentId,
  }) {
    return NotebooksCompanion(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      visibility: visibility ?? this.visibility,
      payload: payload ?? this.payload,
      sortOrder: sortOrder ?? this.sortOrder,
      isPinned: isPinned ?? this.isPinned,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (notebookId.present) {
      map['notebook_id'] = Variable<String>(notebookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isClosed.present) {
      map['is_closed'] = Variable<bool>(isClosed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotebooksCompanion(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('visibility: $visibility, ')
          ..write('payload: $payload, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isPinned: $isPinned, ')
          ..write('isClosed: $isClosed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $DiaryNotebooksTable extends DiaryNotebooks
    with TableInfo<$DiaryNotebooksTable, DiaryNotebookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryNotebooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<int> diaryId = GeneratedColumn<int>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notebookIdMeta = const VerificationMeta(
    'notebookId',
  );
  @override
  late final GeneratedColumn<int> notebookId = GeneratedColumn<int>(
    'notebook_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    diaryId,
    notebookId,
    chapterId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_notebooks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryNotebookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('notebook_id')) {
      context.handle(
        _notebookIdMeta,
        notebookId.isAcceptableOrUnknown(data['notebook_id']!, _notebookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_notebookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {diaryId, notebookId};
  @override
  DiaryNotebookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryNotebookRow(
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diary_id'],
      )!,
      notebookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notebook_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $DiaryNotebooksTable createAlias(String alias) {
    return $DiaryNotebooksTable(attachedDatabase, alias);
  }
}

class DiaryNotebookRow extends DataClass
    implements Insertable<DiaryNotebookRow> {
  final int diaryId;
  final int notebookId;
  final String? chapterId;
  final int position;
  final DateTime addedAt;
  const DiaryNotebookRow({
    required this.diaryId,
    required this.notebookId,
    this.chapterId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['diary_id'] = Variable<int>(diaryId);
    map['notebook_id'] = Variable<int>(notebookId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<String>(chapterId);
    }
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  DiaryNotebooksCompanion toCompanion(bool nullToAbsent) {
    return DiaryNotebooksCompanion(
      diaryId: Value(diaryId),
      notebookId: Value(notebookId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory DiaryNotebookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryNotebookRow(
      diaryId: serializer.fromJson<int>(json['diaryId']),
      notebookId: serializer.fromJson<int>(json['notebookId']),
      chapterId: serializer.fromJson<String?>(json['chapterId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'diaryId': serializer.toJson<int>(diaryId),
      'notebookId': serializer.toJson<int>(notebookId),
      'chapterId': serializer.toJson<String?>(chapterId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  DiaryNotebookRow copyWith({
    int? diaryId,
    int? notebookId,
    Value<String?> chapterId = const Value.absent(),
    int? position,
    DateTime? addedAt,
  }) => DiaryNotebookRow(
    diaryId: diaryId ?? this.diaryId,
    notebookId: notebookId ?? this.notebookId,
    chapterId: chapterId.present ? chapterId.value : this.chapterId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  DiaryNotebookRow copyWithCompanion(DiaryNotebooksCompanion data) {
    return DiaryNotebookRow(
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      notebookId: data.notebookId.present
          ? data.notebookId.value
          : this.notebookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryNotebookRow(')
          ..write('diaryId: $diaryId, ')
          ..write('notebookId: $notebookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(diaryId, notebookId, chapterId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryNotebookRow &&
          other.diaryId == this.diaryId &&
          other.notebookId == this.notebookId &&
          other.chapterId == this.chapterId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class DiaryNotebooksCompanion extends UpdateCompanion<DiaryNotebookRow> {
  final Value<int> diaryId;
  final Value<int> notebookId;
  final Value<String?> chapterId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const DiaryNotebooksCompanion({
    this.diaryId = const Value.absent(),
    this.notebookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryNotebooksCompanion.insert({
    required int diaryId,
    required int notebookId,
    this.chapterId = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : diaryId = Value(diaryId),
       notebookId = Value(notebookId),
       addedAt = Value(addedAt);
  static Insertable<DiaryNotebookRow> custom({
    Expression<int>? diaryId,
    Expression<int>? notebookId,
    Expression<String>? chapterId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (diaryId != null) 'diary_id': diaryId,
      if (notebookId != null) 'notebook_id': notebookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryNotebooksCompanion copyWith({
    Value<int>? diaryId,
    Value<int>? notebookId,
    Value<String?>? chapterId,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return DiaryNotebooksCompanion(
      diaryId: diaryId ?? this.diaryId,
      notebookId: notebookId ?? this.notebookId,
      chapterId: chapterId ?? this.chapterId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (diaryId.present) {
      map['diary_id'] = Variable<int>(diaryId.value);
    }
    if (notebookId.present) {
      map['notebook_id'] = Variable<int>(notebookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryNotebooksCompanion(')
          ..write('diaryId: $diaryId, ')
          ..write('notebookId: $notebookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayMoodsTable extends DayMoods
    with TableInfo<$DayMoodsTable, DayMoodRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayMoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, mood, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_moods';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayMoodRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DayMoodRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayMoodRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DayMoodsTable createAlias(String alias) {
    return $DayMoodsTable(attachedDatabase, alias);
  }
}

class DayMoodRow extends DataClass implements Insertable<DayMoodRow> {
  final String day;
  final String mood;
  final DateTime updatedAt;
  const DayMoodRow({
    required this.day,
    required this.mood,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['mood'] = Variable<String>(mood);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DayMoodsCompanion toCompanion(bool nullToAbsent) {
    return DayMoodsCompanion(
      day: Value(day),
      mood: Value(mood),
      updatedAt: Value(updatedAt),
    );
  }

  factory DayMoodRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayMoodRow(
      day: serializer.fromJson<String>(json['day']),
      mood: serializer.fromJson<String>(json['mood']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'mood': serializer.toJson<String>(mood),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DayMoodRow copyWith({String? day, String? mood, DateTime? updatedAt}) =>
      DayMoodRow(
        day: day ?? this.day,
        mood: mood ?? this.mood,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DayMoodRow copyWithCompanion(DayMoodsCompanion data) {
    return DayMoodRow(
      day: data.day.present ? data.day.value : this.day,
      mood: data.mood.present ? data.mood.value : this.mood,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayMoodRow(')
          ..write('day: $day, ')
          ..write('mood: $mood, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, mood, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayMoodRow &&
          other.day == this.day &&
          other.mood == this.mood &&
          other.updatedAt == this.updatedAt);
}

class DayMoodsCompanion extends UpdateCompanion<DayMoodRow> {
  final Value<String> day;
  final Value<String> mood;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DayMoodsCompanion({
    this.day = const Value.absent(),
    this.mood = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayMoodsCompanion.insert({
    required String day,
    required String mood,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       mood = Value(mood),
       updatedAt = Value(updatedAt);
  static Insertable<DayMoodRow> custom({
    Expression<String>? day,
    Expression<String>? mood,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (mood != null) 'mood': mood,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayMoodsCompanion copyWith({
    Value<String>? day,
    Value<String>? mood,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DayMoodsCompanion(
      day: day ?? this.day,
      mood: mood ?? this.mood,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayMoodsCompanion(')
          ..write('day: $day, ')
          ..write('mood: $mood, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiaryCommentsTable extends DiaryComments
    with TableInfo<$DiaryCommentsTable, DiaryCommentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _commentIdMeta = const VerificationMeta(
    'commentId',
  );
  @override
  late final GeneratedColumn<String> commentId = GeneratedColumn<String>(
    'comment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    commentId,
    diaryId,
    content,
    mood,
    createdAt,
    editedAt,
    images,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_comments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryCommentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('comment_id')) {
      context.handle(
        _commentIdMeta,
        commentId.isAcceptableOrUnknown(data['comment_id']!, _commentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commentIdMeta);
    }
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('images')) {
      context.handle(
        _imagesMeta,
        images.isAcceptableOrUnknown(data['images']!, _imagesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryCommentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryCommentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      commentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment_id'],
      )!,
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}edited_at'],
      ),
      images: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}images'],
      ),
    );
  }

  @override
  $DiaryCommentsTable createAlias(String alias) {
    return $DiaryCommentsTable(attachedDatabase, alias);
  }
}

class DiaryCommentRow extends DataClass implements Insertable<DiaryCommentRow> {
  final int id;
  final String commentId;
  final String diaryId;
  final String content;
  final String? mood;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? images;
  const DiaryCommentRow({
    required this.id,
    required this.commentId,
    required this.diaryId,
    required this.content,
    this.mood,
    required this.createdAt,
    this.editedAt,
    this.images,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['comment_id'] = Variable<String>(commentId);
    map['diary_id'] = Variable<String>(diaryId);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    if (!nullToAbsent || images != null) {
      map['images'] = Variable<String>(images);
    }
    return map;
  }

  DiaryCommentsCompanion toCompanion(bool nullToAbsent) {
    return DiaryCommentsCompanion(
      id: Value(id),
      commentId: Value(commentId),
      diaryId: Value(diaryId),
      content: Value(content),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      images: images == null && nullToAbsent
          ? const Value.absent()
          : Value(images),
    );
  }

  factory DiaryCommentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryCommentRow(
      id: serializer.fromJson<int>(json['id']),
      commentId: serializer.fromJson<String>(json['commentId']),
      diaryId: serializer.fromJson<String>(json['diaryId']),
      content: serializer.fromJson<String>(json['content']),
      mood: serializer.fromJson<String?>(json['mood']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      images: serializer.fromJson<String?>(json['images']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'commentId': serializer.toJson<String>(commentId),
      'diaryId': serializer.toJson<String>(diaryId),
      'content': serializer.toJson<String>(content),
      'mood': serializer.toJson<String?>(mood),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'images': serializer.toJson<String?>(images),
    };
  }

  DiaryCommentRow copyWith({
    int? id,
    String? commentId,
    String? diaryId,
    String? content,
    Value<String?> mood = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> editedAt = const Value.absent(),
    Value<String?> images = const Value.absent(),
  }) => DiaryCommentRow(
    id: id ?? this.id,
    commentId: commentId ?? this.commentId,
    diaryId: diaryId ?? this.diaryId,
    content: content ?? this.content,
    mood: mood.present ? mood.value : this.mood,
    createdAt: createdAt ?? this.createdAt,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    images: images.present ? images.value : this.images,
  );
  DiaryCommentRow copyWithCompanion(DiaryCommentsCompanion data) {
    return DiaryCommentRow(
      id: data.id.present ? data.id.value : this.id,
      commentId: data.commentId.present ? data.commentId.value : this.commentId,
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      content: data.content.present ? data.content.value : this.content,
      mood: data.mood.present ? data.mood.value : this.mood,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      images: data.images.present ? data.images.value : this.images,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryCommentRow(')
          ..write('id: $id, ')
          ..write('commentId: $commentId, ')
          ..write('diaryId: $diaryId, ')
          ..write('content: $content, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('images: $images')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    commentId,
    diaryId,
    content,
    mood,
    createdAt,
    editedAt,
    images,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryCommentRow &&
          other.id == this.id &&
          other.commentId == this.commentId &&
          other.diaryId == this.diaryId &&
          other.content == this.content &&
          other.mood == this.mood &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.images == this.images);
}

class DiaryCommentsCompanion extends UpdateCompanion<DiaryCommentRow> {
  final Value<int> id;
  final Value<String> commentId;
  final Value<String> diaryId;
  final Value<String> content;
  final Value<String?> mood;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<String?> images;
  const DiaryCommentsCompanion({
    this.id = const Value.absent(),
    this.commentId = const Value.absent(),
    this.diaryId = const Value.absent(),
    this.content = const Value.absent(),
    this.mood = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.images = const Value.absent(),
  });
  DiaryCommentsCompanion.insert({
    this.id = const Value.absent(),
    required String commentId,
    required String diaryId,
    required String content,
    this.mood = const Value.absent(),
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.images = const Value.absent(),
  }) : commentId = Value(commentId),
       diaryId = Value(diaryId),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<DiaryCommentRow> custom({
    Expression<int>? id,
    Expression<String>? commentId,
    Expression<String>? diaryId,
    Expression<String>? content,
    Expression<String>? mood,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<String>? images,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commentId != null) 'comment_id': commentId,
      if (diaryId != null) 'diary_id': diaryId,
      if (content != null) 'content': content,
      if (mood != null) 'mood': mood,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (images != null) 'images': images,
    });
  }

  DiaryCommentsCompanion copyWith({
    Value<int>? id,
    Value<String>? commentId,
    Value<String>? diaryId,
    Value<String>? content,
    Value<String?>? mood,
    Value<DateTime>? createdAt,
    Value<DateTime?>? editedAt,
    Value<String?>? images,
  }) {
    return DiaryCommentsCompanion(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
      diaryId: diaryId ?? this.diaryId,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      images: images ?? this.images,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (commentId.present) {
      map['comment_id'] = Variable<String>(commentId.value);
    }
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryCommentsCompanion(')
          ..write('id: $id, ')
          ..write('commentId: $commentId, ')
          ..write('diaryId: $diaryId, ')
          ..write('content: $content, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('images: $images')
          ..write(')'))
        .toString();
  }
}

class $AiConversationsTable extends AiConversations
    with TableInfo<$AiConversationsTable, AiConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _optionsMeta = const VerificationMeta(
    'options',
  );
  @override
  late final GeneratedColumn<String> options = GeneratedColumn<String>(
    'options',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    title,
    personaId,
    scope,
    options,
    pinned,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('options')) {
      context.handle(
        _optionsMeta,
        options.isAcceptableOrUnknown(data['options']!, _optionsMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      options: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiConversationsTable createAlias(String alias) {
    return $AiConversationsTable(attachedDatabase, alias);
  }
}

class AiConversationRow extends DataClass
    implements Insertable<AiConversationRow> {
  final int id;
  final String conversationId;

  /// 标题（用户改名或自动起名）；空为“新对话”。
  final String title;

  /// 对话使用的人设 id；null 为对话的默认人设。
  final String? personaId;

  /// 检索范围 JSON（时间、日记本、标签、固定的日记、检索方式）。
  final String scope;

  /// 这段对话的回答选项 JSON（模型、思考强度；v21）。`{}` 为全部跟随
  /// 默认。编解码见 `AiConversationOptions`。
  final String options;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiConversationRow({
    required this.id,
    required this.conversationId,
    required this.title,
    this.personaId,
    required this.scope,
    required this.options,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || personaId != null) {
      map['persona_id'] = Variable<String>(personaId);
    }
    map['scope'] = Variable<String>(scope);
    map['options'] = Variable<String>(options);
    map['pinned'] = Variable<bool>(pinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiConversationsCompanion toCompanion(bool nullToAbsent) {
    return AiConversationsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      title: Value(title),
      personaId: personaId == null && nullToAbsent
          ? const Value.absent()
          : Value(personaId),
      scope: Value(scope),
      options: Value(options),
      pinned: Value(pinned),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConversationRow(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      title: serializer.fromJson<String>(json['title']),
      personaId: serializer.fromJson<String?>(json['personaId']),
      scope: serializer.fromJson<String>(json['scope']),
      options: serializer.fromJson<String>(json['options']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'title': serializer.toJson<String>(title),
      'personaId': serializer.toJson<String?>(personaId),
      'scope': serializer.toJson<String>(scope),
      'options': serializer.toJson<String>(options),
      'pinned': serializer.toJson<bool>(pinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiConversationRow copyWith({
    int? id,
    String? conversationId,
    String? title,
    Value<String?> personaId = const Value.absent(),
    String? scope,
    String? options,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiConversationRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    title: title ?? this.title,
    personaId: personaId.present ? personaId.value : this.personaId,
    scope: scope ?? this.scope,
    options: options ?? this.options,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiConversationRow copyWithCompanion(AiConversationsCompanion data) {
    return AiConversationRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      title: data.title.present ? data.title.value : this.title,
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      scope: data.scope.present ? data.scope.value : this.scope,
      options: data.options.present ? data.options.value : this.options,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('title: $title, ')
          ..write('personaId: $personaId, ')
          ..write('scope: $scope, ')
          ..write('options: $options, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    title,
    personaId,
    scope,
    options,
    pinned,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversationRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.title == this.title &&
          other.personaId == this.personaId &&
          other.scope == this.scope &&
          other.options == this.options &&
          other.pinned == this.pinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiConversationsCompanion extends UpdateCompanion<AiConversationRow> {
  final Value<int> id;
  final Value<String> conversationId;
  final Value<String> title;
  final Value<String?> personaId;
  final Value<String> scope;
  final Value<String> options;
  final Value<bool> pinned;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AiConversationsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.title = const Value.absent(),
    this.personaId = const Value.absent(),
    this.scope = const Value.absent(),
    this.options = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AiConversationsCompanion.insert({
    this.id = const Value.absent(),
    required String conversationId,
    this.title = const Value.absent(),
    this.personaId = const Value.absent(),
    this.scope = const Value.absent(),
    this.options = const Value.absent(),
    this.pinned = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : conversationId = Value(conversationId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AiConversationRow> custom({
    Expression<int>? id,
    Expression<String>? conversationId,
    Expression<String>? title,
    Expression<String>? personaId,
    Expression<String>? scope,
    Expression<String>? options,
    Expression<bool>? pinned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (title != null) 'title': title,
      if (personaId != null) 'persona_id': personaId,
      if (scope != null) 'scope': scope,
      if (options != null) 'options': options,
      if (pinned != null) 'pinned': pinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AiConversationsCompanion copyWith({
    Value<int>? id,
    Value<String>? conversationId,
    Value<String>? title,
    Value<String?>? personaId,
    Value<String>? scope,
    Value<String>? options,
    Value<bool>? pinned,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AiConversationsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      personaId: personaId ?? this.personaId,
      scope: scope ?? this.scope,
      options: options ?? this.options,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (options.present) {
      map['options'] = Variable<String>(options.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('title: $title, ')
          ..write('personaId: $personaId, ')
          ..write('scope: $scope, ')
          ..write('options: $options, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AiMessagesTable extends AiMessages
    with TableInfo<$AiMessagesTable, AiMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _citationsMeta = const VerificationMeta(
    'citations',
  );
  @override
  late final GeneratedColumn<String> citations = GeneratedColumn<String>(
    'citations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('done'),
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<String> steps = GeneratedColumn<String>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    conversationId,
    role,
    content,
    reasoning,
    citations,
    meta,
    status,
    steps,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('citations')) {
      context.handle(
        _citationsMeta,
        citations.isAcceptableOrUnknown(data['citations']!, _citationsMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      )!,
      citations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations'],
      )!,
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiMessagesTable createAlias(String alias) {
    return $AiMessagesTable(attachedDatabase, alias);
  }
}

class AiMessageRow extends DataClass implements Insertable<AiMessageRow> {
  final int id;
  final String messageId;
  final String conversationId;

  /// `user` 或 `assistant`。
  final String role;

  /// Markdown 正文。
  final String content;

  /// 模型的思考过程（有的话）。
  final String reasoning;

  /// 这条回答参考的日记 JSON 数组（业务 id、标题、日期、编号）。
  final String citations;

  /// 服务商名、模型、用量、错误等 JSON。
  final String meta;

  /// `done` / `error` / `stopped`。
  final String status;

  /// 智能体回答的工具步骤 JSON 数组（每步的说明文字与调用记录，见
  /// `AiAgentStepRecord`）；普通回答为 `[]`。v20 加入。
  final String steps;
  final DateTime createdAt;
  const AiMessageRow({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.reasoning,
    required this.citations,
    required this.meta,
    required this.status,
    required this.steps,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['reasoning'] = Variable<String>(reasoning);
    map['citations'] = Variable<String>(citations);
    map['meta'] = Variable<String>(meta);
    map['status'] = Variable<String>(status);
    map['steps'] = Variable<String>(steps);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiMessagesCompanion toCompanion(bool nullToAbsent) {
    return AiMessagesCompanion(
      id: Value(id),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      reasoning: Value(reasoning),
      citations: Value(citations),
      meta: Value(meta),
      status: Value(status),
      steps: Value(steps),
      createdAt: Value(createdAt),
    );
  }

  factory AiMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiMessageRow(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      reasoning: serializer.fromJson<String>(json['reasoning']),
      citations: serializer.fromJson<String>(json['citations']),
      meta: serializer.fromJson<String>(json['meta']),
      status: serializer.fromJson<String>(json['status']),
      steps: serializer.fromJson<String>(json['steps']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'reasoning': serializer.toJson<String>(reasoning),
      'citations': serializer.toJson<String>(citations),
      'meta': serializer.toJson<String>(meta),
      'status': serializer.toJson<String>(status),
      'steps': serializer.toJson<String>(steps),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiMessageRow copyWith({
    int? id,
    String? messageId,
    String? conversationId,
    String? role,
    String? content,
    String? reasoning,
    String? citations,
    String? meta,
    String? status,
    String? steps,
    DateTime? createdAt,
  }) => AiMessageRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    reasoning: reasoning ?? this.reasoning,
    citations: citations ?? this.citations,
    meta: meta ?? this.meta,
    status: status ?? this.status,
    steps: steps ?? this.steps,
    createdAt: createdAt ?? this.createdAt,
  );
  AiMessageRow copyWithCompanion(AiMessagesCompanion data) {
    return AiMessageRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      citations: data.citations.present ? data.citations.value : this.citations,
      meta: data.meta.present ? data.meta.value : this.meta,
      status: data.status.present ? data.status.value : this.status,
      steps: data.steps.present ? data.steps.value : this.steps,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiMessageRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('citations: $citations, ')
          ..write('meta: $meta, ')
          ..write('status: $status, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    conversationId,
    role,
    content,
    reasoning,
    citations,
    meta,
    status,
    steps,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMessageRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.reasoning == this.reasoning &&
          other.citations == this.citations &&
          other.meta == this.meta &&
          other.status == this.status &&
          other.steps == this.steps &&
          other.createdAt == this.createdAt);
}

class AiMessagesCompanion extends UpdateCompanion<AiMessageRow> {
  final Value<int> id;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> reasoning;
  final Value<String> citations;
  final Value<String> meta;
  final Value<String> status;
  final Value<String> steps;
  final Value<DateTime> createdAt;
  const AiMessagesCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.citations = const Value.absent(),
    this.meta = const Value.absent(),
    this.status = const Value.absent(),
    this.steps = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String messageId,
    required String conversationId,
    required String role,
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.citations = const Value.absent(),
    this.meta = const Value.absent(),
    this.status = const Value.absent(),
    this.steps = const Value.absent(),
    required DateTime createdAt,
  }) : messageId = Value(messageId),
       conversationId = Value(conversationId),
       role = Value(role),
       createdAt = Value(createdAt);
  static Insertable<AiMessageRow> custom({
    Expression<int>? id,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? reasoning,
    Expression<String>? citations,
    Expression<String>? meta,
    Expression<String>? status,
    Expression<String>? steps,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (reasoning != null) 'reasoning': reasoning,
      if (citations != null) 'citations': citations,
      if (meta != null) 'meta': meta,
      if (status != null) 'status': status,
      if (steps != null) 'steps': steps,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiMessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? role,
    Value<String>? content,
    Value<String>? reasoning,
    Value<String>? citations,
    Value<String>? meta,
    Value<String>? status,
    Value<String>? steps,
    Value<DateTime>? createdAt,
  }) {
    return AiMessagesCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      citations: citations ?? this.citations,
      meta: meta ?? this.meta,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (citations.present) {
      map['citations'] = Variable<String>(citations.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (steps.present) {
      map['steps'] = Variable<String>(steps.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiMessagesCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('citations: $citations, ')
          ..write('meta: $meta, ')
          ..write('status: $status, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiResultsTable extends AiResults
    with TableInfo<$AiResultsTable, AiResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _resultIdMeta = const VerificationMeta(
    'resultId',
  );
  @override
  late final GeneratedColumn<String> resultId = GeneratedColumn<String>(
    'result_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<DateTime> periodStart = GeneratedColumn<DateTime>(
    'period_start',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<DateTime> periodEnd = GeneratedColumn<DateTime>(
    'period_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    resultId,
    kind,
    diaryId,
    periodStart,
    periodEnd,
    scope,
    title,
    content,
    personaId,
    meta,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('result_id')) {
      context.handle(
        _resultIdMeta,
        resultId.isAcceptableOrUnknown(data['result_id']!, _resultIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resultIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiResultRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      resultId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      ),
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}period_start'],
      ),
      periodEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}period_end'],
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiResultsTable createAlias(String alias) {
    return $AiResultsTable(attachedDatabase, alias);
  }
}

class AiResultRow extends DataClass implements Insertable<AiResultRow> {
  final int id;
  final String resultId;

  /// `reply`（读后回应）或 `recap`（回顾）。
  final String kind;

  /// 回应所属日记的业务 id；回顾为 null。
  final String? diaryId;

  /// 回顾覆盖的时间范围（含起点、不含终点）。
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// 回顾的范围 JSON（日记本、章节选择、篇数等）。
  final String scope;
  final String title;

  /// Markdown 正文。
  final String content;
  final String? personaId;

  /// 服务商名、模型、用量、人设名快照等 JSON。
  final String meta;
  final DateTime createdAt;
  const AiResultRow({
    required this.id,
    required this.resultId,
    required this.kind,
    this.diaryId,
    this.periodStart,
    this.periodEnd,
    required this.scope,
    required this.title,
    required this.content,
    this.personaId,
    required this.meta,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['result_id'] = Variable<String>(resultId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || diaryId != null) {
      map['diary_id'] = Variable<String>(diaryId);
    }
    if (!nullToAbsent || periodStart != null) {
      map['period_start'] = Variable<DateTime>(periodStart);
    }
    if (!nullToAbsent || periodEnd != null) {
      map['period_end'] = Variable<DateTime>(periodEnd);
    }
    map['scope'] = Variable<String>(scope);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || personaId != null) {
      map['persona_id'] = Variable<String>(personaId);
    }
    map['meta'] = Variable<String>(meta);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiResultsCompanion toCompanion(bool nullToAbsent) {
    return AiResultsCompanion(
      id: Value(id),
      resultId: Value(resultId),
      kind: Value(kind),
      diaryId: diaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(diaryId),
      periodStart: periodStart == null && nullToAbsent
          ? const Value.absent()
          : Value(periodStart),
      periodEnd: periodEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(periodEnd),
      scope: Value(scope),
      title: Value(title),
      content: Value(content),
      personaId: personaId == null && nullToAbsent
          ? const Value.absent()
          : Value(personaId),
      meta: Value(meta),
      createdAt: Value(createdAt),
    );
  }

  factory AiResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiResultRow(
      id: serializer.fromJson<int>(json['id']),
      resultId: serializer.fromJson<String>(json['resultId']),
      kind: serializer.fromJson<String>(json['kind']),
      diaryId: serializer.fromJson<String?>(json['diaryId']),
      periodStart: serializer.fromJson<DateTime?>(json['periodStart']),
      periodEnd: serializer.fromJson<DateTime?>(json['periodEnd']),
      scope: serializer.fromJson<String>(json['scope']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      personaId: serializer.fromJson<String?>(json['personaId']),
      meta: serializer.fromJson<String>(json['meta']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'resultId': serializer.toJson<String>(resultId),
      'kind': serializer.toJson<String>(kind),
      'diaryId': serializer.toJson<String?>(diaryId),
      'periodStart': serializer.toJson<DateTime?>(periodStart),
      'periodEnd': serializer.toJson<DateTime?>(periodEnd),
      'scope': serializer.toJson<String>(scope),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'personaId': serializer.toJson<String?>(personaId),
      'meta': serializer.toJson<String>(meta),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiResultRow copyWith({
    int? id,
    String? resultId,
    String? kind,
    Value<String?> diaryId = const Value.absent(),
    Value<DateTime?> periodStart = const Value.absent(),
    Value<DateTime?> periodEnd = const Value.absent(),
    String? scope,
    String? title,
    String? content,
    Value<String?> personaId = const Value.absent(),
    String? meta,
    DateTime? createdAt,
  }) => AiResultRow(
    id: id ?? this.id,
    resultId: resultId ?? this.resultId,
    kind: kind ?? this.kind,
    diaryId: diaryId.present ? diaryId.value : this.diaryId,
    periodStart: periodStart.present ? periodStart.value : this.periodStart,
    periodEnd: periodEnd.present ? periodEnd.value : this.periodEnd,
    scope: scope ?? this.scope,
    title: title ?? this.title,
    content: content ?? this.content,
    personaId: personaId.present ? personaId.value : this.personaId,
    meta: meta ?? this.meta,
    createdAt: createdAt ?? this.createdAt,
  );
  AiResultRow copyWithCompanion(AiResultsCompanion data) {
    return AiResultRow(
      id: data.id.present ? data.id.value : this.id,
      resultId: data.resultId.present ? data.resultId.value : this.resultId,
      kind: data.kind.present ? data.kind.value : this.kind,
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      scope: data.scope.present ? data.scope.value : this.scope,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      meta: data.meta.present ? data.meta.value : this.meta,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiResultRow(')
          ..write('id: $id, ')
          ..write('resultId: $resultId, ')
          ..write('kind: $kind, ')
          ..write('diaryId: $diaryId, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('scope: $scope, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('personaId: $personaId, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    resultId,
    kind,
    diaryId,
    periodStart,
    periodEnd,
    scope,
    title,
    content,
    personaId,
    meta,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiResultRow &&
          other.id == this.id &&
          other.resultId == this.resultId &&
          other.kind == this.kind &&
          other.diaryId == this.diaryId &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.scope == this.scope &&
          other.title == this.title &&
          other.content == this.content &&
          other.personaId == this.personaId &&
          other.meta == this.meta &&
          other.createdAt == this.createdAt);
}

class AiResultsCompanion extends UpdateCompanion<AiResultRow> {
  final Value<int> id;
  final Value<String> resultId;
  final Value<String> kind;
  final Value<String?> diaryId;
  final Value<DateTime?> periodStart;
  final Value<DateTime?> periodEnd;
  final Value<String> scope;
  final Value<String> title;
  final Value<String> content;
  final Value<String?> personaId;
  final Value<String> meta;
  final Value<DateTime> createdAt;
  const AiResultsCompanion({
    this.id = const Value.absent(),
    this.resultId = const Value.absent(),
    this.kind = const Value.absent(),
    this.diaryId = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.scope = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.personaId = const Value.absent(),
    this.meta = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiResultsCompanion.insert({
    this.id = const Value.absent(),
    required String resultId,
    required String kind,
    this.diaryId = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.scope = const Value.absent(),
    this.title = const Value.absent(),
    required String content,
    this.personaId = const Value.absent(),
    this.meta = const Value.absent(),
    required DateTime createdAt,
  }) : resultId = Value(resultId),
       kind = Value(kind),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<AiResultRow> custom({
    Expression<int>? id,
    Expression<String>? resultId,
    Expression<String>? kind,
    Expression<String>? diaryId,
    Expression<DateTime>? periodStart,
    Expression<DateTime>? periodEnd,
    Expression<String>? scope,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? personaId,
    Expression<String>? meta,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (resultId != null) 'result_id': resultId,
      if (kind != null) 'kind': kind,
      if (diaryId != null) 'diary_id': diaryId,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (scope != null) 'scope': scope,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (personaId != null) 'persona_id': personaId,
      if (meta != null) 'meta': meta,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiResultsCompanion copyWith({
    Value<int>? id,
    Value<String>? resultId,
    Value<String>? kind,
    Value<String?>? diaryId,
    Value<DateTime?>? periodStart,
    Value<DateTime?>? periodEnd,
    Value<String>? scope,
    Value<String>? title,
    Value<String>? content,
    Value<String?>? personaId,
    Value<String>? meta,
    Value<DateTime>? createdAt,
  }) {
    return AiResultsCompanion(
      id: id ?? this.id,
      resultId: resultId ?? this.resultId,
      kind: kind ?? this.kind,
      diaryId: diaryId ?? this.diaryId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      scope: scope ?? this.scope,
      title: title ?? this.title,
      content: content ?? this.content,
      personaId: personaId ?? this.personaId,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (resultId.present) {
      map['result_id'] = Variable<String>(resultId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<DateTime>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<DateTime>(periodEnd.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiResultsCompanion(')
          ..write('id: $id, ')
          ..write('resultId: $resultId, ')
          ..write('kind: $kind, ')
          ..write('diaryId: $diaryId, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('scope: $scope, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('personaId: $personaId, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TodoListsTable extends TodoLists
    with TableInfo<$TodoListsTable, TodoListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorKeyMeta = const VerificationMeta(
    'colorKey',
  );
  @override
  late final GeneratedColumn<String> colorKey = GeneratedColumn<String>(
    'color_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    name,
    colorKey,
    iconKey,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoListRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_key')) {
      context.handle(
        _colorKeyMeta,
        colorKey.isAcceptableOrUnknown(data['color_key']!, _colorKeyMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoListRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_key'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TodoListsTable createAlias(String alias) {
    return $TodoListsTable(attachedDatabase, alias);
  }
}

class TodoListRow extends DataClass implements Insertable<TodoListRow> {
  final int id;
  final String listId;
  final String name;

  /// 强调色的色板键（见界面层的清单色板）；认不出时按默认色显示。
  final String colorKey;

  /// 图标键（见界面层的清单图标集合）；认不出时按默认图标显示。
  final String iconKey;
  final double sortOrder;

  /// 扩展字段（JSON 对象字符串）。
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TodoListRow({
    required this.id,
    required this.listId,
    required this.name,
    required this.colorKey,
    required this.iconKey,
    required this.sortOrder,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['color_key'] = Variable<String>(colorKey);
    map['icon_key'] = Variable<String>(iconKey);
    map['sort_order'] = Variable<double>(sortOrder);
    map['metadata'] = Variable<String>(metadata);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TodoListsCompanion toCompanion(bool nullToAbsent) {
    return TodoListsCompanion(
      id: Value(id),
      listId: Value(listId),
      name: Value(name),
      colorKey: Value(colorKey),
      iconKey: Value(iconKey),
      sortOrder: Value(sortOrder),
      metadata: Value(metadata),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TodoListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoListRow(
      id: serializer.fromJson<int>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      colorKey: serializer.fromJson<String>(json['colorKey']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      metadata: serializer.fromJson<String>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'colorKey': serializer.toJson<String>(colorKey),
      'iconKey': serializer.toJson<String>(iconKey),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'metadata': serializer.toJson<String>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TodoListRow copyWith({
    int? id,
    String? listId,
    String? name,
    String? colorKey,
    String? iconKey,
    double? sortOrder,
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TodoListRow(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    name: name ?? this.name,
    colorKey: colorKey ?? this.colorKey,
    iconKey: iconKey ?? this.iconKey,
    sortOrder: sortOrder ?? this.sortOrder,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TodoListRow copyWithCompanion(TodoListsCompanion data) {
    return TodoListRow(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      colorKey: data.colorKey.present ? data.colorKey.value : this.colorKey,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoListRow(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('colorKey: $colorKey, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    name,
    colorKey,
    iconKey,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoListRow &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.colorKey == this.colorKey &&
          other.iconKey == this.iconKey &&
          other.sortOrder == this.sortOrder &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TodoListsCompanion extends UpdateCompanion<TodoListRow> {
  final Value<int> id;
  final Value<String> listId;
  final Value<String> name;
  final Value<String> colorKey;
  final Value<String> iconKey;
  final Value<double> sortOrder;
  final Value<String> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TodoListsCompanion.insert({
    this.id = const Value.absent(),
    required String listId,
    required String name,
    this.colorKey = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : listId = Value(listId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TodoListRow> custom({
    Expression<int>? id,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<String>? colorKey,
    Expression<String>? iconKey,
    Expression<double>? sortOrder,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (colorKey != null) 'color_key': colorKey,
      if (iconKey != null) 'icon_key': iconKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TodoListsCompanion copyWith({
    Value<int>? id,
    Value<String>? listId,
    Value<String>? name,
    Value<String>? colorKey,
    Value<String>? iconKey,
    Value<double>? sortOrder,
    Value<String>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorKey.present) {
      map['color_key'] = Variable<String>(colorKey.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('colorKey: $colorKey, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TodosTable extends Todos with TableInfo<$TodosTable, TodoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
    'todo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 500,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMinuteMeta = const VerificationMeta(
    'dueMinute',
  );
  @override
  late final GeneratedColumn<int> dueMinute = GeneratedColumn<int>(
    'due_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<String> reminders = GeneratedColumn<String>(
    'reminders',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<String> steps = GeneratedColumn<String>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedDiaryIdMeta = const VerificationMeta(
    'linkedDiaryId',
  );
  @override
  late final GeneratedColumn<String> linkedDiaryId = GeneratedColumn<String>(
    'linked_diary_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    todoId,
    listId,
    title,
    note,
    priority,
    dueDate,
    dueMinute,
    reminders,
    repeat,
    steps,
    completedAt,
    snoozedUntil,
    linkedDiaryId,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('todo_id')) {
      context.handle(
        _todoIdMeta,
        todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_minute')) {
      context.handle(
        _dueMinuteMeta,
        dueMinute.isAcceptableOrUnknown(data['due_minute']!, _dueMinuteMeta),
      );
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('linked_diary_id')) {
      context.handle(
        _linkedDiaryIdMeta,
        linkedDiaryId.isAcceptableOrUnknown(
          data['linked_diary_id']!,
          _linkedDiaryIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      todoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      ),
      dueMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_minute'],
      ),
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      linkedDiaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_diary_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class TodoRow extends DataClass implements Insertable<TodoRow> {
  final int id;
  final String todoId;

  /// 所在清单的业务 id；NULL 为收集箱。
  final String? listId;
  final String title;

  /// 备注（纯文本）。
  final String note;

  /// 优先级（[TodoPriority] 的下标）。
  final int priority;

  /// 截止日 `YYYY-MM-DD`；NULL 为没有日期。
  final String? dueDate;

  /// 截止时刻（一天中的分钟数）；NULL 为全天。没有截止日时总是 NULL。
  final int? dueMinute;

  /// 提醒 JSON 数组（[TodoReminder]）。
  final String reminders;

  /// 重复规则 JSON（[TodoRepeatRule]）；NULL 为不重复。
  final String? repeat;

  /// 步骤 JSON 数组（[TodoStep]）。
  final String steps;

  /// 完成时刻；NULL 为未完成。
  final DateTime? completedAt;

  /// 稍后提醒到的时刻（通知上点“稍后提醒”）；过了即失效。
  final DateTime? snoozedUntil;
  final String? linkedDiaryId;
  final double sortOrder;

  /// 扩展字段（JSON 对象字符串）：来源日记、重复副本的原待办、已完成次数。
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TodoRow({
    required this.id,
    required this.todoId,
    this.listId,
    required this.title,
    required this.note,
    required this.priority,
    this.dueDate,
    this.dueMinute,
    required this.reminders,
    this.repeat,
    required this.steps,
    this.completedAt,
    this.snoozedUntil,
    this.linkedDiaryId,
    required this.sortOrder,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['todo_id'] = Variable<String>(todoId);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    map['title'] = Variable<String>(title);
    map['note'] = Variable<String>(note);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    if (!nullToAbsent || dueMinute != null) {
      map['due_minute'] = Variable<int>(dueMinute);
    }
    map['reminders'] = Variable<String>(reminders);
    if (!nullToAbsent || repeat != null) {
      map['repeat'] = Variable<String>(repeat);
    }
    map['steps'] = Variable<String>(steps);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || linkedDiaryId != null) {
      map['linked_diary_id'] = Variable<String>(linkedDiaryId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['metadata'] = Variable<String>(metadata);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      todoId: Value(todoId),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      title: Value(title),
      note: Value(note),
      priority: Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueMinute: dueMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(dueMinute),
      reminders: Value(reminders),
      repeat: repeat == null && nullToAbsent
          ? const Value.absent()
          : Value(repeat),
      steps: Value(steps),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      linkedDiaryId: linkedDiaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedDiaryId),
      sortOrder: Value(sortOrder),
      metadata: Value(metadata),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TodoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRow(
      id: serializer.fromJson<int>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      listId: serializer.fromJson<String?>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String>(json['note']),
      priority: serializer.fromJson<int>(json['priority']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      dueMinute: serializer.fromJson<int?>(json['dueMinute']),
      reminders: serializer.fromJson<String>(json['reminders']),
      repeat: serializer.fromJson<String?>(json['repeat']),
      steps: serializer.fromJson<String>(json['steps']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      linkedDiaryId: serializer.fromJson<String?>(json['linkedDiaryId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      metadata: serializer.fromJson<String>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'todoId': serializer.toJson<String>(todoId),
      'listId': serializer.toJson<String?>(listId),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'priority': serializer.toJson<int>(priority),
      'dueDate': serializer.toJson<String?>(dueDate),
      'dueMinute': serializer.toJson<int?>(dueMinute),
      'reminders': serializer.toJson<String>(reminders),
      'repeat': serializer.toJson<String?>(repeat),
      'steps': serializer.toJson<String>(steps),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'linkedDiaryId': serializer.toJson<String?>(linkedDiaryId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'metadata': serializer.toJson<String>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TodoRow copyWith({
    int? id,
    String? todoId,
    Value<String?> listId = const Value.absent(),
    String? title,
    String? note,
    int? priority,
    Value<String?> dueDate = const Value.absent(),
    Value<int?> dueMinute = const Value.absent(),
    String? reminders,
    Value<String?> repeat = const Value.absent(),
    String? steps,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<String?> linkedDiaryId = const Value.absent(),
    double? sortOrder,
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TodoRow(
    id: id ?? this.id,
    todoId: todoId ?? this.todoId,
    listId: listId.present ? listId.value : this.listId,
    title: title ?? this.title,
    note: note ?? this.note,
    priority: priority ?? this.priority,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueMinute: dueMinute.present ? dueMinute.value : this.dueMinute,
    reminders: reminders ?? this.reminders,
    repeat: repeat.present ? repeat.value : this.repeat,
    steps: steps ?? this.steps,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    linkedDiaryId: linkedDiaryId.present
        ? linkedDiaryId.value
        : this.linkedDiaryId,
    sortOrder: sortOrder ?? this.sortOrder,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TodoRow copyWithCompanion(TodosCompanion data) {
    return TodoRow(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueMinute: data.dueMinute.present ? data.dueMinute.value : this.dueMinute,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      steps: data.steps.present ? data.steps.value : this.steps,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      linkedDiaryId: data.linkedDiaryId.present
          ? data.linkedDiaryId.value
          : this.linkedDiaryId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRow(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinute: $dueMinute, ')
          ..write('reminders: $reminders, ')
          ..write('repeat: $repeat, ')
          ..write('steps: $steps, ')
          ..write('completedAt: $completedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('linkedDiaryId: $linkedDiaryId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    todoId,
    listId,
    title,
    note,
    priority,
    dueDate,
    dueMinute,
    reminders,
    repeat,
    steps,
    completedAt,
    snoozedUntil,
    linkedDiaryId,
    sortOrder,
    metadata,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRow &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.note == this.note &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.dueMinute == this.dueMinute &&
          other.reminders == this.reminders &&
          other.repeat == this.repeat &&
          other.steps == this.steps &&
          other.completedAt == this.completedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.linkedDiaryId == this.linkedDiaryId &&
          other.sortOrder == this.sortOrder &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TodosCompanion extends UpdateCompanion<TodoRow> {
  final Value<int> id;
  final Value<String> todoId;
  final Value<String?> listId;
  final Value<String> title;
  final Value<String> note;
  final Value<int> priority;
  final Value<String?> dueDate;
  final Value<int?> dueMinute;
  final Value<String> reminders;
  final Value<String?> repeat;
  final Value<String> steps;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> snoozedUntil;
  final Value<String?> linkedDiaryId;
  final Value<double> sortOrder;
  final Value<String> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinute = const Value.absent(),
    this.reminders = const Value.absent(),
    this.repeat = const Value.absent(),
    this.steps = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.linkedDiaryId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TodosCompanion.insert({
    this.id = const Value.absent(),
    required String todoId,
    this.listId = const Value.absent(),
    required String title,
    this.note = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueMinute = const Value.absent(),
    this.reminders = const Value.absent(),
    this.repeat = const Value.absent(),
    this.steps = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.linkedDiaryId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : todoId = Value(todoId),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TodoRow> custom({
    Expression<int>? id,
    Expression<String>? todoId,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? note,
    Expression<int>? priority,
    Expression<String>? dueDate,
    Expression<int>? dueMinute,
    Expression<String>? reminders,
    Expression<String>? repeat,
    Expression<String>? steps,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? snoozedUntil,
    Expression<String>? linkedDiaryId,
    Expression<double>? sortOrder,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'due_date': dueDate,
      if (dueMinute != null) 'due_minute': dueMinute,
      if (reminders != null) 'reminders': reminders,
      if (repeat != null) 'repeat': repeat,
      if (steps != null) 'steps': steps,
      if (completedAt != null) 'completed_at': completedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (linkedDiaryId != null) 'linked_diary_id': linkedDiaryId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TodosCompanion copyWith({
    Value<int>? id,
    Value<String>? todoId,
    Value<String?>? listId,
    Value<String>? title,
    Value<String>? note,
    Value<int>? priority,
    Value<String?>? dueDate,
    Value<int?>? dueMinute,
    Value<String>? reminders,
    Value<String?>? repeat,
    Value<String>? steps,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? snoozedUntil,
    Value<String?>? linkedDiaryId,
    Value<double>? sortOrder,
    Value<String>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueMinute: dueMinute ?? this.dueMinute,
      reminders: reminders ?? this.reminders,
      repeat: repeat ?? this.repeat,
      steps: steps ?? this.steps,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      linkedDiaryId: linkedDiaryId ?? this.linkedDiaryId,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (dueMinute.present) {
      map['due_minute'] = Variable<int>(dueMinute.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<String>(reminders.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (steps.present) {
      map['steps'] = Variable<String>(steps.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (linkedDiaryId.present) {
      map['linked_diary_id'] = Variable<String>(linkedDiaryId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueMinute: $dueMinute, ')
          ..write('reminders: $reminders, ')
          ..write('repeat: $repeat, ')
          ..write('steps: $steps, ')
          ..write('completedAt: $completedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('linkedDiaryId: $linkedDiaryId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DiariesTable diaries = $DiariesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $DiaryTagsTable diaryTags = $DiaryTagsTable(this);
  late final $AnniversariesTable anniversaries = $AnniversariesTable(this);
  late final $DiaryDraftsTable diaryDrafts = $DiaryDraftsTable(this);
  late final $DiaryTemplatesTable diaryTemplates = $DiaryTemplatesTable(this);
  late final $NotebooksTable notebooks = $NotebooksTable(this);
  late final $DiaryNotebooksTable diaryNotebooks = $DiaryNotebooksTable(this);
  late final $DayMoodsTable dayMoods = $DayMoodsTable(this);
  late final $DiaryCommentsTable diaryComments = $DiaryCommentsTable(this);
  late final $AiConversationsTable aiConversations = $AiConversationsTable(
    this,
  );
  late final $AiMessagesTable aiMessages = $AiMessagesTable(this);
  late final $AiResultsTable aiResults = $AiResultsTable(this);
  late final $TodoListsTable todoLists = $TodoListsTable(this);
  late final $TodosTable todos = $TodosTable(this);
  late final Index idxDiariesUpdatedAt = Index(
    'idx_diaries_updated_at',
    'CREATE INDEX idx_diaries_updated_at ON diaries (updated_at)',
  );
  late final Index idxDiariesCreatedAt = Index(
    'idx_diaries_created_at',
    'CREATE INDEX idx_diaries_created_at ON diaries (created_at)',
  );
  late final Index idxDiariesCapsuleUnlockAt = Index(
    'idx_diaries_capsule_unlock_at',
    'CREATE INDEX idx_diaries_capsule_unlock_at ON diaries (capsule_unlock_at)',
  );
  late final Index idxDiariesActiveUpdated = Index(
    'idx_diaries_active_updated',
    'CREATE INDEX idx_diaries_active_updated ON diaries (is_pinned DESC, updated_at DESC, id DESC) WHERE is_deleted = 0 AND is_archived = 0',
  );
  late final Index idxDiariesActiveCreated = Index(
    'idx_diaries_active_created',
    'CREATE INDEX idx_diaries_active_created ON diaries (is_pinned DESC, created_at DESC, id DESC) WHERE is_deleted = 0 AND is_archived = 0',
  );
  late final Index idxDiaryTagsTagId = Index(
    'idx_diary_tags_tag_id',
    'CREATE INDEX idx_diary_tags_tag_id ON diary_tags (tag_id)',
  );
  late final Index idxDiaryNotebooksNotebook = Index(
    'idx_diary_notebooks_notebook',
    'CREATE INDEX idx_diary_notebooks_notebook ON diary_notebooks (notebook_id, position)',
  );
  late final Index idxDiaryCommentsDiary = Index(
    'idx_diary_comments_diary',
    'CREATE INDEX idx_diary_comments_diary ON diary_comments (diary_id, created_at)',
  );
  late final Index idxAiConversationsUpdated = Index(
    'idx_ai_conversations_updated',
    'CREATE INDEX idx_ai_conversations_updated ON ai_conversations (updated_at)',
  );
  late final Index idxAiMessagesConversation = Index(
    'idx_ai_messages_conversation',
    'CREATE INDEX idx_ai_messages_conversation ON ai_messages (conversation_id, created_at)',
  );
  late final Index idxAiResultsDiary = Index(
    'idx_ai_results_diary',
    'CREATE INDEX idx_ai_results_diary ON ai_results (diary_id, created_at)',
  );
  late final Index idxAiResultsKind = Index(
    'idx_ai_results_kind',
    'CREATE INDEX idx_ai_results_kind ON ai_results (kind, created_at)',
  );
  late final Index idxTodosCompletedDue = Index(
    'idx_todos_completed_due',
    'CREATE INDEX idx_todos_completed_due ON todos (completed_at, due_date)',
  );
  late final Index idxTodosList = Index(
    'idx_todos_list',
    'CREATE INDEX idx_todos_list ON todos (list_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    diaries,
    tags,
    diaryTags,
    anniversaries,
    diaryDrafts,
    diaryTemplates,
    notebooks,
    diaryNotebooks,
    dayMoods,
    diaryComments,
    aiConversations,
    aiMessages,
    aiResults,
    todoLists,
    todos,
    idxDiariesUpdatedAt,
    idxDiariesCreatedAt,
    idxDiariesCapsuleUnlockAt,
    idxDiariesActiveUpdated,
    idxDiariesActiveCreated,
    idxDiaryTagsTagId,
    idxDiaryNotebooksNotebook,
    idxDiaryCommentsDiary,
    idxAiConversationsUpdated,
    idxAiMessagesConversation,
    idxAiResultsDiary,
    idxAiResultsKind,
    idxTodosCompletedDue,
    idxTodosList,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diaries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diary_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diary_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DiariesTableCreateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      required String diaryId,
      Value<String> title,
      required String content,
      required String contentText,
      Value<String?> cover,
      Value<String> metadata,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isArchived,
      Value<DateTime?> archivedAt,
      Value<bool> isPinned,
      Value<DateTime?> capsuleUnlockAt,
      Value<DateTime?> capsuleLockedAt,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
    });
typedef $$DiariesTableUpdateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      Value<String> diaryId,
      Value<String> title,
      Value<String> content,
      Value<String> contentText,
      Value<String?> cover,
      Value<String> metadata,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isArchived,
      Value<DateTime?> archivedAt,
      Value<bool> isPinned,
      Value<DateTime?> capsuleUnlockAt,
      Value<DateTime?> capsuleLockedAt,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
    });

final class $$DiariesTableReferences
    extends BaseReferences<_$AppDatabase, $DiariesTable, Diary> {
  $$DiariesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DiaryTagsTable, List<DiaryTag>>
  _diaryTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.diaryTags,
    aliasName: 'diaries__id__diary_tags__diary_id',
  );

  $$DiaryTagsTableProcessedTableManager get diaryTagsRefs {
    final manager = $$DiaryTagsTableTableManager(
      $_db,
      $_db.diaryTags,
    ).filter((f) => f.diaryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_diaryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DiariesTableFilterComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capsuleUnlockAt => $composableBuilder(
    column: $table.capsuleUnlockAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capsuleLockedAt => $composableBuilder(
    column: $table.capsuleLockedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> diaryTagsRefs(
    Expression<bool> Function($$DiaryTagsTableFilterComposer f) f,
  ) {
    final $$DiaryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryTagsTableFilterComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capsuleUnlockAt => $composableBuilder(
    column: $table.capsuleUnlockAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capsuleLockedAt => $composableBuilder(
    column: $table.capsuleLockedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get capsuleUnlockAt => $composableBuilder(
    column: $table.capsuleUnlockAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capsuleLockedAt => $composableBuilder(
    column: $table.capsuleLockedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> diaryTagsRefs<T extends Object>(
    Expression<T> Function($$DiaryTagsTableAnnotationComposer a) f,
  ) {
    final $$DiaryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiariesTable,
          Diary,
          $$DiariesTableFilterComposer,
          $$DiariesTableOrderingComposer,
          $$DiariesTableAnnotationComposer,
          $$DiariesTableCreateCompanionBuilder,
          $$DiariesTableUpdateCompanionBuilder,
          (Diary, $$DiariesTableReferences),
          Diary,
          PrefetchHooks Function({bool diaryTagsRefs})
        > {
  $$DiariesTableTableManager(_$AppDatabase db, $DiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> diaryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime?> capsuleUnlockAt = const Value.absent(),
                Value<DateTime?> capsuleLockedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => DiariesCompanion(
                id: id,
                diaryId: diaryId,
                title: title,
                content: content,
                contentText: contentText,
                cover: cover,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                archivedAt: archivedAt,
                isPinned: isPinned,
                capsuleUnlockAt: capsuleUnlockAt,
                capsuleLockedAt: capsuleLockedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String diaryId,
                Value<String> title = const Value.absent(),
                required String content,
                required String contentText,
                Value<String?> cover = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime?> capsuleUnlockAt = const Value.absent(),
                Value<DateTime?> capsuleLockedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => DiariesCompanion.insert(
                id: id,
                diaryId: diaryId,
                title: title,
                content: content,
                contentText: contentText,
                cover: cover,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                archivedAt: archivedAt,
                isPinned: isPinned,
                capsuleUnlockAt: capsuleUnlockAt,
                capsuleLockedAt: capsuleLockedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiariesTable, Diary>(table),
                  $$DiariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({diaryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (diaryTagsRefs) db.diaryTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (diaryTagsRefs)
                    await $_getPrefetchedDataByColumns<
                      Diary,
                      $DiariesTable,
                      DiaryTag,
                      $DiaryTagsTable
                    >(
                      currentTable: table,
                      referencedTable: $$DiariesTableReferences
                          ._diaryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DiariesTableReferences(db, table, p0).diaryTagsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'diary_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiariesTable,
      Diary,
      $$DiariesTableFilterComposer,
      $$DiariesTableOrderingComposer,
      $$DiariesTableAnnotationComposer,
      $$DiariesTableCreateCompanionBuilder,
      $$DiariesTableUpdateCompanionBuilder,
      (Diary, $$DiariesTableReferences),
      Diary,
      PrefetchHooks Function({bool diaryTagsRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      required int color,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> color,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DiaryTagsTable, List<DiaryTag>>
  _diaryTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.diaryTags,
    aliasName: 'tags__id__diary_tags__tag_id',
  );

  $$DiaryTagsTableProcessedTableManager get diaryTagsRefs {
    final manager = $$DiaryTagsTableTableManager(
      $_db,
      $_db.diaryTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_diaryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> diaryTagsRefs(
    Expression<bool> Function($$DiaryTagsTableFilterComposer f) f,
  ) {
    final $$DiaryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryTagsTableFilterComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  Expression<T> diaryTagsRefs<T extends Object>(
    Expression<T> Function($$DiaryTagsTableAnnotationComposer a) f,
  ) {
    final $$DiaryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool diaryTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
              }) => TagsCompanion(id: id, name: name, color: color),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int color,
              }) => TagsCompanion.insert(id: id, name: name, color: color),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({diaryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (diaryTagsRefs) db.diaryTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (diaryTagsRefs)
                    await $_getPrefetchedDataByColumns<
                      Tag,
                      $TagsTable,
                      DiaryTag,
                      $DiaryTagsTable
                    >(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._diaryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).diaryTagsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'tag_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool diaryTagsRefs})
    >;
typedef $$DiaryTagsTableCreateCompanionBuilder =
    DiaryTagsCompanion Function({
      required int diaryId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$DiaryTagsTableUpdateCompanionBuilder =
    DiaryTagsCompanion Function({
      Value<int> diaryId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$DiaryTagsTableReferences
    extends BaseReferences<_$AppDatabase, $DiaryTagsTable, DiaryTag> {
  $$DiaryTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DiariesTable _diaryIdTable(_$AppDatabase db) =>
      db.diaries.createAlias('diary_tags__diary_id__diaries__id');

  $$DiariesTableProcessedTableManager get diaryId {
    final $_column = $_itemColumn<int>('diary_id')!;

    final manager = $$DiariesTableTableManager(
      $_db,
      $_db.diaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_diaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('diary_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DiaryTagsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryTagsTable> {
  $$DiaryTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DiariesTableFilterComposer get diaryId {
    final $$DiariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiariesTableFilterComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiaryTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryTagsTable> {
  $$DiaryTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DiariesTableOrderingComposer get diaryId {
    final $$DiariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiariesTableOrderingComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiaryTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryTagsTable> {
  $$DiaryTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DiariesTableAnnotationComposer get diaryId {
    final $$DiariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiariesTableAnnotationComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiaryTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryTagsTable,
          DiaryTag,
          $$DiaryTagsTableFilterComposer,
          $$DiaryTagsTableOrderingComposer,
          $$DiaryTagsTableAnnotationComposer,
          $$DiaryTagsTableCreateCompanionBuilder,
          $$DiaryTagsTableUpdateCompanionBuilder,
          (DiaryTag, $$DiaryTagsTableReferences),
          DiaryTag,
          PrefetchHooks Function({bool diaryId, bool tagId})
        > {
  $$DiaryTagsTableTableManager(_$AppDatabase db, $DiaryTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> diaryId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryTagsCompanion(
                diaryId: diaryId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int diaryId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => DiaryTagsCompanion.insert(
                diaryId: diaryId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryTagsTable, DiaryTag>(table),
                  $$DiaryTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({diaryId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (diaryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.diaryId,
                                referencedTable: $$DiaryTagsTableReferences
                                    ._diaryIdTable(db),
                                referencedColumn: $$DiaryTagsTableReferences
                                    ._diaryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$DiaryTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$DiaryTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DiaryTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryTagsTable,
      DiaryTag,
      $$DiaryTagsTableFilterComposer,
      $$DiaryTagsTableOrderingComposer,
      $$DiaryTagsTableAnnotationComposer,
      $$DiaryTagsTableCreateCompanionBuilder,
      $$DiaryTagsTableUpdateCompanionBuilder,
      (DiaryTag, $$DiaryTagsTableReferences),
      DiaryTag,
      PrefetchHooks Function({bool diaryId, bool tagId})
    >;
typedef $$AnniversariesTableCreateCompanionBuilder =
    AnniversariesCompanion Function({
      Value<int> id,
      required String anniversaryId,
      required String title,
      required String baseDate,
      Value<String> recurrence,
      Value<int?> lunarYear,
      Value<int?> lunarMonth,
      Value<int?> lunarDay,
      Value<String?> linkedDiaryId,
      Value<String> note,
      Value<bool> isPinned,
      Value<String> metadata,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$AnniversariesTableUpdateCompanionBuilder =
    AnniversariesCompanion Function({
      Value<int> id,
      Value<String> anniversaryId,
      Value<String> title,
      Value<String> baseDate,
      Value<String> recurrence,
      Value<int?> lunarYear,
      Value<int?> lunarMonth,
      Value<int?> lunarDay,
      Value<String?> linkedDiaryId,
      Value<String> note,
      Value<bool> isPinned,
      Value<String> metadata,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$AnniversariesTableFilterComposer
    extends Composer<_$AppDatabase, $AnniversariesTable> {
  $$AnniversariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anniversaryId => $composableBuilder(
    column: $table.anniversaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseDate => $composableBuilder(
    column: $table.baseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lunarYear => $composableBuilder(
    column: $table.lunarYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lunarMonth => $composableBuilder(
    column: $table.lunarMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lunarDay => $composableBuilder(
    column: $table.lunarDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnniversariesTableOrderingComposer
    extends Composer<_$AppDatabase, $AnniversariesTable> {
  $$AnniversariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anniversaryId => $composableBuilder(
    column: $table.anniversaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseDate => $composableBuilder(
    column: $table.baseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lunarYear => $composableBuilder(
    column: $table.lunarYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lunarMonth => $composableBuilder(
    column: $table.lunarMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lunarDay => $composableBuilder(
    column: $table.lunarDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnniversariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnniversariesTable> {
  $$AnniversariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get anniversaryId => $composableBuilder(
    column: $table.anniversaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get baseDate =>
      $composableBuilder(column: $table.baseDate, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lunarYear =>
      $composableBuilder(column: $table.lunarYear, builder: (column) => column);

  GeneratedColumn<int> get lunarMonth => $composableBuilder(
    column: $table.lunarMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lunarDay =>
      $composableBuilder(column: $table.lunarDay, builder: (column) => column);

  GeneratedColumn<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnniversariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnniversariesTable,
          Anniversary,
          $$AnniversariesTableFilterComposer,
          $$AnniversariesTableOrderingComposer,
          $$AnniversariesTableAnnotationComposer,
          $$AnniversariesTableCreateCompanionBuilder,
          $$AnniversariesTableUpdateCompanionBuilder,
          (
            Anniversary,
            BaseReferences<_$AppDatabase, $AnniversariesTable, Anniversary>,
          ),
          Anniversary,
          PrefetchHooks Function()
        > {
  $$AnniversariesTableTableManager(_$AppDatabase db, $AnniversariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnniversariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnniversariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnniversariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> anniversaryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> baseDate = const Value.absent(),
                Value<String> recurrence = const Value.absent(),
                Value<int?> lunarYear = const Value.absent(),
                Value<int?> lunarMonth = const Value.absent(),
                Value<int?> lunarDay = const Value.absent(),
                Value<String?> linkedDiaryId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnniversariesCompanion(
                id: id,
                anniversaryId: anniversaryId,
                title: title,
                baseDate: baseDate,
                recurrence: recurrence,
                lunarYear: lunarYear,
                lunarMonth: lunarMonth,
                lunarDay: lunarDay,
                linkedDiaryId: linkedDiaryId,
                note: note,
                isPinned: isPinned,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String anniversaryId,
                required String title,
                required String baseDate,
                Value<String> recurrence = const Value.absent(),
                Value<int?> lunarYear = const Value.absent(),
                Value<int?> lunarMonth = const Value.absent(),
                Value<int?> lunarDay = const Value.absent(),
                Value<String?> linkedDiaryId = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => AnniversariesCompanion.insert(
                id: id,
                anniversaryId: anniversaryId,
                title: title,
                baseDate: baseDate,
                recurrence: recurrence,
                lunarYear: lunarYear,
                lunarMonth: lunarMonth,
                lunarDay: lunarDay,
                linkedDiaryId: linkedDiaryId,
                note: note,
                isPinned: isPinned,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnniversariesTable, Anniversary>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AnniversariesTable,
                    Anniversary
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnniversariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnniversariesTable,
      Anniversary,
      $$AnniversariesTableFilterComposer,
      $$AnniversariesTableOrderingComposer,
      $$AnniversariesTableAnnotationComposer,
      $$AnniversariesTableCreateCompanionBuilder,
      $$AnniversariesTableUpdateCompanionBuilder,
      (
        Anniversary,
        BaseReferences<_$AppDatabase, $AnniversariesTable, Anniversary>,
      ),
      Anniversary,
      PrefetchHooks Function()
    >;
typedef $$DiaryDraftsTableCreateCompanionBuilder =
    DiaryDraftsCompanion Function({
      Value<int> id,
      required String draftId,
      Value<String> title,
      Value<String> contentText,
      required String payload,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$DiaryDraftsTableUpdateCompanionBuilder =
    DiaryDraftsCompanion Function({
      Value<int> id,
      Value<String> draftId,
      Value<String> title,
      Value<String> contentText,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DiaryDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DiaryDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryDraftsTable,
          DiaryDraftRow,
          $$DiaryDraftsTableFilterComposer,
          $$DiaryDraftsTableOrderingComposer,
          $$DiaryDraftsTableAnnotationComposer,
          $$DiaryDraftsTableCreateCompanionBuilder,
          $$DiaryDraftsTableUpdateCompanionBuilder,
          (
            DiaryDraftRow,
            BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraftRow>,
          ),
          DiaryDraftRow,
          PrefetchHooks Function()
        > {
  $$DiaryDraftsTableTableManager(_$AppDatabase db, $DiaryDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> draftId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiaryDraftsCompanion(
                id: id,
                draftId: draftId,
                title: title,
                contentText: contentText,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String draftId,
                Value<String> title = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                required String payload,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DiaryDraftsCompanion.insert(
                id: id,
                draftId: draftId,
                title: title,
                contentText: contentText,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryDraftsTable, DiaryDraftRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryDraftsTable,
                    DiaryDraftRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryDraftsTable,
      DiaryDraftRow,
      $$DiaryDraftsTableFilterComposer,
      $$DiaryDraftsTableOrderingComposer,
      $$DiaryDraftsTableAnnotationComposer,
      $$DiaryDraftsTableCreateCompanionBuilder,
      $$DiaryDraftsTableUpdateCompanionBuilder,
      (
        DiaryDraftRow,
        BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraftRow>,
      ),
      DiaryDraftRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryTemplatesTableCreateCompanionBuilder =
    DiaryTemplatesCompanion Function({
      Value<int> id,
      required String templateId,
      Value<String> name,
      required String payload,
      Value<int> sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$DiaryTemplatesTableUpdateCompanionBuilder =
    DiaryTemplatesCompanion Function({
      Value<int> id,
      Value<String> templateId,
      Value<String> name,
      Value<String> payload,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DiaryTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryTemplatesTable> {
  $$DiaryTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryTemplatesTable> {
  $$DiaryTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryTemplatesTable> {
  $$DiaryTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DiaryTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryTemplatesTable,
          DiaryTemplateRow,
          $$DiaryTemplatesTableFilterComposer,
          $$DiaryTemplatesTableOrderingComposer,
          $$DiaryTemplatesTableAnnotationComposer,
          $$DiaryTemplatesTableCreateCompanionBuilder,
          $$DiaryTemplatesTableUpdateCompanionBuilder,
          (
            DiaryTemplateRow,
            BaseReferences<
              _$AppDatabase,
              $DiaryTemplatesTable,
              DiaryTemplateRow
            >,
          ),
          DiaryTemplateRow,
          PrefetchHooks Function()
        > {
  $$DiaryTemplatesTableTableManager(
    _$AppDatabase db,
    $DiaryTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiaryTemplatesCompanion(
                id: id,
                templateId: templateId,
                name: name,
                payload: payload,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String templateId,
                Value<String> name = const Value.absent(),
                required String payload,
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DiaryTemplatesCompanion.insert(
                id: id,
                templateId: templateId,
                name: name,
                payload: payload,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryTemplatesTable, DiaryTemplateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryTemplatesTable,
                    DiaryTemplateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryTemplatesTable,
      DiaryTemplateRow,
      $$DiaryTemplatesTableFilterComposer,
      $$DiaryTemplatesTableOrderingComposer,
      $$DiaryTemplatesTableAnnotationComposer,
      $$DiaryTemplatesTableCreateCompanionBuilder,
      $$DiaryTemplatesTableUpdateCompanionBuilder,
      (
        DiaryTemplateRow,
        BaseReferences<_$AppDatabase, $DiaryTemplatesTable, DiaryTemplateRow>,
      ),
      DiaryTemplateRow,
      PrefetchHooks Function()
    >;
typedef $$NotebooksTableCreateCompanionBuilder =
    NotebooksCompanion Function({
      Value<int> id,
      required String notebookId,
      required String name,
      Value<String> kind,
      Value<String> visibility,
      Value<String> payload,
      Value<int> sortOrder,
      Value<bool> isPinned,
      Value<bool> isClosed,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> parentId,
    });
typedef $$NotebooksTableUpdateCompanionBuilder =
    NotebooksCompanion Function({
      Value<int> id,
      Value<String> notebookId,
      Value<String> name,
      Value<String> kind,
      Value<String> visibility,
      Value<String> payload,
      Value<int> sortOrder,
      Value<bool> isPinned,
      Value<bool> isClosed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> parentId,
    });

class $$NotebooksTableFilterComposer
    extends Composer<_$AppDatabase, $NotebooksTable> {
  $$NotebooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isClosed => $composableBuilder(
    column: $table.isClosed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotebooksTableOrderingComposer
    extends Composer<_$AppDatabase, $NotebooksTable> {
  $$NotebooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isClosed => $composableBuilder(
    column: $table.isClosed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotebooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotebooksTable> {
  $$NotebooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isClosed =>
      $composableBuilder(column: $table.isClosed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);
}

class $$NotebooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotebooksTable,
          NotebookRow,
          $$NotebooksTableFilterComposer,
          $$NotebooksTableOrderingComposer,
          $$NotebooksTableAnnotationComposer,
          $$NotebooksTableCreateCompanionBuilder,
          $$NotebooksTableUpdateCompanionBuilder,
          (
            NotebookRow,
            BaseReferences<_$AppDatabase, $NotebooksTable, NotebookRow>,
          ),
          NotebookRow,
          PrefetchHooks Function()
        > {
  $$NotebooksTableTableManager(_$AppDatabase db, $NotebooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotebooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotebooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotebooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> notebookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isClosed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
              }) => NotebooksCompanion(
                id: id,
                notebookId: notebookId,
                name: name,
                kind: kind,
                visibility: visibility,
                payload: payload,
                sortOrder: sortOrder,
                isPinned: isPinned,
                isClosed: isClosed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                parentId: parentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String notebookId,
                required String name,
                Value<String> kind = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isClosed = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> parentId = const Value.absent(),
              }) => NotebooksCompanion.insert(
                id: id,
                notebookId: notebookId,
                name: name,
                kind: kind,
                visibility: visibility,
                payload: payload,
                sortOrder: sortOrder,
                isPinned: isPinned,
                isClosed: isClosed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotebooksTable, NotebookRow>(table),
                  BaseReferences<_$AppDatabase, $NotebooksTable, NotebookRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotebooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotebooksTable,
      NotebookRow,
      $$NotebooksTableFilterComposer,
      $$NotebooksTableOrderingComposer,
      $$NotebooksTableAnnotationComposer,
      $$NotebooksTableCreateCompanionBuilder,
      $$NotebooksTableUpdateCompanionBuilder,
      (
        NotebookRow,
        BaseReferences<_$AppDatabase, $NotebooksTable, NotebookRow>,
      ),
      NotebookRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryNotebooksTableCreateCompanionBuilder =
    DiaryNotebooksCompanion Function({
      required int diaryId,
      required int notebookId,
      Value<String?> chapterId,
      Value<int> position,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$DiaryNotebooksTableUpdateCompanionBuilder =
    DiaryNotebooksCompanion Function({
      Value<int> diaryId,
      Value<int> notebookId,
      Value<String?> chapterId,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$DiaryNotebooksTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryNotebooksTable> {
  $$DiaryNotebooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryNotebooksTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryNotebooksTable> {
  $$DiaryNotebooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryNotebooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryNotebooksTable> {
  $$DiaryNotebooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<int> get notebookId => $composableBuilder(
    column: $table.notebookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$DiaryNotebooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryNotebooksTable,
          DiaryNotebookRow,
          $$DiaryNotebooksTableFilterComposer,
          $$DiaryNotebooksTableOrderingComposer,
          $$DiaryNotebooksTableAnnotationComposer,
          $$DiaryNotebooksTableCreateCompanionBuilder,
          $$DiaryNotebooksTableUpdateCompanionBuilder,
          (
            DiaryNotebookRow,
            BaseReferences<
              _$AppDatabase,
              $DiaryNotebooksTable,
              DiaryNotebookRow
            >,
          ),
          DiaryNotebookRow,
          PrefetchHooks Function()
        > {
  $$DiaryNotebooksTableTableManager(
    _$AppDatabase db,
    $DiaryNotebooksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryNotebooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryNotebooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryNotebooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> diaryId = const Value.absent(),
                Value<int> notebookId = const Value.absent(),
                Value<String?> chapterId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryNotebooksCompanion(
                diaryId: diaryId,
                notebookId: notebookId,
                chapterId: chapterId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int diaryId,
                required int notebookId,
                Value<String?> chapterId = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => DiaryNotebooksCompanion.insert(
                diaryId: diaryId,
                notebookId: notebookId,
                chapterId: chapterId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryNotebooksTable, DiaryNotebookRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryNotebooksTable,
                    DiaryNotebookRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryNotebooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryNotebooksTable,
      DiaryNotebookRow,
      $$DiaryNotebooksTableFilterComposer,
      $$DiaryNotebooksTableOrderingComposer,
      $$DiaryNotebooksTableAnnotationComposer,
      $$DiaryNotebooksTableCreateCompanionBuilder,
      $$DiaryNotebooksTableUpdateCompanionBuilder,
      (
        DiaryNotebookRow,
        BaseReferences<_$AppDatabase, $DiaryNotebooksTable, DiaryNotebookRow>,
      ),
      DiaryNotebookRow,
      PrefetchHooks Function()
    >;
typedef $$DayMoodsTableCreateCompanionBuilder =
    DayMoodsCompanion Function({
      required String day,
      required String mood,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DayMoodsTableUpdateCompanionBuilder =
    DayMoodsCompanion Function({
      Value<String> day,
      Value<String> mood,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DayMoodsTableFilterComposer
    extends Composer<_$AppDatabase, $DayMoodsTable> {
  $$DayMoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayMoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $DayMoodsTable> {
  $$DayMoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayMoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayMoodsTable> {
  $$DayMoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DayMoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayMoodsTable,
          DayMoodRow,
          $$DayMoodsTableFilterComposer,
          $$DayMoodsTableOrderingComposer,
          $$DayMoodsTableAnnotationComposer,
          $$DayMoodsTableCreateCompanionBuilder,
          $$DayMoodsTableUpdateCompanionBuilder,
          (
            DayMoodRow,
            BaseReferences<_$AppDatabase, $DayMoodsTable, DayMoodRow>,
          ),
          DayMoodRow,
          PrefetchHooks Function()
        > {
  $$DayMoodsTableTableManager(_$AppDatabase db, $DayMoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayMoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayMoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayMoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayMoodsCompanion(
                day: day,
                mood: mood,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String mood,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DayMoodsCompanion.insert(
                day: day,
                mood: mood,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayMoodsTable, DayMoodRow>(table),
                  BaseReferences<_$AppDatabase, $DayMoodsTable, DayMoodRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayMoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayMoodsTable,
      DayMoodRow,
      $$DayMoodsTableFilterComposer,
      $$DayMoodsTableOrderingComposer,
      $$DayMoodsTableAnnotationComposer,
      $$DayMoodsTableCreateCompanionBuilder,
      $$DayMoodsTableUpdateCompanionBuilder,
      (DayMoodRow, BaseReferences<_$AppDatabase, $DayMoodsTable, DayMoodRow>),
      DayMoodRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryCommentsTableCreateCompanionBuilder =
    DiaryCommentsCompanion Function({
      Value<int> id,
      required String commentId,
      required String diaryId,
      required String content,
      Value<String?> mood,
      required DateTime createdAt,
      Value<DateTime?> editedAt,
      Value<String?> images,
    });
typedef $$DiaryCommentsTableUpdateCompanionBuilder =
    DiaryCommentsCompanion Function({
      Value<int> id,
      Value<String> commentId,
      Value<String> diaryId,
      Value<String> content,
      Value<String?> mood,
      Value<DateTime> createdAt,
      Value<DateTime?> editedAt,
      Value<String?> images,
    });

class $$DiaryCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryCommentsTable> {
  $$DiaryCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentId => $composableBuilder(
    column: $table.commentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryCommentsTable> {
  $$DiaryCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentId => $composableBuilder(
    column: $table.commentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryCommentsTable> {
  $$DiaryCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commentId =>
      $composableBuilder(column: $table.commentId, builder: (column) => column);

  GeneratedColumn<String> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);
}

class $$DiaryCommentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryCommentsTable,
          DiaryCommentRow,
          $$DiaryCommentsTableFilterComposer,
          $$DiaryCommentsTableOrderingComposer,
          $$DiaryCommentsTableAnnotationComposer,
          $$DiaryCommentsTableCreateCompanionBuilder,
          $$DiaryCommentsTableUpdateCompanionBuilder,
          (
            DiaryCommentRow,
            BaseReferences<_$AppDatabase, $DiaryCommentsTable, DiaryCommentRow>,
          ),
          DiaryCommentRow,
          PrefetchHooks Function()
        > {
  $$DiaryCommentsTableTableManager(_$AppDatabase db, $DiaryCommentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> commentId = const Value.absent(),
                Value<String> diaryId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<String?> images = const Value.absent(),
              }) => DiaryCommentsCompanion(
                id: id,
                commentId: commentId,
                diaryId: diaryId,
                content: content,
                mood: mood,
                createdAt: createdAt,
                editedAt: editedAt,
                images: images,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String commentId,
                required String diaryId,
                required String content,
                Value<String?> mood = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> editedAt = const Value.absent(),
                Value<String?> images = const Value.absent(),
              }) => DiaryCommentsCompanion.insert(
                id: id,
                commentId: commentId,
                diaryId: diaryId,
                content: content,
                mood: mood,
                createdAt: createdAt,
                editedAt: editedAt,
                images: images,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryCommentsTable, DiaryCommentRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DiaryCommentsTable,
                    DiaryCommentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryCommentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryCommentsTable,
      DiaryCommentRow,
      $$DiaryCommentsTableFilterComposer,
      $$DiaryCommentsTableOrderingComposer,
      $$DiaryCommentsTableAnnotationComposer,
      $$DiaryCommentsTableCreateCompanionBuilder,
      $$DiaryCommentsTableUpdateCompanionBuilder,
      (
        DiaryCommentRow,
        BaseReferences<_$AppDatabase, $DiaryCommentsTable, DiaryCommentRow>,
      ),
      DiaryCommentRow,
      PrefetchHooks Function()
    >;
typedef $$AiConversationsTableCreateCompanionBuilder =
    AiConversationsCompanion Function({
      Value<int> id,
      required String conversationId,
      Value<String> title,
      Value<String?> personaId,
      Value<String> scope,
      Value<String> options,
      Value<bool> pinned,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$AiConversationsTableUpdateCompanionBuilder =
    AiConversationsCompanion Function({
      Value<int> id,
      Value<String> conversationId,
      Value<String> title,
      Value<String?> personaId,
      Value<String> scope,
      Value<String> options,
      Value<bool> pinned,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$AiConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get options =>
      $composableBuilder(column: $table.options, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiConversationsTable,
          AiConversationRow,
          $$AiConversationsTableFilterComposer,
          $$AiConversationsTableOrderingComposer,
          $$AiConversationsTableAnnotationComposer,
          $$AiConversationsTableCreateCompanionBuilder,
          $$AiConversationsTableUpdateCompanionBuilder,
          (
            AiConversationRow,
            BaseReferences<
              _$AppDatabase,
              $AiConversationsTable,
              AiConversationRow
            >,
          ),
          AiConversationRow,
          PrefetchHooks Function()
        > {
  $$AiConversationsTableTableManager(
    _$AppDatabase db,
    $AiConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> personaId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> options = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AiConversationsCompanion(
                id: id,
                conversationId: conversationId,
                title: title,
                personaId: personaId,
                scope: scope,
                options: options,
                pinned: pinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String conversationId,
                Value<String> title = const Value.absent(),
                Value<String?> personaId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> options = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => AiConversationsCompanion.insert(
                id: id,
                conversationId: conversationId,
                title: title,
                personaId: personaId,
                scope: scope,
                options: options,
                pinned: pinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiConversationsTable, AiConversationRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AiConversationsTable,
                    AiConversationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiConversationsTable,
      AiConversationRow,
      $$AiConversationsTableFilterComposer,
      $$AiConversationsTableOrderingComposer,
      $$AiConversationsTableAnnotationComposer,
      $$AiConversationsTableCreateCompanionBuilder,
      $$AiConversationsTableUpdateCompanionBuilder,
      (
        AiConversationRow,
        BaseReferences<_$AppDatabase, $AiConversationsTable, AiConversationRow>,
      ),
      AiConversationRow,
      PrefetchHooks Function()
    >;
typedef $$AiMessagesTableCreateCompanionBuilder =
    AiMessagesCompanion Function({
      Value<int> id,
      required String messageId,
      required String conversationId,
      required String role,
      Value<String> content,
      Value<String> reasoning,
      Value<String> citations,
      Value<String> meta,
      Value<String> status,
      Value<String> steps,
      required DateTime createdAt,
    });
typedef $$AiMessagesTableUpdateCompanionBuilder =
    AiMessagesCompanion Function({
      Value<int> id,
      Value<String> messageId,
      Value<String> conversationId,
      Value<String> role,
      Value<String> content,
      Value<String> reasoning,
      Value<String> citations,
      Value<String> meta,
      Value<String> status,
      Value<String> steps,
      Value<DateTime> createdAt,
    });

class $$AiMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<String> get citations =>
      $composableBuilder(column: $table.citations, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiMessagesTable,
          AiMessageRow,
          $$AiMessagesTableFilterComposer,
          $$AiMessagesTableOrderingComposer,
          $$AiMessagesTableAnnotationComposer,
          $$AiMessagesTableCreateCompanionBuilder,
          $$AiMessagesTableUpdateCompanionBuilder,
          (
            AiMessageRow,
            BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessageRow>,
          ),
          AiMessageRow,
          PrefetchHooks Function()
        > {
  $$AiMessagesTableTableManager(_$AppDatabase db, $AiMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<String> citations = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiMessagesCompanion(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                role: role,
                content: content,
                reasoning: reasoning,
                citations: citations,
                meta: meta,
                status: status,
                steps: steps,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String messageId,
                required String conversationId,
                required String role,
                Value<String> content = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<String> citations = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> steps = const Value.absent(),
                required DateTime createdAt,
              }) => AiMessagesCompanion.insert(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                role: role,
                content: content,
                reasoning: reasoning,
                citations: citations,
                meta: meta,
                status: status,
                steps: steps,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiMessagesTable, AiMessageRow>(table),
                  BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessageRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiMessagesTable,
      AiMessageRow,
      $$AiMessagesTableFilterComposer,
      $$AiMessagesTableOrderingComposer,
      $$AiMessagesTableAnnotationComposer,
      $$AiMessagesTableCreateCompanionBuilder,
      $$AiMessagesTableUpdateCompanionBuilder,
      (
        AiMessageRow,
        BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessageRow>,
      ),
      AiMessageRow,
      PrefetchHooks Function()
    >;
typedef $$AiResultsTableCreateCompanionBuilder =
    AiResultsCompanion Function({
      Value<int> id,
      required String resultId,
      required String kind,
      Value<String?> diaryId,
      Value<DateTime?> periodStart,
      Value<DateTime?> periodEnd,
      Value<String> scope,
      Value<String> title,
      required String content,
      Value<String?> personaId,
      Value<String> meta,
      required DateTime createdAt,
    });
typedef $$AiResultsTableUpdateCompanionBuilder =
    AiResultsCompanion Function({
      Value<int> id,
      Value<String> resultId,
      Value<String> kind,
      Value<String?> diaryId,
      Value<DateTime?> periodStart,
      Value<DateTime?> periodEnd,
      Value<String> scope,
      Value<String> title,
      Value<String> content,
      Value<String?> personaId,
      Value<String> meta,
      Value<DateTime> createdAt,
    });

class $$AiResultsTableFilterComposer
    extends Composer<_$AppDatabase, $AiResultsTable> {
  $$AiResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultId => $composableBuilder(
    column: $table.resultId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiResultsTable> {
  $$AiResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultId => $composableBuilder(
    column: $table.resultId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiResultsTable> {
  $$AiResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get resultId =>
      $composableBuilder(column: $table.resultId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiResultsTable,
          AiResultRow,
          $$AiResultsTableFilterComposer,
          $$AiResultsTableOrderingComposer,
          $$AiResultsTableAnnotationComposer,
          $$AiResultsTableCreateCompanionBuilder,
          $$AiResultsTableUpdateCompanionBuilder,
          (
            AiResultRow,
            BaseReferences<_$AppDatabase, $AiResultsTable, AiResultRow>,
          ),
          AiResultRow,
          PrefetchHooks Function()
        > {
  $$AiResultsTableTableManager(_$AppDatabase db, $AiResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> resultId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> diaryId = const Value.absent(),
                Value<DateTime?> periodStart = const Value.absent(),
                Value<DateTime?> periodEnd = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> personaId = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiResultsCompanion(
                id: id,
                resultId: resultId,
                kind: kind,
                diaryId: diaryId,
                periodStart: periodStart,
                periodEnd: periodEnd,
                scope: scope,
                title: title,
                content: content,
                personaId: personaId,
                meta: meta,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String resultId,
                required String kind,
                Value<String?> diaryId = const Value.absent(),
                Value<DateTime?> periodStart = const Value.absent(),
                Value<DateTime?> periodEnd = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> title = const Value.absent(),
                required String content,
                Value<String?> personaId = const Value.absent(),
                Value<String> meta = const Value.absent(),
                required DateTime createdAt,
              }) => AiResultsCompanion.insert(
                id: id,
                resultId: resultId,
                kind: kind,
                diaryId: diaryId,
                periodStart: periodStart,
                periodEnd: periodEnd,
                scope: scope,
                title: title,
                content: content,
                personaId: personaId,
                meta: meta,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiResultsTable, AiResultRow>(table),
                  BaseReferences<_$AppDatabase, $AiResultsTable, AiResultRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiResultsTable,
      AiResultRow,
      $$AiResultsTableFilterComposer,
      $$AiResultsTableOrderingComposer,
      $$AiResultsTableAnnotationComposer,
      $$AiResultsTableCreateCompanionBuilder,
      $$AiResultsTableUpdateCompanionBuilder,
      (
        AiResultRow,
        BaseReferences<_$AppDatabase, $AiResultsTable, AiResultRow>,
      ),
      AiResultRow,
      PrefetchHooks Function()
    >;
typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      Value<int> id,
      required String listId,
      required String name,
      Value<String> colorKey,
      Value<String> iconKey,
      Value<double> sortOrder,
      Value<String> metadata,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<int> id,
      Value<String> listId,
      Value<String> name,
      Value<String> colorKey,
      Value<String> iconKey,
      Value<double> sortOrder,
      Value<String> metadata,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$TodoListsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorKey =>
      $composableBuilder(column: $table.colorKey, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TodoListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListsTable,
          TodoListRow,
          $$TodoListsTableFilterComposer,
          $$TodoListsTableOrderingComposer,
          $$TodoListsTableAnnotationComposer,
          $$TodoListsTableCreateCompanionBuilder,
          $$TodoListsTableUpdateCompanionBuilder,
          (
            TodoListRow,
            BaseReferences<_$AppDatabase, $TodoListsTable, TodoListRow>,
          ),
          TodoListRow,
          PrefetchHooks Function()
        > {
  $$TodoListsTableTableManager(_$AppDatabase db, $TodoListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorKey = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                listId: listId,
                name: name,
                colorKey: colorKey,
                iconKey: iconKey,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String listId,
                required String name,
                Value<String> colorKey = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TodoListsCompanion.insert(
                id: id,
                listId: listId,
                name: name,
                colorKey: colorKey,
                iconKey: iconKey,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TodoListsTable, TodoListRow>(table),
                  BaseReferences<_$AppDatabase, $TodoListsTable, TodoListRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListsTable,
      TodoListRow,
      $$TodoListsTableFilterComposer,
      $$TodoListsTableOrderingComposer,
      $$TodoListsTableAnnotationComposer,
      $$TodoListsTableCreateCompanionBuilder,
      $$TodoListsTableUpdateCompanionBuilder,
      (
        TodoListRow,
        BaseReferences<_$AppDatabase, $TodoListsTable, TodoListRow>,
      ),
      TodoListRow,
      PrefetchHooks Function()
    >;
typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      Value<int> id,
      required String todoId,
      Value<String?> listId,
      required String title,
      Value<String> note,
      Value<int> priority,
      Value<String?> dueDate,
      Value<int?> dueMinute,
      Value<String> reminders,
      Value<String?> repeat,
      Value<String> steps,
      Value<DateTime?> completedAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> linkedDiaryId,
      Value<double> sortOrder,
      Value<String> metadata,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<int> id,
      Value<String> todoId,
      Value<String?> listId,
      Value<String> title,
      Value<String> note,
      Value<int> priority,
      Value<String?> dueDate,
      Value<int?> dueMinute,
      Value<String> reminders,
      Value<String?> repeat,
      Value<String> steps,
      Value<DateTime?> completedAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> linkedDiaryId,
      Value<double> sortOrder,
      Value<String> metadata,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$TodosTableFilterComposer extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get todoId => $composableBuilder(
    column: $table.todoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMinute => $composableBuilder(
    column: $table.dueMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get todoId => $composableBuilder(
    column: $table.todoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMinute => $composableBuilder(
    column: $table.dueMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get todoId =>
      $composableBuilder(column: $table.todoId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueMinute =>
      $composableBuilder(column: $table.dueMinute, builder: (column) => column);

  GeneratedColumn<String> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedDiaryId => $composableBuilder(
    column: $table.linkedDiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosTable,
          TodoRow,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (TodoRow, BaseReferences<_$AppDatabase, $TodosTable, TodoRow>),
          TodoRow,
          PrefetchHooks Function()
        > {
  $$TodosTableTableManager(_$AppDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> todoId = const Value.absent(),
                Value<String?> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinute = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> linkedDiaryId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                todoId: todoId,
                listId: listId,
                title: title,
                note: note,
                priority: priority,
                dueDate: dueDate,
                dueMinute: dueMinute,
                reminders: reminders,
                repeat: repeat,
                steps: steps,
                completedAt: completedAt,
                snoozedUntil: snoozedUntil,
                linkedDiaryId: linkedDiaryId,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String todoId,
                Value<String?> listId = const Value.absent(),
                required String title,
                Value<String> note = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<int?> dueMinute = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<String?> repeat = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> linkedDiaryId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TodosCompanion.insert(
                id: id,
                todoId: todoId,
                listId: listId,
                title: title,
                note: note,
                priority: priority,
                dueDate: dueDate,
                dueMinute: dueMinute,
                reminders: reminders,
                repeat: repeat,
                steps: steps,
                completedAt: completedAt,
                snoozedUntil: snoozedUntil,
                linkedDiaryId: linkedDiaryId,
                sortOrder: sortOrder,
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TodosTable, TodoRow>(table),
                  BaseReferences<_$AppDatabase, $TodosTable, TodoRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosTable,
      TodoRow,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (TodoRow, BaseReferences<_$AppDatabase, $TodosTable, TodoRow>),
      TodoRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DiariesTableTableManager get diaries =>
      $$DiariesTableTableManager(_db, _db.diaries);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$DiaryTagsTableTableManager get diaryTags =>
      $$DiaryTagsTableTableManager(_db, _db.diaryTags);
  $$AnniversariesTableTableManager get anniversaries =>
      $$AnniversariesTableTableManager(_db, _db.anniversaries);
  $$DiaryDraftsTableTableManager get diaryDrafts =>
      $$DiaryDraftsTableTableManager(_db, _db.diaryDrafts);
  $$DiaryTemplatesTableTableManager get diaryTemplates =>
      $$DiaryTemplatesTableTableManager(_db, _db.diaryTemplates);
  $$NotebooksTableTableManager get notebooks =>
      $$NotebooksTableTableManager(_db, _db.notebooks);
  $$DiaryNotebooksTableTableManager get diaryNotebooks =>
      $$DiaryNotebooksTableTableManager(_db, _db.diaryNotebooks);
  $$DayMoodsTableTableManager get dayMoods =>
      $$DayMoodsTableTableManager(_db, _db.dayMoods);
  $$DiaryCommentsTableTableManager get diaryComments =>
      $$DiaryCommentsTableTableManager(_db, _db.diaryComments);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(_db, _db.aiConversations);
  $$AiMessagesTableTableManager get aiMessages =>
      $$AiMessagesTableTableManager(_db, _db.aiMessages);
  $$AiResultsTableTableManager get aiResults =>
      $$AiResultsTableTableManager(_db, _db.aiResults);
  $$TodoListsTableTableManager get todoLists =>
      $$TodoListsTableTableManager(_db, _db.todoLists);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
}
