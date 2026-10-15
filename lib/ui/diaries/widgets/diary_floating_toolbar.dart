import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_button.dart';

/// 面板内容距卡片上沿：可见按钮离上沿 10dp，与卡片 18dp 圆角留出呼吸。
const double _kPanelTopPadding = 6;

/// 面板最后一行与分隔线的距离：两侧可见按钮到分隔线都是 6dp。
const double _kPanelBottomPadding = 2;
const double _kPanelRowGap = 4;
const double _kPanelDividerHeight = 1;
const double _kPanelChrome =
    _kPanelTopPadding + _kPanelBottomPadding + _kPanelDividerHeight;

/// 面板最多直接露出的行数；更多行在面板内纵向滚动，键盘弹起后正文仍露得出来。
const int _kPanelMaxVisibleRows = 3;

/// 行数超出上限时多露出半行，提示面板还能往下滚。
const double _kPanelScrollPeek = kDiaryToolbarButtonExtent / 2;

/// 编辑页悬浮工具栏：一排放得下的工具常驻，其余收进「更多」面板就地展开。
///
/// - 输入：工具顺序与隐藏项、正文控制器、各工具回调。卡片外观（表面、圆角、
///   阴影）由编辑页提供，这里只排布卡片内的内容；
/// - 输出：[onPanelExtentChanged] 报告面板展开后的目标高度（收起或卸载后为 0），
///   编辑页据此给正文末尾让位，并把光标滚到面板上方；
/// - 状态：展开与否只在本次挂载内有效。工具栏随键盘收起而卸载，下次从收起态
///   开始；录音面板打开时立即收起，两块浮层不叠在一起。
///
/// 面板在卡片内部展开而不走 BottomSheet：新路由会抢走焦点、收起键盘，而这条
/// 工具栏本身就跟着键盘显示，会连同面板一起消失。
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

  bool _expanded = false;

  /// 最近一次排布得到的面板目标高度（不论是否展开）。
  double _panelExtent = 0;

  /// 已经报告给编辑页的高度，避免重复回调。
  double _reportedExtent = 0;

  @override
  void didUpdateWidget(covariant DiaryFloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 录音面板打开时直接收起、不播收起动画：外层 AnimatedSize 会把“面板消失 +
    // 录音面板插入”当作一次尺寸变化统一补间；若内层同时逐帧收拢，外层只能
    // 逐帧追随内层，录音面板的插入过渡就没了。目标高度在本次 build 里报告。
    if (widget.recordingOpen && !oldWidget.recordingOpen && _expanded) {
      _expanded = false;
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

  void _toggle() {
    final expanded = !_expanded;
    setState(() => _expanded = expanded);
    _panelController.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (expanded) {
      _panelController.forward();
    } else {
      _panelController.reverse();
    }
    // 点按发生在构建之外，立即报告：编辑页在面板开始展开的同一帧让出空间。
    _reportExtent(expanded ? _panelExtent : 0);
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
    if (!layout.hasOverflow) {
      // 全部放得下：紧凑居中（与改版前一致），没有面板可展开。旋转到横屏等
      // 情况下保留 _expanded，回到放不下时面板仍按用户上次的选择显示。
      _reportExtent(0, deferred: true);
      return SizedBox(
        height: kDiaryToolbarBarHeight,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < items.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: kDiaryToolbarItemGap),
                _buildTool(context, items[index]),
              ],
            ],
          ),
        ),
      );
    }

    // 放不下：整排按列等分，常驻工具从左依次占格，「更多」固定在最后一格；
    // 面板沿用同样的列宽，上下两部分的按钮对齐成一张网格。
    final cellWidth =
        (width - 2 * kDiaryToolbarHorizontalPadding) / layout.columns;
    Widget cell(DiaryToolbarItem item) => SizedBox(
      width: cellWidth * diaryToolbarItemSlots(item),
      child: Center(child: _buildTool(context, item)),
    );
    final rows = layout.overflowRows;
    final naturalBodyHeight = _bodyHeightForRows(rows.length);
    final bodyHeight = _panelBodyHeight(rows.length);
    _panelExtent = _kPanelChrome + bodyHeight;
    _reportExtent(_expanded ? _panelExtent : 0, deferred: true);

    final showPanel = _expanded || !_panelController.isDismissed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _panelController,
          child: showPanel
              ? _buildPanel(
                  context,
                  rows: rows,
                  cell: cell,
                  bodyHeight: bodyHeight,
                  scrollable: bodyHeight < naturalBodyHeight,
                )
              : null,
          // 收起动画播完（dismissed）才移出树，收起过程中内容随卡片一起收拢。
          builder: (BuildContext context, Widget? panel) {
            if (panel == null || (!_expanded && _panelController.isDismissed)) {
              return const SizedBox.shrink();
            }
            // 顶端对齐：面板像从工具栏后方被拉出，内容随卡片上沿一起上移。
            return SizeTransition(
              sizeFactor: _panelAnimation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: _panelAnimation, child: panel),
            );
          },
        ),
        SizedBox(
          height: kDiaryToolbarBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kDiaryToolbarHorizontalPadding,
            ),
            child: Row(
              children: <Widget>[
                for (final item in layout.pinned) cell(item),
                const Spacer(),
                SizedBox(
                  width: cellWidth,
                  child: Center(
                    child: DiaryToolbarMoreButton(
                      controller: widget.controller,
                      overflow: layout.overflow,
                      expanded: _expanded,
                      recordingOpen: widget.recordingOpen,
                      onPressed: _toggle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 单个工具占固定尺寸的格子：排布按常量计算，按钮实际尺寸受主题影响时
  /// 也不会把整排挤歪。
  Widget _buildTool(BuildContext context, DiaryToolbarItem item) {
    final mediaImportController = widget.mediaImportController;
    return SizedBox(
      width: diaryToolbarItemExtent(item),
      height: kDiaryToolbarButtonExtent,
      child: Center(
        child: quill.QuillSimpleToolbar(
          controller: widget.controller,
          config: buildDiaryToolbarItemConfig(
            context,
            item,
            widget.controller,
            currentTimeFormatPattern: widget.currentTimeFormatPattern,
            onRecordingPressed: widget.onRecordingPressed,
            recordingOpen: widget.recordingOpen,
            onMediaPressed: widget.onMediaPressed,
            activeMediaKind: mediaImportController?.activeKind,
            mediaImportBusy: mediaImportController?.isBusy ?? false,
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required List<List<DiaryToolbarItem>> rows,
    required Widget Function(DiaryToolbarItem item) cell,
    required double bodyHeight,
    required bool scrollable,
  }) {
    final rowsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < rows.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: _kPanelRowGap),
          SizedBox(
            height: kDiaryToolbarButtonExtent,
            child: Row(
              children: <Widget>[for (final item in rows[index]) cell(item)],
            ),
          ),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kDiaryToolbarHorizontalPadding,
            _kPanelTopPadding,
            kDiaryToolbarHorizontalPadding,
            _kPanelBottomPadding,
          ),
          child: SizedBox(
            height: bodyHeight,
            child: scrollable
                ? SingleChildScrollView(primary: false, child: rowsColumn)
                : rowsColumn,
          ),
        ),
        Divider(
          height: _kPanelDividerHeight,
          thickness: 0.8,
          indent: 12,
          endIndent: 12,
          color: ExpressiveSurfaces.cardBorderColor(
            Theme.of(context).colorScheme,
          ),
        ),
      ],
    );
  }

  static double _bodyHeightForRows(int rows) =>
      rows * kDiaryToolbarButtonExtent + math.max(0, rows - 1) * _kPanelRowGap;

  double _panelBodyHeight(int rows) {
    var body = _bodyHeightForRows(rows);
    if (rows > _kPanelMaxVisibleRows) {
      body =
          _bodyHeightForRows(_kPanelMaxVisibleRows) +
          _kPanelRowGap +
          _kPanelScrollPeek;
    }
    return math.max(0.0, math.min(body, widget.maxPanelExtent - _kPanelChrome));
  }
}
