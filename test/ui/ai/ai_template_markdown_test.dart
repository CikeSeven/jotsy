import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/tools/ai_template_markdown.dart';
import 'package:node_diary/ui/ai/tools/ai_template_markdown_inline.dart';
import 'package:node_diary/ui/ai/tools/ai_template_markdown_parse.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_blocks.dart';

/// 比较用的规范形：先经模板白名单，再把相邻同格式的片段合并（合并与否
/// 不影响显示，读出时总是合并）。
String _canonical(Object? body) {
  final document = sanitizeDiaryTemplateBlocks(body);
  void merge(Object? node) {
    if (node is! Map) return;
    final data = node['data'];
    if (data is Map && data['delta'] is List) {
      data['delta'] = [
        for (final run in aiTemplateMergeRuns(
          (data['delta'] as List).cast<Map<String, Object?>>(),
        ))
          {
            'insert': run.text,
            if (run.attributes.isNotEmpty) 'attributes': run.attributes,
          },
      ];
    }
    final children = node['children'];
    if (children is List) children.forEach(merge);
  }

  merge(document['document']);
  return jsonEncode(document);
}

Map<String, Object?> _doc(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

Map<String, Object?> _p(
  List<Map<String, Object?>> delta, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>>? children,
  String type = 'paragraph',
}) => {
  'type': type,
  'children': ?children,
  'data': {'delta': delta, ...data},
};

Map<String, Object?> _t(String text, [Map<String, Object?>? attributes]) => {
  'insert': text,
  'attributes': ?attributes,
};

