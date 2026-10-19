import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_toolbar_color_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_panel.dart';

part 'diary_floating_toolbar_bar.dart';

/// 卡片内正在展开的面板。
enum _ToolbarPanel { none, more, color }

/// 编辑页悬浮工具栏：一排放得下的工具常驻，其余收进「更多」面板就地展开；
/// 文字颜色 / 背景颜色在同一位置展开颜色面板。
///
/// - 输入：工具顺序与隐藏项、正文控制器、各工具回调。卡片外观（表面、圆角、
///   阴影）由编辑页提供，这里只排布卡片内的内容；
/// - 输出：[onPanelExtentChanged] 报告面板展开后的目标高度（收起或卸载后为 0），
///   编辑页据此给正文末尾让位，并把光标滚到面板上方；
/// - 状态：展开哪块面板只在本次挂载内有效。工具栏随键盘收起而卸载，下次从
///   收起态开始；录音面板打开时立即收起，两块浮层不叠在一起。
///
/// 面板在卡片内部展开而不走 BottomSheet / 对话框：新路由会抢走焦点、收起
/// 键盘，而这条工具栏本身就跟着键盘显示，会连同面板一起消失。
///
/// 面板状态机（[_panel] / [_colorTarget] / [_colorFromMore]）：
/// - 「更多」按钮的展开态 = 「更多」面板开着，或颜色面板是从「更多」里点开的
///   （用户眼里仍在「更多」之内）。点按：展开态 → 收起；颜色面板开着 → 换回
///   「更多」；否则打开「更多」；
/// - 常驻的颜色工具：颜色面板正为它的目标、且不是从「更多」打开时再点收起，
///   其余情况都切到它的目标；「更多」里的颜色工具一律切到颜色面板并记下来源；
/// - 面板之间切换（更多 ↔ 颜色）时外层展开系数保持 1，高度由 AnimatedSize
///   补间、内容交叉淡入，新的目标高度立即报告（变高时编辑页随即揭示光标）。
class DiaryFloatingToolbar extends StatefulWidget {
  const DiaryFloatingToolbar({
    super.key,
    required this.controller,
    required this.order,
    this.hiddenItems = const <DiaryToolbarItem>{},
    this.currentTimeFormatPattern,
    this.onRecordingPressed,
    this.recordingOpen = false,
    this.mediaImportController,
    this.onMediaPressed,
    this.onPanelExtentChanged,
    this.maxPanelExtent = double.infinity,
  });

  final quill.QuillController controller;
  final List<DiaryToolbarItem> order;
  final Set<DiaryToolbarItem> hiddenItems;
  final String? currentTimeFormatPattern;
  final VoidCallback? onRecordingPressed;
  final bool recordingOpen;

  /// 媒体控制器由编辑页持有：系统选择器收起键盘时工具栏会卸载，导入不能跟着
  /// 取消。这里只读取它的进行中状态。
  final DiaryMediaImportController? mediaImportController;
  final void Function(DiaryMediaKind)? onMediaPressed;

  /// 面板目标高度（含分隔线）变化时回调：展开为面板高度，收起或卸载后为 0。
  final ValueChanged<double>? onPanelExtentChanged;

  /// 面板（含分隔线）最多占多高，超出部分在面板内纵向滚动。
  final double maxPanelExtent;

  @override
  State<DiaryFloatingToolbar> createState() => _DiaryFloatingToolbarState();
}

