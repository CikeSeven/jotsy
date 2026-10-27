import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../models/notebook_icon.dart';
import '../notebook_cover_parts.dart';
import 'notebook_cover_texture.dart';

/// 封面上的名称与篇数（经典、书脊、满版共用的左对齐排法；贴签与极简另有
/// 字号与对齐，经参数调整）。
class NotebookCoverText extends StatelessWidget {
  const NotebookCoverText({
    super.key,
    required this.name,
    required this.color,
    this.countLabel,
    this.countColor,
    this.nameStyle,
    this.maxLines = 2,
    this.center = false,
  });

  final String name;
  final String? countLabel;

  /// 名称颜色；篇数默认取它的 72%。
  final Color color;
  final Color? countColor;

  /// 覆盖名称字样（默认 `titleSmall` w700、行高 1.25）。
  final TextStyle? nameStyle;
  final int maxLines;

  /// 居中排（贴签）。
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = center ? TextAlign.center : null;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style:
              nameStyle ??
              theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.25,
              ),
        ),
        if (countLabel != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            countLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: theme.textTheme.bodySmall?.copyWith(
              color: countColor ?? color.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }
}

/// 经典版式：没有封面图时图标在左上、名称与篇数在底部；有封面图时图片
/// 铺满上部（约六成，随文字高度伸缩），图标圆压在图片左下角。纹理只画在
/// 露出底色的部分（无图时整张，有图时下方文字区）。
///
/// 默认样式（无纹理、默认取景）的组件树与改版前的 `NotebookCoverBody`
/// 完全一致，书架封面逐像素不变。书脊版式在它左侧加一条书脊后复用它。
class NotebookCoverBody extends StatelessWidget {
  const NotebookCoverBody({
    super.key,
    required this.name,
    required this.icon,
    required this.accent,
    this.coverPath,
    this.countLabel,
    this.style = NotebookCoverStyle.defaults,
  });

  final String name;
  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final String? coverPath;
  final String? countLabel;
  final NotebookCoverStyle style;

  @override
  Widget build(BuildContext context) {
    final text = NotebookCoverText(
      name: name,
      countLabel: countLabel,
      color: accent.onContainer,
    );
    final textureColor = notebookCoverTextureColor(accent.onContainer);
    final cover = coverPath;
    if (cover == null) {
      return notebookCoverTextured(
        texture: style.texture,
        color: textureColor,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NotebookIconCircle(icon: icon, accent: accent),
              const Spacer(),
              text,
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    NotebookCoverImage(
                      path: cover,
                      width: constraints.maxWidth,
                      style: style,
                    ),
              ),
              PositionedDirectional(
                start: AppSpacing.m,
                bottom: AppSpacing.s,
                child: NotebookIconCircle(icon: icon, accent: accent),
              ),
            ],
          ),
        ),
        notebookCoverTextured(
          texture: style.texture,
          color: textureColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.s,
              AppSpacing.m,
              AppSpacing.m,
            ),
            child: text,
          ),
        ),
      ],
    );
  }
}

/// 书脊的颜色：容器色朝 onContainer 走一档的实色（亮色主题里更深），与
/// 一条细折痕线（介于书脊与封面之间的颜色）。
({Color spine, Color crease}) notebookSpineColors(
  DiaryTemplateAccentColors accent,
) {
  final spine = Color.alphaBlend(
    accent.onContainer.withValues(alpha: 0.2),
    accent.container,
  );
  return (
    spine: spine,
    crease: Color.alphaBlend(accent.container.withValues(alpha: 0.6), spine),
  );
}

/// 起始侧的一条书脊：实色底 + 靠内侧的一道细折痕。[width] 为整条宽度，
/// 折痕距内缘 [creaseInset]、宽 [creaseWidth]（小封面按比例缩小）。
class NotebookCoverSpine extends StatelessWidget {
  const NotebookCoverSpine({
    super.key,
    required this.accent,
    this.width = 14,
    this.creaseInset = 3,
    this.creaseWidth = 1.2,
  });

  final DiaryTemplateAccentColors accent;
  final double width;
  final double creaseInset;
  final double creaseWidth;

  @override
  Widget build(BuildContext context) {
    final colors = notebookSpineColors(accent);
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: colors.spine,
        // Row 跟随书写方向：从右到左的语言里书脊在右侧，折痕仍在内侧。
        child: Row(
          children: <Widget>[
            const Spacer(),
            SizedBox(
              width: creaseWidth,
              child: ColoredBox(color: colors.crease),
            ),
            SizedBox(width: creaseInset),
          ],
        ),
      ),
    );
  }
}

/// 书脊版式：起始侧一条书脊，其余按经典排布。
class NotebookCoverSpineBody extends StatelessWidget {
  const NotebookCoverSpineBody({
    super.key,
    required this.name,
    required this.icon,
    required this.accent,
    this.coverPath,
    this.countLabel,
    this.style = NotebookCoverStyle.defaults,
  });

  final String name;
  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final String? coverPath;
  final String? countLabel;
  final NotebookCoverStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NotebookCoverSpine(accent: accent),
        Expanded(
          child: NotebookCoverBody(
            name: name,
            icon: icon,
            accent: accent,
            coverPath: coverPath,
            countLabel: countLabel,
            style: style,
          ),
        ),
      ],
    );
  }
}
