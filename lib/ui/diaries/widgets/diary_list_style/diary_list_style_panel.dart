import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/controllers/diary_list_style_editing.dart';

import 'diary_list_style_tile.dart';

/// 表头一行高度：与代码块、颜色面板的表头同高。
const double _kHeaderHeight = 40;
const double _kHeaderGap = 4;

/// 样式格子之间的行列间距。
const double _kTileGap = 8;
const double _kActionsGap = 12;
const double _kActionsHeight = 40;
const double _kBottomGap = 4;

/// 标题、格子区与操作按钮一排的左右缩进，三者左缘对齐（同代码块面板）。
const double _kInset = 4;

/// [type] 列表的样式选项数：“自动”加各个格式。
int _optionCount(String type) =>
    1 +
    (type == kDiaryBlockNumberedList
        ? DiaryOrderedListStyle.values.length
        : DiaryBulletListStyle.values.length);

/// 样式格子的排布：按面板内容宽度 [innerWidth]（已扣掉卡片左右留白）算出
/// 一行最多放几个，再在行数不变的前提下让各行一样多（8 个排成 4 + 4，而
/// 不是 5 + 3）。宽窗口里一行放得下就排成一行。
({int columns, int rows}) diaryListStyleGrid(double innerWidth, String type) {
  final count = _optionCount(type);
  final width = math.max(0.0, innerWidth - 2 * _kInset);
  final fit = ((width + _kTileGap) / (kDiaryListStyleTileMinWidth + _kTileGap))
      .floor()
      .clamp(1, count);
  final rows = (count / fit).ceil();
  return (columns: (count / rows).ceil(), rows: rows);
}

/// 列表面板内容的自然高度（不含面板外框）：随宽度决定的行数变化，工具栏
/// 据此直接算出面板目标高度，不必等测量。
double diaryListStylePanelHeight(double innerWidth, String type) {
  final rows = diaryListStyleGrid(innerWidth, type).rows;
  return _kHeaderHeight +
      _kHeaderGap +
      rows * kDiaryListStyleTileHeight +
      (rows - 1) * _kTileGap +
      _kActionsGap +
      _kActionsHeight +
      _kBottomGap;
}

/// 悬浮工具栏卡片内的列表面板：表头、样式格子、转为另一种列表 / 转为正文。
///
/// - 输入：正文控制器、当前面板对应的列表类型 [type]（有序或无序，由工具栏
///   按选区决定）、内容宽度 [innerWidth] 与工具栏给的内容高度 [bodyHeight]
///   （小于自然高度时面板内纵向滚动）、收起回调 [onClose]；
/// - 输出：点格子经 [setDiaryListStyle] 把选区触及的每段列表整段改成该样式
///   （面板保持打开，一步撤销）；转为另一种列表后选区仍在列表里，工具栏随
///   选区换成另一种列表的样式；转为正文后经 [onClose] 收起；
/// - 选中哪一格只看正文：选区触及的各段样式相同时选中它（都没选过为“自动”），
///   不同时不选中；
/// - 不走路由、对话框或底部面板，按钮也不请求焦点：那些都会抢走正文焦点、
///   收起键盘，而工具栏跟着键盘显示，会连同面板一起消失。
class DiaryListStylePanel extends StatelessWidget {
  const DiaryListStylePanel({
    super.key,
    required this.controller,
    required this.type,
    required this.innerWidth,
    required this.bodyHeight,
    required this.onClose,
  });

  final editor.DiaryEditorController controller;
  final String type;
  final double innerWidth;
  final double bodyHeight;
  final VoidCallback onClose;

