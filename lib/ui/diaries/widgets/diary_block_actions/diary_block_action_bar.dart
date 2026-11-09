import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_controls.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_block_selection.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../models/diary_toolbar_layout.dart';
import '../diary_toolbar_config.dart';
import '../diary_toolbar_more_panel.dart';
import 'diary_block_actions.dart';
import 'diary_block_more_panel.dart';
import 'diary_block_style_panel.dart';
import 'diary_block_type_panel.dart';

/// 段落操作栏表头一行的高度。
const double kDiaryBlockActionHeaderHeight = 40;

/// 操作栏卡片内正在展开的面板。
enum _BlockPanel { none, type, style, more }

/// 段落选择模式下取代悬浮工具栏的段落操作栏（同一张卡片、同一位置，由
/// `DiaryFloatingToolbar` 在模式里换上）。自上而下：
/// - 面板区：「转换为」「样式」「更多」面板在卡片内向上展开（同工具栏面板：外框
///   [DiaryToolbarPanelFrame]、SizeTransition + 淡入，`medium`），不另开路由、
///   对话框或底部面板；
/// - 表头（[kDiaryBlockActionHeaderHeight]）：「已选 N 段」/「未选择段落」、
///   全选 / 取消全选、完成（退出模式，光标回到第一块末尾）；
/// - 工具一排（与工具栏同高、随工具栏大小缩放）：上移、下移、转换为、样式、
///   复制、删除（错误色）、更多。上移 / 下移可以连点，朝那个方向放不下时
///   停用；一个都没选时操作全部停用（面板仍能开合）。
///
/// 输出：[onPanelExtentChanged] 报告表头加展开面板的高度（卸载后为 0），
/// 编辑页据此给正文末尾让位、计入遮挡高度，与工具栏面板同一条链路。
class DiaryBlockActionBar extends StatefulWidget {
  const DiaryBlockActionBar({
    super.key,
    required this.controller,
    this.scale = 1,
    this.maxPanelExtent,
    this.onPanelExtentChanged,
  });

  final DiaryEditorController controller;

  /// 工具栏大小的缩放比例（见 `DiaryToolbarSize.scale`）。
  final double scale;

  /// 表头与面板最多占多高；超出部分在面板内滚动。见
  /// `DiaryFloatingToolbar.maxPanelExtent`。
  final ValueListenable<double>? maxPanelExtent;
  final ValueChanged<double>? onPanelExtentChanged;

  @override
  State<DiaryBlockActionBar> createState() => _DiaryBlockActionBarState();
}

