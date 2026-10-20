import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 代码块的源码约束（AGENTS.md §6 代码块规则）：
/// - 高亮只经 `DiaryCodeHighlighter` 自带的实例与 22 个语言文件，任何源码都
///   不得导入 `package:highlight/highlight.dart`（会把约 190 种语言编进安装包，
///   自动识别也会逐个试一遍）；
/// - 代码块的模型与组件不直接弹 SnackBar（统一经 `showTrackedSnackBar`），
///   不硬编码黑白、不用渐变与旧加载圈；
/// - 工具栏里的代码块面板、语言选项与按钮不开对话框、底部面板或路由（会抢走
///   正文焦点、收起键盘，工具栏随之消失）；
/// - 只有 `attachDiaryCodeBlockEditing` 能改写 `QuillController.onReplaceText`，
///   之后再赋值会把代码块的回车处理覆盖掉。
void main() {
  const editingFile =
      'lib/ui/diaries/controllers/diary_code_block_editing.dart';
  const codeBlockDirs = <String>[
    'lib/ui/diaries/widgets/diary_code_block/',
    'lib/ui/diaries/models/diary_code_block/',
  ];
  const toolbarFiles = <String>[
    'lib/ui/diaries/widgets/diary_code_block/diary_code_block_panel.dart',
    'lib/ui/diaries/widgets/diary_code_block/diary_code_language_chips.dart',
    'lib/ui/diaries/widgets/diary_code_block/diary_toolbar_code_block_button.dart',
  ];

  String normalize(String path) => path.replaceAll(r'\', '/');

  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .toList();

  /// [files] 中命中 [patterns] 的非注释行，格式为 `路径:行号 uses 名称`。
  List<String> offenders(Iterable<File> files, Map<String, RegExp> patterns) {
    final found = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释里提到这些名字（说明为什么不用）不算违规。
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in patterns.entries) {
          if (entry.value.hasMatch(line)) {
            found.add('${normalize(file.path)}:${i + 1} uses ${entry.key}');
          }
        }
      }
    }
    return found;
  }

  test('the guarded code block sources exist', () {
    expect(libFiles, isNotEmpty);
    for (final dir in codeBlockDirs) {
      expect(Directory(dir).existsSync(), isTrue, reason: dir);
    }
    for (final path in <String>[editingFile, ...toolbarFiles]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('no source imports the full highlight package', () {
    expect(
      offenders(libFiles, <String, RegExp>{
        'package:highlight/highlight.dart': RegExp(
          r'''['"]package:highlight/highlight\.dart['"]''',
        ),
      }),
      isEmpty,
    );
  });

  test('code block models and widgets avoid raw snack bars, fixed '
      'black/white, gradients and the old spinner', () {
    final files = libFiles.where(
      (File file) => codeBlockDirs.any(normalize(file.path).startsWith),
    );
    expect(files, isNotEmpty);
    expect(
      offenders(files, <String, RegExp>{
        '.showSnackBar(': RegExp(r'\.showSnackBar\s*\('),
        'Colors.white': RegExp(r'\bColors\.white\b'),
        'Colors.black': RegExp(r'\bColors\.black\b'),
        'Gradient(': RegExp(r'Gradient\s*\('),
        'CircularProgressIndicator': RegExp(r'\bCircularProgressIndicator\b'),
      }),
      isEmpty,
    );
  });

  test('the toolbar code block panel opens no route, dialog or sheet', () {
    expect(
      offenders(toolbarFiles.map(File.new), <String, RegExp>{
        'showDialog': RegExp(r'\bshowDialog\b'),
        'showModalBottomSheet': RegExp(r'\bshowModalBottomSheet\b'),
        'Navigator.': RegExp(r'\bNavigator\.'),
      }),
      isEmpty,
    );
  });

  test('only attachDiaryCodeBlockEditing assigns onReplaceText', () {
    final assignment = RegExp(r'\bonReplaceText\s*(?:\?\?)?=(?!=)');
    final others = libFiles.where(
      (File file) => normalize(file.path) != editingFile,
    );
    expect(
      offenders(others, <String, RegExp>{'onReplaceText =': assignment}),
      isEmpty,
    );
    // 自检：规则本身能认出那一处赋值，避免正则写错后永远放行。
    expect(
      offenders(
        <File>[File(editingFile)],
        <String, RegExp>{'onReplaceText =': assignment},
      ),
      isNotEmpty,
    );
  });
}
