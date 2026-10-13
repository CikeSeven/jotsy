import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'edit diary page keeps a stable PopScope root when recording panel toggles',
    () async {
      final source = await File(
        'lib/ui/diaries/pages/edit_diary_page.dart',
      ).readAsString();

      // 根节点在 Scaffold 与 PopScope 之间切换会让整棵编辑器子树重建。
      expect(source, contains('canPop: !_isEditEntry && !_recordingPanelOpen'));
      expect(source, isNot(contains('return scaffold;')));
    },
  );
}
