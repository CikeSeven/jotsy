// 工具调用的“可读详情”：把模型给的原始参数写成几行“标签 — 值”（界面语言），
// 替代以前直接打印的 JSON。
//
// 规则（通用，按参数名与 schema 类型）：
// - id 类参数（`id` / `ids` / `*_id`）绝不显示 UUID：从这次调用记下的涉及
//   对象（`AiToolSubject`）里找名称，找不到就不列；
// - 成对的日期（`from`/`to`、`due_from`/`due_to`）合成一行日期范围；
// - 日期按界面语言格式化，布尔为“是 / 否”，列表用顿号连接，schema 里的枚举
//   值经 `aiToolArgValue` 译成界面语言，长文本（正文、备注）标成长条显示；
// - 页面跳转的目标、“立即打开”等已在卡片上表达的参数不列；
// - 个别参数（功能名、语言）由工具的 `describeArg` 给出读法，参数名本身是
//   界面名称的（每项设置）由工具的 `argLabel` 给出名称。
//
// 参数取的是落库的原始参数（模型给什么就是什么），格式不对时原样显示，不抛错。

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_agent_steps.dart';
import '../models/ai_tool_subject.dart';
import '../tools/ai_tool_registry.dart';

/// 详情里的一行。
@immutable
class AiToolFact {
  const AiToolFact(this.label, this.value, {this.long = false, this.color});

  final String label;
  final String value;

  /// 长文本（正文、备注、留言）：引用块显示，超过几行可展开。
  final bool long;

  /// 颜色参数（ARGB）：值旁画一个色块。
  final int? color;
}

/// 这些参数不进详情：目标在卡片上、原始坏参数另在“技术信息”里。
const Set<String> _skipped = <String>{'destination', 'now', '_raw'};

/// 长文本参数。
const Set<String> _longKeys = <String>{'body', 'text', 'note', 'content'};

/// 涉及对象的显示名：标题；日记没有标题时用日期；某一天写成日期。
String aiSubjectName(AppLocalizations l10n, AiToolSubject subject) {
  final title = subject.title.trim();
  final date = subject.date;
  if (subject.kind == AiSubjectKind.day && date != null) {
    return DateFormat.yMMMEd(l10n.localeName).format(date);
  }
  if (title.isNotEmpty) return title;
  if (date != null) return DateFormat.yMMMd(l10n.localeName).format(date);
  return subject.id;
}

/// 参数名的界面写法（`aiToolArgName` 没有译名时用参数名本身）。
String aiToolArgLabel(AppLocalizations l10n, String key) {
  final label = l10n.aiToolArgName('arg_$key');
  return label.isEmpty ? key : label;
}

/// 枚举参数值的界面写法（没有译名时用原值）。
String aiToolEnumLabel(AppLocalizations l10n, String key, String value) {
  final label = l10n.aiToolArgValue('${key}_$value');
  return label.isEmpty ? value : label;
}

/// 把几个名称连起来；太多时写“A、B、C 等 N 个”。
String aiJoinNames(AppLocalizations l10n, List<String> names, {int show = 3}) {
  if (names.length <= show) return names.join(l10n.aiListSeparator);
  return l10n.aiToolNamesAndMore(
    names.take(show).join(l10n.aiListSeparator),
    names.length,
  );
}

List<AiToolFact> aiToolFacts(AppLocalizations l10n, AiAgentCallRecord call) {
  final tool = aiToolByName(call.tool);
  final schema = tool?.schema.properties ?? const <String, AiSchema>{};
  final args = call.args;
  final facts = <AiToolFact>[];
  final handled = <String>{};
  final locale = l10n.localeName;

  DateTime? asDate(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    return DateTime.tryParse(raw.trim());
  }

  String formatDate(DateTime value) => DateFormat.yMMMd(locale).format(value);

  void range(String fromKey, String toKey, String label) {
    final from = asDate(args[fromKey]);
    final to = asDate(args[toKey]);
    if (from == null && to == null) return;
    handled
      ..add(fromKey)
      ..add(toKey);
    final value = from != null && to != null
        ? (from == to
              ? formatDate(from)
              : l10n.aiToolArgRange(formatDate(from), formatDate(to)))
        : from != null
        ? l10n.aiToolArgSince(formatDate(from))
        : l10n.aiToolArgUntil(formatDate(to!));
    facts.add(AiToolFact(label, value));
  }

  range('from', 'to', aiToolArgLabel(l10n, 'date_range'));
  range('due_from', 'due_to', aiToolArgLabel(l10n, 'due_range'));

  for (final MapEntry(:key, :value) in args.entries) {
    if (handled.contains(key) || _skipped.contains(key) || value == null) {
      continue;
    }
    // 合并标签的 `from` 是标签列表，与日期的 `from` 不是一回事。
    final nameKey = key == 'from' && value is List ? 'merge_from' : key;
    final label =
        tool?.argLabel(l10n, nameKey) ?? aiToolArgLabel(l10n, nameKey);
    final custom = tool?.describeArg(l10n, key, value);
    if (custom != null) {
      if (custom.isNotEmpty) facts.add(AiToolFact(label, custom));
      continue;
    }
    if (key == 'id' || key == 'ids' || key.endsWith('_id')) {
      final ids = <String>{
        if (value is String) value,
        if (value is List)
          for (final item in value)
            if (item is String) item,
      };
      final matched = [
        for (final subject in call.subjects)
          if (ids.contains(subject.id)) subject,
      ];
      if (matched.isEmpty) continue;
      // `id` / `ids` 本身不说是什么：按对象的种类称呼（日记、待办……）。
      final kindLabel = key == 'parent_id'
          ? label
          : aiToolArgLabel(l10n, 'kind_${matched.first.kind.name}');
      facts.add(
        AiToolFact(
          kindLabel,
          aiJoinNames(l10n, [
            for (final subject in matched) aiSubjectName(l10n, subject),
          ]),
        ),
      );
      continue;
    }
    final property = schema[key];
    final enumValues = property is AiStringSchema ? property.enumValues : null;
    final String text;
    int? color;
    switch (value) {
      case final bool flag:
        text = flag ? l10n.aiToolArgYes : l10n.aiToolArgNo;
      case final List<Object?> list:
        text = list.map((item) => '$item').join(l10n.aiListSeparator);
      case final String raw when enumValues != null:
        text = aiToolEnumLabel(l10n, key, raw);
      case final String raw when asDate(raw) != null:
        text = formatDate(asDate(raw)!);
      case final int minutes when key == 'remind_before_minutes':
        text = l10n.aiToolArgMinutes(minutes);
      case final String raw when key == 'color':
        text = raw;
        color = _hexColor(raw);
      default:
        text = '$value';
    }
    if (text.trim().isEmpty) continue;
    facts.add(
      AiToolFact(
        label,
        text,
        long: _longKeys.contains(key) || text.length > 60,
        color: color,
      ),
    );
  }
  return facts;
}

/// `#RRGGBB` → 不透明的 ARGB；格式不对时为 null。
int? _hexColor(String raw) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(raw.trim());
  if (match == null) return null;
  return 0xff000000 | int.parse(match.group(1)!, radix: 16);
}
