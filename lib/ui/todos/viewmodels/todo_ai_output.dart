// 待办 AI 输出的解析（纯函数，无 IO）：详情的“AI 拆解”（一行一步）与
// 快速新建的“AI 整理”（一行一个 JSON 对象）。
//
// 都是边收边解析：生成中只认已经收完的整行（最后一行可能只到一半，先不
// 出，免得预览里长出半句再变），结束时才连最后一行一起认。模型不一定听
// 话，所以逐行、逐字段校验：认不出的行、坏字段丢掉，不让整份结果作废。

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 一次最多给出几条建议（步骤还受 [TodoStep.maxSteps] 限制）。
const int kTodoAiMaxSuggestions = 20;

/// 生成中只取收完的整行；[complete] 时连最后一行一起。
List<String> _lines(String text, {required bool complete}) {
  final lines = text.split('\n');
  if (!complete) lines.removeLast();
  return lines;
}

/// 行首的编号、项目符号与勾选框（各自可有可无）。数字后的点不能再跟数字
/// （“1.5 公斤”不是编号），也不认冒号（“10:00 前出门”）。
final RegExp _bullet = RegExp(
  r'^(?:(?:[-*•·+]|\d{1,2}(?:[.．](?!\d)|[)、])|[（(]\d{1,2}[)）])\s*)?'
  r'(?:\[[ xX]?\]\s*)?',
);

/// 一行步骤：去掉编号、项目符号、勾选框与包住整行的粗体；空行、代码围栏、
/// `<text>` 标签与“以下是步骤：”这类引导句为 null。
String? _stepOf(String raw) {
  var line = raw.trim();
  if (line.isEmpty || line.startsWith('```') || line.startsWith('<')) {
    return null;
  }
  line = line.replaceFirst(_bullet, '').trim();
  for (final mark in const <String>['**', '__']) {
    if (line.length > 4 && line.startsWith(mark) && line.endsWith(mark)) {
      line = line.substring(2, line.length - 2).trim();
    }
  }
  if (line.isEmpty || line.endsWith(':') || line.endsWith('：')) return null;
  line = line.replaceAll(RegExp(r'\s+'), ' ');
  if (line.length > TodoStep.maxTitleLength) {
    line = line.substring(0, TodoStep.maxTitleLength);
  }
  return line;
}

/// 模型按行写的步骤 → 步骤标题：与 [existing]（已有步骤）及彼此重复的
/// 丢掉（不分大小写），至多 [max] 条。
List<String> parseTodoAiSteps(
  String text, {
  required bool complete,
  Iterable<String> existing = const <String>[],
  int max = kTodoAiMaxSuggestions,
}) {
  final seen = <String>{for (final title in existing) title.toLowerCase()};
  final out = <String>[];
  for (final raw in _lines(text, complete: complete)) {
    if (out.length >= max) break;
    final step = _stepOf(raw);
    if (step == null || !seen.add(step.toLowerCase())) continue;
    out.add(step);
  }
  return out;
}

/// AI 整理出的一条待办（预览里可改标题、去掉日期 / 清单 / 标签 / 优先级）。
@immutable
class TodoAiItem {
  const TodoAiItem({
    required this.title,
    this.date,
    this.minute,
    this.priority = TodoPriority.none,
    this.listId,
    this.tags = const <String>[],
  });

  /// 标题最长几个字（与快速新建的输入框同一上限）。
  static const int maxTitleLength = 500;

  final String title;

  /// 截止日（只有年月日）；null 为没有日期。
  final DateTime? date;

  /// 截止时刻（一天中的分钟数）；只在有 [date] 时有。
  final int? minute;
  final TodoPriority priority;

  /// 认出的清单（只认用户已有的清单）；null 时按面板上生效的清单。
  final String? listId;
  final List<String> tags;

  TodoAiItem copyWith({
    String? title,
    bool clearDate = false,
    TodoPriority? priority,
    bool clearList = false,
    List<String>? tags,
  }) => TodoAiItem(
    title: title ?? this.title,
    date: clearDate ? null : date,
    minute: clearDate ? null : minute,
    priority: priority ?? this.priority,
    listId: clearList ? null : listId,
    tags: tags ?? this.tags,
  );

  @override
  bool operator ==(Object other) =>
      other is TodoAiItem &&
      other.title == title &&
      other.date == date &&
      other.minute == minute &&
      other.priority == priority &&
      other.listId == listId &&
      listEquals(other.tags, tags);

