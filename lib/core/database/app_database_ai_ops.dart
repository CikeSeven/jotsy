part of 'app_database.dart';

/// 一次对话连同它的全部消息（删除对话的撤销用）。
class AiConversationSnapshot {
  const AiConversationSnapshot(this.conversation, this.messages);

  final AiConversationRow conversation;
  final List<AiMessageRow> messages;
}

/// AI 记录（对话、消息、回应、回顾）的读写。
///
/// 输入：对话页、预览页回应区、回顾页与设置页的读写；输出：drift watch
/// 流与一次性读取。删除是硬删除，撤销由调用方持有被删的整行、经
/// `restore*` 原样写回（与留言同一做法）。
///
/// 这些表不参与局域网同步，写入不必登记编辑会话；读取回应时不过滤私密：
/// 调用方（预览页）已经拿到了这篇日记，说明它来自允许看到它的范围。
mixin _AppDatabaseAiOps on _$AppDatabase {
  // ---------------------------------------------------------------- 对话

  /// 全部对话：置顶在前，其余按最近更新排序；[query] 非空时按标题或消息
  /// 内容匹配（LIKE，不区分大小写的 ASCII）。
  Stream<List<AiConversationRow>> watchAiConversations({String query = ''}) {
    final trimmed = query.trim();
    final select = this.select(aiConversations);
    if (trimmed.isNotEmpty) {
      final pattern = '%${_escapeAiLike(trimmed)}%';
      select.where(
        (t) =>
            t.title.like(pattern, escapeChar: r'\') |
            t.conversationId.isInQuery(
              selectOnly(aiMessages)
                ..addColumns(<Expression<Object>>[aiMessages.conversationId])
                ..where(aiMessages.content.like(pattern, escapeChar: r'\')),
            ),
      );
    }
    select.orderBy(<OrderClauseGenerator<$AiConversationsTable>>[
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return select.watch();
  }

  Stream<AiConversationRow?> watchAiConversation(String conversationId) {
    return (select(aiConversations)
          ..where((t) => t.conversationId.equals(conversationId)))
        .watchSingleOrNull();
  }

  Future<AiConversationRow?> getAiConversation(String conversationId) {
    return (select(
      aiConversations,
    )..where((t) => t.conversationId.equals(conversationId))).getSingleOrNull();
  }

  /// 新建一次对话，返回它的业务 id。
  Future<String> createAiConversation({
    String title = '',
    String? personaId,
    String scopeJson = '{}',
    DateTime? now,
  }) async {
    final id = _newBusinessUuid();
    final time = now ?? DateTime.now();
    await into(aiConversations).insert(
      AiConversationsCompanion.insert(
        conversationId: id,
        title: Value(title),
        personaId: Value(personaId),
        scope: Value(scopeJson),
        createdAt: time,
        updatedAt: time,
      ),
    );
    return id;
  }

  /// 改写对话的标题、人设、范围或置顶。改名与置顶不刷新更新时间（不让它
  /// 跳到列表最前），换人设与范围算一次活动。
  Future<void> updateAiConversation(
    String conversationId, {
    String? title,
    Object? personaId = _aiUnset,
    String? scopeJson,
    bool? pinned,
  }) {
    final touches = scopeJson != null || !identical(personaId, _aiUnset);
    return (update(
      aiConversations,
    )..where((t) => t.conversationId.equals(conversationId))).write(
      AiConversationsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        personaId: identical(personaId, _aiUnset)
            ? const Value.absent()
            : Value(personaId as String?),
        scope: scopeJson == null ? const Value.absent() : Value(scopeJson),
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        updatedAt: touches ? Value(DateTime.now()) : const Value.absent(),
      ),
    );
  }

  /// 删除对话与它的消息，返回整份快照（供撤销）；不存在时返回 null。
  Future<AiConversationSnapshot?> deleteAiConversation(String conversationId) {
    return transaction(() async {
      final row = await getAiConversation(conversationId);
      if (row == null) return null;
      final messages = await (select(
        aiMessages,
      )..where((t) => t.conversationId.equals(conversationId))).get();
      await (delete(
        aiMessages,
      )..where((t) => t.conversationId.equals(conversationId))).go();
      await (delete(aiConversations)..where((t) => t.id.equals(row.id))).go();
      return AiConversationSnapshot(row, messages);
    });
  }

  /// 撤销删除对话：原样写回对话与消息。
  Future<void> restoreAiConversation(AiConversationSnapshot snapshot) {
    return transaction(() async {
      await into(
        aiConversations,
      ).insertOnConflictUpdate(snapshot.conversation.toCompanion(false));
      for (final message in snapshot.messages) {
        await into(
          aiMessages,
        ).insertOnConflictUpdate(message.toCompanion(false));
      }
    });
  }

  // ---------------------------------------------------------------- 消息

  /// 某次对话的消息，按时间旧 → 新。
  Stream<List<AiMessageRow>> watchAiMessages(String conversationId) {
    return (select(aiMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy(<OrderClauseGenerator<$AiMessagesTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Future<List<AiMessageRow>> getAiMessages(String conversationId) {
    return (select(aiMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy(<OrderClauseGenerator<$AiMessagesTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// 追加一条消息并刷新对话的更新时间，返回消息的业务 id。
  Future<String> addAiMessage({
    required String conversationId,
    required String role,
    required String content,
    String reasoning = '',
    String citationsJson = '[]',
    String metaJson = '{}',
    String status = AiMessageStatus.done,
    DateTime? now,
  }) {
    final id = _newBusinessUuid();
    final time = now ?? DateTime.now();
    return transaction(() async {
      await into(aiMessages).insert(
        AiMessagesCompanion.insert(
          messageId: id,
          conversationId: conversationId,
          role: role,
          content: Value(content),
          reasoning: Value(reasoning),
          citations: Value(citationsJson),
          meta: Value(metaJson),
          status: Value(status),
          createdAt: time,
        ),
      );
      await (update(aiConversations)
            ..where((t) => t.conversationId.equals(conversationId)))
          .write(AiConversationsCompanion(updatedAt: Value(time)));
      return id;
    });
  }

  /// 改写一条消息（流式生成结束时写入最终内容与状态）。
  Future<void> updateAiMessage(
    String messageId, {
    String? content,
    String? reasoning,
    String? citationsJson,
    String? metaJson,
    String? status,
  }) {
    return (update(
      aiMessages,
    )..where((t) => t.messageId.equals(messageId))).write(
      AiMessagesCompanion(
        content: content == null ? const Value.absent() : Value(content),
        reasoning: reasoning == null ? const Value.absent() : Value(reasoning),
        citations: citationsJson == null
            ? const Value.absent()
            : Value(citationsJson),
        meta: metaJson == null ? const Value.absent() : Value(metaJson),
        status: status == null ? const Value.absent() : Value(status),
      ),
    );
  }

  /// 删除一组消息（重新生成、编辑重发时删掉它们之后的回答）。
  Future<void> deleteAiMessages(Iterable<String> messageIds) {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return Future<void>.value();
    return (delete(aiMessages)..where((t) => t.messageId.isIn(ids))).go();
  }

  // ---------------------------------------------------------------- 结果

  /// 写一份回应或回顾，返回业务 id。
  Future<String> addAiResult({
    required String kind,
    required String content,
    String? diaryId,
    DateTime? periodStart,
    DateTime? periodEnd,
    String scopeJson = '{}',
    String title = '',
    String? personaId,
    String metaJson = '{}',
    DateTime? now,
  }) async {
    final id = _newBusinessUuid();
    await into(aiResults).insert(
      AiResultsCompanion.insert(
        resultId: id,
        kind: kind,
        content: content,
        diaryId: Value(diaryId),
        periodStart: Value(periodStart),
        periodEnd: Value(periodEnd),
        scope: Value(scopeJson),
        title: Value(title),
        personaId: Value(personaId),
        meta: Value(metaJson),
        createdAt: now ?? DateTime.now(),
      ),
    );
    return id;
  }

  /// 某篇日记的读后回应，按时间旧 → 新。
  Stream<List<AiResultRow>> watchAiRepliesForDiary(String diaryId) {
    return (select(aiResults)
          ..where(
            (t) =>
                t.kind.equals(AiResultKind.reply) & t.diaryId.equals(diaryId),
          )
          ..orderBy(<OrderClauseGenerator<$AiResultsTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// 最近的回顾（新 → 旧）。
  Stream<List<AiResultRow>> watchAiRecaps({int? limit}) {
    final query = select(aiResults)
      ..where((t) => t.kind.equals(AiResultKind.recap))
      ..orderBy(<OrderClauseGenerator<$AiResultsTable>>[
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  Stream<AiResultRow?> watchAiResult(String resultId) {
    return (select(
      aiResults,
    )..where((t) => t.resultId.equals(resultId))).watchSingleOrNull();
  }

  /// 删除并返回被删的整行（供撤销）；不存在时返回 null。
  Future<AiResultRow?> deleteAiResult(String resultId) {
    return transaction(() async {
      final row = await (select(
        aiResults,
      )..where((t) => t.resultId.equals(resultId))).getSingleOrNull();
      if (row != null) {
        await (delete(aiResults)..where((t) => t.id.equals(row.id))).go();
      }
      return row;
    });
  }

  Future<void> restoreAiResult(AiResultRow row) {
    return into(aiResults).insertOnConflictUpdate(row.toCompanion(false));
  }

  // ---------------------------------------------------------------- 整体

  /// 三张表的总条数（设置页“清除全部 AI 记录”的说明用）。
  Stream<int> watchAiRecordCount() {
    return customSelect(
      'SELECT (SELECT COUNT(*) FROM ai_conversations) + '
      '(SELECT COUNT(*) FROM ai_results) AS n',
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
        aiConversations,
        aiResults,
      },
    ).watchSingle().map((row) => row.read<int>('n'));
  }

  /// 清除全部 AI 记录（不可撤销，调用方先确认）。
  Future<void> clearAllAiRecords() {
    return transaction(() async {
      await delete(aiMessages).go();
      await delete(aiConversations).go();
      await delete(aiResults).go();
    });
  }
}

const Object _aiUnset = Object();

String _escapeAiLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
