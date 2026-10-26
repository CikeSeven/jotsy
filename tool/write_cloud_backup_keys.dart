/// 写出发布构建用的网盘应用密钥文件（规则见 `cloud_backup_keys.dart`）。
///
/// 用法（仓库根目录，发布工作流在 flutter build 之前调用，Linux / Windows 同一条命令）：
/// ```text
/// dart run tool/write_cloud_backup_keys.dart cloud_backup_keys.json
/// ```
/// 值从环境变量 `JOTSY_*` 读取，只打印变量名与 GitHub Actions 的告警 / 错误注解，
/// 从不打印值。校验失败时以退出码 1 结束，不写文件。构建结束后由工作流删除该文件。
library;

import 'dart:convert';
import 'dart:io';

import 'cloud_backup_keys.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/write_cloud_backup_keys.dart <out>');
    exit(64);
  }
  // `dart run` 先打印不换行的 “Running build hooks...”；先输出一行普通文字，
  // 保证后面的 ::warning:: / ::error:: 从行首开始，否则 Actions 不认这些注解。
  stdout.writeln(' Checking cloud backup app keys');
  final CloudBackupKeys keys;
  try {
    keys = readCloudBackupKeys(Platform.environment);
  } on CloudBackupKeysException catch (error) {
    stdout
      ..writeln('Cloud backup key validation failed: ${error.message}')
      ..writeln('::error::${error.message}');
    exit(1);
  }
  for (final warning in keys.warnings) {
    stdout.writeln('::warning::$warning');
  }
  File(args.single).writeAsStringSync(jsonEncode(keys.values));
  final names = keys.values.keys.toList()..sort();
  stdout.writeln(
    'Cloud backup keys configured: ${names.isEmpty ? 'none' : names.join(', ')}',
  );
}
