import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';

/// 日记本的类型，按 [Enum.name] 存在 `notebooks.kind` 列。
///
/// - [manual]：用户手动把日记放进来，成员关系存在 `diary_notebooks` 表；
/// - [smart]：按规则自动收录，成员由 SQL 现算，不写关联行。
enum NotebookKind {
  manual,
  smart;

  /// 认不出的值（损坏数据或更新版本写入的新类型）按手动日记本解读，界面至少
  /// 能显示出来；写入成员关系仍以列的原始值为准（见日记本成员操作）。
  static NotebookKind fromName(String? name) =>
      values.asNameMap()[name] ?? manual;
}

/// 日记本的可见性，按 [Enum.name] 存在 `notebooks.visibility` 列。
///
/// - [normal]：本子里的日记照常出现在“全部日记”里；
/// - [hidden]：本子里的日记不出现在“全部日记”里；
/// - [locked]：在 [hidden] 之上，打开本子还要先通过设备验证。
///
/// 只有手动日记本可以设为私密，智能日记本始终是 [normal]。
enum NotebookVisibility {
  normal,
  hidden,
  locked;

  /// 缺省（null）按 [normal]；认不出的值（更新版本写入的新可见性）按最严格
  /// 的 [locked] 解读，与 SQL 私密排除“不等于 normal 即私密”的口径一致：
  /// 宁可多问一次验证，也不把私密本当普通本打开。
  static NotebookVisibility fromName(String? name) {
    if (name == null) return normal;
    return values.asNameMap()[name] ?? locked;
  }
}

/// 日记本内的排序方式；[book] 为目录页手动排好的“成书顺序”。
enum NotebookSort { createdDesc, createdAsc, updatedDesc, book }

/// 写作目标的统计周期。
enum NotebookGoalPeriod { day, week, month }

/// 手动日记本的一个章节（只有一级）。
///
/// [id] 是本子内唯一的短随机串，`diary_notebooks.chapter_id` 引用它；标题改名
/// 不影响归属。章节顺序即 [NotebookPayload.chapters] 的列表顺序。
@immutable
class NotebookChapter {
  const NotebookChapter._(this.id, this.title);

  /// 标题去掉首尾空白后截到 [maxTitleLength] 个字符；[id] 或标题为空时抛
  /// [ArgumentError]（界面层应先校验输入）。
  factory NotebookChapter({required String id, required String title}) {
    final chapter = tryCreate(id: id, title: title);
    if (chapter == null) {
      throw ArgumentError('章节 id 与标题都不能为空');
    }
    return chapter;
  }

  /// 用新生成的 id 建一个章节。
  factory NotebookChapter.create(String title) =>
      NotebookChapter(id: newId(), title: title);

  static const int maxTitleLength = 40;

  final String id;
  final String title;

  /// 与默认构造相同的规整，但不合法时返回 null 而不是抛异常（解码用）。
  static NotebookChapter? tryCreate({
    required String id,
    required String title,
  }) {
    final normalizedId = id.trim();
    final normalizedTitle = _truncateRunes(title.trim(), maxTitleLength);
    if (normalizedId.isEmpty || normalizedTitle.isEmpty) return null;
    return NotebookChapter._(normalizedId, normalizedTitle);
  }

  /// 8 位小写字母数字的随机 id：只需在一个本子的几十个章节里不重复，用不着
  /// UUID 那么长，payload 与关联行都更短。
  static String newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(
        8,
        (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ),
    );
  }

  static NotebookChapter? _fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;
    return tryCreate(id: id, title: title);
  }

  Map<String, Object> _toJson() => <String, Object>{'id': id, 'title': title};

  NotebookChapter withTitle(String title) =>
      NotebookChapter(id: id, title: title);

  @override
  bool operator ==(Object other) =>
      other is NotebookChapter && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'NotebookChapter($id, $title)';
}

/// 写作目标：每 [period] 写 [target] 篇。
@immutable
class NotebookGoal {
  const NotebookGoal._(this.period, this.target);

  /// [target] 夹到 [minTarget]..[maxTarget]。
  factory NotebookGoal({
    required NotebookGoalPeriod period,
    required int target,
  }) => NotebookGoal._(period, target.clamp(minTarget, maxTarget));

