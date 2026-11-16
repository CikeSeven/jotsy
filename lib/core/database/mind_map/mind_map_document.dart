import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'mind_map_rich_text.dart';
import 'mind_map_schema.dart';

/// 思维导图文档的不可变模型与容错编解码（纯 Dart）。
///
/// 输入为存储 JSON（正文 `mind_map` 块的 `data.map`），输出为模型；写回经
/// [MindMapDocument.toJson]。读取规则：
/// - 字段类型不对时按缺省处理，绝不抛出；
/// - 认不出的键原样保留在 `extra`，写回时一并写出（新版本写出的字段在旧版本
///   里编辑后不丢）；结构、主题等枚举类取值也只存原文；
/// - 缺少或重复的节点 id 按节点在树中的位置补一个确定的 id（同一份原文每次
///   读出的 id 相同，不会因为打开一次就产生“改动”）；
/// - 超过 [kMindMapParseDepthLimit] 的子树不解析，原文留在该节点的 `extra`。
///
/// 模型不可变：编辑一律经 mind_map_ops.dart 返回新文档，未改动的子树原样
/// 共享，撤销栈只存文档引用。

/// `copyWith` 里区分“不改”与“改为 null”的占位。
const Object _unset = Object();

/// 一个节点。
@immutable
final class MindMapNode {
  const MindMapNode({
    required this.id,
    this.text = '',
    this.delta,
    this.children = const <MindMapNode>[],
    this.collapsed = false,
    this.side,
    this.style = const <String, Object?>{},
    this.icons = const <String>[],
    this.labels = const <String>[],
    this.note,
    this.href,
    this.image,
    this.task,
    this.boundary,
    this.extra = const <String, Object?>{},
  });

  final String id;
  final String text;

  /// 文字的局部样式原文（[kMindMapNodeDeltaKey]）；null 为没有。只存原文
  /// （认不出的属性不丢），解析、校验与改写只经 mind_map_rich_text.dart。
  final List<Map<String, Object?>>? delta;
  final List<MindMapNode> children;

  /// 子节点是否收起（没有子节点时无意义，照样保存）。
  final bool collapsed;

  /// 根的子节点固定的一侧（[kMindMapSideLeft] / [kMindMapSideRight]）。
  final String? side;

  /// 样式覆盖，键见 mind_map_schema.dart；读写经 [MindMapNodeStyle]。
  final Map<String, Object?> style;
  final List<String> icons;
  final List<String> labels;
  final String? note;
  final String? href;
  final Map<String, Object?>? image;

  /// 待办：`{"done": bool}`；null 为不是待办。
  final Map<String, Object?>? task;

  /// 外框：`{"text": 标题}`；null 为没有外框。
  final Map<String, Object?>? boundary;

  /// 认不出的键，原样写回。
  final Map<String, Object?> extra;

  bool get hasChildren => children.isNotEmpty;
  bool get isTask => task != null;
  bool get taskDone => task?['done'] == true;

  MindMapNode copyWith({
    String? id,
    String? text,
    Object? delta = _unset,
    List<MindMapNode>? children,
    bool? collapsed,
    Object? side = _unset,
    Map<String, Object?>? style,
    List<String>? icons,
    List<String>? labels,
    Object? note = _unset,
    Object? href = _unset,
    Object? image = _unset,
    Object? task = _unset,
    Object? boundary = _unset,
    Map<String, Object?>? extra,
  }) => MindMapNode(
    id: id ?? this.id,
    text: text ?? this.text,
    delta: identical(delta, _unset)
        ? this.delta
        : delta as List<Map<String, Object?>>?,
    children: children ?? this.children,
    collapsed: collapsed ?? this.collapsed,
    side: identical(side, _unset) ? this.side : side as String?,
    style: style ?? this.style,
    icons: icons ?? this.icons,
    labels: labels ?? this.labels,
    note: identical(note, _unset) ? this.note : note as String?,
    href: identical(href, _unset) ? this.href : href as String?,
    image: identical(image, _unset)
        ? this.image
        : image as Map<String, Object?>?,
    task: identical(task, _unset) ? this.task : task as Map<String, Object?>?,
    boundary: identical(boundary, _unset)
        ? this.boundary
        : boundary as Map<String, Object?>?,
    extra: extra ?? this.extra,
  );