class _DiaryFloatingToolbarState extends State<DiaryFloatingToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panelController = AnimationController(
    vsync: this,
  );

  /// 尺寸与透明度都不越界：SizeTransition 的系数一旦超过 1，面板下方会多出
  /// 一截空白，所以这里不用弹簧曲线。
  late final CurvedAnimation _panelAnimation = CurvedAnimation(
    parent: _panelController,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );

  _ToolbarPanel _panel = _ToolbarPanel.none;

  /// 最近一次展开的内容：收起动画期间沿用它，面板随卡片收拢而不是先变空。
  _ToolbarPanel _content = _ToolbarPanel.none;
  DiaryColorTarget _colorTarget = DiaryColorTarget.text;
  bool _colorFromMore = false;

  /// 这篇日记里用过的非预设颜色，只在打开颜色面板、切换目标与应用颜色代码
  /// 后扫描，不随每次输入重算。
  List<Color> _usedColors = const <Color>[];

  /// 最近一次构建时的排布与宽度：点按发生在构建之外，要立即算出新面板的
  /// 目标高度报告给编辑页。
  DiaryToolbarLayout? _layout;
  double _width = 0;

  /// 已经报告给编辑页的高度，避免重复回调。
  double _reportedExtent = 0;

  @override
  void didUpdateWidget(covariant DiaryFloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 录音面板打开时直接收起、不播收起动画：外层 AnimatedSize 会把“面板消失 +
    // 录音面板插入”当作一次尺寸变化统一补间；若内层同时逐帧收拢，外层只能
    // 逐帧追随内层，录音面板的插入过渡就没了。目标高度在本次 build 里报告。
    if (widget.recordingOpen &&
        !oldWidget.recordingOpen &&
        _panel != _ToolbarPanel.none) {
      _panel = _ToolbarPanel.none;
      _panelController.value = 0;
    }
  }

  @override
  void dispose() {
    // 卸载发生在构建收尾阶段，此时回调会让编辑页在锁定的树上刷新，改到下一帧。
    _reportExtent(0, deferred: true);
    _panelAnimation.dispose();
    _panelController.dispose();
    super.dispose();
  }

  bool get _moreExpanded =>
      _panel == _ToolbarPanel.more ||
      (_panel == _ToolbarPanel.color && _colorFromMore);

  /// 当前排布下实际显示的面板：横竖屏切换后全部放得下时，「更多」面板没有
  /// 位置，暂不显示，回到放不下时按用户上次的选择恢复。
  _ToolbarPanel _visiblePanel(DiaryToolbarLayout layout) =>
      _panel == _ToolbarPanel.more && !layout.hasOverflow
      ? _ToolbarPanel.none
      : _panel;

  void _toggleMore() {
    if (_moreExpanded) {
      _setPanel(_ToolbarPanel.none);
    } else {
      _setPanel(_ToolbarPanel.more);
    }
  }

  void _handleColorTool(DiaryColorTarget target, {required bool fromMore}) {
    if (!fromMore &&
        _panel == _ToolbarPanel.color &&
        _colorTarget == target &&
        !_colorFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    final rescan = _panel != _ToolbarPanel.color || _colorTarget != target;
    _colorTarget = target;
    _colorFromMore = fromMore;
    if (rescan) _scanUsedColors();
    _setPanel(_ToolbarPanel.color);
  }

  void _handleCustomColorApplied() {
    setState(_scanUsedColors);
    _reportExtent(_targetExtent());
  }

  void _scanUsedColors() {
    _usedColors = collectDiaryDocumentColors(
      widget.controller.document,
      _colorTarget,
    );
  }

  void _setPanel(_ToolbarPanel next) {
    setState(() {
      _panel = next;
      if (next != _ToolbarPanel.none) _content = next;
    });
    _panelController.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (next == _ToolbarPanel.none) {
      _panelController.reverse();
    } else {
      _panelController.forward();
    }
    // 点按发生在构建之外，立即报告：编辑页在面板开始展开（或换内容）的同一帧
    // 让出空间。
    _reportExtent(_targetExtent());
  }

  void _reportExtent(double extent, {bool deferred = false}) {
    if (extent == _reportedExtent) {
      return;
    }
    _reportedExtent = extent;
    final callback = widget.onPanelExtentChanged;
    if (callback == null) {
      return;
    }
    if (deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(extent));
    } else {
      callback(extent);
    }
  }

  DiaryColorGridLayout _colorGrid() => DiaryColorGridLayout.resolve(
    innerWidth: _width - 2 * kDiaryToolbarHorizontalPadding,
    usedColorCount: _usedColors.length,
  );

  /// 面板内容实际占的高度（已按 [DiaryFloatingToolbar.maxPanelExtent] 夹住）。
  double _bodyHeight(_ToolbarPanel panel) {
    final layout = _layout;
    if (layout == null) return 0;
    return switch (panel) {
      _ToolbarPanel.none => 0,
      _ToolbarPanel.more => diaryToolbarMorePanelBodyHeight(
        layout.overflowRows.length,
        widget.maxPanelExtent,
      ),
      _ToolbarPanel.color => diaryToolbarPanelBodyLimit(
        diaryColorPanelNaturalHeight(_colorGrid()),
        widget.maxPanelExtent,
      ),
    };
  }

  /// 当前选择下的面板目标高度（含外框），收起为 0。
  double _targetExtent() {
    final layout = _layout;
    if (layout == null) return 0;
    final panel = _visiblePanel(layout);
    if (panel == _ToolbarPanel.none) return 0;
    return kDiaryToolbarPanelChrome + _bodyHeight(panel);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[widget.mediaImportController]),
      builder: (BuildContext context, Widget? child) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            _buildContent(context, constraints.maxWidth),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double width) {
    final items = filterEnabledDiaryToolbarOrder(
      widget.order,
      widget.hiddenItems,
    );
    if (items.isEmpty) {
      _reportExtent(0, deferred: true);
      return const SizedBox.shrink();
    }
    final layout = resolveDiaryToolbarLayout(items, width: width);
    _layout = layout;
    _width = width;
    _reportExtent(_targetExtent(), deferred: true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildPanelArea(context, layout),
        SizedBox(
          height: kDiaryToolbarBarHeight,
          child: layout.hasOverflow
              ? _buildOverflowBar(context, layout, width)
              : _buildCompactBar(context, items),
        ),
      ],
    );
  }

  /// 面板区：展开 / 收起由 [_panelController] 驱动（SizeTransition 顶端对齐 +
  /// 淡入），面板之间切换时外框不动，内容高度补间、内容交叉淡入。
  Widget _buildPanelArea(BuildContext context, DiaryToolbarLayout layout) {
    final visible = _visiblePanel(layout);
    // 「更多」因排布变化暂时没有位置时整块不显示，不播动画。
    if (visible == _ToolbarPanel.none && _panel != _ToolbarPanel.none) {
      return const SizedBox.shrink();
    }
    final showPanel =
        visible != _ToolbarPanel.none || !_panelController.isDismissed;
    final content = visible == _ToolbarPanel.none ? _content : visible;
    return AnimatedBuilder(
      animation: _panelController,
      child: showPanel && content != _ToolbarPanel.none
          ? DiaryToolbarPanelFrame(
              contentKey: content,
              child: _buildPanelContent(context, layout, content),
            )
          : null,
      // 收起动画播完（dismissed）才移出树，收起过程中内容随卡片一起收拢。
      builder: (BuildContext context, Widget? panel) {
        if (panel == null ||
            (_panel == _ToolbarPanel.none && _panelController.isDismissed)) {
          return const SizedBox.shrink();
        }
        // 顶端对齐：面板像从工具栏后方被拉出，内容随卡片上沿一起上移。
        return SizeTransition(
          sizeFactor: _panelAnimation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: _panelAnimation, child: panel),
        );
      },
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    DiaryToolbarLayout layout,
    _ToolbarPanel content,
  ) {
    return switch (content) {
      _ToolbarPanel.color => DiaryColorPanel(
        controller: widget.controller,
        target: _colorTarget,
        grid: _colorGrid(),
        usedColors: _usedColors,
        bodyHeight: _bodyHeight(_ToolbarPanel.color),
        active: _panel == _ToolbarPanel.color,
        onCustomColorApplied: _handleCustomColorApplied,
      ),
      _ => DiaryToolbarMorePanel(
        rows: layout.overflowRows,
        bodyHeight: _bodyHeight(_ToolbarPanel.more),
        cell: (DiaryToolbarItem item) =>
            _overflowCell(context, item, layout, inMorePanel: true),
      ),
    };
  }
}
