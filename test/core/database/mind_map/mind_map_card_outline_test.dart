import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';

/// 日记卡片上的导图大纲：从一级主题排起，按大纲顺序展示到二级，行数用完
/// 截断，不看画布上的收起状态。
void main() {
  MindMapDocument map(String outline) =>
      MindMapDocument.blank().copyWith(root: mindMapNodeFromOutline(outline)!);

  List<String> rows(List<MindMapOutlineLine> lines) => <String>[
    for (final line in lines) '${'  ' * (line.depth - 1)}${line.text}',
  ];

  final week = map(
    'Week\n'
    '  Mon\n'
    '    Gym\n'
    '      Legs\n'
    '    Read\n'
    '  Tue\n'
    '    Swim\n'
    '  Wed',
  );

  test('the outline lists first- and second-level topics in outline order, '
      'leaving out deeper ones', () {
    expect(rows(mindMapCardOutline(week, maxLines: 20)), <String>[
      'Mon',
      '  Gym',
      '  Read',
      'Tue',
      '  Swim',
      'Wed',
    ]);
  });

  test('many top-level topics still show their sub-topics; running out of '
      'lines cuts the later branches', () {
    final busy = map(
      'Plan\n'
      '  A\n    a1\n    a2\n'
      '  B\n    b1\n'
      '  C\n    c1\n'
      '  D\n  E\n  F\n  G',
    );
    expect(rows(mindMapCardOutline(busy, maxLines: 6)), <String>[
      'A',
      '  a1',
      '  a2',
      'B',
      '  b1',
      'C',
    ]);
  });

  test('a deeper limit can be asked for', () {
    expect(rows(mindMapCardOutline(week, maxLines: 4, maxDepth: 3)), <String>[
      'Mon',
      '  Gym',
      '    Legs',
      '  Read',
    ]);
  });

  test('topics collapsed on the canvas still list their sub-topics', () {
    final folded = week.copyWith(
      root: week.root.copyWith(
        collapsed: true,
        children: <MindMapNode>[
          week.root.children.first.copyWith(collapsed: true),
          ...week.root.children.skip(1),
        ],
      ),
    );
    expect(rows(mindMapCardOutline(folded, maxLines: 3)), <String>[
      'Mon',
      '  Gym',
      '  Read',
    ]);
  });

  test('line breaks inside a topic collapse into spaces; a map with only the '
      'central topic has no outline', () {
    final multiLine = MindMapDocument.blank().copyWith(
      root: MindMapNode(
        id: 'root',
        text: 'Root',
        children: const <MindMapNode>[
          MindMapNode(id: 'a', text: 'First\n line'),
          MindMapNode(id: 'b', text: ''),
        ],
      ),
    );
    expect(
      mindMapCardOutline(multiLine, maxLines: 4).map((line) => line.text),
      <String>['First line', ''],
    );
    expect(
      mindMapCardOutline(MindMapDocument.blank(text: 'Solo'), maxLines: 4),
      isEmpty,
    );
    expect(mindMapCardOutline(week, maxLines: 0), isEmpty);
  });
}
