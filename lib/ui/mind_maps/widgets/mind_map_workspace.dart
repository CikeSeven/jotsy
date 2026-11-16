import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/keyboard_visibility.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../controllers/mind_map_viewport_controller.dart';
import '../models/mind_map_templates.dart';
import '../sections/mind_map_style_sheet.dart';
import '../viewmodels/mind_map_hit_test.dart';
import 'mind_map_canvas.dart';
import 'mind_map_dock.dart';
import 'mind_map_starter_card.dart';

/// 导图编辑工作区：画布 + 底部工具坞 + 空图起步卡 + 键盘附件条 + 缩放胶囊，
/// 以及桌面快捷键与节点的右键 / 长按菜单。导图日记的编辑页与正文里嵌入
/// 导图的全屏编辑页共用它，宿主只负责外框（顶栏）与保存。
///
/// 输入：编辑会话 [controller]（宿主持有，改动经它的 `onChanged` 写回）、
/// 被顶栏盖住的高度 [topInset]。[onConvertBack] 给出时空图起步卡里有
/// “转回文字日记”。[readOnly] 时只能平移缩放（查看页）。
///
/// 桌面快捷键（只在 `AppPlatform.isDesktop`，编辑文字时一律交给输入框）：
/// Tab / Insert 子主题、Enter 同级（Shift + Enter 加在前面）、Delete /
/// Backspace 删除、F2 / 空格编辑、方向键在节点间移动、Ctrl / ⌘ + Z / Y /
/// Shift + Z 撤销重做、Ctrl / ⌘ + 0 适应屏幕、+ / − 缩放、Ctrl / ⌘ + 1 实际
/// 大小、Ctrl / ⌘ + / 收起或展开、Esc 取消选中（没选中时交给页面返回）。
class MindMapWorkspace extends StatefulWidget {
  const MindMapWorkspace({
    super.key,
    required this.controller,
    this.topInset = 0,
    this.onConvertBack,
    this.readOnly = false,
  });

  final MindMapEditingController controller;
  final double topInset;
  final VoidCallback? onConvertBack;
  final bool readOnly;

  @override
  State<MindMapWorkspace> createState() => MindMapWorkspaceState();
}

class MindMapWorkspaceState extends State<MindMapWorkspace> {
  final MindMapViewportController _viewport = MindMapViewportController();
  final GlobalKey<MindMapCanvasState> _canvas = GlobalKey<MindMapCanvasState>();
  final GlobalKey<ExpressiveMenuAnchorState> _nodeMenu =
      GlobalKey<ExpressiveMenuAnchorState>();
  final ValueNotifier<double> _keyboardInset = ValueNotifier<double>(0);
  final FocusNode _focus = FocusNode(debugLabel: 'mind-map-workspace');
  String? _menuNodeId;

  /// 底部工具坞占的高度（含与屏幕底边的间距）。
  static const double _dockReserve = 92;

  MindMapEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(MindMapWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _viewport.dispose();
    _keyboardInset.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // 结束编辑后把键盘焦点收回工作区，快捷键接着可用。
    if (_controller.editingId == null &&
        AppPlatform.isDesktop &&
        !_focus.hasFocus &&
        (FocusManager.instance.primaryFocus == null ||
            FocusManager.instance.primaryFocus?.context == null)) {
      _focus.requestFocus();
    }
    setState(() {});
  }

  /// 适应屏幕（顶栏按钮等外部入口用）。
  void fitToScreen() => _canvas.currentState?.fitToScreen();

  void _openStyle() {
    _controller.stopEditing();
    showMindMapStyleSheet(context, _controller);
  }

  void _applyTemplate(MindMapTemplate template) {
    _controller.commit(
      template.applyTo(_controller.document, context.l10n),
      select: null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => fitToScreen());
  }

