import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import 'publish_diary_cover_sliver.dart';

/// 发布页头图的插入/移除过渡。
///
/// 选好封面后头图从 0 高度展开并淡入，下方标题与正文随之平滑下移，而不是在
/// 一帧之内被推下整块头图的高度；清除封面时反向收起淡出，期间继续绘制最后
/// 一张封面。边界：
/// - 首次构建即有封面（进入页面时）不播放过渡，随页面转场一起出现；
/// - 更换封面时高度不变，新图由图片自身的解码淡入衔接；
/// - 减少动态效果时直接出现/消失。
class AnimatedPublishDiaryCoverSliver extends StatefulWidget {
  const AnimatedPublishDiaryCoverSliver({super.key, required this.cover});

  /// 当前封面路径；为 null 表示无封面。
  final String? cover;

  @override
  State<AnimatedPublishDiaryCoverSliver> createState() =>
      _AnimatedPublishDiaryCoverSliverState();
}

class _AnimatedPublishDiaryCoverSliverState
    extends State<AnimatedPublishDiaryCoverSliver> {
  /// 最近一次非空封面：移除过渡期间继续绘制它。
  late String? _lastCover = widget.cover;

  @override
  void didUpdateWidget(covariant AnimatedPublishDiaryCoverSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastCover = widget.cover ?? _lastCover;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.cover == null ? 0 : 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, double reveal, Widget? _) {
        final cover = _lastCover;
        if (cover == null || reveal <= 0) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return PublishDiaryCoverSliver(cover: cover, reveal: reveal);
      },
    );
  }
}
