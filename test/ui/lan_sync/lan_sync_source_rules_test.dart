import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lan sync buttons never replace the themed text style with a bare '
      'TextStyle', () {
    // `textStyle: const TextStyle(...)` 会整个替换按钮的文字样式，把主题的
    // 应用字体（HarmonyOSSansSC）一起丢掉，没装中文字体的 Linux 上显示成
    // 方块；应写成 `theme.textTheme.labelLarge?.copyWith(...)`。
    final offenders = <String>[];
    final files = Directory('lib/ui/lan_sync')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      if (RegExp(r'textStyle:\s*const\s+TextStyle\(').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
