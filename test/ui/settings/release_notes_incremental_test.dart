import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/models/release_notes_document.dart';
import 'package:node_diary/ui/settings/models/release_notes_incremental.dart';

/// 流式 Markdown 的增量解析：逐字变长时，每一步的结果都与整段解析一致；
/// 定稿的块保持同一个对象；围栏里的空行、松散列表不被切开。
void main() {
  /// 块的可比较摘要（块对象本身不重载 ==）。
  List<String> digest(List<ReleaseNoteBlock> blocks) => <String>[
    for (final block in blocks)
      '${block.kind.name}|${block.level}|${block.marker}|${block.language}|'
          '${block.plainText}|'
          '${block.spans.map((s) => '${s.bold}${s.italic}${s.code}${s.strike}${s.link}').join(',')}',
  ];

  const samples = <String>[
    // 段落、标题、列表、引用混排。
    '## 这个月\n\n你写了 **12 篇**日记，比上个月多。\n\n'
        '- 工作：8 篇\n- 旅行：3 篇\n  - 海边 2 篇\n\n'
        '> 记得休息。\n\n最后一段，带 `代码` 与 [链接](https://example.com)。\n',
    // 围栏里有空行，后面接正文。
    '先看代码：\n\n```dart\nvoid main() {\n\n  print(1);\n}\n```\n\n写完了。\n',
    // 波浪线围栏里出现反引号围栏。
    '~~~md\n```\n\n内层\n```\n\n~~~\n\n结尾\n',
    // 松散的有序列表（各项之间有空行）与懒编号。
    '步骤：\n\n1. 第一步\n\n1. 第二步\n\n1. 第三步\n\n然后就好了。\n',
    // 表格后面接段落。
    '| 月份 | 篇数 |\n|---|---:|\n| 十月 | 12 |\n| 十一月 | 3 |\n\n以上。\n',
    // 列表项里的续行段落与缩进代码。
    '- 第一项\n\n  续行段落\n\n- 第二项\n\n    缩进代码\n\n收尾。\n',
    // 以数字、短横线开头但不是列表的段落。
    '2024 年过得不错。\n\n-5 度的那天你去了海边。\n\n*强调*开头的一段。\n\n---\n\n完。\n',
    // CRLF 换行。
    '第一段\r\n\r\n第二段\r\n\r\n```\r\ncode\r\n\r\nmore\r\n```\r\n\r\n第三段\r\n',
  ];

  test('every prefix parses the same as a full parse', () {
    for (final sample in samples) {
      final parser = ReleaseNotesIncrementalParser();
      for (var end = 0; end <= sample.length; end++) {
        final prefix = sample.substring(0, end);
        expect(
          digest(parser.update(prefix)),
          digest(parseReleaseNotes(prefix)),
          reason: 'prefix of length $end of ${sample.substring(0, 12)}…',
        );
      }
    }
  });

  test('settled blocks keep their identity while the tail grows', () {
    final parser = ReleaseNotesIncrementalParser();
    final first = parser.update('第一段写完了。\n\n第二段');
    expect(parser.stableCount, 1);
    final settled = first.first;

    final second = parser.update('第一段写完了。\n\n第二段还在写');
    expect(parser.stableCount, 1);
    expect(identical(second.first, settled), isTrue);
    expect(identical(second.last, first.last), isFalse);
    expect(second.last.plainText, '第二段还在写');

    final third = parser.update('第一段写完了。\n\n第二段还在写。\n\n第三段');
    expect(parser.stableCount, 2);
    expect(identical(third.first, settled), isTrue);
    expect(identical(third[1], second.last), isFalse);
  });

  test('does not cut inside a fence or a loose list', () {
    final parser = ReleaseNotesIncrementalParser();
    parser.update('```\nline 1\n\nline 2');
    expect(parser.stableCount, 0);

    final list = ReleaseNotesIncrementalParser();
    final blocks = list.update('1. 一\n\n1. 二\n\n1. 三');
    expect(list.stableCount, 0);
    expect(blocks.map((b) => b.marker), ['1.', '2.', '3.']);
  });

  test('starts over when the text is not a continuation', () {
    final parser = ReleaseNotesIncrementalParser();
    parser.update('旧的回答。\n\n第二段');
    expect(parser.stableCount, 1);

    final blocks = parser.update('重新生成的回答');
    expect(parser.stableCount, 0);
    expect(blocks.single.plainText, '重新生成的回答');
  });
}
