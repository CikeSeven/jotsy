import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_material_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';

part 'diary_color_material_cells.dart';

/// 两行排色阶时一格最宽多少：宽一些的屏幕上色块不至于散得太开，多出的宽度
/// 留在行尾（与色板页一样靠起点排）。
const double _kMaxShadeCellWidth = 56;

/// 色系一行一格最窄多宽：放得下 36dp 的选中环，手指也点得准。
const double _kMinFamilySlotWidth = 40;

/// 色系一行的格宽：可见宽度正好是偶数格，内容两端各留半格。这样当前色系
/// 居中时，两端都正好切在圆点中间；滚到头时贴边的一端是那半格留白，另一端
/// 仍切在圆点中间——只要那一侧还有色系，就露出半个圆点提示还能滑。
double _familySlotWidth(double viewport) {
  var slots = (viewport / _kMinFamilySlotWidth).floor();
  if (slots.isOdd) slots -= 1;
  return viewport / math.max(2, slots);
}

/// 颜色面板的「色系」页：旧版取色对话框里的 Material 色板。上方是当前色系
/// 的色阶（从浅到深，强调色隔一道竖线排在后面），下方一行是可横向滚动的
/// 19 个色系。
///
/// - 输入：目标、选区当前颜色、网格排布、上次看的色系 [initialFamily]；
/// - 输出：点色阶 [onSelected] 写入那一格的原值（不透明，不存进我的颜色）；
///   看的色系变了经 [onFamilyChanged] 告诉工具栏，收起再打开、换页签回来
///   都停在这里；
/// - 换色系：点下方的色系圆点，或在色阶上左右滑动（跟手翻页，越过半页即换）；
///   当前色系的圆点放大并加外环，并滚到这一行的中间，两侧的色系都露得出来；
/// - 跟随：打开时、以及选区颜色变成另一个色系里的某一格时（点了别的文字、
///   换了目标、撤销），翻到那个色系，选中的色阶一眼可见；选区颜色不在色板
///   里或没有颜色时停在原来的色系；
/// - 远处的色系先跳到它的邻页再滑进来（同 TabBarView），不会一路刷过中间
///   十几页；减少动画时直接跳到。
class DiaryColorMaterialPage extends StatefulWidget {
  const DiaryColorMaterialPage({
    super.key,
    required this.target,
    required this.current,
    required this.grid,
    required this.initialFamily,
    required this.onFamilyChanged,
    required this.onSelected,
  });

  final DiaryColorTarget target;
  final DiaryColorValue current;
  final DiaryColorGridLayout grid;
  final DiaryMaterialFamily initialFamily;
  final ValueChanged<DiaryMaterialFamily> onFamilyChanged;
  final ValueChanged<Color> onSelected;

  @override
  State<DiaryColorMaterialPage> createState() => _DiaryColorMaterialPageState();
}

class _DiaryColorMaterialPageState extends State<DiaryColorMaterialPage> {
  late DiaryMaterialFamily _family =
      DiaryMaterialFamily.of(widget.current.color) ?? widget.initialFamily;
  late final PageController _pages = PageController(initialPage: _family.index);

  /// 色系一行的滚动：首次布局时才知道格宽，那时按当前色系居中创建，第一帧
  /// 就停在正确的位置，不先在开头闪一下再跳过去。
  ScrollController? _row;
  double _slotWidth = 0;
  double _rowViewport = 0;

  /// 最近一次看到的选区颜色（ARGB）：只有它变了才跟随，用户自己翻到别的
  /// 色系时不会被拉回去。
  int? _currentArgb;

  /// 程序翻页（点圆点、跟随选区）进行中：途经的页不改当前色系。
  bool _navigating = false;
  int _navigation = 0;

  @override
  void initState() {
    super.initState();
    _currentArgb = widget.current.color?.toARGB32();
    if (_family != widget.initialFamily) widget.onFamilyChanged(_family);
  }

  @override
  void didUpdateWidget(covariant DiaryColorMaterialPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final argb = widget.current.color?.toARGB32();
    if (argb == _currentArgb) return;
    _currentArgb = argb;
    final family = DiaryMaterialFamily.of(widget.current.color);
    if (family == null || family == _family) return;
    // 翻页会发出滚动通知、改动 Scrollable 的状态，不能在构建中进行。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(family);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _row?.dispose();
    super.dispose();
  }

  /// 换到 [family]：圆点、色系一行与色阶页一起过去。
  void _goTo(DiaryMaterialFamily family) {
    if (family != _family) {
      setState(() => _family = family);
      widget.onFamilyChanged(family);
    }
    _centerFamily(family);
    _showPage(family.index);
  }

  /// 用户滑过半页：色阶已经在手指下，只更新圆点与色系一行。
  void _handlePageChanged(int index) {
    if (_navigating) return;
    final family = DiaryMaterialFamily.values[index];
    if (family == _family) return;
    setState(() => _family = family);
    widget.onFamilyChanged(family);
    _centerFamily(family);
  }

  void _showPage(int page) {
    if (!_pages.hasClients) return;
    final position = _pages.page ?? page.toDouble();
    // 已经停在这一页（如点了当前色系的圆点）：只把圆点滚回中间。
    if ((position - page).abs() < 0.001) return;
    final from = position.round();
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final token = ++_navigation;
    _navigating = true;
    if (duration == Duration.zero) {
      _pages.jumpToPage(page);
      _navigating = false;
      return;
    }
    if ((page - from).abs() > 1) {
      _pages.jumpToPage(page > from ? page - 1 : page + 1);
    }
    unawaited(
      _pages
          .animateToPage(
            page,
            duration: duration,
            curve: ExpressiveMotion.spatial,
          )
          .whenComplete(() {
            // 中途又点了别的色系时，由最后那一次收尾。
            if (token == _navigation) _navigating = false;
          }),
    );
  }

