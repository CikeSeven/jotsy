import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_from_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';

/// 文字日记 → 导图：标题定层级，列表按嵌套挂在最近的标题下，段落成为主题，
/// 代码块等不进导图。
void main() {
  Map<String, Object?> document(List<Map<String, Object?>> children) =>
      <String, Object?>{
        'document': <String, Object?>{'type': 'page', 'children': children},
      };

  Map<String, Object?> block(
    String type,
    String text, {
    Map<String, Object?> data = const <String, Object?>{},
    List<Map<String, Object?>> children = const <Map<String, Object?>>[],
  }) => <String, Object?>{
    'type': type,
    'data': <String, Object?>{
      ...data,
      'delta': <Object?>[
        if (text.isNotEmpty) <String, Object?>{'insert': text},
      ],
    },
    if (children.isNotEmpty) 'children': children,
  };

  Map<String, Object?> heading(int level, String text) =>
      block('heading', text, data: <String, Object?>{'level': level});

  test('headings set the levels; lists, paragraphs and quotes hang under the '
      'nearest heading', () {
    final map = mindMapFromDiaryBlocks(
      document(<Map<String, Object?>>[
        block('paragraph', 'Opening thought'),
        heading(1, 'Work'),
        block(
          'bulleted_list',
          'Ship release',
          children: <Map<String, Object?>>[block('bulleted_list', 'Notes')],
        ),
        heading(2, 'Meetings'),
        block('quote', 'Keep them short'),
        heading(1, 'Home'),
        block('todo_list', 'Laundry', data: <String, Object?>{'checked': true}),
        block('todo_list', 'Groceries'),
        block('code', 'print(1)'),
        block('paragraph', ''),
      ]),
      title: '  Monday  ',
    );
    expect(
      mindMapOutlineText(map, untitled: ''),
      'Monday\n'
      '- Opening thought\n'
      '- Work\n'
      '  - Ship release\n'
      '    - Notes\n'
      '  - Meetings\n'
      '    - Keep them short\n'
      '- Home\n'
      '  - Laundry\n'
      '  - Groceries',
    );
    final home = map.root.children.last;
    expect(home.children.first.taskDone, isTrue);
    expect(home.children.last.isTask, isTrue);
    expect(home.children.last.taskDone, isFalse);
    expect(map.root.id, 'root');
  });

  test('without a title the first heading becomes the central topic', () {
    final map = mindMapFromDiaryBlocks(
      document(<Map<String, Object?>>[
        heading(2, 'Book notes'),
        heading(3, 'Chapter 1'),
        block('numbered_list', 'Idea'),
      ]),
      title: '',
    );
    expect(map.root.text, 'Book notes');
    expect(map.root.children.single.text, 'Chapter 1');
    expect(map.root.children.single.children.single.text, 'Idea');
  });

  test('an embedded mind map joins as a subtree where it sits', () {
    final embedded = MindMapDocument.blank(
      text: 'Plan',
    ).copyWith(root: mindMapNodeFromOutline('Plan\n  Step')!);
    final map = mindMapFromDiaryBlocks(
      document(<Map<String, Object?>>[
        heading(1, 'Project'),
        mindMapBlockNode(embedded),
      ]),
      title: 'Diary',
    );
    expect(
      mindMapOutlineText(map, untitled: ''),
      'Diary\n- Project\n  - Plan\n    - Step',
    );
    final ids = <String>{};
    void collect(MindMapNode node) {
      expect(ids.add(node.id), isTrue);
      node.children.forEach(collect);
    }

    collect(map.root);
  });

  test('an empty diary gives a map with only an empty central topic', () {
    final map = mindMapFromDiaryBlocks(
      document(const <Map<String, Object?>>[]),
      title: '',
    );
    expect(mindMapHasOnlyRoot(map), isTrue);
  });
}