  /// 存储形状：空值与缺省值不写出，`extra` 先写、已知键覆盖在后。
  Map<String, Object?> toJson() => <String, Object?>{
    ...extra,
    kMindMapNodeIdKey: id,
    kMindMapNodeTextKey: text,
    // 只写出与文字对得上、且确有样式的局部样式（旧版本改过文字留下的、
    // 已经对不上的那份随这次保存丢掉）。
    if (delta case final delta? when inlineDeltaMatches(delta, text))
      kMindMapNodeDeltaKey: delta,
    if (children.isNotEmpty)
      kMindMapNodeChildrenKey: <Map<String, Object?>>[
        for (final child in children) child.toJson(),
      ],
    if (collapsed) kMindMapNodeCollapsedKey: true,
    kMindMapNodeSideKey: ?side,
    if (style.isNotEmpty) kMindMapNodeStyleKey: style,
    if (icons.isNotEmpty) kMindMapNodeIconsKey: icons,
    if (labels.isNotEmpty) kMindMapNodeLabelsKey: labels,
    if (note case final note? when note.isNotEmpty) kMindMapNodeNoteKey: note,
    if (href case final href? when href.isNotEmpty) kMindMapNodeHrefKey: href,
    kMindMapNodeImageKey: ?image,
    kMindMapNodeTaskKey: ?task,
    kMindMapNodeBoundaryKey: ?boundary,
  };

  static const Set<String> _knownKeys = <String>{
    kMindMapNodeIdKey,
    kMindMapNodeTextKey,
    kMindMapNodeDeltaKey,
    kMindMapNodeChildrenKey,
    kMindMapNodeCollapsedKey,
    kMindMapNodeSideKey,
    kMindMapNodeStyleKey,
    kMindMapNodeIconsKey,
    kMindMapNodeLabelsKey,
    kMindMapNodeNoteKey,
    kMindMapNodeHrefKey,
    kMindMapNodeImageKey,
    kMindMapNodeTaskKey,
    kMindMapNodeBoundaryKey,
  };
}

/// 一张导图。
@immutable
final class MindMapDocument {
  const MindMapDocument({
    required this.root,
    this.structure,
    this.theme,
    this.line,
    this.rainbow,
    this.spacing,
    this.grid,
    this.relations = const <Map<String, Object?>>[],
    this.summaries = const <Map<String, Object?>>[],
    this.extra = const <String, Object?>{},
  });

  /// 只有一个空根节点的导图。
  factory MindMapDocument.blank({
    String text = '',
    String? structure,
    String? theme,
    String? line,
    bool? rainbow,
    String? spacing,
    bool? grid,
  }) => MindMapDocument(
    root: MindMapNode(id: 'root', text: text),
    structure: structure,
    theme: theme,
    line: line,
    rainbow: rainbow,
    spacing: spacing,
    grid: grid,
  );

  final MindMapNode root;

  /// 结构 id 原文（如 `mind_map` / `logic_right`）；null 为缺省。
  final String? structure;
  final String? theme;
  final String? line;
  final bool? rainbow;
  final String? spacing;
  final bool? grid;

  /// 关系线与概要：首版只原样保留，界面与编辑在后续版本接上。
  final List<Map<String, Object?>> relations;
  final List<Map<String, Object?>> summaries;
  final Map<String, Object?> extra;

  static final Expando<MindMapIndex> _indexes = Expando<MindMapIndex>(
    'mindMapIndex',
  );

  /// 按 id 查节点、父节点与深度的索引（随文档缓存，文档不可变所以安全）。
  MindMapIndex get index => _indexes[this] ??= MindMapIndex(root);

