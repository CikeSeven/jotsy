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
          ..write('updatedAt: $updatedAt')
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
          other.updatedAt == this.updatedAt);
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
          ..write('updatedAt: $updatedAt')
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
    idxDiariesUpdatedAt,
    idxDiariesCreatedAt,
    idxDiariesCapsuleUnlockAt,
    idxDiariesActiveUpdated,
    idxDiariesActiveCreated,
    idxDiaryTagsTagId,
    idxDiaryNotebooksNotebook,
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
    aliasName: $_aliasNameGenerator(db.diaries.id, db.diaryTags.diaryId),
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
                  e.readTable(table),
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
                    await $_getPrefetchedData<Diary, $DiariesTable, DiaryTag>(
                      currentTable: table,
                      referencedTable: $$DiariesTableReferences
                          ._diaryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DiariesTableReferences(db, table, p0).diaryTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.diaryId == item.id),
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
    aliasName: $_aliasNameGenerator(db.tags.id, db.diaryTags.tagId),
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
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
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
                    await $_getPrefetchedData<Tag, $TagsTable, DiaryTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._diaryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).diaryTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
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

  static $DiariesTable _diaryIdTable(_$AppDatabase db) => db.diaries
      .createAlias($_aliasNameGenerator(db.diaryTags.diaryId, db.diaries.id));

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
      db.tags.createAlias($_aliasNameGenerator(db.diaryTags.tagId, db.tags.id));

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
                  e.readTable(table),
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
}