  static const int minTarget = 1;
  static const int maxTarget = 20;

  final NotebookGoalPeriod period;
  final int target;

  static NotebookGoal? _fromJson(Object? json) {
    if (json is! Map) return null;
    final period = NotebookGoalPeriod.values.asNameMap()[json['period']];
    final target = json['target'];
    // 数字可能被其他实现写成 3.0，按整数接受；周期认不出就整个目标作废，
    // 不猜一个周期出来。
    if (period == null || target is! num || target != target.roundToDouble()) {
      return null;
    }
    return NotebookGoal(period: period, target: target.toInt());
  }

  Map<String, Object> _toJson() => <String, Object>{
    'period': period.name,
    'target': target,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookGoal && other.period == period && other.target == target;

  @override
  int get hashCode => Object.hash(period, target);
}

/// 日记本 `payload` 列里的全部可演进设置（名称、类型、可见性、置顶、合上
/// 这些需要 SQL 过滤或排序的字段是独立列，不在这里）。
///
/// 格式：`{"desc":"…","icon":"book","color":4283215696,"cover":"/…/x.jpg",
/// "chapters":[{"id":"a1b2c3d4","title":"第一章"}],"sort":"book",
/// "goal":{"period":"week","target":3},"template":"<模板 id>","rules":{…}}`。
/// 稀疏写入：空值与默认值不写，默认设置编码为 `{}`（与列默认值一致）。
/// 逐字段容错：坏 JSON 回退全部默认值，单个字段类型不符只丢弃该字段，不连累
/// 其他字段；章节里坏掉或重复 id 的条目单独丢弃（同 id 保留先出现的）。
///
/// [rules] 是智能日记本的规则原文，由规则编译器解释，这里原样保留，保证旧版本
/// 读写一遍不会丢掉新版本写入的规则字段。
@immutable
class NotebookPayload {
  const NotebookPayload._({
    this.description = '',
    this.icon,
    this.color,
    this.coverPath,
    this.chapters = const <NotebookChapter>[],
    this.sort = NotebookSort.createdDesc,
    this.goal,
    this.templateId,
    this.rules,
  });

  /// 构造时统一规整：简介去首尾空白并截到 [maxDescriptionLength]，空字符串的
  /// 可空字段视为未设置，章节按 id 去重（保留先出现的）。
  factory NotebookPayload({
    String description = '',
    String? icon,
    int? color,
    String? coverPath,
    List<NotebookChapter> chapters = const <NotebookChapter>[],
    NotebookSort sort = NotebookSort.createdDesc,
    NotebookGoal? goal,
    String? templateId,
    Map<String, Object?>? rules,
  }) {
    final seen = <String>{};
    return NotebookPayload._(
      description: _truncateRunes(description.trim(), maxDescriptionLength),
      icon: _nonEmpty(icon),
      color: color != null && color >= 0 && color <= 0xFFFFFFFF ? color : null,
      coverPath: _nonEmpty(coverPath),
      chapters: List<NotebookChapter>.unmodifiable(<NotebookChapter>[
        for (final chapter in chapters)
          if (seen.add(chapter.id)) chapter,
      ]),
      sort: sort,
      goal: goal,
      templateId: _nonEmpty(templateId),
      rules: rules == null ? null : Map<String, Object?>.unmodifiable(rules),
    );
  }

  static const NotebookPayload defaults = NotebookPayload._();
  static const int maxDescriptionLength = 120;

  /// 简介，最长 [maxDescriptionLength] 个字符，未填为空字符串。
  final String description;

  /// 界面图标枚举的名字；数据库层不解释它，认不出的名字由界面回退默认图标。
  final String? icon;

  /// 主题色（ARGB）。
  final int? color;

  /// 封面图片路径（应用私有目录内）。
  final String? coverPath;

  /// 章节，列表顺序即章节顺序；只对手动日记本有意义。
  final List<NotebookChapter> chapters;

  /// 本子内的日记排序方式。
  final NotebookSort sort;

  /// 写作目标；null 表示没有目标。
  final NotebookGoal? goal;

