import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../models/notebook_icon.dart';
import 'notebook_cover_classic.dart';
import 'notebook_cover_image.dart';
import 'notebook_cover_label.dart';
import 'notebook_cover_texture.dart';

/// 小封面的内容（不含文字）：列表行左侧的 44×56 与编辑页版式预览共用。
///
/// 按版式保留主要特征，尺寸按 [width] / 44 等比缩放：
/// - 经典：图标居中，有图时图片铺满（与改版前一致）；
/// - 满版：图片铺满、底部一条浮起的实色条；无图时大一号的图标居中；
/// - 书脊：起始侧一条书脊，其余同经典；
/// - 贴签：中央一块带小图标的贴签；
/// - 极简：不画图标，左上两道“名称”短条；有图时短条在顶部实色带上。
///
/// 纹理画在露出底色的部分，取景同完整封面。外框（圆角、底色、描边、
/// 不透明度）由调用方提供，这里只填满给定的框。
class NotebookCoverMini extends StatelessWidget {
  const NotebookCoverMini({
    super.key,
    required this.icon,
    required this.accent,
    this.coverPath,
    this.style = NotebookCoverStyle.defaults,
    this.width = 44,
  });

  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final String? coverPath;
  final NotebookCoverStyle style;

  /// 外框宽度，决定缩放比例与解码尺寸。
  final double width;

  double get _scale => width / 44;

  @override
  Widget build(BuildContext context) {
    final cover = coverPath;
    // 默认样式：与改版前的小封面同一棵组件树。
    if (style.layout == NotebookCoverLayout.classic &&
        style.texture == NotebookCoverTexture.none &&
        style.hasDefaultCrop &&
        width == 44) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(child: FaIcon(icon.data, size: 18, color: accent.onContainer)),
          if (cover != null) NotebookCoverImage(path: cover, width: 44),
        ],
      );
    }
    final s = _scale;
    final texture = NotebookCoverTextureLayer(
      texture: style.texture,
      color: notebookCoverTextureColor(accent.onContainer),
      scale: 0.6 * s,
    );
    final image = cover == null
        ? null
        : LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                NotebookCoverImage(
                  path: cover,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  style: style,
                ),
          );
    Widget centeredIcon(double size) => Center(
      child: FaIcon(icon.data, size: size * s, color: accent.onContainer),
    );
    switch (style.layout) {
      case NotebookCoverLayout.classic:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[texture, centeredIcon(18), ?image],
        );
      case NotebookCoverLayout.spine:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            NotebookCoverSpine(
              accent: accent,
              width: 6 * s,
              creaseInset: 1.4 * s,
              creaseWidth: 0.8 * s,
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[texture, centeredIcon(16), ?image],
              ),
            ),
          ],
        );
      case NotebookCoverLayout.fullBleed:
        if (image == null) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[texture, centeredIcon(22)],
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image,
            Positioned(
              left: 3 * s,
              right: 3 * s,
              bottom: 3 * s,
              height: 11 * s,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.container,
                  borderRadius: BorderRadius.circular(4 * s),
                ),
              ),
            ),
          ],
        );
      case NotebookCoverLayout.label:
        final scheme = Theme.of(context).colorScheme;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image ?? texture,
            Align(
              alignment: const Alignment(0, -0.12),
              child: Container(
                width: 30 * s,
                height: 18 * s,
                decoration: BoxDecoration(
                  color: notebookLabelPlateColor(scheme),
                  borderRadius: BorderRadius.circular(4 * s),
                  border: Border.all(color: scheme.outlineVariant, width: 0.8),
                ),
                alignment: Alignment.center,
                child: FaIcon(
                  icon.data,
                  size: 9 * s,
                  color: notebookLabelIconColor(
                    accent,
                    notebookLabelPlateColor(scheme),
                  ),
                ),
              ),
            ),
          ],
        );
      case NotebookCoverLayout.minimal:
        final bars = Padding(
          padding: EdgeInsetsDirectional.fromSTEB(5 * s, 6 * s, 5 * s, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _bar(26 * s, 4 * s),
              SizedBox(height: 3 * s),
              _bar(16 * s, 4 * s),
            ],
          ),
        );
        if (image == null) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              texture,
              Align(alignment: AlignmentDirectional.topStart, child: bars),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: 5 * s),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: bars,
              ),
            ),
            Expanded(child: image),
          ],
        );
    }
  }

  /// 极简版式里代表名称的短条。
  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: accent.onContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}
