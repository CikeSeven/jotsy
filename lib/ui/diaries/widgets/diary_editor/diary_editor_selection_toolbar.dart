import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show ProcessTextAction;

import '../../../../core/services/app_platform.dart';
import '../../../../core/services/text_process_actions_service.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../../widgets/text_selection_menu/app_text_selection_layout.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_editor_keyboard_hold.dart';
import 'diary_editor_selection_gestures.dart'
    show kDiarySelectionHandleOverhang;
import 'diary_editor_selection_menu_items.dart';
import 'diary_editor_visible_range.dart';

/// 原生块选区的复制/剪切/粘贴入口。使用应用统一的文字选区菜单（手机为
/// 玻璃胶囊 [AppTextSelectionToolbar]、桌面为竖排菜单 [AppTextContextMenuPanel]，
/// `lib/ui/widgets/text_selection_menu/`）和 AppFlowy 选区几何，菜单项见
/// [diaryEditorSelectionMenuItems]；编辑页的格式工具仍留在既有底部卡片中，
/// 不另造一套格式工具。
///
/// 手机在选出一段文字后自动浮在选区上方；可编辑正文里长按松手（或拖完
/// 把手）只落下光标时——空段落、行尾空白，以及 iOS 上任意位置的长按——
/// 浮在光标上方，只有粘贴与全选（见 `_trackCaretMenu`）。桌面与系统
/// 文本框一致，选中时不出现（否则盖住文字与指针），只在右键时经
/// [diaryEditorContextMenuBuilder] 出现在指针处。
///
/// 手指按着正文、选区又在变（长按选词与扩选、拖动选区把手、横滑移光标）
/// 时菜单收起，让出上游的放大镜；最后一根手指抬起后再按松手时的选区决定
/// 是否弹出（#190，与系统文本框一致）。
///
/// 菜单开着期间每帧结束都按选区与正文看得见的范围（[diaryEditorVisibleRange]，
/// 与把手的边缘自动滚动同一口径）重新定位：上下滚动正文时跟着选区走；选区
/// 只露出一部分时贴着露出的部分；整段离开看得见的范围（滚出视口、被键盘或
/// 底部浮层 [coveredHeight] 盖住）时隐藏，滚回来再出现。菜单本身也不压在
/// 底部浮层上（悬浮工具栏连同展开的面板，#221）。
class DiaryEditorSelectionToolbar extends StatefulWidget {
  const DiaryEditorSelectionToolbar({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.pageScroll = false,
    this.coveredHeight = 0,
  });
  final DiaryEditorController controller;
  final Widget child;
  final bool enabled;

  /// 正文嵌在外层页面的滚动视图里（收缩正文），看得见的范围按外层页面算。
  final bool pageScroll;

  /// 正文底部被悬浮工具栏等盖住的高度（不含键盘），见 `DiaryEditorViewport`。
  final double coveredHeight;
  @override
  State<DiaryEditorSelectionToolbar> createState() =>
      _DiaryEditorSelectionToolbarState();
}

