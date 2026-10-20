import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_custom_picker.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_saved_strip.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch_grid.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

/// 颜色面板的两页：色板（默认 + 预设，下方一行我的颜色与本篇用过的颜色）
/// 与自定义（色谱自由取色 + 颜色代码）。
enum DiaryColorPanelMode { swatches, custom }

/// 表头一行的高度：与工具栏 40dp 一格同高，放得下 36dp 的页签。
const double kDiaryColorPanelHeaderHeight = 40;

/// 表头与下方内容之间的间距。
const double kDiaryColorPanelHeaderGap = 4;

/// 页签最多占表头宽度的比例，余下留给目标标题。
const double _kModeSwitchMaxWidthFactor = 0.62;

/// 颜色面板内容的自然高度：表头 + 间距 + 当前页。工具栏据此直接算出面板
/// 目标高度，不必等测量；与保存了几个颜色无关。两页在常见手机宽度下等高
/// （预设两行 + 我的颜色一行 = 自定义页 128dp），切换页签时面板不跳；
/// 宽屏预设只占一行时高度随之补间。
double diaryColorPanelNaturalHeight(
  DiaryColorPanelMode mode,
  DiaryColorGridLayout grid,
) =>
    kDiaryColorPanelHeaderHeight +
    kDiaryColorPanelHeaderGap +
    switch (mode) {
      DiaryColorPanelMode.swatches => grid.height,
      DiaryColorPanelMode.custom => kDiaryColorCustomPickerHeight,
    };

/// 悬浮工具栏卡片内的颜色面板：表头（目标标题 + 色板 / 自定义页签）与当前页。
///
/// - 输入：正文控制器、当前目标与页签、网格排布、我的颜色 [savedColors]
///   （当前目标的，随保存实时更新）与本篇用过的颜色 [documentColors]（由
///   工具栏在面板打开、切换目标与回到色板时整理，这里不扫描文档）；
/// - 输出：色块经 `controller.formatSelection` 写入 `#AARRGGBB` 或清除属性；
///   我的颜色的增删（自定义页写入后保存、色板里移除或收藏）一律经
///   [onEditSavedColors] 交给 provider 在最新记录上执行；切换页签经
///   [onModeChanged] 交给工具栏（面板高度由工具栏计算并报告给编辑页），
///   我的颜色一行的“+”也经它转到自定义页；
/// - 面板里不放文字 / 背景切换：工具栏上的两个颜色按钮就是切换，点另一个时
///   面板保持打开、色块原地变色，表头标题随之交叉淡入；
/// - 不走路由、对话框或底部面板：那些都会抢走正文焦点、收起键盘，而工具栏
///   跟着键盘显示，会连同面板一起消失。
class DiaryColorPanel extends StatelessWidget {
  const DiaryColorPanel({
    super.key,
    required this.controller,
    required this.target,
    required this.mode,
    required this.onModeChanged,
    required this.grid,
    required this.savedColors,
    required this.documentColors,
    required this.bodyHeight,
    required this.active,
    required this.onEditSavedColors,
  });

  final quill.QuillController controller;
  final DiaryColorTarget target;
  final DiaryColorPanelMode mode;
  final ValueChanged<DiaryColorPanelMode> onModeChanged;
  final DiaryColorGridLayout grid;

  /// 当前目标的我的颜色（保存顺序，新的在前）。
  final List<Color> savedColors;

  /// 本篇用过的非预设颜色（文档顺序）；已保存的由我的颜色一行自行去掉。
  final List<Color> documentColors;

  /// 工具栏给的内容高度；小于自然高度时面板内纵向滚动。
  final double bodyHeight;

  /// 面板是否仍是工具栏当前展开的内容；收起或换成「更多」时为 false，
  /// 正在输入颜色代码的话立即放弃并交还焦点（不等收起动画播完）。
  final bool active;
  final ValueChanged<DiarySavedColorsEdit> onEditSavedColors;

  /// 点色块：写入颜色（null 为清除）；与选区当前值相同则不动正文。
  void _applySwatch(Color? color, DiaryColorValue current) {
    if (color == null ? current.isNone : current.matches(color)) return;
    controller.formatSelection(target.attributeFor(color));
  }

