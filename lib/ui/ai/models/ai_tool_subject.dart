// 工具调用“涉及的对象”：哪几篇日记、哪个日记本、哪些标签 / 待办 / 纪念日。
//
// 工具执行时顺手记下（数据都是现成的，不另查库），存进步骤记录
// （`AiAgentCallRecord.subjects`），界面据此：
// - 卡片标题写出具体对象（“新建待办「买牛奶」”“收进「旅行手记」”）；
// - 详情里列出可点的对象胶囊（点日记打开预览、点标签按标签搜索……）；
// - 参数里的 id 换成名字显示，绝不给用户看 UUID（[input] 为 true 的是参数
//   指向的对象，例如按某个日记本筛选，不算“结果”）。
//
// 名称是执行当时的快照；对象之后被改名、删除时，前往卡片另行实时解析。

import 'package:flutter/foundation.dart';

enum AiSubjectKind { diary, notebook, tag, todo, anniversary, day }

@immutable
class AiToolSubject {
  const AiToolSubject({
    required this.kind,
    required this.id,
    this.title = '',
    this.date,
    this.input = false,
  });

  const AiToolSubject.diary(
    String id, {
    required String title,
    required DateTime date,
    bool input = false,
  }) : this(
         kind: AiSubjectKind.diary,
         id: id,
         title: title,
         date: date,
         input: input,
       );

  const AiToolSubject.notebook(String id, String name, {bool input = false})
    : this(kind: AiSubjectKind.notebook, id: id, title: name, input: input);

  /// 标签以名称为 id（工具参数就是名称）。
  const AiToolSubject.tag(String name, {bool input = false})
    : this(kind: AiSubjectKind.tag, id: name, title: name, input: input);

  const AiToolSubject.todo(String id, String title, {DateTime? due})
    : this(kind: AiSubjectKind.todo, id: id, title: title, date: due);

  const AiToolSubject.anniversary(String id, String title, {DateTime? date})
    : this(kind: AiSubjectKind.anniversary, id: id, title: title, date: date);

  /// 某一天（日历、这天的心情）。
  AiToolSubject.day(DateTime day)
    : this(
        kind: AiSubjectKind.day,
        id: _isoDate(day),
        date: DateTime(day.year, day.month, day.day),
      );

  final AiSubjectKind kind;
  final String id;

  /// 显示名（执行时的快照）；日记没有标题时为空，界面改用日期。
  final String title;

  /// 日记的写作时间、待办的截止、纪念日的日期、某一天。
  final DateTime? date;

  /// 是参数指向的对象（筛选条件、要改的目标），不是查到的结果。
  final bool input;

  /// 一个调用最多存多少个（其余只记个数），控制步骤 JSON 的体积。
  static const int maxStored = 12;

  Map<String, Object?> toJson() => <String, Object?>{
    'k': kind.name,
    'id': id,
    if (title.isNotEmpty) 't': title,
    if (date case final value?) 'd': value.toIso8601String(),
    if (input) 'in': true,
  };

  static AiToolSubject? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    AiSubjectKind? kind;
    for (final value in AiSubjectKind.values) {
      if (value.name == raw['k']) kind = value;
    }
    if (kind == null) return null;
    final title = raw['t'];
    final date = raw['d'];
    return AiToolSubject(
      kind: kind,
      id: id,
      title: title is String ? title : '',
      date: date is String ? DateTime.tryParse(date) : null,
      input: raw['in'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiToolSubject &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.date == date &&
      other.input == input;

  @override
  int get hashCode => Object.hash(kind, id, title, date, input);
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
