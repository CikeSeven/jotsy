import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'diary_list_scope.dart';

/// 智能日记本的规则：模型、JSON 编解码与 SQL 编译（纯函数，无 IO）。
///
/// 存在 `NotebookPayload.rules` 里，格式：
/// `{"match":"all","rules":[{"type":"tags","mode":"any","names":["旅行"]}, …]}`。
///
/// 规则类型（`type`）：
/// - `tags {mode: any|all|none, names}`：按标签**名称**（合并导入会按名称重映射
///   标签，本地 id 不可靠，所以从不存 id）；
/// - `mood {emojis}`：心情是其中之一；
/// - `weather {contains}` / `location {contains}`：天气 / 地点包含某段文字（忽略
///   ASCII 大小写）；
/// - `keyword {text}`：标题或正文包含某段文字；
/// - `date {kind, …}`：`between {from,to}`（本地日期，含首尾）、`lastDays {days}`、
///   `thisYear`、`monthEveryYear {month}`、`dayEveryYear`（与今天同月同日）；
/// - `media {kind: image|audio|video|attachment}`：正文里有这类嵌入；
/// - `flag {kind: hasCover|pinned}`。
///
/// 容错：单条规则坏了（缺字段、类型不符、新版本的未知类型）解码为
/// [NotebookUnknownRule] 并保留原文，旧版本读写一遍不会丢掉新版本的规则；
/// 它编译为“什么都不匹配”。不提供字数规则：字数口径（DESIGN.md §3.3）无法在
/// SQL 里计算。

/// 多条规则的组合方式：全部满足（AND）或任一满足（OR）。
enum NotebookRuleMatch { all, any }

/// 规则集：组合方式 + 至多 [maxRules] 条规则。
@immutable
class NotebookRuleSet {
  NotebookRuleSet({
    this.match = NotebookRuleMatch.all,
    List<NotebookRule> rules = const <NotebookRule>[],
  }) : rules = List<NotebookRule>.unmodifiable(rules.take(maxRules));

  static const int maxRules = 12;

  final NotebookRuleMatch match;
  final List<NotebookRule> rules;

  bool get isEmpty => rules.isEmpty;

  /// 解码 payload 里的规则原文；null 或不是对象时为空规则集。认不出的
  /// `match` 按更严格的 [NotebookRuleMatch.all] 解读。
  static NotebookRuleSet decode(Map<String, Object?>? json) {
    if (json == null) return NotebookRuleSet();
    final rawRules = json['rules'];
    return NotebookRuleSet(
      match:
          NotebookRuleMatch.values.asNameMap()[json['match']] ??
          NotebookRuleMatch.all,
      rules: <NotebookRule>[
        if (rawRules is List)
          for (final raw in rawRules) NotebookRule.fromJson(raw),
      ],
    );
  }

  Map<String, Object?> encode() => <String, Object?>{
    'match': match.name,
    'rules': <Map<String, Object?>>[for (final rule in rules) rule.toJson()],
  };