  bool get _numbered => type == kDiaryBlockNumberedList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final natural = diaryListStylePanelHeight(innerWidth, type);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _kHeaderHeight,
          child: _buildHeader(
            context,
            _numbered
                ? l10n.diaryListStyleNumberedTitle
                : l10n.diaryListStyleBulletedTitle,
          ),
        ),
        const SizedBox(height: _kHeaderGap),
        ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => _buildGrid(context),
        ),
        const SizedBox(height: _kActionsGap),
        SizedBox(height: _kActionsHeight, child: _buildActions(context)),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < natural
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同代码块、颜色面板表头。
  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kInset),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
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

  Widget _buildGrid(BuildContext context) {
    final l10n = context.l10n;
    final current = selectedDiaryListStyle(controller, type);
    final tiles = <Widget>[
      DiaryListStyleTile(
        key: const ValueKey<String>('list-style-auto'),
        numbered: _numbered,
        label: l10n.diaryListStyleAuto,
        selected: current != null && current.id == null,
        onTap: () => setDiaryListStyle(controller, type, null),
      ),
      if (_numbered)
        for (final style in DiaryOrderedListStyle.values)
          DiaryListStyleTile(
            key: ValueKey<String>('list-style-${style.id}'),
            numbered: true,
            ordered: style,
            label: _orderedLabel(l10n, style),
            selected: current?.id == style.id,
            onTap: () => setDiaryListStyle(controller, type, style.id),
          )
      else
        for (final style in DiaryBulletListStyle.values)
          DiaryListStyleTile(
            key: ValueKey<String>('list-style-${style.id}'),
            numbered: false,
            bullet: style,
            label: _bulletLabel(l10n, style),
            selected: current?.id == style.id,
            onTap: () => setDiaryListStyle(controller, type, style.id),
          ),
    ];
    final columns = diaryListStyleGrid(innerWidth, type).columns;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Column(
        children: <Widget>[
          for (var start = 0; start < tiles.length; start += columns) ...[
            if (start > 0) const SizedBox(height: _kTileGap),
            Row(
              children: <Widget>[
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: _kTileGap),
                  // 最后一行不满时空出位置，格子与上一行对齐、不被拉宽。
                  Expanded(
                    child: start + column < tiles.length
                        ? tiles[start + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          _action(
            icon: _numbered ? FontAwesomeIcons.listUl : FontAwesomeIcons.listOl,
            label: _numbered
                ? l10n.diaryListToBulleted
                : l10n.diaryListToNumbered,
            onPressed: () => controller.setBlockType(
              _numbered ? kDiaryBlockBulletedList : kDiaryBlockNumberedList,
            ),
          ),
          const SizedBox(width: _kTileGap),
          _action(
            icon: FontAwesomeIcons.paragraph,
            label: l10n.diaryListToText,
            onPressed: () {
              controller.setBlockType(kDiaryBlockParagraph);
              onClose();
            },
          ),
        ],
      ),
    );
  }

  /// 两个等宽的 tonal 按钮；放不下时图标与文字一起缩小（同代码块面板）。
  Widget _action({
    required FaIconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, _kActionsHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(icon, size: 14),
              const SizedBox(width: 6),
              Text(label, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }

  static String _orderedLabel(
    AppLocalizations l10n,
    DiaryOrderedListStyle style,
  ) => switch (style) {
    DiaryOrderedListStyle.decimal => l10n.diaryListStyleDecimal,
    DiaryOrderedListStyle.parenthesized => l10n.diaryListStyleParenthesized,
    DiaryOrderedListStyle.circled => l10n.diaryListStyleCircled,
    DiaryOrderedListStyle.chinese => l10n.diaryListStyleChinese,
    DiaryOrderedListStyle.lowerAlpha => l10n.diaryListStyleLowerAlpha,
    DiaryOrderedListStyle.upperAlpha => l10n.diaryListStyleUpperAlpha,
    DiaryOrderedListStyle.lowerRoman => l10n.diaryListStyleLowerRoman,
    DiaryOrderedListStyle.upperRoman => l10n.diaryListStyleUpperRoman,
  };

  static String _bulletLabel(
    AppLocalizations l10n,
    DiaryBulletListStyle style,
  ) => switch (style) {
    DiaryBulletListStyle.disc => l10n.diaryListStyleDisc,
    DiaryBulletListStyle.circle => l10n.diaryListStyleCircle,
    DiaryBulletListStyle.square => l10n.diaryListStyleSquare,
    DiaryBulletListStyle.diamond => l10n.diaryListStyleDiamond,
    DiaryBulletListStyle.star => l10n.diaryListStyleStar,
    DiaryBulletListStyle.arrow => l10n.diaryListStyleArrow,
    DiaryBulletListStyle.dash => l10n.diaryListStyleDash,
  };
}
