import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/sections/diary_head_section.dart' show DiaryLayoutMode;
import '../../diaries/sections/diaries_list_section.dart';

/// 选中日日记的“卡片”展示：直接复用日记列表的单列卡片（封面、标签、置顶
/// 徽章、未解封胶囊的封存态都与列表一致）。
///
/// 输入：选中日期、当天日记、卡片标签上限与打开回调；无副作用。
///
/// 列表卡片是 sliver，无法放进时间线所用的盒子级交叉淡入容器；换日时改为
/// 整段 sliver 从 0 淡入（`medium + effects`，减少动画时直接显示），旧内容
/// 不做淡出，避免两段长度不同的列表叠放时下方内容跳动。日历里不提供左滑
/// 归档与长按多选：这两个操作属于日记列表的管理场景。
class CalendarDayCardsSliver extends StatefulWidget {
  const CalendarDayCardsSliver({
    super.key,
    required this.day,
    required this.diaries,
    required this.maxVisibleTags,
    required this.onOpenDiary,
    required this.onCreate,
  });

  final DateTime day;
  final List<DiaryWithTags> diaries;
  final int maxVisibleTags;
  final DiaryOpenCallback onOpenDiary;
  final VoidCallback onCreate;

  @override
  State<CalendarDayCardsSliver> createState() => _CalendarDayCardsSliverState();
}

class _CalendarDayCardsSliverState extends State<CalendarDayCardsSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.medium,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: ExpressiveMotion.effects,
  );

  @override
  void didUpdateWidget(covariant CalendarDayCardsSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (DateUtils.isSameDay(oldWidget.day, widget.day)) {
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      _fade.value = 1;
      return;
    }
    _fade
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverFadeTransition(
      opacity: _opacity,
      sliver: DiariesListSection(
        diaries: widget.diaries,
        layoutMode: DiaryLayoutMode.list,
        selectedDiaryIds: const <String>{},
        isSelectionMode: false,
        maxVisibleTags: widget.maxVisibleTags,
        onCreate: widget.onCreate,
        onOpenEditor: widget.onOpenDiary,
        onToggleSelection: (_, __) {},
      ),
    );
  }
}
