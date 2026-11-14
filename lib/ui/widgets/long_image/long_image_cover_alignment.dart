import 'package:flutter/widgets.dart';
import 'package:node_diary/ui/widgets/expressive_image_frame.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// 裁切显示（`BoxFit.cover`）的图片按比例选择对齐：长图顶部对齐露出开头，
/// 其余保持 [fallback]（默认居中）。
///
/// 长截图居中裁切只会露出中段，看不出是什么。比例取自解码结果：本组件与
/// 图片组件解析同一个 [image]，ImageCache 让两者共用一次解码；缓存命中时
/// 监听在注册时同步回调，首帧即是正确的对齐；首次解码时两边在同一次通知里
/// 更新，图片出现的那一帧对齐已经就位。
///
/// 输入：图片来源（必须与 builder 中图片组件使用的是同一个 provider，或键相等）。
/// 输出：把对齐交给 [builder]。副作用：持有一个图片流监听，卸载或换图时移除。
class LongImageCoverAlignment extends StatefulWidget {
  const LongImageCoverAlignment({
    super.key,
    required this.image,
    required this.builder,
    this.fallback = Alignment.center,
  });

  final ImageProvider image;
  final AlignmentGeometry fallback;
  final Widget Function(BuildContext context, AlignmentGeometry alignment)
  builder;

  @override
  State<LongImageCoverAlignment> createState() =>
      _LongImageCoverAlignmentState();
}

class _LongImageCoverAlignmentState extends State<LongImageCoverAlignment> {
  late final DisposableBuildContext<_LongImageCoverAlignmentState>
  _scrollContext = DisposableBuildContext<_LongImageCoverAlignmentState>(this);
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImage,
    onError: (_, _) {},
  );
  bool _long = false;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(LongImageCoverAlignment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _listen();
    }
  }

  void _listen() {
    // Image 自己会在快速滚动时推迟新解码；这个尺寸监听也必须遵循同样的
    // 策略，否则它先把原图送进缓存，反而绕过 Image 的滚动保护。键仍是原
    // provider 的键，缓存命中时立即显示，不会额外读取或解码。
    final stream = ScrollAwareImageProvider(
      context: _scrollContext,
      imageProvider: widget.image,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) {
      return;
    }
    _stopListening();
    _stream = stream;
    _listening = true;
    stream.addListener(_listener);
  }

  void _stopListening() {
    if (_listening) {
      _stream?.removeListener(_listener);
      _listening = false;
    }
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    final image = info.image;
    final long = isLongImageSize(
      Size(image.width.toDouble(), image.height.toDouble()),
    );
    // 每个监听拿到的是独立的克隆，读完尺寸立即释放。
    info.dispose();
    if (long == _long) {
      return;
    }
    if (synchronousCall || !mounted) {
      _long = long;
      return;
    }
    setState(() => _long = long);
  }

  @override
  void dispose() {
    _scrollContext.dispose();
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _long ? Alignment.topCenter : widget.fallback,
    );
  }
}

/// 以 cover 裁切显示的图片（封面、缩略图）：长图顶部对齐，首次解码淡入。
///
/// [image] 应已按显示尺寸缩小（[boundedImageProvider]），这里只负责对齐与
/// 绘制参数。
class CoverCroppedImage extends StatelessWidget {
  const CoverCroppedImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.filterQuality = FilterQuality.low,
    this.frameBuilder = expressiveImageFrameBuilder,
    this.errorBuilder,
  });

  final ImageProvider image;
  final double? width;
  final double? height;
  final FilterQuality filterQuality;

  /// 默认首次解码淡入。需要只给画面加裁切与描边、而不套住 [errorBuilder]
  /// 的失败占位时（[Image] 的失败分支不经 frameBuilder），由调用方传入
  /// 包了一层的版本，淡入仍应经 [expressiveImageFrameBuilder]。
  final ImageFrameBuilder frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LongImageCoverAlignment(
      image: image,
      builder: (BuildContext context, AlignmentGeometry alignment) => Image(
        image: image,
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: filterQuality,
        frameBuilder: frameBuilder,
        errorBuilder: errorBuilder,
      ),
    );
  }
}