  MindMapDocument copyWith({
    MindMapNode? root,
    Object? structure = _unset,
    Object? theme = _unset,
    Object? line = _unset,
    Object? rainbow = _unset,
    Object? spacing = _unset,
    Object? grid = _unset,
    List<Map<String, Object?>>? relations,
    List<Map<String, Object?>>? summaries,
  }) => MindMapDocument(
    root: root ?? this.root,
    structure: identical(structure, _unset)
        ? this.structure
        : structure as String?,
    theme: identical(theme, _unset) ? this.theme : theme as String?,
    line: identical(line, _unset) ? this.line : line as String?,
    rainbow: identical(rainbow, _unset) ? this.rainbow : rainbow as bool?,
    spacing: identical(spacing, _unset) ? this.spacing : spacing as String?,
    grid: identical(grid, _unset) ? this.grid : grid as bool?,
    relations: relations ?? this.relations,
    summaries: summaries ?? this.summaries,
    extra: extra,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    ...extra,
    kMindMapVersionKey: kMindMapVersion,
    kMindMapRootKey: root.toJson(),
    kMindMapStructureKey: ?structure,
    kMindMapThemeKey: ?theme,
    kMindMapLineKey: ?line,
    kMindMapRainbowKey: ?rainbow,
    kMindMapSpacingKey: ?spacing,
    kMindMapGridKey: ?grid,
    if (relations.isNotEmpty) kMindMapRelationsKey: relations,
    if (summaries.isNotEmpty) kMindMapSummariesKey: summaries,
  };

