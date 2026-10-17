/// 检查 ARB 文案是否符合 AGENTS.md §4（规则见 `arb_lint.dart`）。
///
/// 用法（仓库根目录）：`dart run tool/check_arb.dart`
///
/// 从 `l10n.yaml` 读取 `arb-dir` 与 `template-arb-file`，检查该目录下全部
/// `.arb`；有违规时逐条输出并以退出码 1 结束。在 GitHub Actions 中额外输出
/// `::error` 注解，让问题直接标在 PR 的对应行上。只读文件，不改写任何内容。
library;

import 'dart:convert';
import 'dart:io';

import 'arb_lint.dart';

void main() {
  final config = _readL10nConfig(File('l10n.yaml'));
  final arbDir = Directory(config['arb-dir'] ?? 'lib/l10n');
  final templateFile = config['template-arb-file'] ?? 'app_en.arb';

  final files = <String, File>{};
  final arbs = <String, Map<String, Object?>>{};
  String? templateLocale;
  final arbFiles =
      arbDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in arbFiles) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      _fail('${file.path}: top level must be a JSON object');
    }
    final locale = decoded['@@locale'] as String? ?? _localeFromName(file);
    files[locale] = file;
    arbs[locale] = decoded;
    if (file.uri.pathSegments.last == templateFile) {
      templateLocale = locale;
    }
  }
  if (templateLocale == null) {
    _fail('${arbDir.path}/$templateFile not found');
  }

  final issues = lintArbs(arbs, templateLocale: templateLocale);
  if (issues.isEmpty) {
    final keys = arbs[templateLocale]!.keys.where((k) => !k.startsWith('@'));
    stdout.writeln(
      'ARB check passed: ${keys.length} messages in '
      '${arbs.length} locales (${arbs.keys.join(', ')}).',
    );
    return;
  }

  final annotate = Platform.environment['GITHUB_ACTIONS'] == 'true';
  final sources = <String, String>{};
  for (final issue in issues) {
    final file = files[issue.locale]!;
    final path = file.path;
    stderr.writeln('$path: $issue');
    if (annotate) {
      final source = sources[path] ??= file.readAsStringSync();
      final line = issue.key == null ? null : _lineOf(source, issue.key!);
      stdout.writeln(
        '::error file=$path${line == null ? '' : ',line=$line'}'
        '::${_escapeAnnotation(issue.toString())}',
      );
    }
  }
  stderr.writeln(
    '\n${issues.length} ARB issue(s). See AGENTS.md §4; after fixing the '
    'ARB files run `flutter gen-l10n` and commit the generated code.',
  );
  exitCode = 1;
}

/// 只取 `l10n.yaml` 的单行 `key: value`，足够覆盖 gen-l10n 的配置写法，
/// 避免为一个脚本引入 yaml 依赖。
Map<String, String> _readL10nConfig(File file) {
  if (!file.existsSync()) {
    return const <String, String>{};
  }
  final entry = RegExp(r'^([A-Za-z-]+):\s*(\S+)\s*$');
  return <String, String>{
    for (final line in file.readAsLinesSync())
      if (entry.firstMatch(line) case final match?) match[1]!: match[2]!,
  };
}

/// `app_zh.arb` → `zh`；没有 `@@locale` 时与 gen-l10n 一样按文件名推断。
String _localeFromName(File file) {
  final name = file.uri.pathSegments.last.replaceAll('.arb', '');
  final separator = name.indexOf('_');
  return separator < 0 ? name : name.substring(separator + 1);
}

/// [key] 在 ARB 源文本中首次作为 JSON 键出现的行号（从 1 开始）。
int? _lineOf(String source, String key) {
  final match = RegExp('"${RegExp.escape(key)}"\\s*:').firstMatch(source);
  if (match == null) {
    return null;
  }
  return '\n'.allMatches(source.substring(0, match.start)).length + 1;
}

String _escapeAnnotation(String message) => message
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
