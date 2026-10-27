import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../models/notebook_icon.dart';
import '../notebook_cover_parts.dart';
import 'notebook_cover_classic.dart';
import 'notebook_cover_label.dart';
import 'notebook_cover_minimal.dart';
import 'notebook_cover_texture.dart';

/// 完整封面（3:4）的内容，按 [style] 的版式排布：
///
/// - 经典 / 书脊：见 [NotebookCoverBody] / [NotebookCoverSpineBody]；
/// - 满版：封面图铺满整张封面，名称与篇数在底部一块浮起的实色条上（容器色，
///   不用渐变遮罩）；无图时大图标居中、名称在底部；
/// - 贴签：底色（或封面图）铺满，中央一块 surface 色、细描边的圆角贴签，
///   小图标、名称与篇数写在贴签上；
/// - 极简：不画图标，名称放大加粗靠上，篇数在底部；有图时图片做背景，名称
///   放在顶部的实色带上、篇数放在左下的实色小牌上，保证可读。
///
/// 右上角角标、选中描边、合上的不透明度与水波纹由外层 `NotebookCoverTile`
/// 统一叠加；[reserveBadge] 为 true 时，靠上排的名称（极简）在行尾让出
/// 角标的位置。只负责展示。
class NotebookCoverLayoutBody extends StatelessWidget {
  const NotebookCoverLayoutBody({
    super.key,
    required this.name,
    required this.icon,
    required this.accent,
    required this.style,
    this.coverPath,
    this.countLabel,
    this.reserveBadge = false,
  });

  final String name;
  final NotebookIcon icon;
  final DiaryTemplateAccentColors accent;
  final NotebookCoverStyle style;
  final String? coverPath;
  final String? countLabel;
  final bool reserveBadge;

  @override
  Widget build(BuildContext context) {
    return switch (style.layout) {
      NotebookCoverLayout.classic => NotebookCoverBody(
        name: name,
        icon: icon,
        accent: accent,
        coverPath: coverPath,
        countLabel: countLabel,
        style: style,
      ),
      NotebookCoverLayout.spine => NotebookCoverSpineBody(
        name: name,
        icon: icon,
        accent: accent,
        coverPath: coverPath,
        countLabel: countLabel,
        style: style,
      ),
      NotebookCoverLayout.fullBleed => NotebookCoverFullBleedBody(this),
      NotebookCoverLayout.label => NotebookCoverLabelBody(this),
      NotebookCoverLayout.minimal => NotebookCoverMinimalBody(this),
    };
  }
}

/// 铺满父级的封面图（按显示框的宽高解码与取景）。
class NotebookCoverFilledImage extends StatelessWidget {
  const NotebookCoverFilledImage({
    super.key,
    required this.path,
    required this.style,
  });

  final String path;
  final NotebookCoverStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          NotebookCoverImage(
            path: path,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            style: style,
          ),
    );
  }
}

/// 满版版式：封面图铺满整张封面，左上一个小图标圆，名称与篇数写在底部
/// 浮起的圆角实色条上；没有封面图时大图标居中、名称在底部。
class NotebookCoverFullBleedBody extends StatelessWidget {
  const NotebookCoverFullBleedBody(this.data, {super.key});

  final NotebookCoverLayoutBody data;

  @override
  Widget build(BuildContext context) {
    final accent = data.accent;
    final text = NotebookCoverText(
      name: data.name,
      countLabel: data.countLabel,
      color: accent.onContainer,
    );
    final cover = data.coverPath;
    if (cover == null) {
      return notebookCoverTextured(
        texture: data.style.texture,
        color: notebookCoverTextureColor(accent.onContainer),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: NotebookIconCircle(
                    icon: data.icon,
                    accent: accent,
                    size: 64,
                  ),
                ),
              ),
              text,
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        NotebookCoverFilledImage(path: cover, style: data.style),
        PositionedDirectional(
          top: AppSpacing.s,
          start: AppSpacing.s,
          child: NotebookIconCircle(icon: data.icon, accent: accent, size: 30),
        ),
        Positioned(
          left: AppSpacing.s,
          right: AppSpacing.s,
          bottom: AppSpacing.s,
          // 浮起的实色条：圆角容器色，纹理只画在条里露出的底色上。
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: accent.container,
              child: notebookCoverTextured(
                texture: data.style.texture,
                color: notebookCoverTextureColor(accent.onContainer),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: SizedBox(width: double.infinity, child: text),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
