import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_strip_slots.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

part 'diary_color_saved_strip_cells.dart';

/// 我的颜色与本篇颜色之间的分隔宽度（不占一整格）。
const double _kDividerSlotWidth = 13;

/// 滚动区里一格最窄多宽：放得下 36dp 的选中环与角标。
const double _kMinSlotWidth = 40;

/// 滚动区一格的宽度：尽量接近上方网格的列宽，并让可见宽度正好容下“整数格 +
/// 半格”。颜色多到放不下时，最右边露出半个色块，一看就知道还能往左滑；
/// 若按列宽对齐，截断正好落在格子边界上，像是已经到头了。
double diaryColorStripSlotWidth(double viewport, double cellWidth) {
  final target = cellWidth * 0.85 < _kMinSlotWidth
      ? _kMinSlotWidth
      : cellWidth * 0.85;
  final whole = (viewport / target - 0.5).floor();
  if (whole < 1) return cellWidth;
  return viewport / (whole + 0.5);
}

/// 色板页下方的“我的颜色”一行（40dp）：首格新建、中间横向滚动、末格管理。
///
/// - 输入：目标、选区当前颜色、列数（列宽与上方预设网格对齐）、我的颜色
///   [saved]（保存顺序）与本篇用过的颜色 [document]（面板已去掉预设）；
/// - 输出：点色块 [onSelected]（套用，不改我的颜色）；首格 [onCreate]（转到
///   自定义页调新颜色）；管理中点我的颜色 [onRemove]、点本篇颜色 [onKeep]；
/// - 状态：管理开关只在这一行的这次挂载内有效——切换目标（面板换一行重建）、
///   换到自定义页或收起面板都会退出；什么颜色都没有了也自动退出；
/// - 动画：条目进出原地展开 / 收拢（[mergeDiaryColorStripSlots]，`medium`），
///   首次显示的条目不播；一个都没有时显示说明文字；
/// - 排布：首格与末格按网格列宽对齐，中间的格宽见 [diaryColorStripSlotWidth]。
///
/// 管理不走对话框或菜单：那些会抢走正文焦点、收起键盘，工具栏会跟着消失。
class DiaryColorSavedStrip extends StatefulWidget {
  const DiaryColorSavedStrip({
    super.key,
    required this.target,
    required this.current,
    required this.columns,
    required this.saved,
    required this.document,
    required this.onSelected,
    required this.onCreate,
    required this.onRemove,
    required this.onKeep,
  });

  final DiaryColorTarget target;
  final DiaryColorValue current;
  final int columns;
  final List<Color> saved;
  final List<Color> document;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCreate;
  final ValueChanged<Color> onRemove;
  final ValueChanged<Color> onKeep;

  @override
  State<DiaryColorSavedStrip> createState() => _DiaryColorSavedStripState();
}

class _DiaryColorSavedStripState extends State<DiaryColorSavedStrip> {
  late List<DiaryColorStripSlot> _slots = <DiaryColorStripSlot>[
    for (final entry in _entries) DiaryColorStripSlot(entry),
  ];
  bool _editing = false;

  /// 首次构建之后才给新条目播展开动画：面板打开时整页已在淡入。
  bool _built = false;

  List<DiaryColorStripEntry> get _entries =>
      diaryColorStripEntries(saved: widget.saved, document: widget.document);

  @override
  void didUpdateWidget(covariant DiaryColorSavedStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved != widget.saved ||
        oldWidget.document != widget.document) {
      final entries = _entries;
      _slots = mergeDiaryColorStripSlots(_slots, entries);
      if (entries.isEmpty) _editing = false;
    }
  }

  /// 收拢播完的格子移出这一行（仍在离开状态才移，中途回来的保留）。
  void _drop(String key) {
    if (!mounted) return;
    setState(() {
      _slots = <DiaryColorStripSlot>[
        for (final slot in _slots)
          if (!(slot.leaving && slot.key == key)) slot,
      ];
    });
  }

  void _setEditing(bool editing) {
    if (editing == _editing) return;
    setState(() => _editing = editing);
  }

  void _handleLongPress() {
    // Android 上 InkResponse 已经经 Feedback.forLongPress 震动；iOS 不会，
    // 补一次以确认进入管理（DESIGN §4.3）。
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _setEditing(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasColors = _entries.isNotEmpty;
    final animateIn = _built;
    _built = true;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final cellWidth = constraints.maxWidth / widget.columns;
        return Row(
          children: <Widget>[
            SizedBox(
              width: cellWidth,
              child: _CreateCell(onTap: widget.onCreate),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: <Widget>[...previous, ?current],
                    ),
                child: _slots.isEmpty
                    ? _EmptyHint(
                        key: const ValueKey<String>('empty'),
                        inset: (cellWidth - kDiaryColorSwatchSize) / 2,
                      )
                    : _buildScroller(
                        context,
                        diaryColorStripSlotWidth(
                          constraints.maxWidth - 2 * cellWidth,
                          cellWidth,
                        ),
                        animateIn,
                      ),
              ),
            ),
            SizedBox(
              width: cellWidth,
              child: ExpressiveIconSwap(
                switchKey: hasColors,
                child: hasColors
                    ? _ManageToggle(
                        editing: _editing,
                        onTap: () => _setEditing(!_editing),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScroller(
    BuildContext context,
    double slotWidth,
    bool animateIn,
  ) {
    final l10n = context.l10n;
    final target = widget.target;
    final current = widget.current;
    Widget swatch(DiaryColorStripEntry entry) {
      final color = entry.color!;
      final hex = diaryColorRgbHex(color);
      final saved = entry.kind == DiaryColorStripKind.saved;
      return DiaryColorSwatch(
        color: color,
        target: target,
        selected: current.matches(color),
        tooltip: false,
        badge: !_editing
            ? DiaryColorSwatchBadge.none
            : saved
            ? DiaryColorSwatchBadge.remove
            : DiaryColorSwatchBadge.keep,
        label: switch ((_editing, saved)) {
          (true, true) => l10n.diaryColorPanelRemoveColor(hex),
          (true, false) => l10n.diaryColorPanelKeepColor(hex),
          (false, true) => l10n.diaryColorPanelSavedColor(hex),
          (false, false) => l10n.diaryColorPanelDocumentColor(hex),
        },
        onTap: () {
          if (!_editing) {
            widget.onSelected(color);
          } else if (saved) {
            widget.onRemove(color);
          } else {
            widget.onKeep(color);
          }
        },
        onLongPress: _editing ? null : _handleLongPress,
      );
    }

    return SingleChildScrollView(
      key: const ValueKey<String>('strip'),
      scrollDirection: Axis.horizontal,
      primary: false,
      child: Row(
        children: <Widget>[
          for (final slot in _slots)
            _StripCell(
              key: ValueKey<String>(slot.key),
              width: slot.entry.kind == DiaryColorStripKind.divider
                  ? _kDividerSlotWidth
                  : slotWidth,
              leaving: slot.leaving,
              animateIn: animateIn,
              onExited: () => _drop(slot.key),
              child: slot.entry.kind == DiaryColorStripKind.divider
                  ? const _StripDivider()
                  : swatch(slot.entry),
            ),
        ],
      ),
    );
  }
}
