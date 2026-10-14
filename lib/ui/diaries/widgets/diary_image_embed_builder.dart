import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';

/// 正文图片按独立块渲染，圆角、微边框与上下留白和视频/附件卡片保持同一节奏。
///
/// 上游 [QuillEditorImageEmbedBuilder] 把图片当作行内 WidgetSpan 放进文本行：
/// 直角、贴着文字基线、没有段间距。这里只接管显示层：
/// - 点击仍复用上游构建出的回调：编辑页保留缩放/复制/删除/保存菜单，阅读页
///   继续经 `onImageClicked` 打开大图（上游菜单未导出，无法在这里直接构造）；
/// - 缩放菜单写入的宽高只作为上限，见 [diaryImageEmbedBounds]。
class DiaryImageEmbedBuilder extends QuillEditorImageEmbedBuilder {
  DiaryImageEmbedBuilder({required super.config});

  /// 图片独占一行时走 EmbedProxy 块级布局；与文字同行的旧数据 Quill 仍按行内渲染。
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final upstream = super.build(context, embedContext);
    // 升级后若上游不再以 GestureDetector 包裹，退回原样渲染，至少不丢点击菜单。
    if (upstream is! GestureDetector) return upstream;
    final image = GestureDetector(
      onTap: upstream.onTap,
      child: DiaryEmbeddedImage(
        source: embedContext.node.value.data.toString(),
        bounds: diaryImageEmbedBounds(embedContext.node),
      ),
    );
    if (embedContext.inline) return image;
    // 小图按原尺寸水平居中；heightFactor 防止有界高度下 Center 撑满整行。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(heightFactor: 1, child: image),
    );
  }
}

/// 正文图片本体。provider 按来源缓存在 State 中：编辑器每次改动都会重建
/// 文本行，若每次构建新 provider，base64 图片会反复解码并闪烁。
class DiaryEmbeddedImage extends StatefulWidget {
  const DiaryEmbeddedImage({
    super.key,
    required this.source,
    this.bounds = const BoxConstraints(),
  });

  final String source;
  final BoxConstraints bounds;

  @override
  State<DiaryEmbeddedImage> createState() => _DiaryEmbeddedImageState();
}

class _DiaryEmbeddedImageState extends State<DiaryEmbeddedImage> {
  late ImageProvider _provider = resolveDiaryImageProvider(widget.source);

  @override
  void didUpdateWidget(DiaryEmbeddedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _provider = resolveDiaryImageProvider(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    // 不给 Image 指定宽高：RenderImage 会在约束内按原始比例取尺寸，
    // 裁切与边框因此贴合画面本身。
    return ConstrainedBox(
      constraints: widget.bounds,
      child: Image(
        image: _provider,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final framed = ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.fromBorderSide(
                  ExpressiveSurfaces.cardBorderSide(colors),
                ),
              ),
              child: child,
            ),
          );
          // 已在缓存中的图片直接显示；首次解码时淡入，避免尺寸确定瞬间硬切。
          if (wasSynchronouslyLoaded) return framed;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            curve: ExpressiveMotion.effects,
            child: framed,
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const _DiaryImageFallback(),
      ),
    );
  }
}

/// 文件被删除或来源失效时的占位，避免正文里出现空白或框架默认错误块。
class _DiaryImageFallback extends StatelessWidget {
  const _DiaryImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colors),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.image,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.l10n.imageLoadFailed,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