  @override
  int get hashCode =>
      Object.hash(title, date, minute, priority, listId, Object.hashAll(tags));
}

/// 模型写的 JSON Lines → 待办，逐字段校验：
///
/// - `title` 必须是非空字符串，否则整条丢掉；
/// - `date` 只认合法的 `YYYY-MM-DD`，且在今天前后一年到十年内；
/// - `time` 只认 `HH:mm`，没有日期时不要；
/// - `priority` 只认 0–3 的整数或 none / low / medium / high；
/// - `list` 只认 [lists] 里已有的名字（不分大小写），认不出就不带；
/// - `tags` 经 [TodoTags.normalizeAll] 规整（待办标签，不是日记标签）。
///
/// 有的模型不听“一行一个”，把对象放进数组或分成多行写：结束时一条都没
/// 认出，就把全文当作数组（或 `{"todos": [...]}`）再试一次。
List<TodoAiItem> parseTodoAiItems(
  String text, {
  required bool complete,
  required List<TodoListRow> lists,
  required DateTime today,
  int max = kTodoAiMaxSuggestions,
}) {
  final out = <TodoAiItem>[];
  void add(Object? raw) {
    if (out.length >= max) return;
    final item = _itemOf(raw, lists: lists, today: today);
    if (item != null) out.add(item);
  }

  for (final raw in _lines(text, complete: complete)) {
    var line = raw.trim();
    if (line.startsWith('[')) line = line.substring(1).trim();
    if (line.endsWith(',')) line = line.substring(0, line.length - 1).trim();
    if (line.endsWith(']')) line = line.substring(0, line.length - 1).trim();
    if (!line.startsWith('{') || !line.endsWith('}')) continue;
    add(_decode(line));
  }
  if (complete && out.isEmpty) {
    final whole = _decode(_unfenced(text));
    final list = switch (whole) {
      final List<Object?> list => list,
      {'todos': final List<Object?> list} => list,
      _ => const <Object?>[],
    };
    list.forEach(add);
  }
  return out;
}

Object? _decode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

String _unfenced(String text) {
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  return (fence?.group(1) ?? text).trim();
}

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _clock = RegExp(r'^(\d{1,2}):(\d{2})$');

TodoAiItem? _itemOf(
  Object? raw, {
  required List<TodoListRow> lists,
  required DateTime today,
}) {
  if (raw is! Map) return null;
  final rawTitle = raw['title'];
  if (rawTitle is! String) return null;
  var title = rawTitle.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (title.isEmpty) return null;
  if (title.length > TodoAiItem.maxTitleLength) {
    title = title.substring(0, TodoAiItem.maxTitleLength);
  }
  final date = _dateOf(raw['date'], today);
  final tags = raw['tags'];
  return TodoAiItem(
    title: title,
    date: date,
    minute: date == null ? null : _minuteOf(raw['time']),
    priority: _priorityOf(raw['priority']),
    listId: _listOf(raw['list'], lists),
    tags: tags is List
        ? TodoTags.normalizeAll(tags.whereType<String>())
        : const <String>[],
  );
}

DateTime? _dateOf(Object? raw, DateTime today) {
  if (raw is! String) return null;
  final match = _isoDate.firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime 会把 2 月 30 日顺延成 3 月 2 日：对不上就是不存在的日子。
  if (date.month != month || date.day != day) return null;
  if (year < today.year - 1 || year > today.year + 10) return null;
  return date;
}

int? _minuteOf(Object? raw) {
  if (raw is! String) return null;
  final match = _clock.firstMatch(raw.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

TodoPriority _priorityOf(Object? raw) {
  if (raw is int && raw >= 0 && raw < TodoPriority.values.length) {
    return TodoPriority.values[raw];
  }
  if (raw is String) {
    for (final value in TodoPriority.values) {
      if (value.name == raw.trim().toLowerCase()) return value;
    }
  }
  return TodoPriority.none;
}

String? _listOf(Object? raw, List<TodoListRow> lists) {
  if (raw is! String) return null;
  final name = raw.trim().replaceFirst(RegExp(r'^[#＃]'), '').toLowerCase();
  if (name.isEmpty) return null;
  for (final list in lists) {
    if (list.name.trim().toLowerCase() == name) return list.listId;
  }
  return null;
}
