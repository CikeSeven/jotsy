import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/content_codec.dart';

export 'package:appflowy_editor/appflowy_editor.dart'
    show Document, Node, Selection, Position, Delta;

/// 日记编辑会话：持有 AppFlowy 文档、选区与事务，不参与路由、文件 IO 或写库。
/// 原生输入、工具栏与媒体操作都改同一份树，嵌套内容不会经平铺 Delta 往返。
/// 事务与选区通知合并到 Listenable，页面的自动保存链路继续读同步快照。
class DiaryEditorController extends ChangeNotifier {
  DiaryEditorController({
    af.Document? document,
    af.Selection? selection,
    bool readOnly = false,
  }) : state = af.EditorState(
         document: document ?? af.Document.blank(withInitialText: true),
       ) {
    state.editable = !readOnly;
    // 初始选区先于监听器赋值，也要遵循只读正文不留插入点的规则；否则
    // 首块是图片时，上游的 cover 光标会给整行盖一层灰色，并一直留在预览里。
    final initialSelection = readOnly && selection?.isCollapsed == true
        ? null
        : selection;
    state.selection = initialSelection;
    _lastSelection = initialSelection;
    _subscription = state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after &&
          event.$2.operations.isNotEmpty) {
        revision++;
        notifyListeners();
      }
    });
    state.selectionNotifier.addListener(_onSelection);
    state.toggledStyleNotifier.addListener(notifyListeners);
  }

  factory DiaryEditorController.fromContent(
    String content, {
    bool readOnly = false,
  }) => DiaryEditorController(
    document: diaryEditorDocument(content),
    readOnly: readOnly,
  );

  final af.EditorState state;
  late final StreamSubscription<af.EditorTransactionValue> _subscription;
  int revision = 0;

  /// 正在拖动段落：块随手指实时挪到落点（`DiaryBlockDragSession`）。期间
  /// 视口不揭示光标——揭示引起的滚动会让手指下的落点继续变化，一路连锁。
  bool draggingBlock = false;
  int _views = 0;
  bool _disposeRequested = false;
  bool get isDisposed => _disposeRequested;
  af.Selection? _lastSelection;
  af.Document get document => state.document;
  af.Selection? get selection {
    final current = state.selection ?? _lastSelection;
    return current != null && document.nodeAtPath(current.end.path) != null
        ? current
        : null;
  }

  void _onSelection() {
    if (_isReadOnlyCaret) {
      // 只读正文没有插入点，但上游点按（以及复制后收起选区）照样留下折叠
      // 选区，画出闪烁光标和 Android 的水滴把手。下一个微任务里清掉，赶在
      // 光标绘制（布局后回调）之前；不记进 _lastSelection，也不通知监听者。
      scheduleMicrotask(() {
        if (!state.isDisposed && _isReadOnlyCaret) state.selection = null;
      });
      return;
    }
    if (state.selection != null) _lastSelection = state.selection;
    notifyListeners();
  }

  /// 只读时不该出现的折叠选区。拖动选区把手或长按扩选途中选区可能暂时
  /// 折叠，上游后续的拖动更新依赖选区仍在，所以拖动中不算；拖动结束时
  /// 上游会再发一次不带拖动模式的选区更新，届时仍折叠才清掉。
  bool get _isReadOnlyCaret {
    final selection = state.selection;
    if (!readOnly || selection == null || !selection.isCollapsed) return false;
    // 上游未导出该键与 MobileSelectionDragMode，自身也在多处重复这个字面量。
    final dragMode = state.selectionExtraInfo?['selection_drag_mode'];
    return dragMode is! Enum || dragMode.name == 'none';
  }

  bool get readOnly => !state.editable;
  set readOnly(bool value) => state.editable = !value;
  String get contentJson => encodeDiaryBlocks(document.toJson());
  String get plainText => diaryBlocksPlainText(document.toJson());
  bool get hasContent => diaryBlocksHaveVisibleContent(document.toJson());

  /// 媒体导入失败时恢复提交前快照；恢复不进入撤销，避免失败的半次插入留下
  /// 无效历史路径。正常编辑、拖动、格式化都必须使用细粒度事务。
  void restoreContent(String content, {af.Selection? selection}) {
    final restored = diaryEditorDocument(content);
    final transaction = state.transaction
      ..insertNodes([0], restored.root.children.toList())
      ..deleteNodes(document.root.children.toList())
      ..afterSelection = selection;
    apply(transaction, recordUndo: false);
    state.undoManager.undoStack.clear();
    state.undoManager.redoStack.clear();
  }

  List<af.Node> get selectedNodes {
    final selection = this.selection;
    return selection == null
        ? const []
        : state.getNodesInSelection(selection.normalized);
  }

  /// 选区横跨不同格式时仅返回共同属性；折叠选区同时考虑“接下来输入”的样式。
  Map<String, dynamic> get selectionAttributes {
    final selection = this.selection;
    if (selection == null) return const {};
    final normalized = selection.normalized;
    if (normalized.isCollapsed) {
      final delta = document.nodeAtPath(normalized.end.path)?.delta;
      return {
        ...?delta?.sliceAttributes(normalized.end.offset),
        ...state.toggledStyle,
      };
    }
    final result = <String, dynamic>{};
    var first = true;
    for (final node in selectedNodes) {
      final delta = node.delta;
      if (delta == null) continue;
      final start = node.path.equals(normalized.start.path)
          ? normalized.start.offset
          : 0;
      final end = node.path.equals(normalized.end.path)
          ? normalized.end.offset
          : delta.length;
      for (final op in delta.slice(
        start.clamp(0, delta.length),
        end.clamp(0, delta.length),
      )) {
        final attributes = op.attributes ?? const <String, dynamic>{};
        if (first) {
          result.addAll(attributes);
          first = false;
        } else {
          result.removeWhere((key, value) => attributes[key] != value);
        }
      }
    }
    return result;
  }

  void select(af.Selection? selection) {
    final restoreToggled =
        state.selection == null && selection == _lastSelection
        ? Map<String, dynamic>.of(state.toggledStyle)
        : const <String, dynamic>{};
    unawaited(state.updateSelectionWithReason(selection));
    // 颜色代码输入框和正文交接焦点时，上游会暂时清空选区。恢复同一选区
    // 不能清掉刚在折叠光标上设置的“下次输入”格式；真正换选区仍按上游清空。
    for (final entry in restoreToggled.entries) {
      state.updateToggledStyle(entry.key, entry.value);
    }
  }

  void format(String key, Object? value) {
    final selection = this.selection;
    if (selection == null || readOnly) return;
    if (selection.isCollapsed) {
      state.updateToggledStyle(key, value);
    } else {
      final normalized = selection.normalized;
      final transaction = state.transaction;
      for (final node in selectedNodes) {
        final delta = node.delta;
        if (delta == null) continue;
        final from = node.path.equals(normalized.start.path)
            ? normalized.start.offset
            : 0;
        final to = node.path.equals(normalized.end.path)
            ? normalized.end.offset
            : delta.length;
        transaction.formatText(node, from, to - from, {key: value});
      }
      transaction.afterSelection = selection;
      apply(transaction);
    }
  }

  void toggle(String key) =>
      format(key, selectionAttributes[key] == true ? null : true);

  void formatSelection(MapEntry<String, Object?> attribute) =>
      format(attribute.key, attribute.value);

  Map<String, Object?> get activeAttributes {
    final nodes = selectedNodes;
    return {
      ...selectionAttributes,
      if (nodes.isNotEmpty &&
          nodes.every((node) => node.type == nodes.first.type))
        'type': nodes.first.type,
      if (nodes.isNotEmpty) 'depth': nodes.first.path.length - 1,
      if (nodes.isNotEmpty) 'level': nodes.first.attributes['level'],
    };
  }

  void setBlockType(String type, {Map<String, dynamic> attributes = const {}}) {
    if (readOnly) return;
    final transaction = state.transaction;
    for (final node in selectedNodes) {
      if (node.delta == null) continue;
      transaction.updateNodeType(node, type, {
        kDiaryBlockDeltaKey: node.delta!.toJson(),
        if (node.attributes['align'] case final align?) 'align': align,
        ...attributes,
      });
    }
    transaction.afterSelection = selection;
    apply(transaction);
  }

  void apply(
    af.Transaction transaction, {
    bool allowReadOnly = false,
    bool recordUndo = true,
    bool updateSelection = true,
  }) {
    unawaited(
      state.apply(
        transaction,
        skipEditableCheck: allowReadOnly,
        options: af.ApplyOptions(
          source: recordUndo
              ? af.TransactionSource.userEdit
              : af.TransactionSource.none,
        ),
        skipHistoryDebounce: true,
        withUpdateSelection: updateSelection,
      ),
    );
  }

  void undo() => state.undoManager.undo();
  void redo() => state.undoManager.redo();
  bool get hasUndo => state.undoManager.undoStack.isNonEmpty;
  bool get hasRedo => state.undoManager.redoStack.isNonEmpty;

  void attachView() => _views++;
  void detachView() {
    _views--;
    _releaseStateIfUnused();
  }

  void _releaseStateIfUnused() {
    if (!_disposeRequested || _views != 0 || state.isDisposed) return;
    // Flutter 先释放父 State 再卸载子 Element。等本轮同步卸载结束后再释放
    // 上游 notifier，键盘、选区与块组件才能正常注销各自的监听。更换模板、
    // 预览翻页和正常返回共用此生命周期，不依赖“还会不会再来一帧”。
    scheduleMicrotask(() {
      if (_views == 0 && !state.isDisposed) state.dispose();
    });
  }

  @override
  void dispose() {
    if (_disposeRequested) return;
    _disposeRequested = true;
    state.selectionNotifier.removeListener(_onSelection);
    state.toggledStyleNotifier.removeListener(notifyListeners);
    unawaited(_subscription.cancel());
    _releaseStateIfUnused();
    super.dispose();
  }
}

/// 输入为任一代存储内容。通过 JSON 做隔离，编辑会话不能改动模板或缓存快照。
af.Document diaryEditorDocument(String content) {
  return decodeDiaryContentToDocument(content);
}

Iterable<af.Node> walkDiaryEditorNodes(af.Document document) sync* {
  Iterable<af.Node> visit(Iterable<af.Node> nodes) sync* {
    for (final node in nodes) {
      yield node;
      yield* visit(node.children);
    }
  }

  yield* visit(document.root.children);
}

/// 历史模板变量展开仍以平铺字符偏移报告光标；只在装入模板时换算一次，
/// 编辑中的选区始终使用原生 Path + offset。
af.Selection diaryEditorSelectionAtOffset(af.Document document, int offset) {
  var remaining = offset.clamp(0, 1 << 30);
  final nodes = walkDiaryEditorNodes(document).toList();
  for (final node in nodes) {
    final length = node.delta?.length ?? 1;
    if (remaining <= length) {
      return af.Selection.collapsed(
        af.Position(path: node.path, offset: remaining),
      );
    }
    remaining -= length + 1;
  }
  final last = nodes.last;
  return af.Selection.collapsed(
    af.Position(path: last.path, offset: last.delta?.length ?? 1),
  );
}
