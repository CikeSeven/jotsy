import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_rich_text.dart';

/// 主题文字的局部样式：delta 的容错读取与写出、改字时样式跟着字走、切换
/// 样式按整条取值去冗余、压成一行时不错位。
void main() {
  const bold = InlineTextMarks(bold: true);
  const red = InlineTextMarks(color: '#FFE53935');

  MindMapNode node(String text, List<Object?> delta) =>
      MindMapDocument.decode(<String, Object?>{
        'root': <String, Object?>{'id': 'root', 'text': text, 'delta': delta},
      }).root;

  group('读取与写出', () {
    test('拼得上文字的 delta 按段读出，相邻同样式的段合并', () {
      final runs = mindMapRunsOf(
        node('项目计划与预算', <Object?>[
          <String, Object?>{'insert': '项目'},
          <String, Object?>{
            'insert': '计',
            'attributes': <String, Object?>{'bold': true},
          },
          <String, Object?>{
            'insert': '划',
            'attributes': <String, Object?>{'bold': true},
          },
          <String, Object?>{'insert': '与预算'},
        ]),
      );
      expect(runs, const <InlineTextRun>[
        InlineTextRun('项目'),
        InlineTextRun('计划', bold),
        InlineTextRun('与预算'),
      ]);
    });

    test('拼不上文字的 delta（旧版本改过文字）按没有样式读，也不再写出', () {
      final stale = node('新文字', <Object?>[
        <String, Object?>{
          'insert': '旧',
          'attributes': <String, Object?>{'bold': true},
        },
      ]);
      expect(mindMapRunsOf(stale), const <InlineTextRun>[InlineTextRun('新文字')]);
      expect(mindMapHasRichText(stale), isFalse);
      expect(stale.toJson().containsKey('delta'), isFalse);
    });

    test('认不出的属性原样写回，坏类型的属性按没设处理', () {
      final source = node('ab', <Object?>[
        <String, Object?>{
          'insert': 'a',
          'attributes': <String, Object?>{
            'bold': 'yes',
            'color': 'not-a-color',
            'future': 1,
          },
        },
        <String, Object?>{
          'insert': 'b',
          'attributes': <String, Object?>{'italic': true},
        },
      ]);
      final runs = mindMapRunsOf(source);
      expect(runs.first.marks.bold, isNull);
      expect(runs.first.marks.color, isNull);
      expect(runs.first.marks.extra, <String, Object?>{'future': 1});
      final encoded = encodeInlineDelta(runs)!;
      expect(encoded.first['attributes'], <String, Object?>{'future': 1});
      expect(encoded.last['attributes'], <String, Object?>{'italic': true});
    });

    test('一个样式都没有时不写 delta', () {
      expect(
        encodeInlineDelta(const <InlineTextRun>[
          InlineTextRun('a'),
          InlineTextRun('b'),
        ]),
        isNull,
      );
      final plain = node('ab', <Object?>[
        <String, Object?>{'insert': 'ab'},
      ]);
      expect(plain.toJson().containsKey('delta'), isFalse);
    });
  });

  group('改字时样式跟着字走', () {
    const runs = <InlineTextRun>[
      InlineTextRun('ab'),
      InlineTextRun('CD', bold),
      InlineTextRun('ef'),
    ];

    test('在段中间插入继承前一个字', () {
      expect(remapRunsAfterEdit(runs, 'abCxDef'), const <InlineTextRun>[
        InlineTextRun('ab'),
        InlineTextRun('CxD', bold),
        InlineTextRun('ef'),
      ]);
    });

    test('紧跟在粗体之后插入也是粗体，开头插入继承第一个字', () {
      expect(
        remapRunsAfterEdit(runs, 'abCDxef')[1],
        const InlineTextRun('CDx', bold),
      );
      final atStart = remapRunsAfterEdit(const <InlineTextRun>[
        InlineTextRun('AB', bold),
      ], 'xAB');
      expect(atStart, const <InlineTextRun>[InlineTextRun('xAB', bold)]);
    });

    test('设了接下来打的字的样式时新字用它', () {
      expect(
        remapRunsAfterEdit(runs, 'abxCDef', pending: red),
        const <InlineTextRun>[
          InlineTextRun('ab'),
          InlineTextRun('x', red),
          InlineTextRun('CD', bold),
          InlineTextRun('ef'),
        ],
      );
    });

    test('跨段删除只留下两侧的字', () {
      expect(remapRunsAfterEdit(runs, 'aDef'), const <InlineTextRun>[
        InlineTextRun('a'),
        InlineTextRun('D', bold),
        InlineTextRun('ef'),
      ]);
    });

    test('替换选中的字取被替换的第一个字的样式', () {
      expect(remapRunsAfterEdit(runs, 'abXYZef'), const <InlineTextRun>[
        InlineTextRun('ab'),
        InlineTextRun('XYZ', bold),
        InlineTextRun('ef'),
      ]);
    });

    test('不切开代理对', () {
      final before = <InlineTextRun>[
        const InlineTextRun('a'),
        const InlineTextRun('😀', bold),
      ];
      // 😀 与 😃 的高位代理相同：公共前缀会停在代理对中间。
      final after = remapRunsAfterEdit(before, 'a😃');
      expect(after, const <InlineTextRun>[
        InlineTextRun('a'),
        InlineTextRun('😃', bold),
      ]);
    });

    test('MindMapOps.setText 改字后 delta 跟着走', () {
      final document = MindMapDocument.decode(<String, Object?>{
        'root': <String, Object?>{
          'id': 'root',
          'text': 'abCD',
          'delta': <Object?>[
            <String, Object?>{'insert': 'ab'},
            <String, Object?>{
              'insert': 'CD',
              'attributes': <String, Object?>{'bold': true},
            },
          ],
        },
      });
      final next = MindMapOps.setText(document, 'root', 'xabCD');
      expect(mindMapRunsOf(next.root), const <InlineTextRun>[
        InlineTextRun('xab'),
        InlineTextRun('CD', bold),
      ]);
      final cleared = MindMapOps.setText(next, 'root', '');
      expect(cleared.root.delta, isNull);
    });
  });

  group('设样式', () {
    test('选中的字切换粗体，再切一次取消', () {
      const runs = <InlineTextRun>[InlineTextRun('项目计划')];
      final on = toggleMark(runs, 2, 4, InlineMark.bold, base: false);
      expect(on, const <InlineTextRun>[
        InlineTextRun('项目'),
        InlineTextRun('计划', bold),
      ]);
      expect(toggleMark(on, 2, 4, InlineMark.bold, base: false), runs);
    });

    test('整条是粗体时局部取消写成 false，再打开时去掉属性', () {
      const runs = <InlineTextRun>[InlineTextRun('中心主题')];
      final off = toggleMark(runs, 0, 2, InlineMark.bold, base: true);
      expect(
        off.first,
        const InlineTextRun('中心', InlineTextMarks(bold: false)),
      );
      expect(toggleMark(off, 0, 2, InlineMark.bold, base: true), runs);
    });

    test('选区里有一部分开着时先全部打开', () {
      const runs = <InlineTextRun>[
        InlineTextRun('ab', bold),
        InlineTextRun('cd'),
      ];
      expect(
        toggleMark(runs, 0, 4, InlineMark.bold, base: false),
        const <InlineTextRun>[InlineTextRun('abcd', bold)],
      );
    });

    test('formatText 只改范围里的字，clearMindMapMark 去掉同名属性', () {
      final document = MindMapDocument.blank(text: 'abcd');
      final next = MindMapOps.formatText(
        document,
        'root',
        1,
        3,
        (marks) => marks.withColor(InlineColorMark.highlight, '#FFFDD835'),
      );
      final runs = mindMapRunsOf(next.root);
      expect(
        inlineCommonColor(runs, 1, 3, InlineColorMark.highlight),
        '#FFFDD835',
      );
      expect(inlineCommonColor(runs, 0, 3, InlineColorMark.highlight), isNull);
      expect(
        clearMindMapMark(runs, InlineColorMark.highlight.key),
        const <InlineTextRun>[InlineTextRun('abcd')],
      );
    });
  });

  test('压成一行时样式不错位', () {
    const runs = <InlineTextRun>[
      InlineTextRun('  ab \n '),
      InlineTextRun('CD', bold),
      InlineTextRun('\nef  '),
    ];
    expect(oneLineMindMapRuns(runs), const <InlineTextRun>[
      InlineTextRun('ab '),
      InlineTextRun('CD ', bold),
      InlineTextRun('ef'),
    ]);
    expect(inlineRunsText(oneLineMindMapRuns(runs)), 'ab CD ef');
  });
}
