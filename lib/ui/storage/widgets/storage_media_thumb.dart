import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/storage/storage_usage_models.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../providers/storage_providers.dart';

/// 一个媒体的方形缩略图：图片按显示尺寸保持比例缩小解码、cover 裁切（长图
/// 顶部对齐）、首次解码淡入；视频取一帧（只有能读视频的平台，见
/// `MediaCompressor.supportsVideoInfo`），取不到时与录音、附件一样画类别图标；
/// [masked]（私密未揭示、未解封的胶囊）只画锁，不读文件。
///
/// [extent] 为显示边长（逻辑像素），决定解码尺寸；格子里按格宽传入。
class StorageMediaThumb extends ConsumerStatefulWidget {
  const StorageMediaThumb({
    super.key,
    required this.entry,
    required this.masked,
    required this.extent,
  });

  final StorageMediaEntry entry;
  final bool masked;
  final double extent;

  @override
  ConsumerState<StorageMediaThumb> createState() => _StorageMediaThumbState();
}

class _StorageMediaThumbState extends ConsumerState<StorageMediaThumb> {
  Future<String?>? _videoFrame;

  @override
  void initState() {
    super.initState();
    _loadVideoFrame();
  }

  @override
  void didUpdateWidget(StorageMediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.key != widget.entry.key ||
        oldWidget.masked != widget.masked) {
      _loadVideoFrame();
    }
  }

  void _loadVideoFrame() {
    _videoFrame =
        widget.entry.kind == DiaryBlockMediaKind.video && !widget.masked
        ? ref.read(storageMediaServiceProvider).videoThumbnail(widget.entry)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    if (widget.masked) return const _IconTile(icon: FontAwesomeIcons.lock);
    switch (entry.kind) {
      case DiaryBlockMediaKind.image:
        return _Picture(source: entry.path, extent: widget.extent);
      case DiaryBlockMediaKind.video:
        return FutureBuilder<String?>(
          future: _videoFrame,
          builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
            final frame = snapshot.data;
            if (frame == null) {
              return const _IconTile(icon: FontAwesomeIcons.film);
            }
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _Picture(source: frame, extent: widget.extent),
                const Center(child: _PlayBadge()),
              ],
            );
          },
        );
      case DiaryBlockMediaKind.audio:
        return const _IconTile(icon: FontAwesomeIcons.microphone);
      case DiaryBlockMediaKind.attachment:
        return _IconTile(icon: storageAttachmentIcon(entry.fileName));
    }
  }
}

/// 附件按扩展名选图标。
FaIconData storageAttachmentIcon(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'pdf' => FontAwesomeIcons.filePdf,
    'doc' || 'docx' || 'odt' || 'rtf' => FontAwesomeIcons.fileWord,
    'xls' || 'xlsx' || 'ods' || 'csv' => FontAwesomeIcons.fileExcel,
    'ppt' || 'pptx' || 'odp' => FontAwesomeIcons.filePowerpoint,
    'zip' || 'rar' || '7z' || 'tar' || 'gz' => FontAwesomeIcons.fileZipper,
    'txt' || 'md' => FontAwesomeIcons.fileLines,
    _ => FontAwesomeIcons.file,
  };
}

class _Picture extends StatelessWidget {
  const _Picture({required this.source, required this.extent});

  final String source;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final pixels = (extent * MediaQuery.devicePixelRatioOf(context)).round();
    return CoverCroppedImage(
      // 只限宽度（另一边由 boundedImageProvider 限在纹理上限内）：同时限高
      // 会让长图按比例缩成细条，再裁成正方形时发虚；宽度取 2 倍，横图裁成
      // 正方形后高度也够用（与日记行缩略图同一取法）。
      image: boundedImageProvider(
        diaryImageProvider(source),
        width: pixels * 2,
      ),
      errorBuilder: (context, _, _) =>
          const _IconTile(icon: FontAwesomeIcons.image),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: FaIcon(icon, size: 18, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FaIcon(FontAwesomeIcons.play, size: 10, color: scheme.onSurface),
      ),
    );
  }
}
