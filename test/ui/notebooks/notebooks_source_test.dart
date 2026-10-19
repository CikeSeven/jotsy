import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md §6 的源码约束：日记本模块的提示条经 Home 的跟踪接口、等待态
/// 用 Expressive 加载指示、不用渐变与固定黑白色、动画时长只取
/// ExpressiveMotion token、图标只用 FontAwesome、不用 SDK 弹出菜单。
void main() {
  final files = Directory('lib/ui/notebooks')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();

  test('the notebooks module has source files', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test('${file.path} follows the UI rules', () {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.showSnackBar(')));
      expect(source, isNot(contains('CircularProgressIndicator')));
      expect(source, isNot(contains('Gradient(')));
      // 动画时长只取 ExpressiveMotion；controllers/ 里的防抖、超时不是动画
      // （AGENTS.md §6 例外），不在此列。
      if (!file.path.contains('/controllers/')) {
        expect(source, isNot(contains('Duration(milliseconds')));
      }
      expect(source, isNot(contains('Colors.white')));
      expect(source, isNot(contains('Colors.black')));
      expect(source, isNot(contains('Icon(Icons.')));
      expect(source, isNot(contains('PopupMenu')));
      expect(source, isNot(contains('showMenu(')));
    });
  }
}
