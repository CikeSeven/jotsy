// 一次对话从哪些日记里找材料（存进 `ai_conversations.scope` 的 JSON）。
//
// - auto：按 AI 设置里的检索方式（智能 / 关键词 / 最近 N 天）；
// - recent：最近 [AiChatScope.days] 天；
// - all：全部日记（仍按关键词挑最相关的，放不下的不放）；
// - range：[AiChatScope.start] 到 [AiChatScope.end]（含首尾两天）；
// - diary：固定一篇日记（预览页“继续聊聊”），只存业务 id 与标题快照。
//
// 不论哪种，多篇上下文都经 `getAiContextDiaries`（排除私密与回收站等）；
// 固定的那一篇按单篇功能的口径（私密日记只在用户允许时）。

import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AiChatScopeKind { auto, recent, all, range, diary }

@immutable
class AiChatScope {
  const AiChatScope.auto()
    : kind = AiChatScopeKind.auto,
      days = 0,
      start = null,
      end = null,
      diaryId = null,
      diaryTitle = null;

  const AiChatScope.recent(this.days)
    : kind = AiChatScopeKind.recent,
      start = null,
      end = null,
      diaryId = null,
      diaryTitle = null;

  const AiChatScope.all()
    : kind = AiChatScopeKind.all,
      days = 0,
      start = null,
      end = null,
      diaryId = null,
      diaryTitle = null;

  /// [start] / [end] 为两头的日期（含），存本地零点。
  AiChatScope.range(DateTime first, DateTime last)
    : kind = AiChatScopeKind.range,
      days = 0,
      start = DateTime(first.year, first.month, first.day),
      end = DateTime(last.year, last.month, last.day),
      diaryId = null,
      diaryTitle = null;

  const AiChatScope.diary({required String this.diaryId, this.diaryTitle})
    : kind = AiChatScopeKind.diary,
      days = 0,
      start = null,
      end = null;

  /// “最近 N 天”的可选值。
  static const List<int> recentChoices = <int>[7, 30, 90, 365];

  final AiChatScopeKind kind;
  final int days;
  final DateTime? start;
  final DateTime? end;
  final String? diaryId;
  final String? diaryTitle;

  String encode() => jsonEncode(<String, Object?>{
    'kind': kind.name,
    if (kind == AiChatScopeKind.recent) 'days': days,
    if (start != null) 'start': start!.millisecondsSinceEpoch,
    if (end != null) 'end': end!.millisecondsSinceEpoch,
    'diaryId': ?diaryId,
    'diaryTitle': ?diaryTitle,
  });

  /// 从存储读回：认不出或缺字段时为 auto。
  static AiChatScope decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const AiChatScope.auto();
      switch (json['kind']) {
        case 'recent':
          final days = json['days'];
          return days is int && days > 0
              ? AiChatScope.recent(days)
              : const AiChatScope.auto();
        case 'all':
          return const AiChatScope.all();
        case 'range':
          final start = json['start'];
          final end = json['end'];
          if (start is int && end is int) {
            return AiChatScope.range(
              DateTime.fromMillisecondsSinceEpoch(start),
              DateTime.fromMillisecondsSinceEpoch(end),
            );
          }
        case 'diary':
          final id = json['diaryId'];
          final title = json['diaryTitle'];
          if (id is String && id.isNotEmpty) {
            return AiChatScope.diary(
              diaryId: id,
              diaryTitle: title is String ? title : null,
            );
          }
      }
    } on FormatException {
      // 落到下面。
    }
    return const AiChatScope.auto();
  }

  @override
  bool operator ==(Object other) =>
      other is AiChatScope &&
      other.kind == kind &&
      other.days == days &&
      other.start == start &&
      other.end == end &&
      other.diaryId == diaryId;

  @override
  int get hashCode => Object.hash(kind, days, start, end, diaryId);
}
