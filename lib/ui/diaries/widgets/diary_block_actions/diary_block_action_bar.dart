import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_selection.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../models/diary_toolbar_layout.dart';
import '../diary_panel_action_cell.dart';
import '../diary_toolbar_more_panel.dart';
import 'diary_block_actions.dart';
import 'diary_block_more_panel.dart';
import 'diary_block_panel_body.dart';
import 'diary_block_style_panel.dart';
import 'diary_block_type_panel.dart';

/// 段落操作栏表头一行的高度。
const double kDiaryBlockActionHeaderHeight = 44;

/// 工具一排在标准工具栏大小下的高度（图标 + 标签的格子 48dp，下方留 6dp）；
/// 随工具栏大小缩放。
const double _kToolsHeight = 54;
const double _kToolsBottomGap = 6;

/// 操作栏卡片内正在展开的面板。
enum _BlockPanel { none, type, style, more }

/// 段落选择模式下取代悬浮工具栏的段落操作栏（同一张卡片、同一位置，由
/// `DiaryFloatingToolbar` 在模式里换上）。自上而下：
/// - 面板区：「转换」「样式」「更多」面板在卡片内向上展开（同工具栏面板：外框
///   [DiaryToolbarPanelFrame]、SizeTransition + 淡入，`medium`），不另开路由、
///   对话框或底部面板；
/// - 表头（[kDiaryBlockActionHeaderHeight]）：「已选 N 段」/「未选择段落」，
///   右侧文字按钮「全选 / 取消全选」与主色药丸按钮「完成」（退出模式，光标
///   回到第一块末尾）；
/// - 工具一排（随工具栏大小缩放）：上移、下移、转换、样式、复制、删除
///   （错误色）、更多，都是图标在上、短标签在下的格子，开着面板的那格垫
///   `primaryContainer`。上移 / 下移可以连点，也可以按住不放连续移动，朝
///   那个方向放不下时停用；一个都没选时操作全部停用（面板仍能开合）。
///
/// 换上时表头与工具淡入（`fast`），卡片高度由宿主的 AnimatedSize 补间。
///
/// 输出：[onPanelExtentChanged] 报告卡片比工具栏一排多出的高度（表头、
/// 工具一排比工具栏高出的部分、展开的面板；卸载后为 0），编辑页据此给正文
/// 末尾让位、计入遮挡高度，与工具栏面板同一条链路。
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

  /// 卡片在工具栏一排之上最多再占多高；超出部分在面板内滚动。见
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

  double get _toolsHeight => _kToolsHeight * widget.scale;

  /// 表头与工具一排比工具栏一排多出的高度：宿主已经按工具栏一排的高度
  /// 给正文让了位，多出来的这部分与面板一起报告。
  double get _baseExtent =>
      kDiaryBlockActionHeaderHeight +
      _toolsHeight -
      diaryToolbarBarHeight(widget.scale);

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
    }, _maxExtent - _baseExtent),
  };

  double _targetExtent() =>
      _baseExtent +
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
          // 换上操作栏时内容淡入；卡片本身（可能是玻璃）不进透明度层。
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            curve: ExpressiveMotion.effects,
            builder: (BuildContext context, double t, Widget? child) =>
                Opacity(opacity: t, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: kDiaryBlockActionHeaderHeight,
                  child: _buildHeader(context),
                ),
                SizedBox(height: _toolsHeight, child: _buildTools(context)),
              ],
            ),
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
    final colors = theme.colorScheme;
    final count = _selection.count;
    final all = _selection.isAllSelected;
    final label = theme.textTheme.labelLarge;
    // 两个按钮都比默认的矮：表头只有 44dp，卡片里也不放大点按区。
    const compact = VisualDensity(horizontal: -2, vertical: -2);
    return Padding(
      // 左缘与工具格里的图标大致对齐，右缘与工具格的外沿对齐。
      padding: const EdgeInsetsDirectional.only(
        start: 18,
        end: kDiaryToolbarHorizontalPadding + kDiaryBlockPanelCellInset,
        top: 4,
      ),
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
                  color: count == 0 ? colors.onSurfaceVariant : null,
                ),
              ),
            ),
          ),
          // 上限只为最窄的屏幕兜底：四种语言的「取消全选」都在这个宽度以内，
          // 计数占剩下的宽度、放不下时省略，「完成」始终完整。
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 148),
            child: TextButton(
              onPressed: all ? _selection.clear : _selection.selectAll,
              style: TextButton.styleFrom(
                visualDensity: compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: label,
              ),
              child: Text(
                all ? l10n.commonDeselectAll : l10n.commonSelectAll,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () => _selection.exit(),
            style: FilledButton.styleFrom(
              visualDensity: compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: label?.copyWith(fontWeight: FontWeight.w600),
            ),
            child: Text(l10n.diaryBlockSelectionDone),
          ),
        ],
      ),
    );
  }

  Widget _buildTools(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final some = _selection.count > 0 && !controller.readOnly;
    final canUp = some && DiaryBlockActions.canStep(controller, up: true);
    final canDown = some && DiaryBlockActions.canStep(controller, up: false);
    final tools = <Widget>[
      _tool(
        icon: FontAwesomeIcons.arrowUp,
        label: l10n.diaryEditorMoveBlockUp,
        enabled: canUp,
        repeatOnHold: true,
        onTap: () => DiaryBlockActions.step(controller, up: true),
      ),
      _tool(
        icon: FontAwesomeIcons.arrowDown,
        label: l10n.diaryEditorMoveBlockDown,
        enabled: canDown,
        repeatOnHold: true,
        onTap: () => DiaryBlockActions.step(controller, up: false),
      ),
      _tool(
        icon: FontAwesomeIcons.arrowRightArrowLeft,
        label: l10n.diaryBlockTurnInto,
        selected: _panel == _BlockPanel.type,
        onTap: () => _toggle(_BlockPanel.type),
      ),
      _tool(
        icon: FontAwesomeIcons.font,
        label: l10n.diaryBlockStyle,
        selected: _panel == _BlockPanel.style,
        onTap: () => _toggle(_BlockPanel.style),
      ),
      _tool(
        icon: FontAwesomeIcons.copy,
        label: l10n.diaryBlockCopy,
        enabled: some,
        onTap: () => unawaited(DiaryBlockActions.copy(context, controller)),
      ),
      _tool(
        icon: FontAwesomeIcons.trashCan,
        label: l10n.commonDelete,
        enabled: some,
        destructive: true,
        onTap: () => DiaryBlockActions.delete(context, controller),
      ),
      _tool(
        icon: FontAwesomeIcons.ellipsis,
        label: l10n.diaryEditorMoreActions,
        selected: _panel == _BlockPanel.more,
        onTap: () => _toggle(_BlockPanel.more),
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: kDiaryToolbarHorizontalPadding,
        right: kDiaryToolbarHorizontalPadding,
        bottom: _kToolsBottomGap * widget.scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final tool in tools)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kDiaryBlockPanelCellInset,
                ),
                child: tool,
              ),
            ),
        ],
      ),
    );
  }

  /// 一个工具：与面板里的格子同一种（图标在上、标签在下），不垫底，开着
  /// 面板时垫 primaryContainer；按工具栏大小缩放。
  Widget _tool({
    required FaIconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool selected = false,
    bool destructive = false,
    bool repeatOnHold = false,
  }) => DiaryPanelActionCell(
    icon: icon,
    label: label,
    enabled: enabled,
    selected: selected,
    destructive: destructive,
    repeatOnHold: repeatOnHold,
    maxLines: 1,
    scale: widget.scale,
    onTap: onTap,
  );
}
