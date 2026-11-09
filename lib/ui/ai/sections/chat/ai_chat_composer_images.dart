// 对话输入栏里与附图有关的部件（DESIGN §5.29“输入栏”）：
// - [AiComposerImageStrip]：输入框上方一行已添加的缩略图（与写留言面板同一个
//   [DiaryCommentImageStrip]），没有图片时收起，出现 / 收起按动效补间；
// - [AiComposerAttachButton]：胶囊行最左边的附图按钮。能拍照的平台点按弹出
//   “从相册选择 / 拍照”菜单（两项单行动作，锚定弹出菜单），其余平台直接打开
//   选择器；满了或正在复制时停用；
// - [AiComposerNote]：缩略图下方的一行小字（多选被截掉、没有权限、模型看不到
//   图片）。
//
// 选图、复制与归属都在 [DiaryCommentImagesController]，这里只负责显示与点按。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/controllers/diary_comment_images_controller.dart';
import '../../../diaries/widgets/diary_comments/diary_comment_image_strip.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';

class AiComposerImageStrip extends StatelessWidget {
  const AiComposerImageStrip({super.key, required this.images});

  final DiaryCommentImagesController images;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: images,
      builder: (context, _) {
        final empty = images.images.isEmpty && images.pending == 0;
        return AnimatedSize(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.spatial,
          alignment: Alignment.topCenter,
          child: empty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: DiaryCommentImageStrip(
                    images: images.images,
                    pending: images.pending,
                    onRemove: images.remove,
                  ),
                ),
        );
      },
    );
  }
}

class AiComposerAttachButton extends StatelessWidget {
  const AiComposerAttachButton({
    super.key,
    required this.images,
    required this.enabled,
    required this.onPick,
    this.onTakePhoto,
  });

  final DiaryCommentImagesController images;
  final bool enabled;
  final VoidCallback onPick;

  /// 拍照；null 时（不能拍照的平台）按钮直接打开选择器。
  final VoidCallback? onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: images,
      builder: (context, _) {
        final active = enabled && images.canAdd;
        Widget button(VoidCallback onPressed) => IconButton(
          tooltip: l10n.aiChatAttachImages,
          visualDensity: VisualDensity.compact,
          onPressed: active ? onPressed : null,
          icon: const FaIcon(FontAwesomeIcons.image, size: 16),
        );
        final takePhoto = onTakePhoto;
        if (takePhoto == null) return button(onPick);
        return ExpressiveMenuAnchor(
          placement: ExpressiveMenuPlacement.start,
          menuChildren: [
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.images),
              onPressed: onPick,
              child: Text(l10n.diaryMediaFromLibrary),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.camera),
              onPressed: takePhoto,
              child: Text(l10n.diaryMediaTakePhoto),
            ),
          ],
          builder: (context, menu, _) => button(menu.toggle),
        );
      },
    );
  }
}

/// 一行说明；[error] 时为 error 色（添加失败、没有权限）。
class AiComposerNote extends StatelessWidget {
  const AiComposerNote({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: error ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
