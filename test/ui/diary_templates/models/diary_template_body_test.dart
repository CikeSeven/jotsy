import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_body.dart';

void main() {
  group('sanitize', () {
    test('drops every media embed and keeps text, formats and dividers', () {
      final ops = sanitizeDiaryTemplateOps(<Object?>[
        {
          'insert': '标题',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': {'image': '/data/user/0/app/diary_images/a.jpg'},
        },
        {'insert': '\n'},
        {
          'insert': {'video': '/private/v.mp4'},
        },
        {
          'insert': {'audio': '{"path":"/private/a.m4a"}'},
        },
        {
          'insert': {'attachment': '/private/f.pdf'},
        },
        {
          'insert': {'file': '/private/x'},
        },
        {
          'insert': {'unknownEmbed': 'whatever'},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n正文\n'},
        {'retain': 3},
        'not a map',
      ]);

      expect(ops, [
        {
          'insert': '标题',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n正文\n'},
      ]);
      expect(jsonEncode(ops), isNot(contains('/private')));
      expect(jsonEncode(ops), isNot(contains('/data')));
    });

    test('an image inside a line keeps the rest of that line', () {
      final ops = sanitizeDiaryTemplateOps(<Object?>[
        {'insert': '前'},
        {
          'insert': {'image': '/a.jpg'},
        },
        {'insert': '后\n'},
      ]);
      expect(ops, [
        {'insert': '前'},
        {'insert': '后\n'},
      ]);
    });

    test('the result always ends with a line break', () {
      expect(
        sanitizeDiaryTemplateOps(<Object?>[
          {'insert': '没有换行'},
        ]),
        [
          {'insert': '没有换行'},
          {'insert': '\n'},
        ],
      );
      expect(sanitizeDiaryTemplateOps(null), emptyDiaryTemplateOps);
      expect(
        sanitizeDiaryTemplateOps(<Object?>[
          {
            'insert': {'image': '/a.jpg'},
          },
        ]),
        emptyDiaryTemplateOps,
      );
    });

    test('code block languages survive sanitizing', () {
      final ops = sanitizeDiaryTemplateOps(<Object?>[
        {'insert': 'print(1)'},
        {
          'insert': '\n',
          'attributes': {'code-block': 'python'},
        },
      ]);
      expect(ops.last['attributes'], {'code-block': 'python'});
    });

    test('the result decodes into a Quill document', () {
      final ops = sanitizeDiaryTemplateOps(<Object?>[
        {'insert': '一行'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      final document = decodeDiaryContentToDocument(jsonEncode(ops));
      expect(document.toPlainText(), '一行\n');
    });
  });

  group('blocks', () {
    test('each block kind compiles to the matching line attributes', () {
      final ops = compileDiaryTemplateBlocks(
        const <DiaryTemplateBlock>[
          TplLabel('小标题：', mark: '📖'),
          TplParagraph(),
          TplGap(),
          TplNote('小字'),
          TplBullets(['甲', '']),
          TplNumbered(['']),
          TplChecklist(['']),
          TplQuote('引用\n换行'),
          TplDivider(),
          TplParagraph('结尾'),
        ],
        labelColor: '#FF3B7BE8',
        noteColor: '#FF7E848E',
      );
      expect(ops, [
        {
          'insert': '📖 小标题',
          'attributes': {'bold': true, 'color': '#FF3B7BE8'},
        },
        {'insert': '：'},
        {'insert': '\n'},
        {'insert': '\n'},
        {'insert': '\n'},
        {
          'insert': '小字',
          'attributes': {'size': 'small', 'color': '#FF7E848E'},
        },
        {'insert': '\n'},
        {'insert': '甲'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {'insert': '引用 换行'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
        {
          'insert': {'divider': 'hr'},
        },
        {'insert': '\n'},
        {'insert': '结尾'},
        {'insert': '\n'},
      ]);
      // 编译结果本身已在白名单内。
      expect(sanitizeDiaryTemplateOps(ops), ops);
    });

    test('a label keeps its trailing colon and spaces unformatted', () {
      final ops = compileDiaryTemplateBlocks(const <DiaryTemplateBlock>[
        TplLabel('Book: '),
        TplLabel('没有冒号'),
      ]);
      expect(ops, [
        {
          'insert': 'Book',
          'attributes': {'bold': true},
        },
        {'insert': ': '},
        {'insert': '\n'},
        {
          'insert': '没有冒号',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
    });
  });

  test('the caret goes to the first empty line, or the end without one', () {
    expect(firstEmptyLineOffset('标题\n\n正文\n'), 3);
    expect(firstEmptyLineOffset('\n后面\n'), 0);
    expect(firstEmptyLineOffset('一行\n两行\n'), 5);
    expect(firstEmptyLineOffset(''), 0);
  });
}
