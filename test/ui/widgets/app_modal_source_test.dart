import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 底部面板与对话框只经 `lib/ui/widgets/app_modal/` 的
/// `showAppModalBottomSheet` / `showAppDialog` 打开：直接调用 SDK 的
/// `showModalBottomSheet` / `showDialog` 会绕过“背景与材质”的玻璃切换，
/// 玻璃模式下冒出一块实色面板。
void main() {
  const componentDir = 'lib/ui/widgets/app_modal/';
  final forbidden = <String, RegExp>{
    // showAppModalBottomSheet / showAppDialog 前面带字母，不匹配。
    'showModalBottomSheet': RegExp(
      r'(?<![A-Za-z_])showModalBottomSheet\s*[<(]',
    ),
    'showDialog': RegExp(r'(?<![A-Za-z_])showDialog\s*[<(]'),
  };
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .where(
        (File file) =>
            !file.path.replaceAll(r'\', '/').startsWith(componentDir),
      )
      .toList();

  test('sheets and dialogs outside app_modal use the unified entries', () {
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释里提到 SDK 函数名不算违规。
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in forbidden.entries) {
          if (entry.value.hasMatch(line)) {
            offenders.add('${file.path}:${i + 1} uses ${entry.key}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
