import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_lock_flow.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_tree_rows.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

/// 嵌套的界面口径：树形行与缩进、兄弟间拖动换算、私密继承的提示来源，以及
/// 同一上锁范围里切换不再验证。
NotebookRow _row(
  String id, {
  String? parent,
  int order = 0,
  NotebookKind kind = NotebookKind.manual,
  NotebookVisibility visibility = NotebookVisibility.normal,
  bool closed = false,
}) {
  final now = DateTime(2026, 10, 1);
  return NotebookRow(
    id: id.hashCode,
    notebookId: id,
    name: id,
    kind: kind.name,
    visibility: visibility.name,
    payload: NotebookPayload.defaults.encode(),
    sortOrder: order,
    isPinned: false,
    isClosed: closed,
    createdAt: now,
    updatedAt: now,
    parentId: parent,
  );
}

List<(String, int)> _flat(List<NotebookTreeRow> rows) => <(String, int)>[
  for (final row in rows) (row.notebook.id, row.indent),
];

void main() {
  // 旅行 > 2025 > 东京；旅行 > 2024；读书（顶层）；照片（智能，旅行的子本）。
  final tree = NotebookTree(<NotebookRow>[
    _row('旅行', order: 0),
    _row('2025', parent: '旅行', order: 1),
    _row('东京', parent: '2025', order: 2),
    _row('2024', parent: '旅行', order: 3, closed: true),
    _row('读书', order: 4),
    _row('照片', parent: '旅行', order: 5, kind: NotebookKind.smart),
  ]);

  test('tree rows follow depth-first order with indents per level', () {
    expect(_flat(notebookTreeRows(tree)), <(String, int)>[
      ('旅行', 0),
      ('2025', 1),
      ('东京', 2),
      ('2024', 1),
      ('照片', 1),
      ('读书', 0),
    ]);
  });

  test('a filtered-out parent lifts its children one level', () {
    final rows = notebookTreeRows(
      tree,
      include: (notebook) => notebook.id != '2025',
    );
    expect(_flat(rows), contains(('东京', 1)));
  });

  test('subtree rows list every descendant under its root', () {
    expect(
      _flat(notebookSubtreeRows(tree, <NotebookView>[tree['旅行']!])),
      <(String, int)>[
        ('旅行', 0),
        ('2025', 1),
        ('东京', 2),
        ('2024', 1),
        ('照片', 1),
      ],
    );
  });

  group('sibling order after a drag', () {
    final ids = <String>['旅行', '2025', '东京', '2024', '照片', '读书'];
    String? parentOf(String id) => tree[id]!.parentId;

    test('moving a child up reorders it among its siblings', () {
      // 把“照片”拖到“2025”前面。
      expect(notebookSiblingOrderAfterDrag(ids, 4, 1, parentOf), <String>[
        '照片',
        '2025',
        '2024',
      ]);
    });

    test('dropping into another subtree keeps the parent', () {
      // 把“读书”拖进“旅行”的子本中间：仍是顶层，排在“旅行”之后（原位）。
      expect(notebookSiblingOrderAfterDrag(ids, 5, 2, parentOf), <String>[
        '旅行',
        '读书',
      ]);
      // 把“2025”拖到最底下：只是排到兄弟最后。
      expect(notebookSiblingOrderAfterDrag(ids, 1, 5, parentOf), <String>[
        '2024',
        '照片',
        '2025',
      ]);
    });
  });

  test('inherited privacy names the nearest parent that set it', () {
    final private = NotebookTree(<NotebookRow>[
      _row('保险箱', visibility: NotebookVisibility.locked),
      _row('日常', parent: '保险箱', order: 1),
      _row('隐藏', visibility: NotebookVisibility.hidden, order: 2),
    ]);
    final locked = notebookInheritedPrivacy(
      private,
      private['日常'],
      NotebookVisibility.normal,
    );
    expect(locked?.source.id, '保险箱');
    expect(locked?.visibility, NotebookVisibility.locked);
    // 自己已经同样严格时不提示。
    expect(
      notebookInheritedPrivacy(
        private,
        private['保险箱'],
        NotebookVisibility.locked,
      ),
      isNull,
    );
    expect(
      notebookInheritedPrivacy(
        private,
        private['隐藏'],
        NotebookVisibility.normal,
      )?.visibility,
      NotebookVisibility.hidden,
    );
    expect(
      notebookInheritedPrivacy(private, null, NotebookVisibility.normal),
      isNull,
    );
  });

  test('switching inside one lock scope needs no new authentication', () {
    final locks = NotebookTree(<NotebookRow>[
      _row('保险箱', visibility: NotebookVisibility.locked),
      _row('日常', parent: '保险箱', order: 1),
      _row('旅行', order: 2),
      _row('日记', parent: '旅行', order: 3, visibility: NotebookVisibility.locked),
    ]);
    // 从全部日记进入：要验证。
    expect(notebookSwitchRequiresAuth(locks, locks['日常']!), isTrue);
    // 上锁的父本与随之上锁的子本之间：不再验证。
    expect(
      notebookSwitchRequiresAuth(locks, locks['日常']!, fromId: '保险箱'),
      isFalse,
    );
    expect(
      notebookSwitchRequiresAuth(locks, locks['保险箱']!, fromId: '日常'),
      isFalse,
    );
    // 普通父本里进入自己上了锁的子本：仍要验证；回到父本不用。
    expect(
      notebookSwitchRequiresAuth(locks, locks['日记']!, fromId: '旅行'),
      isTrue,
    );
    expect(
      notebookSwitchRequiresAuth(locks, locks['旅行']!, fromId: '日记'),
      isFalse,
    );
    // 不同的上锁范围之间：要验证。
    expect(
      notebookSwitchRequiresAuth(locks, locks['日记']!, fromId: '保险箱'),
      isTrue,
    );
  });
}
