import 'diary_blocks_schema.dart';

/// 从按阅读顺序到达的块建立子树：旧缩进跳级时就近降到合法父块下，遇到
/// 不画子块的块（标题、引用、代码块、媒体）挂到更外层。
/// 历史格式转换和第三方导入共用这一条规则，输出键序与编辑器 Node 一致。
class DiaryBlocksBuilder {
  final _root = <Map<String, Object?>>[];
  final _stack = <Map<String, Object?>>[];

  void add(Map<String, Object?> node, int indent) {
    var depth = indent.clamp(0, _stack.length);
    while (depth > 0 &&
        !kDiaryContainerBlockTypes.contains(_stack[depth - 1]['type'])) {
      depth--;
    }
    if (depth == 0) {
      _root.add(node);
    } else {
      final parent = _stack[depth - 1];
      ((parent[kDiaryBlockChildrenKey] ??= <Map<String, Object?>>[])
              as List<Map<String, Object?>>)
          .add(node);
    }
    _stack
      ..length = depth
      ..add(node);
  }

  Map<String, Object?> build() => {
    'document': {
      'type': 'page',
      'children': [
        if (_root.isEmpty)
          {
            'type': 'paragraph',
            'data': {'delta': <Object?>[]},
          },
        ..._root.map(_ordered),
      ],
    },
  };

  Map<String, Object?> _ordered(Map<String, Object?> node) => {
    'type': node['type'],
    if (node['children'] case final List<Map<String, Object?>> children)
      'children': children.map(_ordered).toList(),
    if (node['data'] case final data?) 'data': data,
  };
}