  NotebookRuleSet copyWith({
    NotebookRuleMatch? match,
    List<NotebookRule>? rules,
  }) => NotebookRuleSet(match: match ?? this.match, rules: rules ?? this.rules);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NotebookRuleSet ||
        other.match != match ||
        other.rules.length != rules.length) {
      return false;
    }
    for (var i = 0; i < rules.length; i++) {
      if (other.rules[i] != rules[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(match, Object.hashAll(rules));
}

/// 一条规则。子类各自实现值相等，规则集可直接比较“有没有改动”。
@immutable
sealed class NotebookRule {
  const NotebookRule();

  /// JSON 里的 `type`。
  String get type;

  Map<String, Object?> toJson();

  /// 解码一条规则；任何不合法的输入都得到 [NotebookUnknownRule]。
  static NotebookRule fromJson(Object? json) {
    if (json is! Map) {
      return NotebookUnknownRule(const <String, Object?>{});
    }
    final map = <String, Object?>{
      for (final entry in json.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final rule = switch (map['type']) {
      'tags' => NotebookTagsRule._fromJson(map),
      'mood' => NotebookMoodRule._fromJson(map),
      'weather' => NotebookTextRule._fromJson(NotebookTextField.weather, map),
      'location' => NotebookTextRule._fromJson(NotebookTextField.location, map),
      'keyword' => NotebookTextRule._fromJson(NotebookTextField.keyword, map),
      'date' => NotebookDateRule._fromJson(map),
      'media' => NotebookMediaRule._fromJson(map),
      'flag' => NotebookFlagRule._fromJson(map),
      _ => null,
    };
    return rule ?? NotebookUnknownRule(map);
  }
}

/// 标签规则的匹配方式：含任一 / 全部都含 / 都不含。
enum NotebookTagMatch { any, all, none }

final class NotebookTagsRule extends NotebookRule {
  /// [names] 去首尾空白、去空、去重（保留先出现的）。
  NotebookTagsRule({required this.mode, required Iterable<String> names})
    : names = _cleanStrings(names);

  final NotebookTagMatch mode;
  final List<String> names;

  @override
  String get type => 'tags';

  static NotebookTagsRule? _fromJson(Map<String, Object?> json) {
    final mode = NotebookTagMatch.values.asNameMap()[json['mode']];
    final names = _stringList(json['names']);
    if (mode == null || names == null) return null;
    final rule = NotebookTagsRule(mode: mode, names: names);
    return rule.names.isEmpty ? null : rule;
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'mode': mode.name,
    'names': names,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookTagsRule &&
      other.mode == mode &&
      _listEquals(other.names, names);

  @override
  int get hashCode => Object.hash(type, mode, Object.hashAll(names));
}

final class NotebookMoodRule extends NotebookRule {
  NotebookMoodRule({required Iterable<String> emojis})
    : emojis = _cleanStrings(emojis);

  final List<String> emojis;

  @override
  String get type => 'mood';

  static NotebookMoodRule? _fromJson(Map<String, Object?> json) {
    final emojis = _stringList(json['emojis']);
    if (emojis == null) return null;
    final rule = NotebookMoodRule(emojis: emojis);
    return rule.emojis.isEmpty ? null : rule;
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'emojis': emojis,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookMoodRule && _listEquals(other.emojis, emojis);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(emojis));
}

/// 文字包含类规则针对的字段；枚举名即 JSON 的 `type`。
enum NotebookTextField { weather, location, keyword }

/// 天气 / 地点 / 关键词包含一段文字。JSON 字段名沿用各自的约定：天气与地点
/// 为 `contains`，关键词为 `text`。
final class NotebookTextRule extends NotebookRule {
  NotebookTextRule({required this.field, required String text})
    : text = text.trim();

  final NotebookTextField field;
  final String text;

  @override
  String get type => field.name;

  String get _jsonKey => _keyFor(field);

  static String _keyFor(NotebookTextField field) =>
      field == NotebookTextField.keyword ? 'text' : 'contains';

  static NotebookTextRule? _fromJson(
    NotebookTextField field,
    Map<String, Object?> json,
  ) {
    final text = json[_keyFor(field)];
    if (text is! String || text.trim().isEmpty) return null;
    return NotebookTextRule(field: field, text: text);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    _jsonKey: text,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookTextRule && other.field == field && other.text == text;

  @override
  int get hashCode => Object.hash(field, text);
}

/// 日期规则的种类。
enum NotebookDateKind {
  between,
  lastDays,
  thisYear,
  monthEveryYear,
  dayEveryYear,
}

/// 按发表时间（`created_at`）筛选。相对的种类（最近 N 天、今年、今天这一天）
/// 在编译时按“今天”算出边界。
final class NotebookDateRule extends NotebookRule {
  const NotebookDateRule._(
    this.kind, {
    this.from,
    this.to,
    this.days,
    this.month,
  });

  /// 固定区间（本地日期，含首尾）；[from] 晚于 [to] 时自动交换。
  factory NotebookDateRule.between(DateTime from, DateTime to) {
    final a = _dateOnly(from);
    final b = _dateOnly(to);
    return NotebookDateRule._(
      NotebookDateKind.between,
      from: a.isAfter(b) ? b : a,
      to: a.isAfter(b) ? a : b,
    );
  }

  /// 最近 [days] 天（含今天），夹到 [minDays]..[maxDays]。
  factory NotebookDateRule.lastDays(int days) => NotebookDateRule._(
    NotebookDateKind.lastDays,
    days: days.clamp(minDays, maxDays),
  );

  const NotebookDateRule.thisYear() : this._(NotebookDateKind.thisYear);

  /// 每年的 [month] 月（1–12）；越界时抛 [ArgumentError]。
  factory NotebookDateRule.monthEveryYear(int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', '月份须为 1–12');
    }
    return NotebookDateRule._(NotebookDateKind.monthEveryYear, month: month);
  }

  /// 每年的今天（与今天同月同日）。
  const NotebookDateRule.dayEveryYear() : this._(NotebookDateKind.dayEveryYear);

  static const int minDays = 1;
  static const int maxDays = 3650;

  final NotebookDateKind kind;

  /// [NotebookDateKind.between] 的首尾日期（本地零点）。
  final DateTime? from;
  final DateTime? to;

  /// [NotebookDateKind.lastDays] 的天数。
  final int? days;

  /// [NotebookDateKind.monthEveryYear] 的月份。
  final int? month;

  @override
  String get type => 'date';

  static NotebookDateRule? _fromJson(Map<String, Object?> json) {
    final kind = NotebookDateKind.values.asNameMap()[json['kind']];
    switch (kind) {
      case NotebookDateKind.between:
        final from = _parseDate(json['from']);
        final to = _parseDate(json['to']);
        if (from == null || to == null) return null;
        return NotebookDateRule.between(from, to);
      case NotebookDateKind.lastDays:
        final days = _wholeNumber(json['days']);
        return days == null ? null : NotebookDateRule.lastDays(days);
      case NotebookDateKind.thisYear:
        return const NotebookDateRule.thisYear();
      case NotebookDateKind.monthEveryYear:
        final month = _wholeNumber(json['month']);
        if (month == null || month < 1 || month > 12) return null;
        return NotebookDateRule.monthEveryYear(month);
      case NotebookDateKind.dayEveryYear:
        return const NotebookDateRule.dayEveryYear();
      case null:
        return null;
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'kind': kind.name,
    if (from case final from?) 'from': _formatDate(from),
    if (to case final to?) 'to': _formatDate(to),
    'days': ?days,
    'month': ?month,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookDateRule &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.days == days &&
      other.month == month;

  @override
  int get hashCode => Object.hash(type, kind, from, to, days, month);
}

/// 正文嵌入的种类。
enum NotebookMediaKind { image, audio, video, attachment }

final class NotebookMediaRule extends NotebookRule {
  const NotebookMediaRule(this.kind);

  final NotebookMediaKind kind;

  @override
  String get type => 'media';

  static NotebookMediaRule? _fromJson(Map<String, Object?> json) {
    final kind = NotebookMediaKind.values.asNameMap()[json['kind']];
    return kind == null ? null : NotebookMediaRule(kind);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'kind': kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookMediaRule && other.kind == kind;

  @override
  int get hashCode => Object.hash(type, kind);
}

/// 日记的标记：有封面 / 已置顶。
enum NotebookFlagKind { hasCover, pinned }

final class NotebookFlagRule extends NotebookRule {
  const NotebookFlagRule(this.kind);

  final NotebookFlagKind kind;

  @override
  String get type => 'flag';

  static NotebookFlagRule? _fromJson(Map<String, Object?> json) {
    final kind = NotebookFlagKind.values.asNameMap()[json['kind']];
    return kind == null ? null : NotebookFlagRule(kind);
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'kind': kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookFlagRule && other.kind == kind;

  @override
  int get hashCode => Object.hash(type, kind);
}

/// 认不出或不合法的规则：原样保留 [raw]，编码时写回原文，编译为不匹配。
final class NotebookUnknownRule extends NotebookRule {
  NotebookUnknownRule(Map<String, Object?> raw)
    : raw = Map<String, Object?>.unmodifiable(raw);

  final Map<String, Object?> raw;

  @override
  String get type {
    final type = raw['type'];
    return type is String ? type : '';
  }

  @override
  Map<String, Object?> toJson() => raw;

  @override
  bool operator ==(Object other) =>
      other is NotebookUnknownRule && _jsonEquals(other.raw, raw);

  @override
  int get hashCode => _jsonHash(raw);
}

/// 把规则集编译成作用于别名 `d`（`diaries` 表）的 SQL 条件。
///
/// - `all` 用 AND、`any` 用 OR 连接各条规则；
/// - 空规则集与 [NotebookUnknownRule] 编译为 `0`（什么都不匹配）：智能日记本
///   悄悄显示全部日记比暂时为空更糟；
/// - 相对日期按 [now]（缺省为当前时刻）所在的**那一天**算边界：同一天内重复
///   编译得到相等的谓词（它是查询 provider 的 key 的一部分，不能每次都变）；
/// - 未解封的时间胶囊只按标题、日期与置顶参与匹配：标签、心情、天气、地点、
///   正文、嵌入与封面都在解封前保密（与日历筛选“不按心情或标签泄露胶囊”同
///   一口径，DESIGN.md §5.7），所以这些条件都加上“已解封”。“已解封”按 SQL
///   的当前时刻判断，不进参数，理由同上。
///
/// 私密排除不在这里：智能范围的查询总会再加上私密排除。
DiaryScopePredicate compileNotebookRules(NotebookRuleSet set, {DateTime? now}) {
  if (set.isEmpty) return const DiaryScopePredicate(sql: '0');
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final variables = <Variable<Object>>[];
  final parts = <String>[
    for (final rule in set.rules) '(${_compileRule(rule, today, variables)})',
  ];
  final joiner = set.match == NotebookRuleMatch.all ? ' AND ' : ' OR ';
  return DiaryScopePredicate(sql: parts.join(joiner), variables: variables);
}

/// 胶囊已解封（或不是胶囊）。`capsule_unlock_at` 与 drift 的其他时间列一样存
/// Unix 秒。
const String _unsealedSql =
    '(d.capsule_unlock_at IS NULL OR '
    "d.capsule_unlock_at <= CAST(strftime('%s', 'now') AS INTEGER))";

String _unsealed(String condition) => '$_unsealedSql AND $condition';

String _compileRule(
  NotebookRule rule,
  DateTime today,
  List<Variable<Object>> variables,
) {
  switch (rule) {
    case NotebookTagsRule(:final mode, :final names):
      if (names.isEmpty) return '0';
      variables.addAll(<Variable<Object>>[
        for (final name in names) Variable<String>(name),
      ]);
      final matched =
          'FROM diary_tags rdt JOIN tags rt ON rt.id = rdt.tag_id '
          'WHERE rdt.diary_id = d.id AND rt.name IN (${_placeholders(names.length)})';
      switch (mode) {
        case NotebookTagMatch.any:
          return _unsealed('EXISTS (SELECT 1 $matched)');
        case NotebookTagMatch.all:
          variables.add(Variable<int>(names.length));
          return _unsealed('(SELECT COUNT(DISTINCT rt.name) $matched) = ?');
        case NotebookTagMatch.none:
          return _unsealed('NOT EXISTS (SELECT 1 $matched)');
      }
    case NotebookMoodRule(:final emojis):
      if (emojis.isEmpty) return '0';
      variables.addAll(<Variable<Object>>[
        for (final emoji in emojis) Variable<String>(emoji),
      ]);
      return _unsealed(
        "json_extract(d.metadata, '\$.context.moodEmoji') "
        'IN (${_placeholders(emojis.length)})',
      );
    case NotebookTextRule(:final field, :final text):
      if (text.isEmpty) return '0';
      final pattern = '%${_escapeLike(text)}%';
      switch (field) {
        case NotebookTextField.weather:
        case NotebookTextField.location:
          variables.add(Variable<String>(pattern));
          return _unsealed(
            "json_extract(d.metadata, '\$.context.${field.name}') "
            "LIKE ? ESCAPE '\\'",
          );
        case NotebookTextField.keyword:
          // 标题在胶囊卡片上本就可见；正文只在解封后参与（与首页搜索一致）。
          variables
            ..add(Variable<String>(pattern))
            ..add(Variable<String>(pattern));
          return "d.title LIKE ? ESCAPE '\\' OR "
              "($_unsealedSql AND d.content_text LIKE ? ESCAPE '\\')";
      }
    case NotebookDateRule():
      return _compileDate(rule, today, variables);
    case NotebookMediaRule(:final kind):
      return _unsealed(
        '(${[for (final pattern in _mediaPatterns(kind)) "d.content LIKE '$pattern'"].join(' OR ')})',
      );
    case NotebookFlagRule(:final kind):
      return switch (kind) {
        NotebookFlagKind.hasCover => _unsealed(
          "d.cover IS NOT NULL AND TRIM(d.cover) <> ''",
        ),
        NotebookFlagKind.pinned => 'd.is_pinned = 1',
      };
    case NotebookUnknownRule():
      return '0';
  }
}

String _compileDate(
  NotebookDateRule rule,
  DateTime today,
  List<Variable<Object>> variables,
) {
  String range(DateTime start, DateTime endExclusive) {
    variables
      ..add(Variable<DateTime>(start))
      ..add(Variable<DateTime>(endExclusive));
    return 'd.created_at >= ? AND d.created_at < ?';
  }

  DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  switch (rule.kind) {
    case NotebookDateKind.between:
      final from = rule.from;
      final to = rule.to;
      if (from == null || to == null) return '0';
      return range(from, addDays(to, 1));
    case NotebookDateKind.lastDays:
      final days = rule.days ?? NotebookDateRule.minDays;
      // 含今天往前数 days 天；明天及以后（未来日期的胶囊）不算“最近”。
      return range(addDays(today, 1 - days), addDays(today, 1));
    case NotebookDateKind.thisYear:
      return range(DateTime(today.year), DateTime(today.year + 1));
    case NotebookDateKind.monthEveryYear:
      final month = rule.month;
      if (month == null) return '0';
      variables.add(Variable<int>(month));
      return "CAST(strftime('%m', d.created_at, 'unixepoch', 'localtime') "
          'AS INTEGER) = ?';
    case NotebookDateKind.dayEveryYear:
      variables.add(
        Variable<String>('${_twoDigits(today.month)}-${_twoDigits(today.day)}'),
      );
      return "strftime('%m-%d', d.created_at, 'unixepoch', 'localtime') = ?";
  }
}

/// 正文里某类嵌入的 LIKE 模式（不含用户输入，直接写进 SQL）。
///
/// 正文是 Dart `jsonEncode` 写出的紧凑 Delta：嵌入为
/// `{"insert":{"image":"…"}}`、`{"insert":{"video":"…"}}`、
/// `{"insert":{"audio":"{\"path\":…}"}}`（自定义嵌入的数据是再编码一层的 JSON
/// 字符串，内层引号被转义）、`{"insert":{"attachment":"{…}"}}`（旧版为 `file`）。
/// 文字里的引号一定被转义成 `\"`，所以 `"image":` 这样未转义的“键 + 冒号”只能
/// 出现在 JSON 结构里，不会被正文文字误中。旧版 AppFlowy 文档（尚未改写成
/// Delta 的历史正文）的节点写作 `"type":"image"`，一并认出。
List<String> _mediaPatterns(NotebookMediaKind kind) => switch (kind) {
  NotebookMediaKind.image => const <String>['%"image":%', '%"type":"image"%'],
  NotebookMediaKind.audio => const <String>['%"audio":%'],
  NotebookMediaKind.video => const <String>['%"video":%', '%"type":"video"%'],
  NotebookMediaKind.attachment => const <String>[
    '%"attachment":%',
    '%"file":%',
    '%"type":"attachment"%',
    '%"type":"file"%',
  ],
};

/// LIKE 的转义：用户输入里的 `%`、`_` 与转义符本身按字面匹配。
String _escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

String _placeholders(int count) => List<String>.filled(count, '?').join(', ');

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_twoDigits(date.month)}-'
    '${_twoDigits(date.day)}';

final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 只接受真实存在的 `YYYY-MM-DD`（2 月 30 日之类会被 DateTime 进位，按坏数据
/// 处理）。
DateTime? _parseDate(Object? value) {
  if (value is! String) return null;
  final match = _datePattern.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// 整数（其他实现可能写成 3.0）；其余类型为 null。
int? _wholeNumber(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

/// 字符串列表；不是列表或含非字符串元素时为 null（整条规则作废）。
List<String>? _stringList(Object? value) {
  if (value is! List) return null;
  final result = <String>[];
  for (final item in value) {
    if (item is! String) return null;
    result.add(item);
  }
  return result;
}

List<String> _cleanStrings(Iterable<String> values) {
  final seen = <String>{};
  return List<String>.unmodifiable(<String>[
    for (final value in values)
      if (value.trim() case final trimmed when trimmed.isNotEmpty)
        if (seen.add(trimmed)) trimmed,
  ]);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// JSON 树相等：Map 与键顺序无关，List 按顺序。
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