class _DiaryBlockActionBarState extends State<DiaryBlockActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panelController = AnimationController(
    vsync: this,
  );
  late final CurvedAnimation _panelAnimation = CurvedAnimation(
    parent: _panelController,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  _BlockPanel _panel = _BlockPanel.none;

  /// 最近一次展开的内容：收起动画期间沿用它。
  _BlockPanel _content = _BlockPanel.none;
  double? _reported;

  DiaryBlockSelection get _selection => widget.controller.blockSelection;

  double get _maxExtent => widget.maxPanelExtent?.value ?? double.infinity;

  @override
  void initState() {
    super.initState();
    widget.maxPanelExtent?.addListener(_onMaxExtent);
  }

  @override
  void didUpdateWidget(DiaryBlockActionBar old) {
    super.didUpdateWidget(old);
    if (old.maxPanelExtent != widget.maxPanelExtent) {
      old.maxPanelExtent?.removeListener(_onMaxExtent);
      widget.maxPanelExtent?.addListener(_onMaxExtent);
    }
  }

  @override
  void dispose() {
    widget.maxPanelExtent?.removeListener(_onMaxExtent);
    // 卸载发生在构建收尾阶段，改到下一帧报告，不在锁定的树上刷新编辑页。
    final callback = widget.onPanelExtentChanged;
    if (callback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(0));
    }
    _panelAnimation.dispose();
    _panelController.dispose();
    super.dispose();
  }

  void _onMaxExtent() {
    if (_panel != _BlockPanel.none) setState(() {});
  }

  /// 面板内容的高度（已按上限夹住）。
  double _bodyHeight(_BlockPanel panel) => switch (panel) {
    _BlockPanel.none => 0,
    _ => diaryToolbarPanelBodyLimit(switch (panel) {
      _BlockPanel.type => kDiaryBlockTypePanelHeight,
      _BlockPanel.style => kDiaryBlockStylePanelHeight,
      _ => kDiaryBlockMorePanelHeight,
    }, _maxExtent - kDiaryBlockActionHeaderHeight),
  };

  double _targetExtent() =>
      kDiaryBlockActionHeaderHeight +
      (_panel == _BlockPanel.none
          ? 0
          : kDiaryToolbarPanelChrome + _bodyHeight(_panel));

  void _report({bool deferred = false}) {
    final extent = _targetExtent();
    if (extent == _reported) return;
    _reported = extent;
    final callback = widget.onPanelExtentChanged;
    if (callback == null) return;
    if (deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback(extent);
      });
    } else {
      callback(extent);
    }
  }

  void _toggle(_BlockPanel panel) {
    final next = _panel == panel ? _BlockPanel.none : panel;
    setState(() {
      _panel = next;
      if (next != _BlockPanel.none) _content = next;
    });
    _panelController.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (next == _BlockPanel.none) {
      unawaited(_panelController.reverse());
    } else {
      unawaited(_panelController.forward());
    }
    _report();
  }

  @override
  Widget build(BuildContext context) {
    _report(deferred: true);
    return ListenableBuilder(
      // 文档变了（移动后能不能再移）与选择变了都要刷新停用态。
      listenable: Listenable.merge([widget.controller, _selection]),
      builder: (BuildContext context, Widget? child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildPanelArea(context),
          SizedBox(
            height: kDiaryBlockActionHeaderHeight,
            child: _buildHeader(context),
          ),
          SizedBox(
            height: diaryToolbarBarHeight(widget.scale),
            child: _buildTools(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelArea(BuildContext context) {
    final content = _panel == _BlockPanel.none ? _content : _panel;
    return AnimatedBuilder(
      animation: _panelController,
      child: content == _BlockPanel.none
          ? null
          : DiaryToolbarPanelFrame(
              contentKey: content,
              maxBodyHeight: _bodyHeight(content),
              child: _buildPanel(content),
            ),
      builder: (BuildContext context, Widget? panel) {
        if (panel == null ||
            (_panel == _BlockPanel.none && _panelController.isDismissed)) {
          return const SizedBox.shrink();
        }
        return SizeTransition(
          sizeFactor: _panelAnimation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: _panelAnimation, child: panel),
        );
      },
    );
  }

  Widget _buildPanel(_BlockPanel panel) => switch (panel) {
    _BlockPanel.type => DiaryBlockTypePanel(
      controller: widget.controller,
      bodyHeight: _bodyHeight(panel),
    ),
    _BlockPanel.style => DiaryBlockStylePanel(
      controller: widget.controller,
      bodyHeight: _bodyHeight(panel),
    ),
    _BlockPanel.more => DiaryBlockMorePanel(
      controller: widget.controller,
      bodyHeight: _bodyHeight(panel),
    ),
    _BlockPanel.none => const SizedBox.shrink(),
  };

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = _selection.count;
    final all = _selection.isAllSelected;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                count == 0
                    ? l10n.diaryBlockSelectionNone
                    : l10n.diaryBlockSelectionCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: all ? _selection.clear : _selection.selectAll,
            child: Text(all ? l10n.commonDeselectAll : l10n.commonSelectAll),
          ),
          TextButton.icon(
            onPressed: () => _selection.exit(),
            icon: const FaIcon(FontAwesomeIcons.check, size: 14),
            label: Text(l10n.diaryBlockSelectionDone),
          ),
        ],
      ),
    );
  }

  Widget _buildTools(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final some = _selection.count > 0 && !controller.readOnly;
    final tools = <Widget>[
      _tool(
        context,
        icon: FontAwesomeIcons.angleUp,
        tooltip: l10n.diaryEditorMoveBlockUp,
        onPressed: some && DiaryBlockActions.canStep(controller, up: true)
            ? () => DiaryBlockActions.step(controller, up: true)
            : null,
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.angleDown,
        tooltip: l10n.diaryEditorMoveBlockDown,
        onPressed: some && DiaryBlockActions.canStep(controller, up: false)
            ? () => DiaryBlockActions.step(controller, up: false)
            : null,
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.arrowRightArrowLeft,
        tooltip: l10n.diaryBlockTurnInto,
        active: _panel == _BlockPanel.type,
        onPressed: () => _toggle(_BlockPanel.type),
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.font,
        tooltip: l10n.diaryBlockStyle,
        active: _panel == _BlockPanel.style,
        onPressed: () => _toggle(_BlockPanel.style),
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.copy,
        tooltip: l10n.diaryBlockCopy,
        onPressed: some
            ? () => unawaited(DiaryBlockActions.copy(context, controller))
            : null,
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.trashCan,
        tooltip: l10n.commonDelete,
        destructive: true,
        onPressed: some
            ? () => DiaryBlockActions.delete(context, controller)
            : null,
      ),
      _tool(
        context,
        icon: FontAwesomeIcons.ellipsis,
        tooltip: l10n.diaryEditorMoreActions,
        active: _panel == _BlockPanel.more,
        onPressed: () => _toggle(_BlockPanel.more),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kDiaryToolbarHorizontalPadding,
      ),
      child: Row(
        children: <Widget>[
          for (final tool in tools) Expanded(child: Center(child: tool)),
        ],
      ),
    );
  }

  /// 一个工具：外观同工具栏按钮（32dp 可见按钮、展开面板时垫
  /// primaryContainer），停用时 38%；按工具栏大小整体缩放。
  Widget _tool(
    BuildContext context, {
    required FaIconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
    bool destructive = false,
  }) {
    final button = ExpressiveStateBlend(
      active: active,
      builder: (BuildContext context, double t, Widget? child) {
        final colors = Theme.of(context).colorScheme;
        final base = Color.lerp(
          destructive ? colors.error : colors.onSurface,
          colors.onPrimaryContainer,
          t,
        )!;
        return IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: kDiaryToolbarButtonConstraints,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: ExpressiveControls.shape,
            backgroundColor: WidgetStatePropertyAll(
              colors.primaryContainer.withValues(alpha: t),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? base.withValues(alpha: 0.38)
                  : base,
            ),
          ),
          icon: FaIcon(icon, size: 14),
        );
      },
    );
    return diaryToolbarScaledTool(
      button,
      width: kDiaryToolbarButtonExtent,
      scale: widget.scale,
    );
  }
}
