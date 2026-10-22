/// 合并 CI 各测试分片的 Flutter 行覆盖率，不依赖额外安装的 LCOV 工具。
///
/// 输入为 Flutter 默认 `--coverage` 输出，按源文件与行号累加命中次数；
/// LF / LH 必须从合并后的行重新计算，否则共享代码会被多次计入分母。
/// 不接受函数或分支覆盖率，避免将来切换采集模式后静默丢失数据。
/// 用法：`dart run tool/merge_lcov.dart <output> <input> [<input> ...]`。
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length < 2) {
    stderr.writeln('Usage: merge_lcov.dart <output> <input> [<input> ...]');
    exitCode = 64;
    return;
  }
  final merged = mergeLcov(
    arguments.skip(1).map((path) => File(path).readAsStringSync()),
  );
  File(arguments.first)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(merged);
}

String mergeLcov(Iterable<String> reports) {
  final sources = <String, Map<int, int>>{};
  for (final report in reports) {
    var hasSource = false;
    Map<int, int>? current;
    for (final line in const LineSplitter().convert(report)) {
      if (line.startsWith('SF:')) {
        if (current != null || line.length == 3) {
          throw FormatException('Invalid LCOV source record', line);
        }
        current = sources.putIfAbsent(line.substring(3), () => <int, int>{});
        hasSource = true;
      } else if (line.startsWith('DA:')) {
        final values = line.substring(3).split(',');
        final number = int.tryParse(values.first);
        final hits = values.length == 2 ? int.tryParse(values.last) : null;
        if (current == null ||
            number == null ||
            number <= 0 ||
            hits == null ||
            hits < 0) {
          throw FormatException('Invalid LCOV line coverage', line);
        }
        current.update(
          number,
          (previous) => previous + hits,
          ifAbsent: () => hits,
        );
      } else if (line == 'end_of_record') {
        current = null;
      } else if (line.isNotEmpty &&
          !line.startsWith('TN:') &&
          !line.startsWith('LF:') &&
          !line.startsWith('LH:')) {
        throw FormatException('Only Flutter line coverage is supported', line);
      }
    }
    if (current != null) {
      throw const FormatException('LCOV report ended before end_of_record');
    }
    if (!hasSource) {
      throw const FormatException('LCOV report has no source records');
    }
  }
  if (sources.isEmpty) {
    throw const FormatException('No LCOV source records found');
  }

  final output = StringBuffer();
  for (final source in sources.keys.toList()..sort()) {
    final lines = sources[source]!;
    output.writeln('SF:$source');
    for (final number in lines.keys.toList()..sort()) {
      output.writeln('DA:$number,${lines[number]}');
    }
    output
      ..writeln('LF:${lines.length}')
      ..writeln('LH:${lines.values.where((hits) => hits > 0).length}')
      ..writeln('end_of_record');
  }
  return output.toString();
}
