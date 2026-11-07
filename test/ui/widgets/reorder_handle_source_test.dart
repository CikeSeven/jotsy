import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 可排序列表的拖动手柄只经 `ReorderHandle`（`lib/ui/widgets/reorder_handle.dart`）：
/// 以前各列表各拼一个 `ReorderableDragStartListener` + `Padding` 包小图标，
/// 留白不参与命中测试，实际只有图标那十几像素能按到；外观也有三竖线、
/// gripLines、gripVertical 三种。可排序列表的 proxyDecorator 必须包
/// `ReorderHandleLift`（共用的两个装饰函数已包好），拖起的那一行才保持握住状态。
void main() {
  const handleFile = 'lib/ui/widgets/reorder_handle.dart';
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .toList();

  /// 去掉整行注释后的源码，注释里提到组件名不算。
  String code(File file) => file
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('drag handles outside ReorderHandle are not hand-built', () {
    expect(files, isNotEmpty);
    // ReorderableDelayedDragStartListener（长按后拖）不在此列。
    final pattern = RegExp(r'\bReorderableDragStartListener\s*\(');
    final offenders = <String>[
      for (final file in files)
        if (file.path.replaceAll(r'\', '/') != handleFile &&
            pattern.hasMatch(code(file)))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('reorderable lists keep the lifted row holding its handle', () {
    final list = RegExp(
      r'\b(ReorderableListView|SliverReorderableList)\s*[.(]',
    );
    final decorated = RegExp(
      r'\b(expressiveReorderProxyDecorator|cardRowReorderProxyDecorator)\b|'
      r'\bReorderHandleLift\s*\(',
    );
    final offenders = <String>[
      for (final file in files)
        if (list.hasMatch(code(file)) && !decorated.hasMatch(code(file)))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
