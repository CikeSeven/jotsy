import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/services/diary_typography.dart';
import '../../diaries/viewmodels/diary_text_appearance.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../viewmodels/mind_map_look.dart';
import 'mind_map_outline_row.dart';

/// 大纲视图：同一张导图的缩进列表，与画布编辑的是同一份文档、同一个
/// 选中与编辑状态。
///
/// - 点一行选中并编辑文字；行首圆点为分支色，有子主题时是可点的折叠箭头；
///   文字按正文排版 [appearance] 排（与日记正文同一字体、字号、行距与字
///   间距），字号再按层级与主题自己的字号放大；主题的文字样式（整条的与
///   局部的）照画，编辑框同样经 `InlineRichTextController` 设局部样式（格式
///   条与快捷键与画布相同）；
/// - 长按（手机）或右键（桌面）一行弹出与画布相同的主题菜单（[onNodeMenu]，
///   编辑文字、加主题、插入、主题样式、复制剪切粘贴、删除等）；
/// - 编辑中：Enter 在后面加同级（行首回车加在前面，手机软键盘的回车同样、
///   键盘不收起），空行退格删除这一行并编辑上一行；桌面另有 Tab / Shift +
///   Tab 缩进与取消缩进、Alt + ↑ / ↓ 上移下移；手机上这些操作在键盘上方的
///   附件条里（由工作区提供）；
/// - 新进入编辑的主题那一行不在已构建的范围里时（见 [_revealEditing]），
///   先把列表跳到它附近，输入框建出来才拿得到焦点、键盘不收起；
/// - 只读时只能展开收起（不写回文档，见 [MindMapEditingController] 的只读）。
class MindMapOutlineView extends StatefulWidget {
  const MindMapOutlineView({
    super.key,
    required this.controller,
    this.appearance = const DiaryTextAppearance(typography: DiaryTypography()),
    this.padding = EdgeInsets.zero,
    this.onNodePart,
    this.onNodeMenu,
    this.revealPadding = const EdgeInsets.all(20),
  });

  final MindMapEditingController controller;

  /// 正文排版（工作区经 `diaryTextAppearanceProvider` 给出）；缺省为默认
  /// 排版与主题字体。
  final DiaryTextAppearance appearance;
  final EdgeInsets padding;

  /// 点了一行的备注 / 链接标记。
  final void Function(String id, String part)? onNodePart;

  /// 长按或右键一行时弹主题菜单（只读时不弹）。
  final void Function(String id, Offset globalPosition)? onNodeMenu;

  /// 编辑中的光标要露在视口里哪一块之内（四周让开的距离，盖在列表上的
  /// 顶栏、视图切换与桌面的格式条），见 [MindMapOutlineRow.revealPadding]。
  final EdgeInsets revealPadding;

  @override
  State<MindMapOutlineView> createState() => _MindMapOutlineViewState();
}

class _MindMapOutlineViewState extends State<MindMapOutlineView> {
  final Set<String> _readOnlyExpanded = <String>{};
  final Set<String> _readOnlyCollapsed = <String>{};

  /// 自带控制器（不用页面的 PrimaryScrollController）：[_revealEditing]
  /// 要按估算的位置跳。
  final ScrollController _scroll = ScrollController();

  /// 上一次通知时正在编辑的主题（只在换了主题时检查要不要跳）。
  String? _lastEditing;

  MindMapEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastEditing = _controller.editingId;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(MindMapOutlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _lastEditing = widget.controller.editingId;
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final id = _controller.editingId;
    if (id == _lastEditing) return;
    _lastEditing = id;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealEditing(id));
  }

  /// 正在编辑的行没建出来时把列表跳到它附近。
  ///
  /// 中心主题回车加的子主题排在最后、在展开着一大棵子树的主题后面加的同级
  /// 排在子树之后，都可能落在列表已构建（视口加缓存区）的范围之外：那一行
  /// 不构建，输入框就拿不到焦点，键盘随之收起。这一帧过后输入框仍没挂到
  /// 文字会话上，就按行的平均高度估算它的位置跳过去（行高不一，估算可能
  /// 差几行，所以再看下一帧，最多 [attempts] 次）；建出来后输入框获得焦点，
  /// 自己按 `revealPadding` 精确露出光标。
  void _revealEditing(String id, {int attempts = 3}) {
    if (!mounted || attempts <= 0 || !_scroll.hasClients) return;
    if (_controller.editingId != id ||
        _controller.textSession.current != null) {
      return;
    }
    final rows = _rows(_controller.document);
    final index = rows.indexWhere((row) => row.$1.id == id);
    if (index < 0) return;
    final position = _scroll.position;
    final rowExtent =
        (position.maxScrollExtent + position.viewportDimension) / rows.length;
    position.jumpTo(
      (index * rowExtent - position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _revealEditing(id, attempts: attempts - 1),
    );
  }

  bool _collapsed(MindMapNode node) {
    if (!_controller.readOnly) return node.collapsed;
    if (_readOnlyCollapsed.contains(node.id)) return true;
    if (_readOnlyExpanded.contains(node.id)) return false;
    return node.collapsed;
  }

  void _toggle(MindMapNode node) {
    if (_controller.readOnly) {
      setState(() {
        if (_collapsed(node)) {
          _readOnlyCollapsed.remove(node.id);
          _readOnlyExpanded.add(node.id);
        } else {
          _readOnlyExpanded.remove(node.id);
          _readOnlyCollapsed.add(node.id);
        }
      });
      return;
    }
    _controller.toggleCollapsed(node.id);
  }

  List<(MindMapNode, int)> _rows(MindMapDocument document) {
    final rows = <(MindMapNode, int)>[];
    void visit(MindMapNode node, int depth) {
      rows.add((node, depth));
      if (_collapsed(node)) return;
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    visit(document.root, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final document = controller.document;
        final look = MindMapLook.of(context, document);
        final styles = look.styles;
        final rows = _rows(document);
        return ListView.builder(
          controller: _scroll,
          // 与不传控制器时一样：内容不满一屏也能拖（顶栏随拖动显隐）。
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding + const EdgeInsets.fromLTRB(8, 8, 16, 24),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int i) {
            final (node, depth) = rows[i];
            final visual = styles.visualOf(document.index, node);
            return MindMapOutlineRow(
              key: ValueKey<String>('outline-${node.id}'),
              controller: controller,
              styles: styles,
              appearance: widget.appearance,
              node: node,
              depth: depth,
              branchColor: depth == 0
                  ? Theme.of(context).colorScheme.primary
                  : visual.branchColor,
              collapsed: _collapsed(node),
              onToggle: () => _toggle(node),
              onNodePart: widget.onNodePart,
              onNodeMenu: widget.onNodeMenu,
              revealPadding: widget.revealPadding,
              previousVisible: i == 0 ? null : rows[i - 1].$1.id,
            );
          },
        );
      },
    );
  }
}
