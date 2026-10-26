import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/sections/diary_head_section.dart' show DiaryLayoutMode;
import '../../../core/services/settings_service.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../diaries/sections/diaries_list_section.dart';

/// 选中日日记的“卡片”展示：直接复用日记列表的单列卡片（封面、标签、置顶
/// 徽章、未解封胶囊的封存态都与列表一致）。
///
/// 输入：选中日期、当天日记、卡片标签上限、卡片样式与打开回调；无副作用。
///
/// 列表卡片是 sliver，无法放进时间线所用的盒子级交叉淡入容器；换日时改为
/// 整段 sliver 从 0 淡入（`medium + effects`，减少动画时直接显示），旧内容
/// 不做淡出，避免两段长度不同的列表叠放时下方内容跳动。日历里不提供左滑
/// 归档与长按多选：这两个操作属于日记列表的管理场景。
///
/// 卡片样式按这一列实际的宽度解析（宽窗口里是居中的 720 一列或双栏的
/// 右栏，比窗口窄）：宽度取 sliver 的横轴约束。
class CalendarDayCardsSliver extends StatefulWidget {
  const CalendarDayCardsSliver({
    super.key,
    required this.day,
    required this.diaries,
    required this.maxVisibleTags,
    required this.onOpenDiary,
    required this.onCreate,
    this.cardStyle = DiaryCardStyle.defaults,
    this.moodOptions = SettingsService.defaultMoodOptions,
  });

  final DateTime day;
  final List<DiaryWithTags> diaries;
  final int maxVisibleTags;
  final DiaryOpenCallback onOpenDiary;
  final VoidCallback onCreate;

  /// 与日记列表相同的用户卡片样式。
  final DiaryCardStyle cardStyle;
  final List<String> moodOptions;

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

  /// 上一次按哪个宽度构建的卡片列表，见 [build]。
  double? _listWidth;
  Widget? _list;

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 本组件重建即输入可能变了：下次布局时按新输入重建列表。
    _list = null;
    return SliverFadeTransition(
      opacity: _opacity,
      // 横轴宽度只有 sliver 布局时才知道。SliverLayoutBuilder 的约束含滚动
      // 偏移，每个滚动帧都会重跑这个回调：宽度没变时交回上一次的同一个
      // widget 实例，框架据此跳过整段列表的重建，滚动时只多一次比较。
      sliver: SliverLayoutBuilder(
        builder: (BuildContext context, SliverConstraints constraints) {
          final width = constraints.crossAxisExtent;
          final cached = _list;
          if (cached != null && _listWidth == width) {
            return cached;
          }
          _listWidth = width;
          return _list = DiariesListSection(
            diaries: widget.diaries,
            layoutMode: DiaryLayoutMode.list,
            selectedDiaryIds: const <String>{},
            isSelectionMode: false,
            maxVisibleTags: widget.maxVisibleTags,
            onCreate: widget.onCreate,
            onOpenEditor: widget.onOpenDiary,
            onToggleSelection: (_, __) {},
            cardStyle: widget.cardStyle,
            moodOptions: widget.moodOptions,
            availableWidth: width,
          );
        },
      ),
    );
  }
}
