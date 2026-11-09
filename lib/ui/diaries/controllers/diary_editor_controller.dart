import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 上游的自动滚动器类型未导出，EditorState.autoScroller 的覆盖要用到它。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/auto_scroller.dart'
    show AutoScroller;
import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/content_codec.dart';
import '../models/diary_link_candidate.dart';
import 'diary_block_convert.dart';
import 'diary_block_selection.dart';
import 'diary_link_typing.dart';
import 'diary_toggle_state.dart';

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
    this.linkSource,
  }) : state = _DiaryEditorState(
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
        _contentSnapshot = null;
        notifyListeners();
      }
    });
    state.selectionNotifier.addListener(_onSelection);
    state.toggledStyleNotifier.addListener(_onToggledStyle);
    (state as _DiaryEditorState).blockSelection = blockSelection;
  }

  factory DiaryEditorController.fromContent(
    String content, {
    bool readOnly = false,
    DiaryLinkSource? linkSource,
  }) => DiaryEditorController(
    document: diaryEditorDocument(content),
    readOnly: readOnly,
    linkSource: linkSource,
  );

  /// 在 [document] 里放在 [caret] 处的插入点：位置所指的块不存在或不是文字块
  /// 时为 null，偏移按块的文字长度夹取。用于从别处带来的位置（预览页双击
  /// 处）——那份文档与这里可能略有出入（预览里刚勾了待办还没写回）。
  static af.Selection? collapsedSelectionAt(
    af.Document document,
    af.Position caret,
  ) {
    final delta = document.nodeAtPath(caret.path)?.delta;
    if (delta == null) return null;
    return af.Selection.collapsed(
      af.Position(
        path: caret.path,
        offset: caret.offset.clamp(0, delta.length),
      ),
    );
  }

  final af.EditorState state;

  /// 折叠光标上设了网址后接着打字的链接输入会话（见 [DiaryLinkTyping]）。
  late final DiaryLinkTyping linkTyping = DiaryLinkTyping(state);

  /// 段落选择模式（点段落把手进入，见 [DiaryBlockSelection]）。
  late final DiaryBlockSelection blockSelection = DiaryBlockSelection(state);

  /// 能否插入日记链接（`@`、卡片命令、链接对话框的日记 / 日记本页）；
  /// null 即不能（模板编辑页、只读正文）。见 [DiaryLinkSource]。
  final DiaryLinkSource? linkSource;

  /// 选区菜单（手机选中后浮出的菜单、桌面右键菜单）里的“AI…”：编辑页在
  /// AI 写作可用时设置，菜单项只在有选中文字、可编辑且它不为 null 时出现。
  VoidCallback? aiSelectionHandler;

  /// 图片菜单里的“AI 描述图片”：编辑页在图片理解可用时设置，返回描述文字
  /// （取消或失败为 null）；为 null 时菜单里没有这一项。
  Future<String?> Function(String source)? aiImageDescriber;
  late final StreamSubscription<af.EditorTransactionValue> _subscription;
  int revision = 0;

  /// 只保留当前正文版本的两个存储镜像，不保留额外的 JSON 树。选区、待输入
  /// 格式、标题与 metadata 的变化不会改变正文，不能因此再次扫描长文。
  /// 原生输入、撤销/重做、拖动预览与失败恢复均经同步 transactionStream
  /// 的 after 事件失效；必须先失效再通知，保存监听者才不会读到上一版。
  ({String json, String text})? _contentSnapshot;

  /// 在 [action] 里发生的选区更新不接上输入法，也就不会把收起的软键盘拉起
  /// 来（上游每次选区变化都重新接上输入法，编辑值一变就 `show()`）。只用于
  /// 不输入文字的选区操作：软键盘收着时拖选区把手、复制后收成光标、全选；
  /// 调用方先确认软键盘收着（见 `holdHiddenKeyboard`）。之后点正文打字时
  /// 上游照常重新接上并弹出键盘。
  T holdingKeyboard<T>(T Function() action) {
    final state = this.state as _DiaryEditorState;
    state.holds++;
    try {
      return action();
    } finally {
      state.holds--;
    }
  }

  /// 正在拖动段落：块随手指实时挪到落点（`DiaryBlockDragSession`）。期间
  /// 视口不揭示光标——揭示引起的滚动会让手指下的落点继续变化，一路连锁。
  bool draggingBlock = false;
  int _views = 0;
  bool _disposeRequested = false;
  bool get isDisposed => _disposeRequested;
  af.Selection? _lastSelection;
  Map<String, dynamic> _lastToggledStyle = const {};
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
    if (state.selection != null) {
      _lastSelection = state.selection;
      _lastToggledStyle = Map.of(state.toggledStyle);
      // 段落选择模式里正文没有选区：别处把选区设成非空（撤销 / 重做、
      // 页面动作）即由它接手，退出模式、不再动选区。上游点按落下的选区已在
      // EditorState 里挡掉，到不了这里。
      if (blockSelection.isActive) {
        blockSelection.exit(DiaryBlockSelectionExit.release);
      }
    }
    _revealCollapsedSelection();
    notifyListeners();
  }

  void _onToggledStyle() {
    // 上游在失焦、选区变为 null 时先清空待输入格式。保留最后一次实际设置，
    // 只在恢复同一插入点时取回；失焦期间颜色面板的新设置覆盖对应属性。
    _lastToggledStyle = {
      if (state.selection == null) ..._lastToggledStyle,
      ...state.toggledStyle,
    };
    notifyListeners();
  }

  /// 选区落进已收起的折叠块里（撤销 / 重做、程序设的选区、方向键越过
  /// 标题等）时展开它，光标才画得出来；展开不进撤销栈，见
  /// [expandDiaryTogglesAroundSelection]。推到微任务里执行：选区通知常在
  /// 上游 `apply` 的中途发出，不在里面再套一次事务；微任务赶在下一帧之前，
  /// 收起的内容随即建好。只读正文没有光标，不展开；拖动段落时块本来就
  /// 不会落进收起的内容。
  void _revealCollapsedSelection() {
    if (readOnly ||
        draggingBlock ||
        !diarySelectionInsideCollapsedToggle(state)) {
      return;
    }
    scheduleMicrotask(() {
      if (!state.isDisposed && !readOnly) {
        expandDiaryTogglesAroundSelection(state);
      }
    });
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
  ({String json, String text}) get _snapshot {
    final cached = _contentSnapshot;
    if (cached != null) return cached;
    final tree = document.toJson();
    return _contentSnapshot = (
      json: encodeDiaryBlocks(tree),
      text: diaryBlocksPlainText(tree),
    );
  }

  String get contentJson => _snapshot.json;
  String get plainText => _snapshot.text;

  /// 正文是否有看得见的内容（有字的块或媒体等嵌入块），与
  /// `diaryBlocksHaveVisibleContent` 同一口径。
  ///
  /// 直接按先序遍历节点、遇到第一处内容就返回，不把整篇文档转成 JSON：
  /// 编辑页标题旁的 AI 按钮、写作灵感条等在每次输入时都会问它，长日记里
  /// 整篇序列化会让打字发卡；有字的日记通常在第一块就能返回。
  bool get hasContent {
    bool visit(af.Node node) {
      if (kDiaryEmbedBlockTypes.contains(node.type)) return true;
      final delta = node.delta;
      if (delta != null && delta.toPlainText().trim().isNotEmpty) return true;
      for (final child in node.children) {
        if (visit(child)) return true;
      }
      return false;
    }

    for (final node in document.root.children) {
      if (visit(node)) return true;
    }
    return false;
  }

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

  /// 选区横跨不同格式时仅返回共同属性；折叠选区同时考虑“接下来输入”的样式
  /// 与链接输入会话（接着打的字带上它的 `href`，工具栏「链接」随之高亮）。
  Map<String, dynamic> get selectionAttributes {
    final selection = this.selection;
    if (selection == null) return const {};
    final normalized = selection.normalized;
    if (normalized.isCollapsed) {
      final delta = document.nodeAtPath(normalized.end.path)?.delta;
      return {
        ...?delta?.sliceAttributes(normalized.end.offset),
        ...state.toggledStyle,
        if (linkTyping.href case final href?) kDiaryInlineHref: href,
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
        ? {..._lastToggledStyle, ...state.toggledStyle}
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
    // 对齐按选区里第一个非代码文字块（工具栏「对齐」按钮的图标与选中态），
    // 与对齐面板的作用范围一致。
    final firstText = nodes
        .where((node) => node.delta != null && node.type != kDiaryBlockCode)
        .firstOrNull;
    return {
      ...selectionAttributes,
      if (nodes.isNotEmpty &&
          nodes.every((node) => node.type == nodes.first.type))
        'type': nodes.first.type,
      if (nodes.isNotEmpty) 'depth': nodes.first.path.length - 1,
      if (nodes.isNotEmpty) 'level': nodes.first.attributes['level'],
      kDiaryBlockAlignKey: firstText?.attributes[kDiaryBlockAlignKey],
      // 工具栏「缩进」的选中态：第一个文字块缩进了首行。
      kDiaryParagraphIndentKey: firstText?.attributes[kDiaryParagraphIndentKey],
    };
  }

  /// 选中的文字块换成 [type]；换成不画子块的类型时子块提到后面（见
  /// [addDiaryBlockTypeChange]）。
  void setBlockType(String type, {Map<String, dynamic> attributes = const {}}) {
    if (readOnly) return;
    final transaction = state.transaction;
    transaction.afterSelection = addDiaryBlockTypeChange(
      transaction,
      root: document.root,
      nodes: [
        for (final node in selectedNodes)
          if (node.delta != null) node,
      ],
      type: type,
      attributesFor: (node) => {
        kDiaryBlockDeltaKey: node.delta!.toJson(),
        if (node.attributes['align'] case final align?) 'align': align,
        ...attributes,
      },
      selection: selection,
    );
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
    linkTyping.end();
    blockSelection.dispose();
    state.selectionNotifier.removeListener(_onSelection);
    state.toggledStyleNotifier.removeListener(_onToggledStyle);
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

/// 会话的 EditorState：在三处补上上游缺的行为。
///
/// - 收起的键盘（见 [DiaryEditorController.holdingKeyboard]）：上游键盘服务
///   在选区通知里按 `selectionExtraInfoDoNotAttachTextService` 决定是否接上
///   输入法，这里在选区写入前补上这个标记；其余信息（拖动方式、是否禁止
///   浮动工具栏）原样。
/// - 关掉的自动滚动（见 [autoScroller]）。
/// - 段落选择模式（[blockSelection]）里挡掉手势落下的选区：上游手机与桌面
///   选区服务的点按、长按、拖选都以 `uiEvent` 写选区，写进去就会落下光标、
///   接上输入法弹出键盘；模式里的点按由块上的手势自己处理（切换选中）。
class _DiaryEditorState extends af.EditorState {
  _DiaryEditorState({required super.document});

  int holds = 0;
  DiaryBlockSelection? blockSelection;

  /// 上游只有桌面滚动服务理会 [disableAutoScroll]；手机滚动服务照样在每次
  /// 选区变化后用这个滚动器做固定边距的边缘滚动，拖选区时还会逐帧续滚。
  /// 可编辑的整页正文（`DiaryEditor` 非收缩、非只读时关掉自动滚动）已经由
  /// 自己的组件负责滚动：`DiaryEditorViewport` 按实际遮挡揭示光标，
  /// `DiaryEditorSelectionGestures` 在拖选区（把手、长按）到边缘时滚动。上游
  /// 再同时对同一个滚动位置 animateTo，两边每次都把对方的滚动动画顶掉，被
  /// 顶掉的一方 Future 立刻完成、马上再滚一次——整个循环在微任务里转、一帧
  /// 也不让出，界面直接卡死（把选区把手拖到正文顶部时必现：交给上游的点
  /// 夹在可见顶边，上游朝上量的边距越出视口）。关掉时不交出滚动器，手机与
  /// 桌面一致。
  ///
  /// 手机滚动服务第一次用到时取一次并一直沿用；上游在编辑器 initState 里
  /// 就写好 [disableAutoScroll]，早于任何选区变化。会话的只读与否在创建后
  /// 不再改变，取到的结果不会过期。
  @override
  AutoScroller? get autoScroller =>
      disableAutoScroll ? null : super.autoScroller;

  @override
  Future<void> updateSelectionWithReason(
    af.Selection? selection, {
    af.SelectionUpdateReason reason = af.SelectionUpdateReason.transaction,
    Map? extraInfo,
    af.SelectionType? customSelectionType,
  }) {
    if (selection != null &&
        reason == af.SelectionUpdateReason.uiEvent &&
        (blockSelection?.isActive ?? false)) {
      return Future<void>.value();
    }
    return super.updateSelectionWithReason(
      selection,
      reason: reason,
      extraInfo: holds > 0
          ? {...?extraInfo, af.selectionExtraInfoDoNotAttachTextService: true}
          : extraInfo,
      customSelectionType: customSelectionType,
    );
  }
}
