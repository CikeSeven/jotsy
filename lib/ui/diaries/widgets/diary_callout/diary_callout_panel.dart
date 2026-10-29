import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/diaries/controllers/diary_callout_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/models/diary_callout_tone.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 表头一行高度：与代码块、列表、文字样式面板的表头同高。
const double _kHeaderHeight = 40;
const double _kHeaderGap = 4;

/// 图标一排与底色一排的高度（一格 40dp，放得下 36dp 的选中环）。
const double _kRowHeight = 40;
const double _kRowGap = 8;

/// 底色一排与操作按钮之间的间距、按钮高度与底部留白（同代码块面板）。
const double _kActionsGap = 12;
const double _kActionsHeight = 40;
const double _kBottomGap = 4;

/// 标题、两排选项与按钮的左右缩进，四者左缘对齐（同代码块、列表面板）。
const double _kInset = 4;

/// 图标格里 emoji 的字号，与选中底色的边长、圆角。
const double _kIconSize = 20;
const double _kIconCell = 36;
const double _kIconCellRadius = 12;

/// 提示块面板内容的自然高度（不含面板外框）。与选区、取值无关，工具栏据此
/// 直接算出面板目标高度，不必等测量。
const double kDiaryCalloutPanelHeight =
    _kHeaderHeight +
    _kHeaderGap +
    _kRowHeight +
    _kRowGap +
    _kRowHeight +
    _kActionsGap +
    _kActionsHeight +
    _kBottomGap;

/// 悬浮工具栏卡片内的提示块面板：表头、8 个图标、6 种底色、「转为正文」。
///
/// - 输入：正文控制器、工具栏给的内容高度 [bodyHeight]（小于自然高度时面板
///   内纵向滚动）、收起回调 [onClose]；
/// - 输出：点图标 / 底色经 [setDiaryCalloutIcon] / [setDiaryCalloutTone] 改写
///   选区里每个提示块（一个事务、一步撤销，面板保持打开）；「转为正文」经
///   [convertDiaryCalloutsToText] 改写后经 [onClose] 收起（从「更多」打开的
///   回到「更多」，由工具栏决定）；
/// - 选中哪一项只看正文（随选区与撤销变化）：选区里的提示块取值不同时不选中；
/// - 两排选项都等分整行宽度，320dp 的手机上同样排成一行；
/// - 不走路由、对话框或底部面板，按钮也不请求焦点：那些都会抢走正文焦点、
///   收起键盘，而工具栏跟着键盘显示，会连同面板一起消失。
class DiaryCalloutPanel extends StatelessWidget {
  const DiaryCalloutPanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
    required this.onClose,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: _kHeaderHeight, child: _buildHeader(context)),
        const SizedBox(height: _kHeaderGap),
        ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: _kRowHeight, child: _buildIcons(context)),
              const SizedBox(height: _kRowGap),
              SizedBox(height: _kRowHeight, child: _buildTones(context)),
            ],
          ),
        ),
        const SizedBox(height: _kActionsGap),
        SizedBox(height: _kActionsHeight, child: _buildAction(context)),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < kDiaryCalloutPanelHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同代码块、列表面板表头。
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kInset),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          context.l10n.diaryEditorCallout,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildIcons(BuildContext context) {
    final selected = selectedDiaryCalloutIcon(controller);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          for (final icon in kDiaryCalloutIconChoices)
            Expanded(
              child: _DiaryCalloutIconCell(
                icon: icon,
                selected: icon == selected,
                onTap: () => setDiaryCalloutIcon(controller, icon),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTones(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = selectedDiaryCalloutTone(controller);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          for (final tone in DiaryCalloutTone.values)
            Expanded(
              // 与颜色面板的色块同一规格：强调色实心圆，选中时外加一圈环。
              child: DiaryColorSwatch(
                color: tone.accent(scheme),
                target: DiaryColorTarget.text,
                selected: tone == selected,
                label: _toneLabel(l10n, tone),
                onTap: () => setDiaryCalloutTone(controller, tone),
              ),
            ),
        ],
      ),
    );
  }

  /// 「转为正文」：铺满一行的 tonal 按钮，放不下（窄屏英文）时整体缩小。
  Widget _buildAction(BuildContext context) {
    final base = FilledButton.styleFrom(
      minimumSize: const Size(0, _kActionsHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: FilledButton.tonal(
        onPressed: () {
          convertDiaryCalloutsToText(controller);
          onClose();
        },
        // 面板在玻璃工具栏里时叠上玻璃底色与描边，经典时原样。
        style: AppGlassField.tonalButtonStyle(context)?.merge(base) ?? base,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const FaIcon(FontAwesomeIcons.paragraph, size: 14),
              const SizedBox(width: 6),
              Text(context.l10n.diaryCalloutToText, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  static String _toneLabel(AppLocalizations l10n, DiaryCalloutTone tone) =>
      switch (tone) {
        DiaryCalloutTone.neutral => l10n.diaryCalloutToneDefault,
        DiaryCalloutTone.yellow => l10n.diaryCalloutToneYellow,
        DiaryCalloutTone.green => l10n.diaryCalloutToneGreen,
        DiaryCalloutTone.blue => l10n.diaryCalloutToneBlue,
        DiaryCalloutTone.red => l10n.diaryCalloutToneRed,
        DiaryCalloutTone.purple => l10n.diaryCalloutTonePurple,
      };
}

/// 一格图标选项：emoji 居中，选中时垫 primaryContainer 圆角方块，经
/// [ExpressiveStateBlend] 补间；只是按钮，不请求焦点。
class _DiaryCalloutIconCell extends StatelessWidget {
  const _DiaryCalloutIconCell({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kIconCellRadius),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: icon,
      excludeSemantics: true,
      // 窄屏（320dp 下一格约 34dp）时方块随格宽缩小，不溢出。
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Center(
          child: _buildCell(
            colors,
            shape,
            math.min(_kIconCell, constraints.maxWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(ColorScheme colors, ShapeBorder shape, double dimension) {
    return ExpressiveStateBlend(
      active: selected,
      builder: (BuildContext context, double t, Widget? child) => Material(
        color: colors.primaryContainer.withValues(alpha: t),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        canRequestFocus: false,
        child: SizedBox.square(
          dimension: dimension,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                icon,
                maxLines: 1,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: _kIconSize, height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
