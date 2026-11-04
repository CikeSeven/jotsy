import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 首页“日记”页上次所在的范围，存在本机偏好 `app.settings.home_last_scope`
/// （冷启动时由 `homeNotebookScopeRestoreProvider` 恢复）。
///
/// 只记范围本身（哪本日记本、哪一章、或“未收录”），不记临时排序与上锁
/// 会话：这些在恢复时按当时的书架重新判断。全部日记不写键（见 [encode]）。
///
/// 格式为 JSON 对象，逐字段容错：
/// - `{"unfiled": true}`：未收录；
/// - `{"notebook": "<业务 id>"}`，可带 `"chapter": "<章节 id>"` 或
///   `"unassigned": true`（未分章）；
/// - 其余（空、不是对象、`notebook` 不是非空字符串）一律按全部日记处理。
@immutable
class HomeNotebookScopeMemory {
  const HomeNotebookScopeMemory.notebook(
    String this.notebookId, {
    this.chapterId,
    this.unassignedChapterOnly = false,
  }) : unfiled = false;

  const HomeNotebookScopeMemory.unfiled()
    : notebookId = null,
      chapterId = null,
      unassignedChapterOnly = false,
      unfiled = true;

  /// 日记本的业务 id；未收录时为 null。
  final String? notebookId;
  final bool unfiled;
  final String? chapterId;
  final bool unassignedChapterOnly;

  /// 解析存储的原文；认不出时为 null（按全部日记处理）。
  static HomeNotebookScopeMemory? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    if (json['unfiled'] == true) return const HomeNotebookScopeMemory.unfiled();
    final notebookId = _nonEmpty(json['notebook']);
    if (notebookId == null) return null;
    final chapterId = _nonEmpty(json['chapter']);
    return HomeNotebookScopeMemory.notebook(
      notebookId,
      chapterId: chapterId,
      unassignedChapterOnly: chapterId == null && json['unassigned'] == true,
    );
  }

  /// 全部日记（[notebookId] 为 null 且不在未收录）返回 null，调用方据此
  /// 删除键。
  static String? encode({
    String? notebookId,
    bool unfiled = false,
    String? chapterId,
    bool unassignedChapterOnly = false,
  }) {
    if (notebookId != null) {
      return jsonEncode(<String, Object>{
        'notebook': notebookId,
        if (chapterId != null)
          'chapter': chapterId
        else if (unassignedChapterOnly)
          'unassigned': true,
      });
    }
    return unfiled ? jsonEncode(const <String, Object>{'unfiled': true}) : null;
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  @override
  bool operator ==(Object other) =>
      other is HomeNotebookScopeMemory &&
      other.notebookId == notebookId &&
      other.unfiled == unfiled &&
      other.chapterId == chapterId &&
      other.unassignedChapterOnly == unassignedChapterOnly;

  @override
  int get hashCode =>
      Object.hash(notebookId, unfiled, chapterId, unassignedChapterOnly);
}
