import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/image_viewer_hero.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_options.dart';
import '../models/explore_view_data.dart';
import '../providers/explore_providers.dart';
import '../widgets/explore_shared_widgets.dart';

/// 媒体画廊卡：日记里的图片，横条、宫格或拼贴（一大几小）。
///
/// 默认只用概览里的封面（不读正文）；开了“包括正文里的图片”时改读最近几篇
/// 带图日记的正文（[exploreRecentMediaProvider]，限量）。点按缩略图以共享
/// 元素打开看图页（可在那里直接打开日记），标题行尾进入完整的媒体画廊页。
class ExploreMediaCard extends ConsumerWidget {
  const ExploreMediaCard({
    super.key,
    required this.config,
    required this.covers,
  });

  final ExploreModuleConfig config;

  /// 封面图（已按数量截取）。
  final List<ExploreMediaItem> covers;

  static Object heroTag(String source) =>
      ImageViewerHeroTag('explore_card', source);

  static const double _gap = 6;

  /// 宫格与拼贴的列数：每列约 150，至少三列（与媒体画廊页的列数规则一致）。
  static int _columns(double width) {
    final columns = ((width + _gap) / (150 + _gap)).floor();
    return columns < 3 ? 3 : columns;
  }

  static double _cellSide(double width) {
    final columns = _columns(width);
    return (width - _gap * (columns - 1)) / columns;
  }

  /// 从第 [start] 张起的 [count] 张，每行 [columns] 格。逐行用 Row 排而不用
  /// Wrap：一行正好排满时，Wrap 会因浮点误差提前折行，Row 的溢出判断带容差。
  static Widget _cells({
    required int start,
    required int count,
    required int columns,
    required double side,
    required Widget Function(
      int index, {
      required double width,
      required double height,
    })
    thumb,
  }) {
    return Column(
      children: <Widget>[
        for (var row = 0; row * columns < count; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
            child: Row(
              children: <Widget>[
                for (var col = 0; col < columns; col++)
                  if (row * columns + col < count) ...<Widget>[
                    if (col > 0) const SizedBox(width: _gap),
                    thumb(
                      start + row * columns + col,
                      width: side,
                      height: side,
                    ),
                  ],
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ExploreActionsScope.of(context);
    final count = config.count(ExploreOptions.mediaCount);
    final items = config.toggle(ExploreOptions.mediaInline)
        ? ref.watch(exploreRecentMediaProvider(count)).value ?? covers
        : covers;
    final style = config.choice(ExploreOptions.mediaStyle);
    Widget thumb(int index, {required double width, required double height}) =>
        _MediaThumb(
          items: items,
          index: index,
          width: width,
          height: height,
          onTap: (BuildContext cellContext) =>
              actions.openImage(cellContext, items, index, heroTag: heroTag),
        );
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.images,
            title: l10n.exploreModuleMedia,
            trailing: ExploreHeaderArrow(
              tooltip: l10n.autoT0061,
              onPressed: actions.openMediaGallery,
            ),
          ),
          if (items.isEmpty)
            ExploreInlineHint(message: l10n.autoT0062)
          else
            switch (style) {
              ExploreMediaStyle.strip => SizedBox(
                height: 108,
                child: DesktopHorizontalScroll(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) =>
                        thumb(index, width: 140, height: 108),
                  ),
                ),
              ),
              ExploreMediaStyle.grid => LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    _cells(
                      start: 0,
                      count: items.length,
                      columns: _columns(constraints.maxWidth),
                      side: _cellSide(constraints.maxWidth),
                      thumb: thumb,
                    ),
              ),
              // 拼贴：第一张占 2×2 格，右侧两行排满其余列，之后的按格排。
              ExploreMediaStyle.mosaic => LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final width = constraints.maxWidth;
                  final columns = _columns(width);
                  final small = _cellSide(width);
                  final big = small * 2 + _gap;
                  final beside = (columns - 2) * 2;
                  final rest = 1 + beside;
                  return Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          thumb(0, width: big, height: big),
                          if (items.length > 1) ...<Widget>[
                            const SizedBox(width: _gap),
                            // 右侧两行、每行 columns - 2 格；逐格排而不用 Wrap：
                            // Row 的溢出判断带浮点容差，Wrap 会因误差提前折行。
                            Column(
                              children: <Widget>[
                                for (var row = 0; row < 2; row++)
                                  if (1 + row * (columns - 2) < items.length)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: row == 0 ? 0 : _gap,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          for (
                                            var col = 0;
                                            col < columns - 2;
                                            col++
                                          )
                                            if (1 + row * (columns - 2) + col <
                                                items.length) ...<Widget>[
                                              if (col > 0)
                                                const SizedBox(width: _gap),
                                              thumb(
                                                1 + row * (columns - 2) + col,
                                                width: small,
                                                height: small,
                                              ),
                                            ],
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (items.length > rest) ...<Widget>[
                        const SizedBox(height: _gap),
                        _cells(
                          start: rest,
                          count: items.length - rest,
                          columns: columns,
                          side: small,
                          thumb: thumb,
                        ),
                      ],
                    ],
                  );
                },
              ),
            },
        ],
      ),
    );
  }
}

/// 一张可点的缩略图：缩略图本身不透明，水波纹画在叠于其上的透明 Material
/// 上；Builder 提供格子自己的 context，点按时从这里抓取已绘制的画面作为
/// 看图页的飞入画面。
class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.items,
    required this.index,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final List<ExploreMediaItem> items;
  final int index;
  final double width;
  final double height;
  final ValueChanged<BuildContext> onTap;

  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final source = items[index].source;
    return SizedBox(
      width: width,
      height: height,
      child: Builder(
        builder: (BuildContext cellContext) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ImageViewerHeroSource(
              tag: ExploreMediaCard.heroTag(source),
              borderRadius: BorderRadius.circular(_radius),
              child: ExploreMediaThumb(
                source: source,
                width: width,
                height: height,
                radius: _radius,
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(_radius),
                onTap: () => onTap(cellContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