  /// 色系一行里让 [family] 居中（到头时贴边）。第 i 个圆点的中心在
  /// (i + 1) × 格宽（前面有半格留白），见 [_familySlotWidth]。
  double _rowOffset(DiaryMaterialFamily family) {
    final extent = (DiaryMaterialFamily.values.length + 1) * _slotWidth;
    final max = math.max(0.0, extent - _rowViewport);
    final centered = (family.index + 1) * _slotWidth - _rowViewport / 2;
    return centered.clamp(0.0, max);
  }

  void _centerFamily(DiaryMaterialFamily family) {
    final row = _row;
    if (row == null || !row.hasClients) return;
    final offset = _rowOffset(family);
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      row.jumpTo(offset);
    } else {
      unawaited(
        row.animateTo(
          offset,
          duration: duration,
          curve: ExpressiveMotion.effects,
        ),
      );
    }
  }

  /// 色阶一格的宽度：一行排完时与色板页同一列宽；两行时平分整行，但不超过
  /// [_kMaxShadeCellWidth]。
  double _shadeCellWidth(double width) {
    final grid = widget.grid;
    if (grid.materialColumns == kDiaryMaterialMaxShades) {
      return width / grid.columns;
    }
    return math.min(width / grid.materialColumns, _kMaxShadeCellWidth);
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    return SizedBox(
      height: grid.materialHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final width = constraints.maxWidth;
          final shadeCell = _shadeCellWidth(width);
          final inset = (shadeCell - kDiaryColorSwatchSize) / 2;
          // stretch：色系一行在宽屏上放得下全部圆点时也从起点排，不被居中。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: grid.materialShadesHeight,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: DiaryMaterialFamily.values.length,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (BuildContext context, int index) => _ShadeGrid(
                    family: DiaryMaterialFamily.values[index],
                    target: widget.target,
                    current: widget.current,
                    columns: grid.materialColumns,
                    cellWidth: shadeCell,
                    onSelected: widget.onSelected,
                  ),
                ),
              ),
              Divider(
                height: DiaryColorGridLayout.stripGap,
                thickness: 0.8,
                indent: inset,
                endIndent: inset,
                color: ExpressiveSurfaces.cardBorderColor(
                  Theme.of(context).colorScheme,
                ),
              ),
              SizedBox(
                height: DiaryColorGridLayout.cellHeight,
                child: _buildFamilies(context, width),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 色系一行：两端各留半格，格宽见 [_familySlotWidth]。
  Widget _buildFamilies(BuildContext context, double width) {
    _slotWidth = _familySlotWidth(width);
    _rowViewport = width;
    final l10n = context.l10n;
    return SingleChildScrollView(
      controller: _row ??= ScrollController(
        initialScrollOffset: _rowOffset(_family),
      ),
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: _slotWidth / 2),
      child: Row(
        children: <Widget>[
          for (final family in DiaryMaterialFamily.values)
            SizedBox(
              width: _slotWidth,
              child: _FamilyDot(
                color: family.color,
                selected: family == _family,
                label: l10n.diaryColorPanelFamily(family.label(l10n)),
                onTap: () => _goTo(family),
              ),
            ),
        ],
      ),
    );
  }
}

/// 色系的显示名（与预设同名的复用预设的文案）。
extension DiaryMaterialFamilyLabel on DiaryMaterialFamily {
  String label(AppLocalizations l10n) => switch (this) {
    DiaryMaterialFamily.red => l10n.diaryColorRed,
    DiaryMaterialFamily.pink => l10n.diaryColorPink,
    DiaryMaterialFamily.purple => l10n.diaryColorPurple,
    DiaryMaterialFamily.deepPurple => l10n.diaryColorDeepPurple,
    DiaryMaterialFamily.indigo => l10n.diaryColorIndigo,
    DiaryMaterialFamily.blue => l10n.diaryColorBlue,
    DiaryMaterialFamily.lightBlue => l10n.diaryColorLightBlue,
    DiaryMaterialFamily.cyan => l10n.diaryColorCyan,
    DiaryMaterialFamily.teal => l10n.diaryColorTeal,
    DiaryMaterialFamily.green => l10n.diaryColorGreen,
    DiaryMaterialFamily.lightGreen => l10n.diaryColorLightGreen,
    DiaryMaterialFamily.lime => l10n.diaryColorLime,
    DiaryMaterialFamily.yellow => l10n.diaryColorYellow,
    DiaryMaterialFamily.amber => l10n.diaryColorAmber,
    DiaryMaterialFamily.orange => l10n.diaryColorOrange,
    DiaryMaterialFamily.deepOrange => l10n.diaryColorDeepOrange,
    DiaryMaterialFamily.brown => l10n.diaryColorBrown,
    DiaryMaterialFamily.grey => l10n.diaryColorGray,
    DiaryMaterialFamily.blueGrey => l10n.diaryColorBlueGray,
  };

  /// 一格色阶的显示名：“红 500”“蓝 A200”，灰色系两端是“白”“黑”。
  String shadeLabel(AppLocalizations l10n, DiaryMaterialShade shade) =>
      switch (shade.kind) {
        DiaryMaterialShadeKind.white => l10n.diaryColorWhite,
        DiaryMaterialShadeKind.black => l10n.diaryColorBlack,
        _ => l10n.diaryColorShade(label(l10n), shade.tone),
      };
}
