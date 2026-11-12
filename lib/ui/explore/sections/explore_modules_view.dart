import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../home/widgets/keep_alive_page.dart';
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
  const ExploreModulesView({
    super.key,
    required this.slots,
    this.sliver = false,
  });

  final List<ExploreModuleSlot> slots;
  final bool sliver;

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
    if (sliver) {
      double? width;
      Widget? content;
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          // SliverConstraints 的滚动偏移逐帧变化，但列数只依赖列宽。沿用
          // 同一棵 sliver 子树，避免在每个滚动帧重建列表代理与所有行包装。
          if (width != constraints.crossAxisExtent || content == null) {
            width = constraints.crossAxisExtent;
            content = _buildSliver(
              columnsFor(look.columns, width!),
              look.cardGap,
              look.flow,
            );
          }
          return content!;
        },
      );
    }
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

  /// 单列与对齐行共用一个惰性列表；错落布局才拆成几段 sliver。首屏不再
  /// 排版全部图表、启动下方卡片的查询和图片解码。已经看过的行保活，避免
  /// 滚回来重播数字动画或重置“换一篇”与回忆轮播的位置。
  Widget _buildSliver(int columns, double gap, ExploreWideFlow flow) {
    if (columns <= 1) {
      return _sliverRows(<Widget>[for (final slot in slots) _keyed(slot)], gap);
    }
    final sections = <Widget>[];
    var run = <ExploreModuleSlot>[];
    final rows = <Widget>[];
    void flush() {
      if (run.isEmpty) return;
      if (flow == ExploreWideFlow.rows || run.length == 1) {
        rows.addAll(_aligned(run, columns, gap));
      } else {
        if (rows.isNotEmpty) {
          sections.add(_sliverRows(List<Widget>.of(rows), gap));
          rows.clear();
        }
        final cards = List<ExploreModuleSlot>.of(run);
        sections.add(
          SliverMasonryGrid.count(
            crossAxisCount: cards.length < columns ? cards.length : columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childCount: cards.length,
            itemBuilder: (context, index) => KeepAlivePage(
              key: ValueKey<ExploreModuleId>(cards[index].config.id),
              child: _keyed(cards[index]),
            ),
          ),
        );
      }
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
    if (rows.isNotEmpty) sections.add(_sliverRows(rows, gap));
    return SliverMainAxisGroup(
      slivers: <Widget>[
        for (var i = 0; i < sections.length; i++)
          SliverPadding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
            sliver: sections[i],
          ),
      ],
    );
  }

  static Widget _sliverRows(List<Widget> rows, double gap) {
    final indices = <Key, int>{
      for (var i = 0; i < rows.length; i++) rows[i].key!: i,
    };
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => KeepAlivePage(
          key: rows[index].key,
          child: Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
            child: rows[index],
          ),
        ),
        childCount: rows.length,
        findChildIndexCallback: (key) => indices[key],
      ),
    );
  }

  static List<Widget> _aligned(
    List<ExploreModuleSlot> run,
    int columns,
    double gap,
  ) {
    return <Widget>[
      for (var start = 0; start < run.length; start += columns)
        Row(
          key: ValueKey<ExploreModuleId>(run[start].config.id),
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
  /// 二十张），仅设置页的小型预览使用这个一次排完的盒布局；正式页面用
  /// [_buildSliver] 里的惰性网格。
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