  /// 容错读取；不是对象或没有根节点时为一张空导图。
  factory MindMapDocument.decode(Object? raw) {
    if (raw is! Map) return MindMapDocument.blank();
    final map = raw.cast<String, Object?>();
    final used = <String>{};
    final root = _decodeNode(
      map[kMindMapRootKey],
      fallbackId: 'root',
      used: used,
      depth: 0,
    );
    return MindMapDocument(
      root: root,
      structure: _string(map[kMindMapStructureKey]),
      theme: _string(map[kMindMapThemeKey]),
      line: _string(map[kMindMapLineKey]),
      rainbow: _bool(map[kMindMapRainbowKey]),
      spacing: _string(map[kMindMapSpacingKey]),
      grid: _bool(map[kMindMapGridKey]),
      relations: _objectList(map[kMindMapRelationsKey]),
      summaries: _objectList(map[kMindMapSummariesKey]),
      extra: <String, Object?>{
        for (final entry in map.entries)
          if (!_documentKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const Set<String> _documentKeys = <String>{
    kMindMapVersionKey,
    kMindMapRootKey,
    kMindMapStructureKey,
    kMindMapThemeKey,
    kMindMapLineKey,
    kMindMapRainbowKey,
    kMindMapSpacingKey,
    kMindMapGridKey,
    kMindMapRelationsKey,
    kMindMapSummariesKey,
  };
}

MindMapNode _decodeNode(
  Object? raw, {
  required String fallbackId,
  required Set<String> used,
  required int depth,
}) {
  final map = raw is Map
      ? raw.cast<String, Object?>()
      : const <String, Object?>{};
  final rawId = _string(map[kMindMapNodeIdKey]);
  String id;
  if (rawId != null && rawId.isNotEmpty && !used.contains(rawId)) {
    id = rawId;
  } else {
    id = fallbackId;
    while (used.contains(id)) {
      id = '${id}x';
    }
  }
  used.add(id);
  final extra = <String, Object?>{
    for (final entry in map.entries)
      if (!MindMapNode._knownKeys.contains(entry.key)) entry.key: entry.value,
  };
  final rawChildren = map[kMindMapNodeChildrenKey];
  final children = <MindMapNode>[];
  if (rawChildren is List) {
    if (depth >= kMindMapParseDepthLimit) {
      // 过深的子树不再解析：原文挂在 extra 里，写回时原样写出。
      extra[kMindMapNodeChildrenKey] = rawChildren;
    } else {
      for (var i = 0; i < rawChildren.length; i++) {
        final child = rawChildren[i];
        if (child is! Map) continue;
        children.add(
          _decodeNode(
            child,
            fallbackId: '$fallbackId-$i',
            used: used,
            depth: depth + 1,
          ),
        );
      }
    }
  }
  final side = _string(map[kMindMapNodeSideKey]);
  final delta = _objectList(map[kMindMapNodeDeltaKey]);
  return MindMapNode(
    id: id,
    text: _string(map[kMindMapNodeTextKey]) ?? '',
    delta: delta.isEmpty ? null : delta,
    children: List<MindMapNode>.unmodifiable(children),
    collapsed: map[kMindMapNodeCollapsedKey] == true,
    side: side == kMindMapSideLeft || side == kMindMapSideRight ? side : null,
    style: _object(map[kMindMapNodeStyleKey]) ?? const <String, Object?>{},
    icons: _stringList(map[kMindMapNodeIconsKey]),
    labels: _stringList(map[kMindMapNodeLabelsKey]),
    note: _string(map[kMindMapNodeNoteKey]),
    href: _string(map[kMindMapNodeHrefKey]),
    image: _object(map[kMindMapNodeImageKey]),
    task: _object(map[kMindMapNodeTaskKey]),
    boundary: _object(map[kMindMapNodeBoundaryKey]),
    extra: extra,
  );
}

String? _string(Object? value) => value is String ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

Map<String, Object?>? _object(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(value.whereType<String>());
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return List<Map<String, Object?>>.unmodifiable(<Map<String, Object?>>[
    for (final item in value)
      if (item is Map) item.cast<String, Object?>(),
  ]);
}

/// 一张导图的只读索引：id → 节点 / 父节点 / 深度 / 在父节点里的位置，以及
/// 先序顺序。随文档缓存（[MindMapDocument.index]）。
final class MindMapIndex {
  MindMapIndex(this.root) {
    void visit(MindMapNode node, String? parent, int depth, int position) {
      _nodes[node.id] = node;
      _parents[node.id] = parent;
      _depths[node.id] = depth;
      _positions[node.id] = position;
      preorder.add(node.id);
      for (var i = 0; i < node.children.length; i++) {
        visit(node.children[i], node.id, depth + 1, i);
      }
    }

    visit(root, null, 0, 0);
  }

  final MindMapNode root;
  final Map<String, MindMapNode> _nodes = <String, MindMapNode>{};
  final Map<String, String?> _parents = <String, String?>{};
  final Map<String, int> _depths = <String, int>{};
  final Map<String, int> _positions = <String, int>{};
  final Map<String, int> _descendantCounts = <String, int>{};

  /// 全部节点 id，先序（与大纲、纯文本镜像同一顺序）。
  final List<String> preorder = <String>[];

  int get length => preorder.length;

  bool contains(String id) => _nodes.containsKey(id);

  MindMapNode? operator [](String id) => _nodes[id];

  String? parentOf(String id) => _parents[id];

  int depthOf(String id) => _depths[id] ?? 0;

  /// 在父节点子列表里的下标（根为 0）。
  int positionOf(String id) => _positions[id] ?? 0;

  /// 从根到 [id] 的祖先 id（不含它自己），根在前。
  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var current = _parents[id];
    while (current != null) {
      out.add(current);
      current = _parents[current];
    }
    return out.reversed.toList();
  }

  /// [ancestor] 是否为 [id] 本身或它的祖先。
  bool isSelfOrAncestor(String ancestor, String id) {
    String? current = id;
    while (current != null) {
      if (current == ancestor) return true;
      current = _parents[current];
    }
    return false;
  }

  /// 子孙节点总数（不含自己）。
  int descendantCountOf(String id) {
    final cached = _descendantCounts[id];
    if (cached != null) return cached;
    final node = _nodes[id];
    if (node == null) return 0;
    var count = 0;
    for (final child in node.children) {
      count += 1 + descendantCountOf(child.id);
    }
    return _descendantCounts[id] = count;
  }

  /// 根的第几个子节点的分支（根自身为 -1）：分支配色按它取色。
  int branchOf(String id) {
    String? current = id;
    while (current != null) {
      final parent = _parents[current];
      if (parent == null) return -1;
      if (parent == root.id) return _positions[current] ?? 0;
      current = parent;
    }
    return -1;
  }
}

/// 新节点 id：8 位小写字母与数字，[isTaken] 为真的不用。
String newMindMapNodeId(
  bool Function(String id) isTaken, [
  math.Random? random,
]) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = random ?? _random;
  while (true) {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    final id = buffer.toString();
    if (!isTaken(id)) return id;
  }
}

final math.Random _random = math.Random();
