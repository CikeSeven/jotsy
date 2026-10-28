import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/explore_appearance.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_id.dart';
import '../widgets/explore_appearance_scope.dart';

/// 排进探索页的一张卡片：设置（决定宽窗口下占整行还是一列）与已建好的卡片。
@immutable
class ExploreModuleSlot {
  const ExploreModuleSlot({required this.config, required this.child});

  final ExploreModuleConfig config;
  final Widget child;
}

/// 探索页卡片的排布。
///
/// 列数按实际可用宽度（[LayoutBuilder]，不看屏宽）与外观里的“宽窗口列数”：
/// 自动时内容宽 ≥ 720 为两列；手动两列需 ≥ 600、三列需 ≥ 900，不够时少一列；
/// 手机宽度一律单列，宽度设置不起作用。
///
/// 多列时，占整行的卡片单独一行；连续的半宽卡片按外观里的排布摆放：
/// - 对齐成行：每 N 张一行、顶端对齐（不用 IntrinsicHeight——“那年今日”的
///   PageView 不支持固有尺寸测量），一行凑不满时这几张平分整行；
/// - 错落：这一段半宽卡片按顺序逐张放进当前最矮的一列（Masonry），高矮
///   不一的卡片不会在行间留出大块空白；只有一张时占整行。
class ExploreModulesView extends StatelessWidget {
  const ExploreModulesView({super.key, required this.slots});

  final List<ExploreModuleSlot> slots;

  /// [width] 下实际的列数。
  static int columnsFor(ExploreWideColumns columns, double width) {
    return switch (columns) {
      ExploreWideColumns.one => 1,
      ExploreWideColumns.auto => width >= 720 ? 2 : 1,
      ExploreWideColumns.two => width >= 600 ? 2 : 1,
      ExploreWideColumns.three =>
        width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final look = ExploreAppearanceScope.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = columnsFor(look.columns, constraints.maxWidth);
        final gap = look.cardGap;
        final rows = <Widget>[];
        if (columns <= 1) {
          for (final slot in slots) {
            rows.add(_keyed(slot));
          }
        } else {
          var run = <ExploreModuleSlot>[];
          void flush() {
            if (run.isEmpty) return;
            rows.addAll(
              look.flow == ExploreWideFlow.staggered
                  ? _staggered(run, columns, gap)
                  : _aligned(run, columns, gap),
            );
            run = <ExploreModuleSlot>[];
          }

          for (final slot in slots) {
            if (slot.config.resolvedSpan == ExploreModuleSpan.half) {
              run.add(slot);
            } else {
              flush();
              rows.add(_keyed(slot));
            }
          }
          flush();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }

  static Widget _keyed(ExploreModuleSlot slot) => KeyedSubtree(
    key: ValueKey<ExploreModuleId>(slot.config.id),
    child: slot.child,
  );

  static List<Widget> _aligned(
    List<ExploreModuleSlot> run,
    int columns,
    double gap,
  ) {
    return <Widget>[
      for (var start = 0; start < run.length; start += columns)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (
              var i = start;
              i < start + columns && i < run.length;
              i++
            ) ...<Widget>[
              if (i > start) SizedBox(width: gap),
              Expanded(child: _keyed(run[i])),
            ],
          ],
        ),
    ];
  }

  /// 错落：这一段半宽卡片按顺序逐张放进当前最矮的一列（Masonry），高矮
  /// 不一的卡片不会在行间留出大块空白；只有一张时占整行。卡片不多（最多
  /// 二十张），shrinkWrap 的非滚动网格一次排完，开销可忽略。
  static List<Widget> _staggered(
    List<ExploreModuleSlot> run,
    int columns,
    double gap,
  ) {
    if (run.length == 1) return <Widget>[_keyed(run.single)];
    return <Widget>[
      MasonryGridView.count(
        crossAxisCount: run.length < columns ? run.length : columns,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: run.length,
        itemBuilder: (BuildContext context, int index) => _keyed(run[index]),
      ),
    ];
  }
}
