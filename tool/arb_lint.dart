/// ARB 文案规范检查（AGENTS.md §4），供 `tool/check_arb.dart` 与测试共用。
///
/// 输入：各语言 ARB 解码后的 JSON 对象（键为语言代码）与模板语言。
/// 输出：违规列表 [ArbIssue]，为空即通过；不读写文件，也不依赖 Flutter。
///
/// 检查项：
/// - 每个语言的文案键集合一致（缺译时 gen-l10n 只会静默回落到模板）；
/// - 每个文案键都有 `@key` 元数据且 `description` 非空，没有孤立的元数据；
/// - 文案里用到的占位符都在本文件的 `placeholders` 里声明（未声明的占位符
///   会被 gen-l10n 推断成 `Object`）；
/// - 占位符的 `type` 只能是 gen-l10n 接受的 [allowedPlaceholderTypes]。
library;

/// AGENTS.md §4 允许的占位符类型；`Object` 与缺省类型都会被拒绝。
const allowedPlaceholderTypes = <String>{
  'String',
  'int',
  'double',
  'num',
  'DateTime',
};

/// 一条违规：[locale] 文件里的 [key]（文件级问题为 null）及原因。
class ArbIssue {
  const ArbIssue(this.locale, this.key, this.message);

  final String locale;
  final String? key;
  final String message;

  @override
  String toString() => key == null ? message : '$key: $message';
}

/// 按 AGENTS.md §4 检查 [arbs]，[templateLocale] 的键集合视为基准。
List<ArbIssue> lintArbs(
  Map<String, Map<String, Object?>> arbs, {
  required String templateLocale,
}) {
  final template = arbs[templateLocale];
  if (template == null) {
    return <ArbIssue>[
      ArbIssue(templateLocale, null, 'template ARB file is missing'),
    ];
  }
  final issues = <ArbIssue>[];
  final templateKeys = _messageKeys(template);
  for (final MapEntry(key: locale, value: arb) in arbs.entries) {
    final keys = _messageKeys(arb);
    if (locale != templateLocale) {
      for (final key in templateKeys.difference(keys)) {
        issues.add(ArbIssue(locale, key, 'missing translation'));
      }
      for (final key in keys.difference(templateKeys)) {
        issues.add(ArbIssue(locale, key, 'not in the template ARB'));
      }
    }
    for (final key in keys) {
      issues.addAll(_lintMessage(locale, key, arb[key], arb['@$key']));
    }
    for (final key in arb.keys) {
      if (key.startsWith('@') &&
          !key.startsWith('@@') &&
          !arb.containsKey(key.substring(1))) {
        issues.add(ArbIssue(locale, key, 'metadata without a message'));
      }
    }
  }
  return issues;
}

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

Iterable<ArbIssue> _lintMessage(
  String locale,
  String key,
  Object? message,
  Object? metadata,
) sync* {
  if (message is! String) {
    yield ArbIssue(locale, key, 'message must be a string');
    return;
  }
  if (metadata is! Map<String, Object?>) {
    yield ArbIssue(locale, key, 'missing "@$key" metadata');
    return;
  }
  final description = metadata['description'];
  if (description is! String || description.trim().isEmpty) {
    yield ArbIssue(locale, key, '"@$key" needs a non-empty description');
  }

  final Set<String> used;
  try {
    used = icuPlaceholderNames(message);
  } on FormatException catch (error) {
    yield ArbIssue(locale, key, 'invalid ICU syntax: ${error.message}');
    return;
  }
  final declared = metadata['placeholders'] ?? const <String, Object?>{};
  if (declared is! Map<String, Object?>) {
    yield ArbIssue(locale, key, '"placeholders" must be an object');
    return;
  }
  for (final name in used.difference(declared.keys.toSet())) {
    yield ArbIssue(locale, key, 'placeholder {$name} is not declared');
  }
  for (final MapEntry(key: name, value: spec) in declared.entries) {
    final type = spec is Map<String, Object?> ? spec['type'] : null;
    if (!allowedPlaceholderTypes.contains(type)) {
      yield ArbIssue(
        locale,
        key,
        'placeholder {$name} type must be one of '
        '${allowedPlaceholderTypes.join('/')} (got ${type ?? 'none'})',
      );
    }
  }
}

/// 返回 ICU 文案 [message] 中引用的占位符名。
///
/// 只认 gen-l10n 默认（未开启 use-escaping / relax-syntax）的语法：`{name}`
/// 与 `{name, plural|select|selectordinal, 选择子{分支} ...}`，分支内可再嵌
/// 套占位符；分支文本（如 `other{words}` 的 words）不是占位符。花括号不配
/// 对或参数格式不对时抛出 [FormatException]，与 gen-l10n 一样拒绝该文案。
Set<String> icuPlaceholderNames(String message) {
  final scanner = _IcuScanner(message);
  scanner.parseText(nested: false);
  return scanner.names;
}

class _IcuScanner {
  _IcuScanner(this.source);

  static final _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
  static const _branchingKinds = <String>{'plural', 'select', 'selectordinal'};

  final String source;
  final names = <String>{};
  var _index = 0;

  bool get _atEnd => _index >= source.length;

  /// 读普通文本直到结尾；[nested] 时遇到闭合分支的 `}` 即返回（不消费）。
  void parseText({required bool nested}) {
    while (!_atEnd) {
      switch (source[_index]) {
        case '{':
          _parseArgument();
        case '}':
          if (nested) {
            return;
          }
          throw FormatException('unmatched "}"', source, _index);
        default:
          _index++;
      }
    }
    if (nested) {
      throw FormatException('unclosed "{"', source, _index);
    }
  }

  void _parseArgument() {
    _expect('{');
    final name = _readIdentifier('placeholder name');
    names.add(name);
    _skipSpaces();
    if (_tryConsume('}')) {
      return;
    }
    _expect(',');
    final kind = _readIdentifier('argument type');
    if (!_branchingKinds.contains(kind)) {
      throw FormatException('unsupported argument type "$kind"', source);
    }
    _expect(',');
    var branches = 0;
    while (true) {
      _skipSpaces();
      if (_tryConsume('}')) {
        break;
      }
      _readSelector();
      _expect('{');
      parseText(nested: true);
      _expect('}');
      branches++;
    }
    if (branches == 0) {
      throw FormatException('"$kind" needs at least one branch', source);
    }
  }

  /// 选择子：`=1`、`one`、`other`、`male` 等，止于空白或 `{`。
  void _readSelector() {
    final start = _index;
    while (!_atEnd && !_isSpace(source[_index]) && source[_index] != '{') {
      if (source[_index] == '}') {
        throw FormatException('branch selector without a body', source, start);
      }
      _index++;
    }
    if (_index == start) {
      throw FormatException('expected a branch selector', source, _index);
    }
    _skipSpaces();
  }

  String _readIdentifier(String what) {
    _skipSpaces();
    final match = _identifier.matchAsPrefix(source, _index);
    if (match == null) {
      throw FormatException('expected $what', source, _index);
    }
    _index = match.end;
    return match[0]!;
  }

  void _expect(String char) {
    _skipSpaces();
    if (!_tryConsume(char)) {
      throw FormatException('expected "$char"', source, _index);
    }
  }

  bool _tryConsume(String char) {
    if (!_atEnd && source[_index] == char) {
      _index++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (!_atEnd && _isSpace(source[_index])) {
      _index++;
    }
  }

  static bool _isSpace(String char) => char.trim().isEmpty;
}
