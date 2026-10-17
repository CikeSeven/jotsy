/// 写出应用内更新清单 `jotsy-update.json`（规则见 `update_manifest.dart`）。
///
/// 用法（仓库根目录，发布工作流在构建签名安装包之后调用）：
/// ```text
/// dart run tool/write_update_manifest.dart \
///   --tag v0.6.1 --artifacts release-artifacts \
///   --out release-artifacts/jotsy-update.json \
///   [--published-at 2026-10-20T08:00:00Z] [--notes-fallback body.md]
/// ```
/// 版本取 `pubspec.yaml`，说明取 `docs/releases/<tag>.md` 与 `<tag>.en.md`，
/// 中文文件缺失时用 `--notes-fallback`（Release 正文）。出错时以退出码 1 结束。
library;

import 'dart:io';

import 'update_manifest.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final tag = options['tag'];
  final artifacts = options['artifacts'];
  final out = options['out'];
  if (tag == null || artifacts == null || out == null) {
    _fail(
      'Usage: dart run tool/write_update_manifest.dart --tag <tag> '
      '--artifacts <dir> --out <file> [--published-at <iso8601>] '
      '[--notes-fallback <file>]',
    );
  }
  final publishedAtRaw = options['published-at'] ?? '';
  final fallbackPath = options['notes-fallback'];
  final fallbackFile = fallbackPath == null ? null : File(fallbackPath);
  try {
    final manifest = await buildUpdateManifest(
      pubspec: File('pubspec.yaml').readAsStringSync(),
      tag: tag,
      artifacts: Directory(artifacts),
      releaseNotes: Directory('docs/releases'),
      publishedAt: DateTime.tryParse(publishedAtRaw),
      fallbackNotes: fallbackFile != null && fallbackFile.existsSync()
          ? fallbackFile.readAsStringSync()
          : null,
    );
    File(out).writeAsStringSync(manifest);
    stdout.writeln('Wrote $out');
  } on StateError catch (error) {
    _fail(error.message);
  }
}

/// `--name value` 形式的参数；为一个脚本不引入 args 依赖。
Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') || i + 1 >= args.length) {
      _fail('Unexpected argument: $arg');
    }
    options[arg.substring(2)] = args[++i];
  }
  return options;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