  void _openNodeMenu(String id, Offset globalPosition) {
    setState(() => _menuNodeId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodeMenu.currentState?.openAt(globalPosition);
    });
  }

  // ---------------- 键盘 ----------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!AppPlatform.isDesktop || widget.readOnly) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final controller = _controller;
    if (controller.editingId != null) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final primary = AppPlatform.isMacOS
        ? keys.isMetaPressed
        : keys.isControlPressed;
    final key = event.logicalKey;
    final canvas = _canvas.currentState;
    final selected = controller.selectedId;

    if (primary) {
      if (key == LogicalKeyboardKey.keyZ) {
        keys.isShiftPressed ? controller.redo() : controller.undo();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyY) {
        controller.redo();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0) {
        canvas?.fitToScreen();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1) {
        canvas?.zoomToActual();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.numpadAdd) {
        canvas?.zoomBy(1.25);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.numpadSubtract) {
        canvas?.zoomBy(0.8);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.slash && selected != null) {
        controller.toggleCollapsed(selected);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.insert) {
      controller.addChild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (selected == null) {
        controller.select(controller.document.root.id);
      } else {
        controller.addSibling(before: keys.isShiftPressed);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      controller.deleteSelected();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.f2 || key == LogicalKeyboardKey.space) &&
        selected != null) {
      controller.startEditing(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && selected != null) {
      controller.select(null);
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => AxisDirection.left,
      LogicalKeyboardKey.arrowRight => AxisDirection.right,
      LogicalKeyboardKey.arrowUp => AxisDirection.up,
      LogicalKeyboardKey.arrowDown => AxisDirection.down,
      _ => null,
    };
    if (direction != null) {
      final scene = canvas?.scene;
      if (scene == null) return KeyEventResult.ignored;
      if (selected == null) {
        controller.select(controller.document.root.id);
      } else if (mindMapNeighbour(scene, selected, direction)
          case final next?) {
        controller.select(next);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------- 界面 ----------------

  List<Widget> _nodeMenuItems(BuildContext context) {
    final l10n = context.l10n;
    final id = _menuNodeId;
    final node = id == null ? null : _controller.document.index[id];
    if (node == null) return const <Widget>[];
    final isRoot = id == _controller.document.root.id;
    return <Widget>[
      ExpressiveMenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.pen),
        onPressed: () => _controller.startEditing(node.id),
        child: Text(l10n.mindMapEditText),
      ),
      ExpressiveMenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.diagramSuccessor),
        onPressed: () => _controller.addChild(parentId: node.id),
        child: Text(l10n.mindMapAddChild),
      ),
      ExpressiveMenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.diagramNext),
        onPressed: () {
          _controller.select(node.id);
          _controller.addSibling();
        },
        child: Text(l10n.mindMapAddSibling),
      ),
      if (node.children.isNotEmpty)
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            node.collapsed
                ? FontAwesomeIcons.upRightAndDownLeftFromCenter
                : FontAwesomeIcons.downLeftAndUpRightToCenter,
          ),
          onPressed: () => _controller.toggleCollapsed(node.id),
          child: Text(
            node.collapsed ? l10n.mindMapExpand : l10n.mindMapCollapse,
          ),
        ),
      if (!isRoot)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: () {
            _controller.select(node.id);
            _controller.deleteSelected();
          },
          child: Text(l10n.mindMapDelete),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final editing = controller.editingId != null;
    final keyboardUp = KeyboardVisibility.of(context);
    // 还只有中心主题时浮出模板起步卡（中心主题写了字也一样：套用模板保留它）。
    final onlyRoot = mindMapHasOnlyRoot(controller.document);
    final showStarter = !widget.readOnly && onlyRoot && !editing && !keyboardUp;
    final showDock = !widget.readOnly && !(editing && !AppPlatform.isDesktop);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final padding = EdgeInsets.only(
      top: widget.topInset,
      bottom: widget.readOnly ? bottomSafe : _dockReserve + bottomSafe,
    );
    return Focus(
      focusNode: _focus,
      autofocus: AppPlatform.isDesktop,
      onKeyEvent: _onKey,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _KeyboardInsetProbe(notifier: _keyboardInset),
          Semantics(
            label: context.l10n.mindMapCanvasLabel,
            child: MindMapCanvas(
              key: _canvas,
              controller: controller,
              viewport: _viewport,
              padding: padding,
              keyboardInset: _keyboardInset,
              interactive: !widget.readOnly,
              onNodeMenu: _openNodeMenu,
            ),
          ),
          Positioned(
            top: widget.topInset + 10,
            right: 12,
            child: _ZoomChip(
              viewport: _viewport,
              onFit: () => _canvas.currentState?.fitToScreen(),
              onActual: () => _canvas.currentState?.zoomToActual(),
              onZoomIn: () => _canvas.currentState?.zoomBy(1.25),
              onZoomOut: () => _canvas.currentState?.zoomBy(0.8),
            ),
          ),
          if (showDock || showStarter)
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (showStarter) ...<Widget>[
                          MindMapStarterCard(
                            onTemplate: _applyTemplate,
                            onConvertBack: widget.onConvertBack,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (showDock)
                          MindMapDock(
                            controller: controller,
                            onOpenStyle: _openStyle,
                            onFit: () => _canvas.currentState?.fitToScreen(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (editing && !AppPlatform.isDesktop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: KeyboardInsetPadding(
                child: _EditingAccessoryBar(controller: controller),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: ExpressiveMenuAnchor(
              key: _nodeMenu,
              menuChildren: _nodeMenuItems(context),
              builder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 只读 viewInsets 的一层：键盘升降时只有它逐帧重建，把高度交给画布。
class _KeyboardInsetProbe extends StatelessWidget {
  const _KeyboardInsetProbe({required this.notifier});

  final ValueNotifier<double> notifier;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != notifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.value = inset;
      });
    }
    return const SizedBox.shrink();
  }
}

/// 手机上编辑文字时，键盘上方的附件条：子主题、同级、换行、完成。
class _EditingAccessoryBar extends StatelessWidget {
  const _EditingAccessoryBar({required this.controller});

  final MindMapEditingController controller;

  void _insertNewLine() {
    final primary = FocusManager.instance.primaryFocus?.context;
    final editable = primary?.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return;
    final value = editable.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid) return;
    final text = value.text.replaceRange(selection.start, selection.end, '\n');
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection.start + 1),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    Widget action(FaIconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FaIcon(icon, size: 15, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DiaryFloatingToolbarSurface(
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: <Widget>[
                action(
                  FontAwesomeIcons.diagramSuccessor,
                  l10n.mindMapAddChild,
                  () => controller.addChild(),
                ),
                action(
                  FontAwesomeIcons.diagramNext,
                  l10n.mindMapAddSibling,
                  () => controller.addSibling(),
                ),
                action(
                  FontAwesomeIcons.turnDown,
                  l10n.mindMapNewLine,
                  _insertNewLine,
                ),
                action(
                  FontAwesomeIcons.check,
                  l10n.mindMapDone,
                  controller.stopEditing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右上角的缩放比例胶囊：点开为适应屏幕、实际大小、放大、缩小。
class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.viewport,
    required this.onFit,
    required this.onActual,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final MindMapViewportController viewport;
  final VoidCallback onFit;
  final VoidCallback onActual;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.expand),
          onPressed: onFit,
          child: Text(l10n.mindMapFit),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.crosshairs),
          onPressed: onActual,
          child: Text(l10n.mindMapZoomActual),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.magnifyingGlassPlus),
          closeOnActivate: false,
          onPressed: onZoomIn,
          child: Text(l10n.mindMapZoomIn),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.magnifyingGlassMinus),
          closeOnActivate: false,
          onPressed: onZoomOut,
          child: Text(l10n.mindMapZoomOut),
        ),
      ],
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? _) =>
              ListenableBuilder(
                listenable: viewport,
                builder: (BuildContext context, Widget? _) {
                  final percent = (viewport.scale * 100).round();
                  return _ChipSurface(
                    child: InkWell(
                      onTap: menu.toggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          '${math.max(1, percent)}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

/// 缩放胶囊的表面：玻璃时为控件玻璃（不加投影，叠在画布上很轻），经典时
/// 为一块 `surfaceContainerHigh` 胶囊。
class _ChipSurface extends StatelessWidget {
  const _ChipSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    if (AppGlass.of(context).isGlass(AppGlassComponent.controls)) {
      return AppGlassSurface(
        component: AppGlassComponent.controls,
        borderRadius: radius,
        blur: AppGlassBlur.always,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
