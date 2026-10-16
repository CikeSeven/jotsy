import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md §6 的源码约束：纪念日模块的提示条经 Home 的跟踪接口、等待态
/// 用 Expressive 加载指示、不用渐变、动画时长只取 ExpressiveMotion token。
void main() {
  final files = Directory('lib/ui/anniversaries')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();

  test('the anniversary module has source files', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test('${file.path} follows the UI rules', () {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.showSnackBar(')));
      expect(source, isNot(contains('CircularProgressIndicator')));
      expect(source, isNot(contains('Gradient(')));
      expect(source, isNot(contains('Duration(milliseconds')));
    });
  }
}
