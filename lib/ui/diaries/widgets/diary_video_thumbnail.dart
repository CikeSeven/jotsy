import 'dart:io';

import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_rows.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_thumbnail.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_viewport_gate.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_cover_alignment.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/widgets/video_play_badge.dart';
import 'package:node_diary/ui/widgets/width_layout_builder.dart';

/// 正文视频小图取帧的最长边（像素）：16:9 的帧短边约 405，裁成 120dp 的方格
/// 在 3 倍屏上也不发虚。
const int kDiaryVideoPosterMaxSide = 720;

/// 正文视频的小图显示（视频块 `data.thumbnail == true`，#252）：与图片小图
/// 同一个方格（边长见 [diaryThumbnailExtentFor]，在一排里由
/// [DiaryThumbnailExtent] 给出）、12dp 圆角与微边框，画面是视频的一帧
/// （[VideoPosterCache]，cover 裁切），正中一个小播放圆钮。点按由外层处理
/// （`DiaryVideoThumbnailBlock`）。
///
/// 方格一开始就占好：取帧期间与离屏时都是 `surfaceContainerHighest` 底 +
/// 播放圆钮，帧解码后淡入，正文不跳动；离屏时不触发原生取帧并释放纹理。
class DiaryVideoThumbnail extends StatelessWidget {
  const DiaryVideoThumbnail({
    super.key,
    required this.video,
    required this.posters,
  });

  final DiaryFileAttachment video;
  final VideoPosterCache posters;

  @override
  Widget build(BuildContext context) {
    final rowExtent = DiaryThumbnailExtent.maybeOf(context);
    if (rowExtent != null) return _gatedTile(rowExtent);
    return WidthLayoutBuilder(
      builder: (context, width) => _gatedTile(diaryThumbnailExtentFor(width)),
    );
  }

  Widget _gatedTile(double extent) => DiaryMediaViewportGate(
    builder: (context, active) => _DiaryVideoThumbnailTile(
      video: video,
      posters: posters,
      extent: extent,
      active: active,
    ),
  );
}

class _DiaryVideoThumbnailTile extends StatefulWidget {
  const _DiaryVideoThumbnailTile({
    required this.video,
    required this.posters,
    required this.extent,
    required this.active,
  });

  final DiaryFileAttachment video;
  final VideoPosterCache posters;
  final double extent;
  final bool active;

  @override
  State<_DiaryVideoThumbnailTile> createState() =>
      _DiaryVideoThumbnailTileState();
}

class _DiaryVideoThumbnailTileState extends State<_DiaryVideoThumbnailTile> {
  Future<String?>? _poster;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(_DiaryVideoThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.path != widget.video.path ||
        oldWidget.posters != widget.posters) {
      _poster = null;
      if (widget.active) _load();
    } else if (!oldWidget.active && widget.active && _poster == null) {
      _load();
    }
  }

  void _load() {
    _poster = widget.posters.isSupported
        ? widget.posters.posterOf(
            widget.video.path,
            maxSide: kDiaryVideoPosterMaxSide,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(kDiaryImageThumbnailRadius);
    final pixels = (widget.extent * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    return Semantics(
      label: widget.video.displayName,
      image: true,
      child: SizedBox.square(
        dimension: widget.extent,
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.fromBorderSide(
                ExpressiveSurfaces.cardBorderSide(colors),
              ),
            ),
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (widget.active)
                    FutureBuilder<String?>(
                      future: _poster,
                      builder: (context, snapshot) {
                        final frame = snapshot.data;
                        if (frame == null) return const SizedBox.shrink();
                        return CoverCroppedImage(
                          image: boundedImageProvider(
                            FileImage(File(frame)),
                            width: pixels,
                            height: pixels,
                            cover: true,
                          ),
                          width: widget.extent,
                          height: widget.extent,
                          // 帧在小格子里缩得很多，low 档的采样会出锯齿。
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        );
                      },
                    ),
                  const Center(child: VideoPlayBadge(iconSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
