import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/models/release_notes_document.dart';

void main() {
  test('parses headings, paragraphs and inline styles', () {
    final blocks = parseReleaseNotes(
      '## 版本要点\n'
      '新增 **网盘备份** 与 `Markdown` 导入，详见 [文档](https://example.com/doc)。\n',
    );

    expect(blocks.map((b) => b.kind), <ReleaseNoteBlockKind>[
      ReleaseNoteBlockKind.heading,
      ReleaseNoteBlockKind.paragraph,
    ]);
    expect(blocks.first.level, 2);
    expect(blocks.first.plainText, '版本要点');
    final spans = blocks[1].spans;
    expect(spans.firstWhere((s) => s.text == '网盘备份').bold, isTrue);
    expect(spans.firstWhere((s) => s.text == 'Markdown').code, isTrue);
    expect(
      spans.firstWhere((s) => s.text == '文档').link,
      'https://example.com/doc',
    );
  });

  test('flattens nested and ordered lists with depth and markers', () {
    final blocks = parseReleaseNotes(
      '- 第一项\n'
      '  - 子项\n'
      '- 第二项\n'
      '\n'
      '3. 有序三\n'
      '4. 有序四\n',
    );

    expect(
      blocks.map((b) => (b.kind, b.level, b.marker, b.plainText)).toList(),
      <(ReleaseNoteBlockKind, int, String?, String)>[
        (ReleaseNoteBlockKind.listItem, 0, null, '第一项'),
        (ReleaseNoteBlockKind.listItem, 1, null, '子项'),
        (ReleaseNoteBlockKind.listItem, 0, null, '第二项'),
        (ReleaseNoteBlockKind.listItem, 0, '3.', '有序三'),
        (ReleaseNoteBlockKind.listItem, 0, '4.', '有序四'),
      ],
    );
  });

  test('keeps quotes, code blocks and rules, ignoring unsafe links', () {
    final blocks = parseReleaseNotes(
      '> 注意：[本地](file:///etc/passwd)\n'
      '\n'
      '```\nflutter build apk\n```\n'
      '\n'
      '---\n',
    );

    expect(blocks.map((b) => b.kind), <ReleaseNoteBlockKind>[
      ReleaseNoteBlockKind.quote,
      ReleaseNoteBlockKind.code,
      ReleaseNoteBlockKind.rule,
    ]);
    expect(blocks.first.spans.every((s) => s.link == null), isTrue);
    expect(blocks[1].text, 'flutter build apk');
  });

  test('renders an empty document as no blocks', () {
    expect(parseReleaseNotes(''), isEmpty);
    expect(parseReleaseNotes('\n\n'), isEmpty);
  });
}