class _DiaryEditorSelectionToolbarState
    extends State<DiaryEditorSelectionToolbar> {
  static _DiaryEditorSelectionToolbarState? _active;
  OverlayEntry? _entry;
  bool _scheduled = false;

  /// 菜单此刻的位置（全局坐标）；选区整段不在看得见的范围里时为 null，
  /// 菜单不画（见 [_measurePlacement]）。
  _MenuPlacement? _placement;

  /// 已登记下一帧结束时的重新定位（见 [_track]）。
  bool _tracking = false;

  /// 按在正文上的触点数，经 [build] 里只观察指针、不参与手势竞争的
  /// [Listener] 统计。
  int _pointers = 0;

  /// 第一根手指按下时的选区。
  af.Selection? _pressSelection;

  /// 手指按着期间选区变过：正在选择，菜单收起直到全部抬起。
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DiaryEditorSelectionToolbar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _caretMenu = null;
      _selecting = false;
      _pressSelection = null;
      _hide();
    }
  }

  void _onControllerChanged() {
    _trackCaretMenu();
    final controller = widget.controller;
    if (_pointers > 0 &&
        !_selecting &&
        !controller.state.isDisposed &&
        controller.state.selection != _pressSelection) {
      _selecting = true;
    }
    _schedule();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointers++ > 0) return;
    final state = widget.controller.state;
    _pressSelection = state.isDisposed ? null : state.selection;
    _selecting = false;
  }

  void _onPointerUp(PointerEvent event) {
    if (_pointers == 0 || --_pointers > 0 || !_selecting) return;
    _selecting = false;
    // Listener 先于手势识别器收到抬起：长按 / 拖动结束时上游交还选区的通知
    // 还没到，交给帧后按最终选区决定。抬起本身不一定触发新帧，主动要一帧。
    _schedule();
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final selection = widget.controller.state.selection;
      if (!widget.enabled ||
          AppPlatform.isDesktop ||
          _selecting ||
          selection == null ||
          (selection.isCollapsed && selection != _caretMenu)) {
        _hide();
      } else {
        _show();
      }
    });
  }

  /// 长按松手后落下的光标；非 null 时手机在光标上方出菜单（粘贴、全选）。
  af.Selection? _caretMenu;

  /// 每次控制器通知时同步更新 [_caretMenu]（不等到下一帧：期间可能还有
  /// 别的选区更新覆盖掉判定依据）。
  ///
  /// 上游手机选区服务在长按结束（Android 与 iOS）和拖完选区把手时，都以
  /// uiEvent 原因、`doNotAttachTextService: false` 交还选区，且不带“禁止
  /// 浮动工具栏”；点按、横滑移动光标（带禁止标记）、输入与程序设的选区
  /// 都不满足。长按空段落时上游取到的词边界是空的（折叠选区），过去手机
  /// 菜单只认非折叠选区，因此不出菜单、无从粘贴（#119）。
  ///
  /// 正文原本没有焦点时，长按松手才连接输入法并取得焦点，`DiaryEditor`
  /// 的 `_onFocus` 随即以 transaction 原因把同一选区重设一次，覆盖掉这组
  /// 信息；所以记住这次请求，只在选区变化（输入、粘贴、程序换选区）或
  /// 又有一次手势（点按等 uiEvent）时清除。只读正文没有插入点，不出菜单。
  void _trackCaretMenu() {
    final controller = widget.controller;
    if (controller.readOnly || controller.state.isDisposed) {
      _caretMenu = null;
      return;
    }
    final state = controller.state;
    final selection = state.selection;
    final uiEvent =
        state.selectionUpdateReason == af.SelectionUpdateReason.uiEvent;
    final info = state.selectionExtraInfo;
    final released =
        uiEvent &&
        info != null &&
        info[af.selectionExtraInfoDoNotAttachTextService] == false &&
        info[af.selectionExtraInfoDisableFloatingToolbar] != true;
    if (released && selection != null && selection.isCollapsed) {
      _caretMenu = selection;
    } else if (selection != _caretMenu || (uiEvent && !released)) {
      _caretMenu = null;
    }
  }

  /// 菜单开着期间监听的“其他应用的文字处理”列表（见 [_show]）。
  ValueListenable<List<ProcessTextAction>>? _processActions;

  void _hide() {
    _processActions?.removeListener(_onProcessActions);
    _processActions = null;
    _entry?.remove();
    _entry = null;
    _placement = null;
    if (identical(_active, this)) _active = null;
  }

  /// 按本帧布局后的选区与看得见的范围算菜单位置；变了返回 true。
  bool _measurePlacement() {
    final next = _currentPlacement();
    if (next == _placement) return false;
    _placement = next;
    return true;
  }

  _MenuPlacement? _currentPlacement() {
    final controller = widget.controller;
    if (controller.state.isDisposed) return null;
    final rects = controller.state.selectionRects();
    if (rects.isEmpty) return null;
    // 翻到选区下方时让出整块把手触控区（文字下方
    // kDiarySelectionHandleOverhang），否则选区靠近屏幕顶部时菜单正好盖在
    // 把手上，按到的是菜单（#190）。
    const handleDrop = Offset(
      0,
      kDiarySelectionHandleOverhang - AppTextToolbarGeometry.gapBelow,
    );
    // 不在任何纵向滚动视图里的正文（如嵌在不滚动的卡片里）没有“滚出去”
    // 一说：照旧贴着整个选区，只避开系统栏与键盘。
    if (diaryEditorScrollable(
          context,
          controller,
          pageScroll: widget.pageScroll,
        ) ==
        null) {
      return (
        primary: rects.first.topCenter,
        secondary: rects.last.bottomCenter + handleDrop,
        bottomLimit: null,
      );
    }
    final visible = diaryEditorVisibleRange(
      context,
      controller,
      pageScroll: widget.pageScroll,
      coveredHeight: widget.coveredHeight,
    );
    if (visible == null) return null;
    final shown = [
      for (final rect in rects)
        if (rect.bottom > visible.top && rect.top < visible.bottom) rect,
    ];
    if (shown.isEmpty) return null;
    // 只露出一部分时贴着露出的那段：上沿不高于看得见的顶端，下沿不低于
    // 看得见的底端（不翻到盖住选区的浮层上）。
    return (
      primary: Offset(
        shown.first.center.dx,
        math.max(shown.first.top, visible.top),
      ),
      secondary:
          Offset(
            shown.last.center.dx,
            math.min(shown.last.bottom, visible.bottom),
          ) +
          handleDrop,
      // 编辑页（正文自己的列表）的菜单不越过看得见的底端：底下是悬浮工具栏
      // 与它的面板，模板编辑页则是排在正文下方的工具栏。嵌入阅读页时底下
      // 没有叠在正文上的浮层，系统栏与键盘由菜单自己避开；不再按外层滚动
      // 视图的底边限制（视图可能只有内容那么高，展开「更多」时放不下）。
      bottomLimit: widget.pageScroll ? null : visible.bottom,
    );
  }

  /// 菜单开着期间每帧结束都重新定位一次（帧尾回调不请求新帧，静止时不
  /// 耗电）：上下滚动正文（正文自己的列表或外层页面）、键盘升降、面板展开
  /// 与页头动画都会移动选区或改变看得见的范围；位置变了才重建菜单。
  void _track() {
    if (_tracking) return;
    _tracking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tracking = false;
      final entry = _entry;
      if (!mounted || entry == null) return;
      if (_measurePlacement()) entry.markNeedsBuild();
      _track();
    });
  }

  /// 查询在菜单开着时返回：重建一次，补上新查到的动作。
  void _onProcessActions() => _entry?.markNeedsBuild();

  void _show() {
    if (_active != this) _active?._hide();
    _active = this;
    _measurePlacement();
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    // 每次显示时在后台重新查询其他应用的文字处理（装卸了应用下次即可看到），
    // 先用上次的结果画出菜单，不等查询；监听只在菜单开着期间，收起即撤掉。
    final processText = TextProcessActionsService.instance;
    _processActions = processText.actions..addListener(_onProcessActions);
    unawaited(processText.refresh());
    _entry = OverlayEntry(
      builder: (_) {
        final placement = _placement;
        if (!mounted ||
            widget.controller.state.isDisposed ||
            placement == null) {
          // 选区整段不在看得见的范围里：不画；滚回来时胶囊重新挂载、
          // 重播入场动画。
          return const SizedBox.shrink();
        }
        final controller = widget.controller;
        final selection = controller.selection;
        if (selection == null) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context),
          child: AppTextSelectionToolbar(
            // 选区变了，展开的「更多」就收起；胶囊本身不重建（拖动把手时
            // 选区每帧都在变，换 key 会每帧重播入场动画）。
            collapseScope: selection,
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: placement.primary,
              secondaryAnchor: placement.secondary,
            ),
            bottomLimit: placement.bottomLimit,
            actions: diaryEditorSelectionMenuItems(
              context,
              controller,
              // 点过菜单项就不再是“刚长按”：粘贴空剪贴板时选区不变，也不能
              // 在下一次通知时把菜单弹回来。
              dismiss: () {
                _caretMenu = null;
                _hide();
              },
              // 与系统文本框一致，手机复制后把选区收成光标。
              afterCopy: () {
                _caretMenu = null;
                _hide();
                if (controller.state.isDisposed) return;
                void collapse() =>
                    controller.select(af.Selection.collapsed(selection.end));
                // 软键盘收着时不因收成光标把它拉起来。复制写剪贴板是异步的，
                // 回来时菜单所在的正文可能已经卸载，那时照常收起。
                mounted
                    ? holdHiddenKeyboard(context, controller, collapse)
                    : collapse();
              },
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _track();
  }

  @override
  void dispose() {
    _hide();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerUp: _onPointerUp,
    onPointerCancel: _onPointerUp,
    child: widget.child,
  );
}

/// 手机选区菜单的位置（全局坐标）：[primary] 为露出的第一行上沿中点，
/// [secondary] 为露出的最后一行下沿中点再让出把手触控区；[bottomLimit] 为
/// 看得见的范围的下沿（底部浮层的上沿），为 null 时只避开系统栏与键盘。
typedef _MenuPlacement = ({
  Offset primary,
  Offset secondary,
  double? bottomLimit,
});

/// 桌面正文的右键菜单，交给 [af.AppFlowyEditor.contextMenuBuilder]。
///
/// 上游桌面选区服务在右键时先按位置调整选区（点在已选的段落里保留选区，
/// 否则把光标移到该处），再插入菜单与一层透明遮罩：在菜单外按下指针、选区
/// 清空或调用 dismiss 时一并收起，并在菜单开着时屏蔽正文输入。这里只负责
/// 画菜单与执行动作。
af.ContextMenuWidgetBuilder diaryEditorContextMenuBuilder(
  DiaryEditorController controller,
) =>
    (context, position, editorState, dismiss) => Theme(
      data: Theme.of(context),
      child: _DiaryEditorContextMenu(
        controller: controller,
        // 上游把指针位置向右下偏移 10 再交出；系统文本框的右键菜单以指针为
        // 左上角，这里还原，与标题等输入框一致。
        anchor: position - const Offset(10, 10),
        dismiss: dismiss,
      ),
    );

class _DiaryEditorContextMenu extends StatefulWidget {
  const _DiaryEditorContextMenu({
    required this.controller,
    required this.anchor,
    required this.dismiss,
  });
  final DiaryEditorController controller;
  final Offset anchor;
  final VoidCallback dismiss;

  @override
  State<_DiaryEditorContextMenu> createState() =>
      _DiaryEditorContextMenuState();
}

class _DiaryEditorContextMenuState extends State<_DiaryEditorContextMenu> {
  final FocusNode _focus = FocusNode(debugLabel: 'diary_editor_context_menu');
  FocusNode? _previous;
  final TextProcessActionsService _processText =
      TextProcessActionsService.instance;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // 菜单开着时上游让正文失焦；焦点移到菜单上，开着期间的按键不落到正文或
    // 页面。Esc / ↑ / ↓ / Enter 由 AppTextContextMenuPanel 的早期按键处理器
    // 在分发给焦点之前拦下（Esc 收起菜单并返回 handled，不会落到页面——编辑页
    // 的 Esc 是返回），这里不再另设 Esc 分支，免得同一次按键收起两次。
    _previous = primaryFocus;
    _focus.requestFocus();
    // 桌面目前不提供其他应用的文字处理（查询总为空），仍与手机同一口径：
    // 打开时刷新，结果在菜单开着时到达就重建。
    _processText.actions.addListener(_onProcessActions);
    unawaited(_processText.refresh());
  }

  void _onProcessActions() {
    if (mounted) setState(() {});
  }

  /// 只收起一次：Esc 的连发事件或点按后又按 Esc，都不会让上游的 dismiss
  /// 在菜单已移除后再跑一遍。
  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.dismiss();
  }

  @override
  void dispose() {
    _processText.actions.removeListener(_onProcessActions);
    // 编辑态收起时上游会重新聚焦正文，菜单此时已不持有焦点；只读正文没有
    // 上游键盘服务，由这里把焦点还给打开菜单前的位置。
    final previous = _previous;
    if (_focus.hasFocus && previous != null && previous.context != null) {
      previous.requestFocus();
    }
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    child: AppTextContextMenuPanel(
      anchor: widget.anchor,
      onDismiss: _dismiss,
      // 桌面复制后保留选区，与系统文本框一致。
      actions: diaryEditorSelectionMenuItems(
        context,
        widget.controller,
        dismiss: _dismiss,
        afterCopy: _dismiss,
      ),
    ),
  );
}