  /// 在本子里新建日记时默认套用的模板 id。
  final String? templateId;

  /// 智能日记本的规则原文（见类注释）。
  final Map<String, Object?>? rules;

  /// 章节 id 集合，便于判断某个 `chapter_id` 是否仍然有效。
  Set<String> get chapterIds => <String>{
    for (final chapter in chapters) chapter.id,
  };

  static NotebookPayload decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (json is! Map) return defaults;
    final description = json['desc'];
    final icon = json['icon'];
    final color = json['color'];
    final cover = json['cover'];
    final chapters = json['chapters'];
    final template = json['template'];
    final rules = json['rules'];
    return NotebookPayload(
      description: description is String ? description : '',
      icon: icon is String ? icon : null,
      color: color is int ? color : null,
      coverPath: cover is String ? cover : null,
      chapters: <NotebookChapter>[
        if (chapters is List)
          for (final item in chapters) ?NotebookChapter._fromJson(item),
      ],
      sort:
          NotebookSort.values.asNameMap()[json['sort']] ??
          NotebookSort.createdDesc,
      goal: NotebookGoal._fromJson(json['goal']),
      templateId: template is String ? template : null,
      rules: rules is Map
          ? <String, Object?>{
              for (final entry in rules.entries)
                if (entry.key is String) entry.key as String: entry.value,
            }
          : null,
    );
  }

  /// 编码为稀疏 JSON；默认设置得到 `{}`。
  String encode() => jsonEncode(<String, Object?>{
    if (description.isNotEmpty) 'desc': description,
    'icon': ?icon,
    'color': ?color,
    'cover': ?coverPath,
    if (chapters.isNotEmpty)
      'chapters': <Map<String, Object>>[
        for (final chapter in chapters) chapter._toJson(),
      ],
    if (sort != NotebookSort.createdDesc) 'sort': sort.name,
    'goal': ?goal?._toJson(),
    'template': ?templateId,
    'rules': ?rules,
  });

  /// 可空字段传 null 表示“不改”，要清空时用对应的 `clear*` 开关。
  NotebookPayload copyWith({
    String? description,
    String? icon,
    bool clearIcon = false,
    int? color,
    bool clearColor = false,
    String? coverPath,
    bool clearCoverPath = false,
    List<NotebookChapter>? chapters,
    NotebookSort? sort,
    NotebookGoal? goal,
    bool clearGoal = false,
    String? templateId,
    bool clearTemplateId = false,
    Map<String, Object?>? rules,
    bool clearRules = false,
  }) {
    return NotebookPayload(
      description: description ?? this.description,
      icon: clearIcon ? null : icon ?? this.icon,
      color: clearColor ? null : color ?? this.color,
      coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
      chapters: chapters ?? this.chapters,
      sort: sort ?? this.sort,
      goal: clearGoal ? null : goal ?? this.goal,
      templateId: clearTemplateId ? null : templateId ?? this.templateId,
      rules: clearRules ? null : rules ?? this.rules,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotebookPayload &&
      other.description == description &&
      other.icon == icon &&
      other.color == color &&
      other.coverPath == coverPath &&
      _listEquals(other.chapters, chapters) &&
      other.sort == sort &&
      other.goal == goal &&
      other.templateId == templateId &&
      _jsonEquals(other.rules, rules);

  @override
  int get hashCode => Object.hash(
    description,
    icon,
    color,
    coverPath,
    Object.hashAll(chapters),
    sort,
    goal,
    templateId,
    _jsonHash(rules),
  );
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// 按 Unicode 码点截断，避免把表情等代理对切成半个字符。
String _truncateRunes(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  final runes = value.runes;
  if (runes.length <= maxLength) return value;
  return String.fromCharCodes(runes.take(maxLength));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 规则原文是 JSON 树：Map 按键比较（与键顺序无关），List 按顺序比较。
bool _jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// 与 [_jsonEquals] 一致的哈希：Map 的键值对无序合并。
int _jsonHash(Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(<int>[
      for (final entry in value.entries)
        Object.hash(entry.key, _jsonHash(entry.value)),
    ]);
  }
  if (value is List) return Object.hashAll(value.map(_jsonHash));
  return value.hashCode;
}
