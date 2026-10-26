import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_material_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_custom_picker.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_material_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_saved_strip.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch_grid.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

part 'diary_color_panel_header.dart';

/// 颜色面板的三页：色板（默认 + 预设，下方一行我的颜色与本篇用过的颜色）、
/// 色系（Material 色板：各色系的深浅色阶）与自定义（色谱自由取色 + 颜色代码）。
enum DiaryColorPanelMode { swatches, material, custom }

/// 表头一行的高度：与工具栏 40dp 一格同高，放得下 36dp 的页签。
const double kDiaryColorPanelHeaderHeight = 40;

/// 表头与下方内容之间的间距。
const double kDiaryColorPanelHeaderGap = 4;

/// 颜色面板内容的自然高度：表头 + 间距 + 当前页。工具栏据此直接算出面板
/// 目标高度，不必等测量；与保存了几个颜色无关。三页在常见手机宽度下等高
/// （预设两行 + 我的颜色一行 = 色阶两行 + 色系一行 = 自定义页 128dp），切换
/// 页签时面板不跳；宽屏预设或色阶只占一行时高度随之补间。
double diaryColorPanelNaturalHeight(
  DiaryColorPanelMode mode,
  DiaryColorGridLayout grid,
) =>
    kDiaryColorPanelHeaderHeight +
    kDiaryColorPanelHeaderGap +
    switch (mode) {
      DiaryColorPanelMode.swatches => grid.height,
      DiaryColorPanelMode.material => grid.materialHeight,
      DiaryColorPanelMode.custom => kDiaryColorCustomPickerHeight,
    };

/// 悬浮工具栏卡片内的颜色面板：表头（目标标题 + 色板 / 色系 / 自定义页签）与
/// 当前页。
///
/// - 输入：正文控制器、当前目标与页签、网格排布、我的颜色 [savedColors]
///   （当前目标的，随保存实时更新）、本篇用过的颜色 [documentColors]（由
///   工具栏在面板打开、切换目标与回到色板时整理，这里不扫描文档）与色系页
///   上次看的色系 [materialFamily]；
/// - 输出：色块经 `controller.formatSelection` 写入 `#AARRGGBB` 或清除属性；
///   色系页看的色系变了经 [onMaterialFamilyChanged] 交给工具栏记住；
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
    this.materialFamily = DiaryMaterialFamily.red,
    this.onMaterialFamilyChanged,
  });

  final editor.DiaryEditorController controller;
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

  /// 色系页打开时显示的色系（选区颜色在色板里时以选区为准）。
  final DiaryMaterialFamily materialFamily;
  final ValueChanged<DiaryMaterialFamily>? onMaterialFamilyChanged;

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
          child: _DiaryColorPanelHeader(
            target: target,
            mode: mode,
            columns: grid.columns,
            onModeChanged: onModeChanged,
          ),
        ),
        const SizedBox(height: kDiaryColorPanelHeaderGap),
        ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => _buildPage(
            context,
            DiaryColorValue.of(controller.selectionAttributes, target),
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
        DiaryColorPanelMode.material => DiaryColorMaterialPage(
          key: const ValueKey<DiaryColorPanelMode>(
            DiaryColorPanelMode.material,
          ),
          target: target,
          current: current,
          grid: grid,
          initialFamily: materialFamily,
          onFamilyChanged: (DiaryMaterialFamily family) =>
              onMaterialFamilyChanged?.call(family),
          onSelected: (Color color) => _applySwatch(color, current),
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
}