void main() {
  group('round trip', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('every built-in template body survives ($locale)', () {
        for (final template in buildBuiltInDiaryTemplates(
          lookupAppLocalizations(locale),
        )) {
          final markdown = aiTemplateMarkdownOf(template.bodyJson);
          expect(
            _canonical(aiTemplateBodyFromMarkdown(markdown)),
            _canonical(template.bodyJson),
            reason: '${template.id}\n$markdown',
          );
        }
      });
    }

    test('every block type, option and inline format survives', () {
      final document = _doc([
        _p([
          _t('心情', {'bold': true, 'font_color': '#FFDA6A10'}),
          _t('：'),
        ]),
        _p([]),
        _p(
          [_t('居中 {align=center}')],
          data: {'align': 'center', 'firstLineIndent': false},
        ),
        _p([_t('{align=right}')]),
        _p([_t('# 不是标题')]),
        _p([_t('1. 不是编号')]),
        _p([_t('- 不是列表')]),
        _p([_t('---')]),
        _p([_t('> 不是引用')]),
        _p([_t('  前后空格  ')]),
        _p([_t('a*b_c`d[e]f<g>h~i\\j |k| ____ {{日期}} {{时间:HH:mm}}')]),
        _p([
          _t('粗', {'bold': true}),
          _t('斜', {'italic': true}),
          _t('粗斜', {'bold': true, 'italic': true}),
          _t('删', {'strikethrough': true}),
          _t('下', {'underline': true}),
          _t('码', {'code': true}),
          _t('码`里', {'code': true}),
          _t('上', {'script': 'super'}),
          _t('下', {'script': 'sub'}),
          _t('链接', {'href': 'https://example.com/a_(b)'}),
          _t('粗链接', {'href': 'https://example.com', 'bold': true}),
          _t('自定义', {'font_color': '#FF123456', 'bg_color': '#80ABCDEF'}),
          _t('黄底', {'bg_color': '#66FFC107'}),
          _t('大', {'size': 'large'}),
          _t('数字号', {'size': 1.3}),
        ]),
        _p([_t('一级')], type: 'heading', data: {'level': 1}),
        _p([_t('六级')], type: 'heading', data: {'level': 6, 'align': 'right'}),
        _p(
          [_t('项目')],
          type: 'bulleted_list',
          data: {'listStyle': 'star'},
          children: [
            _p([_t('子项目')], type: 'bulleted_list'),
            _p(
              [_t('子编号')],
              type: 'numbered_list',
              data: {'listStyle': 'lower-roman'},
              children: [_p([])],
            ),
          ],
        ),
        _p([], type: 'bulleted_list'),
        _p([_t('一')], type: 'numbered_list'),
        _p([_t('二')], type: 'numbered_list'),
        _p([_t('没做')], type: 'todo_list', data: {'checked': false}),
        _p([_t('做了')], type: 'todo_list', data: {'checked': true}),
        _p([_t('引用')], type: 'quote'),
        _p(
          [
            _t('提示', {'bold': true}),
          ],
          type: 'callout',
          data: {'icon': '💡', 'tone': 'yellow'},
        ),
        _p([_t('无图标提示')], type: 'callout'),
        _p(
          [_t('折叠')],
          type: 'toggle_list',
          data: {'collapsed': true},
          children: [
            _p([_t('里面')]),
            {'type': 'divider'},
          ],
        ),
        _p([_t('展开')], type: 'toggle_list', data: {'collapsed': false}),
        _p([_t('默认')], type: 'toggle_list'),
        {'type': 'divider'},
        _p(
          [_t('void main() {}\n  ```inner\n')],
          type: 'code',
          data: {'language': 'dart'},
        ),
        _p([], type: 'code'),
        _table(headerRow: true),
        _table(headerRow: false),
        _p(
          [_t('段落')],
          children: [
            _p([_t('段落的子段落')]),
          ],
        ),
      ]);
      final markdown = aiTemplateMarkdownOf(document);
      expect(
        _canonical(aiTemplateBodyFromMarkdown(markdown)),
        _canonical(document),
        reason: markdown,
      );
    });

    test('an empty body is a single empty paragraph', () {
      expect(aiTemplateMarkdownOf(_doc([_p([])])), '');
      expect(
        _canonical(aiTemplateBodyFromMarkdown('')),
        _canonical(_doc([_p([])])),
      );
    });
  });

  group('writing for the model', () {
    test('built-in labels read as colored bold text and preset names', () {
      final markdown = aiTemplateMarkdownOf(
        _doc([
          _p([
            _t('Mood', {'bold': true, 'font_color': '#FFDA6A10'}),
            _t(': '),
          ]),
        ]),
      );
      expect(markdown, r'<span style="color: orange">**Mood**</span>:\ ');
    });
  });

  group('reading what models write', () {
    Map<String, Object?> first(String markdown) {
      final children =
          (aiTemplateBodyFromMarkdown(markdown)['document']! as Map)['children']
              as List;
      return (children.first as Map).cast<String, Object?>();
    }

    test('bold next to full-width punctuation still works', () {
      final node = first('**心情：**今天不错');
      expect(node['data'], {
        'delta': [
          {
            'insert': '心情：',
            'attributes': {'bold': true},
          },
          {'insert': '今天不错'},
        ],
      });
    });

    test('underscores and unpaired stars stay text', () {
      final node = first('书名：______ 5 * 3');
      expect((node['data']! as Map)['delta'], [
        {'insert': '书名：______ 5 * 3'},
      ]);
    });

    test('preset color names and hex colors both work', () {
      final node = first(
        '<span style="color: Blue">A</span><span style="color:#ff0000">B</span>',
      );
      expect((node['data']! as Map)['delta'], [
        {
          'insert': 'A',
          'attributes': {'font_color': '#FF3B7BE8'},
        },
        {
          'insert': 'B',
          'attributes': {'font_color': '#FFFF0000'},
        },
      ]);
    });

    test('blank lines are empty paragraphs and 4-space indents nest once', () {
      final document = aiTemplateBodyFromMarkdown('- a\n        - b\n\n- c');
      final children = (document['document']! as Map)['children'] as List;
      expect(children, hasLength(3));
      expect(((children[0] as Map)['children'] as List), hasLength(1));
      expect(((children[1] as Map)['data'] as Map)['delta'], isEmpty);
    });

    test('children of a heading are lifted to the same level', () {
      final document = aiTemplateBodyFromMarkdown('# Title\n  under');
      final children = (document['document']! as Map)['children'] as List;
      expect(children, hasLength(2));
    });

    test('images and media are dropped', () {
      final node = first('看 ![图](P1) 这里');
      expect((node['data']! as Map)['delta'], [
        {'insert': '看  这里'},
      ]);
    });

    test('unsafe links lose the link but keep the text', () {
      final node = first('[点我](javascript:alert(1))');
      expect((node['data']! as Map)['delta'], [
        {'insert': '点我'},
      ]);
    });
  });
}

Map<String, Object?> _table({required bool headerRow}) => {
  'type': 'table',
  'children': [
    for (var row = 0; row < 2; row++)
      for (var col = 0; col < 2; col++)
        {
          'type': 'table/cell',
          'children': [
            if (row == 1 && col == 1) ...[
              _p([
                _t('a|b', {'code': true}),
              ]),
              _p([], data: {'align': 'center'}),
              _p([
                _t('<br> ', {'bold': true}),
              ]),
            ] else
              _p([_t('格$row$col')]),
          ],
          'data': {'rowPosition': row, 'colPosition': col},
        },
  ],
  'data': {'colsLen': 2, 'rowsLen': 2, if (headerRow) 'headerRow': true},
};