  @override
  Widget build(BuildContext context) {
    final natural = diaryColorPanelNaturalHeight(mode, grid);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: kDiaryColorPanelHeaderHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _buildHeader(context, constraints.maxWidth),
          ),
        ),
        const SizedBox(height: kDiaryColorPanelHeaderGap),
        ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => _buildPage(
            context,
            DiaryColorValue.of(
              controller.getSelectionStyle().attributes,
              target,
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < natural
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 当前页；换页时交叉淡入。旧页不参与定尺寸、可以画出新页的范围：面板
  /// 外框随新页高度补间并负责裁切，变矮时旧页随外框一起收拢而不是先被截断。
  Widget _buildPage(BuildContext context, DiaryColorValue current) {
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      layoutBuilder: (Widget? currentChild, List<Widget> previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          for (final child in previous)
            Positioned(top: 0, left: 0, right: 0, child: child),
          ?currentChild,
        ],
      ),
      child: switch (mode) {
        DiaryColorPanelMode.swatches => SizedBox(
          key: const ValueKey<DiaryColorPanelMode>(
            DiaryColorPanelMode.swatches,
          ),
          height: grid.height,
          child: _buildSwatchesPage(context, current),
        ),
        DiaryColorPanelMode.custom => DiaryColorCustomPicker(
          key: const ValueKey<DiaryColorPanelMode>(DiaryColorPanelMode.custom),
          controller: controller,
          target: target,
          current: current,
          active: active,
          savedColors: savedColors,
          onSave: (Color color, Color? replacing) => onEditSavedColors(
            (DiarySavedColors saved) =>
                saved.save(target, color, replacing: replacing),
          ),
        ),
      },
    );
  }

  /// 色板页：预设网格，细分隔线（两端对齐色块圆的边缘），我的颜色一行。
  /// 我的颜色一行按目标交叉淡入：两种目标的颜色各不相同，管理状态也随之
  /// 结束。
  Widget _buildSwatchesPage(BuildContext context, DiaryColorValue current) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final inset =
            (constraints.maxWidth / grid.columns - kDiaryColorSwatchSize) / 2;
        return Column(
          children: <Widget>[
            SizedBox(
              height: grid.presetHeight,
              child: DiaryColorSwatchGrid(
                target: target,
                current: current,
                grid: grid,
                onSelected: (Color? color) => _applySwatch(color, current),
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
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                child: DiaryColorSavedStrip(
                  key: ValueKey<DiaryColorTarget>(target),
                  target: target,
                  current: current,
                  columns: grid.columns,
                  saved: savedColors,
                  document: documentColors,
                  onSelected: (Color color) => _applySwatch(color, current),
                  onCreate: () => onModeChanged(DiaryColorPanelMode.custom),
                  onRemove: (Color color) => onEditSavedColors(
                    (DiarySavedColors saved) => saved.remove(target, color),
                  ),
                  onKeep: (Color color) => onEditSavedColors(
                    (DiarySavedColors saved) => saved.save(target, color),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double width) {
    final l10n = context.l10n;
    // 与色块网格同一列宽（可用宽度 / 列数）。
    final cellWidth = width / grid.columns;
    Widget label(String text) => Text(text, maxLines: 1);
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            // 标题起点对齐第一个色块圆的左缘（色块在格子里居中）。
            padding: EdgeInsetsDirectional.only(
              start: (cellWidth - kDiaryColorSwatchSize) / 2,
            ),
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: <Widget>[...previous, ?current],
              ),
              child: Text(
                _targetItem.label(l10n),
                key: ValueKey<DiaryColorTarget>(target),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 页签按标签自身宽度排列、优先完整显示，标题让出空间（窄屏英文可能
        // 省略）；超大字号下页签整体缩小，不溢出 40dp 表头。
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width * _kModeSwitchMaxWidthFactor,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: ExpressiveButtonGroup<DiaryColorPanelMode>(
              dense: true,
              segments: <ButtonSegment<DiaryColorPanelMode>>[
                ButtonSegment<DiaryColorPanelMode>(
                  value: DiaryColorPanelMode.swatches,
                  label: label(l10n.diaryColorPanelSwatches),
                ),
                ButtonSegment<DiaryColorPanelMode>(
                  value: DiaryColorPanelMode.custom,
                  label: label(l10n.diaryColorPanelCustom),
                ),
              ],
              selected: <DiaryColorPanelMode>{mode},
              onSelectionChanged: (Set<DiaryColorPanelMode> selection) =>
                  onModeChanged(selection.single),
            ),
          ),
        ),
      ],
    );
  }

  /// 标题沿用工具栏上对应按钮的名称（文字颜色 / 背景颜色）。
  DiaryToolbarItem get _targetItem => switch (target) {
    DiaryColorTarget.text => DiaryToolbarItem.textColor,
    DiaryColorTarget.background => DiaryToolbarItem.backgroundColor,
  };
}
