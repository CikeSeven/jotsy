import 'package:flutter/widgets.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// [LongImageSourceBuilder] 交给 builder 的当前解析状态。
///
/// 状态只会前进：尺寸未知 → 尺寸已知（普通图到此为止）→ 长图分片就绪。
@immutable
class LongImageSnapshot {
  const LongImageSnapshot._({
    required this.sizeResolved,
    this.size,
    this.tiles,
  });

  static const LongImageSnapshot pending = LongImageSnapshot._(
    sizeResolved: false,
  );

  /// 尺寸是否已读出（含读取失败）。读取失败或网络图时 [size] 为 null，
  /// 调用方按普通图片显示。
  final bool sizeResolved;

  /// 原图像素尺寸。
  final Size? size;

  /// 长图的分片；切片尚未完成时为 null。不支持切片（非 Android、`data:` URI、
  /// 带 EXIF 旋转）或切片失败时为整张原图的单段，按比例缩小解码。
  final LongImageTiles? tiles;

  bool get isLong => size != null && isLongImageSize(size!);
}

/// 解析图片来源的尺寸与（长图时的）分片，状态变化时重建。
///
/// 已缓存的结果在首帧同步给出（同一张图在正文显示过之后，看图页与重建的正文
/// 都不再闪一帧空白）；未缓存时先给 [LongImageSnapshot.pending]，读完再
/// setState。来源变化时重新解析；异步结果回来时若来源已变或已卸载则丢弃。
class LongImageSourceBuilder extends StatefulWidget {
  const LongImageSourceBuilder({
    super.key,
    required this.source,
    required this.builder,
  });

  final String source;
  final Widget Function(BuildContext context, LongImageSnapshot snapshot)
  builder;

  @override
  State<LongImageSourceBuilder> createState() => _LongImageSourceBuilderState();
}

class _LongImageSourceBuilderState extends State<LongImageSourceBuilder> {
  LongImageSnapshot _snapshot = LongImageSnapshot.pending;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(LongImageSourceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _snapshot = LongImageSnapshot.pending;
      _resolve();
    }
  }

  void _resolve() {
    final source = widget.source;
    if (ImageDimensions.isResolved(source)) {
      _applySize(source, ImageDimensions.peek(source), synchronous: true);
      return;
    }
    ImageDimensions.resolve(source).then((size) {
      _applySize(source, size, synchronous: false);
    });
  }

  void _applySize(String source, Size? size, {required bool synchronous}) {
    if (!mounted || source != widget.source) {
      return;
    }
    final next = LongImageSnapshot._(sizeResolved: true, size: size);
    _set(next, synchronous: synchronous);
    if (size == null || !next.isLong) {
      return;
    }
    final service = LongImageTileService.instance;
    LongImageTiles fallback() => LongImageTiles.single(
      source,
      width: size.width.round(),
      height: size.height.round(),
    );
    if (!isLocalImageSource(source)) {
      _set(_withTiles(size, fallback()), synchronous: synchronous);
      return;
    }
    if (service.isResolved(source)) {
      _set(
        _withTiles(size, service.peek(source) ?? fallback()),
        synchronous: synchronous,
      );
      return;
    }
    service.tilesFor(source).then((tiles) {
      if (!mounted || source != widget.source) {
        return;
      }
      _set(_withTiles(size, tiles ?? fallback()), synchronous: false);
    });
  }

  static LongImageSnapshot _withTiles(Size size, LongImageTiles tiles) =>
      LongImageSnapshot._(sizeResolved: true, size: size, tiles: tiles);

  void _set(LongImageSnapshot next, {required bool synchronous}) {
    if (synchronous) {
      _snapshot = next;
    } else {
      setState(() => _snapshot = next);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _snapshot);
}
