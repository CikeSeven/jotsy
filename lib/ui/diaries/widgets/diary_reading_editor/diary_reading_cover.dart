import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../widgets/image_viewer_hero.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../diary_preview/diary_preview_header.dart';
import '../diary_preview/diary_preview_surface.dart';
import '../publish_diary_cover_sliver.dart';

/// 阅读式编辑页的头图：与预览页同一几何（[diaryPreviewCoverGeometry]）与
/// 画法（[PublishDiaryCoverFrame]），只是不在 sliver 里——编辑页的页头放在
/// 正文编辑器自己的虚拟滚动里（`DiaryEditor.header`），没有
/// `SliverPersistentHeader` 可用。
///
/// 滚动淡出：预览页的头图随滚动收起时淡出并缩小到 0.96；这里头图高度不变、
/// 随页面平移，淡出与缩小按“已经滚出视口顶边的比例”换算，开着
/// “滚动淡出”时两处看起来一致。比例在每次滚动之后的帧末量一次（见
/// [_DiaryReadingCoverState._measure]），只重建图片这一小块。
class DiaryReadingCover extends StatefulWidget {
  const DiaryReadingCover({
    super.key,
    required this.source,
    required this.resolved,
    required this.onTap,
    this.heroTag,
    this.placeholder,
  });

  final String source;
  final DiaryPreviewResolvedStyle resolved;
  final ValueChanged<ImageViewerHero?> onTap;

  /// 共享元素标签（列表封面飞入的落点、点按进看图页的起点）；null 时不建立。
  final Object? heroTag;

  /// 列表封面抓取的画面：飞入的落点与解码前的占位。
  final ui.Image? placeholder;

  @override
  State<DiaryReadingCover> createState() => _DiaryReadingCoverState();
}

class _DiaryReadingCoverState extends State<DiaryReadingCover> {
  /// 0 = 完全滚出顶边，1 = 完整可见。
  final ValueNotifier<double> _progress = ValueNotifier<double>(1);
  ScrollPosition? _position;
  bool _measureScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 编辑器的虚拟列表在跳转时会换用另一份内部列表，头图随之换到新的
    // Scrollable 下：依赖关系变化时重新挂监听。
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_scheduleMeasure);
    _position = position?..addListener(_scheduleMeasure);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleMeasure);
    _progress.dispose();
    super.dispose();
  }

  /// 滚动位置在布局之前变化，此时量到的还是上一帧的位置：等这一帧布局
  /// 完成再量，一帧最多量一次。
  void _scheduleMeasure() {
    if (_measureScheduled || !widget.resolved.style.cover.fadeOnScroll) {
      return;
    }
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !viewport.attached ||
        !box.hasSize ||
        box.size.height <= 0) {
      return;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final hidden = (-top).clamp(0.0, box.size.height);
    _progress.value = 1 - hidden / box.size.height;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.resolved;
    final fade = resolved.style.cover.fadeOnScroll;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final geometry = diaryPreviewCoverGeometry(
          resolved,
          constraints.maxWidth,
        );
        final background = diaryPreviewPageColors(context, resolved).page;
        return SizedBox(
          height: geometry.extent,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (BuildContext context, double progress, Widget? _) {
              final visible = fade ? progress : 1.0;
              return PublishDiaryCoverFrame(
                cover: widget.source,
                decodeHeight: geometry.extent,
                padding: geometry.padding,
                borderRadius: geometry.radius,
                heroTag: widget.heroTag,
                placeholder: widget.placeholder,
                onTap: widget.onTap,
                opacity: visible,
                scale: 0.96 + visible * 0.04,
                background: background,
                fillFrame: geometry.fill,
              );
            },
          ),
        );
      },
    );
  }
}
