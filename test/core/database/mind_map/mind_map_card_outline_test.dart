import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';

/// 日记卡片上的导图大纲：从一级主题排起，按层挑选、按先序排出，收起的
/// 主题不展开，行数与深度有上限。
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

  test('with room for everything the outline lists every topic below the '
      'central one in order', () {
    expect(rows(mindMapCardOutline(week, maxLines: 20)), <String>[
      'Mon',
      '  Gym',
      '    Legs',
      '  Read',
      'Tue',
      '  Swim',
      'Wed',
    ]);
  });

  test('few lines keep every top-level topic first, then fill sub-topics '
      'from the first branch on', () {
    expect(rows(mindMapCardOutline(week, maxLines: 3)), <String>[
      'Mon',
      'Tue',
      'Wed',
    ]);
    expect(rows(mindMapCardOutline(week, maxLines: 5)), <String>[
      'Mon',
      '  Gym',
      '  Read',
      'Tue',
      'Wed',
    ]);
    expect(rows(mindMapCardOutline(week, maxLines: 2)), <String>['Mon', 'Tue']);
  });

  test('topics deeper than the depth limit are left out', () {
    expect(rows(mindMapCardOutline(week, maxLines: 20, maxDepth: 2)), <String>[
      'Mon',
      '  Gym',
      '  Read',
      'Tue',
      '  Swim',
      'Wed',
    ]);
  });

  test('a collapsed topic keeps its sub-topics folded away; a collapsed '
      'central topic still lists its top-level topics', () {
    final mon = week.root.children.first;
    final folded = week.copyWith(
      root: week.root.copyWith(
        children: <MindMapNode>[
          mon.copyWith(collapsed: true),
          ...week.root.children.skip(1),
        ],
      ),
    );
    expect(rows(mindMapCardOutline(folded, maxLines: 20)), <String>[
      'Mon',
      'Tue',
      '  Swim',
      'Wed',
    ]);
    final rootFolded = week.copyWith(root: week.root.copyWith(collapsed: true));
    expect(rows(mindMapCardOutline(rootFolded, maxLines: 3)), <String>[
      'Mon',
      'Tue',
      'Wed',
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
  });
}
