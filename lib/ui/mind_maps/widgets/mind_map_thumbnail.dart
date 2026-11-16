import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../l10n/app_localizations.dart';
import '../layout/mind_map_layout.dart';
import '../layout/mind_map_scene.dart';
import '../layout/mind_map_text_cache.dart';
import '../viewmodels/mind_map_frame.dart';
import '../viewmodels/mind_map_look.dart';
import 'mind_map_painter.dart';

/// 导图的静态缩略图：整张图等比缩放进给定区域（不放大超过 [maxScale]）。
///
/// 卡片、预览舞台、嵌入卡片与样式面板的预览格共用；与画布同一份布局与绘制，
/// 外观一致。布局在本组件里做一次（自带文字缓存，随组件释放），只在文档或
/// 外观变化时重做；绘制包在 [RepaintBoundary] 里，列表滚动时不重画。
/// 节点超过 [thumbnailNodeLimit] 个的大图只画到第三层（更深的分支显示为
/// 收起徽标），缩略图看不清那么多字。
class MindMapThumbnail extends StatefulWidget {
  const MindMapThumbnail({
    super.key,
    required this.document,
    this.padding = const EdgeInsets.all(14),
    this.maxScale = 1,
    this.alignment = Alignment.center,
    this.overrideStructure,
    this.overrideTheme,
  });

  final MindMapDocument document;
  final EdgeInsets padding;
  final double maxScale;
  final Alignment alignment;

  /// 样式面板的预览格：用样例图套某种结构 / 主题。
  final String? overrideStructure;
  final String? overrideTheme;

  static const int thumbnailNodeLimit = 300;

  @override
  State<MindMapThumbnail> createState() => _MindMapThumbnailState();
}

class _MindMapThumbnailState extends State<MindMapThumbnail> {
  final MindMapTextCache _texts = MindMapTextCache();
  MindMapScene? _scene;
  MindMapDocument? _layoutDocument;
  MindMapLook? _layoutLook;

  @override
  void dispose() {
    _texts.dispose();
    super.dispose();
  }

  MindMapDocument get _effectiveDocument {
    var document = widget.document;
    if (widget.overrideStructure != null || widget.overrideTheme != null) {
      document = document.copyWith(
        structure: widget.overrideStructure ?? document.structure,
        theme: widget.overrideTheme ?? document.theme,
      );
    }
    if (document.index.length > MindMapThumbnail.thumbnailNodeLimit) {
      final index = document.index;
      for (final id in index.preorder) {
        if (index.depthOf(id) == 3 && index[id]!.children.isNotEmpty) {
          document = MindMapOps.setCollapsed(document, id, true);
        }
      }
    }
    return document;
  }

  @override
  Widget build(BuildContext context) {
    final document = _effectiveDocument;
    final look = MindMapLook.of(context, document);
    if (!identical(widget.document, _layoutDocument) ||
        look != _layoutLook ||
        _scene == null) {
      _scene = layoutMindMap(document, look.config(_texts));
      _layoutDocument = widget.document;
      _layoutLook = look;
    }
    final scene = _scene!;
    final root = widget.document.root.text.trim();
    return Semantics(
      image: true,
      label:
          '${root.isEmpty ? context.l10n.mindMapUntitled : root}, '
          '${context.l10n.mindMapTopicCount(mindMapNodeCount(widget.document))}',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ThumbnailPainter(
            frame: MindMapFrame.still(scene),
            options: MindMapPaintOptions(palette: look.palette),
            padding: widget.padding,
            maxScale: widget.maxScale,
            alignment: widget.alignment,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter({
    required this.frame,
    required this.options,
    required this.padding,
    required this.maxScale,
    required this.alignment,
  });

  final MindMapFrame frame;
  final MindMapPaintOptions options;
  final EdgeInsets padding;
  final double maxScale;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _bounds;
    final area = padding.deflateRect(Offset.zero & size);
    if (bounds.isEmpty || area.isEmpty) return;
    final scale = mindMapFitScale(bounds.size, area.size, maxScale);
    final drawn = Size(bounds.width * scale, bounds.height * scale);
    final target = alignment.inscribe(drawn, area);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(target.left, target.top);
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);
    paintMindMap(canvas, frame, options, zoom: scale);
    canvas.restore();
  }

  Rect get _bounds {
    if (frame.nodes.isEmpty) return Rect.zero;
    var rect = frame.nodes.first.rect;
    for (final node in frame.nodes) {
      rect = rect.expandToInclude(node.rect);
      if (node.scene.hiddenCount > 0) {
        rect = rect.expandToInclude(
          Rect.fromCircle(center: node.scene.toggleCenter, radius: 12),
        );
      }
    }
    for (final guide in frame.guides) {
      rect = rect.expandToInclude(Rect.fromPoints(guide.from, guide.to));
    }
    return rect.inflate(4);
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      !identical(oldDelegate.frame.nodes, frame.nodes) ||
      oldDelegate.options.palette != options.palette ||
      oldDelegate.padding != padding ||
      oldDelegate.maxScale != maxScale ||
      oldDelegate.alignment != alignment;
}

/// 把 [content] 等比放进 [area] 的缩放（不超过 [maxScale]）。
double mindMapFitScale(Size content, Size area, double maxScale) {
  if (content.isEmpty) return maxScale;
  final scale = (area.width / content.width) < (area.height / content.height)
      ? area.width / content.width
      : area.height / content.height;
  return scale > maxScale ? maxScale : scale;
}

/// 按导图的外形给一个合适的显示高度（宽 [width]，夹在 [min] 与 [max] 之间）。
double mindMapPreferredHeight(
  MindMapDocument document,
  BuildContext context, {
  required double width,
  required double min,
  required double max,
}) {
  // 只看节点数估算外形：真实尺寸要布局才知道，卡片这里不值得为此布局两次。
  final count = document.index.length;
  final aspect = count <= 3
      ? 2.4
      : count <= 12
      ? 1.7
      : 1.3;
  return (width / aspect).clamp(min, max);
}
