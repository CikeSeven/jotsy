// 对话输入栏里与附图有关的部件（DESIGN §5.29“输入栏”）：
// - [AiComposerImageStrip]：输入框上方一行已添加的缩略图（与写留言面板同一个
//   [DiaryCommentImageStrip]），没有图片时收起，出现 / 收起按动效补间；
// - [AiComposerAttachButton]：底排最左边的按钮。对话页是“＋”，点按弹出锚定
//   菜单：从相册选择、拍照（能拍照的平台）、范围、人设（后两行行尾写着当前
//   值，最多 4 项单行动作）；没有额外几行时是附图按钮，不能拍照的平台点了
//   直接打开选择器。附图满了或正在复制时只停用附图两项；
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

/// “＋”菜单里的一行设置（范围、人设）：图标、名称与行尾的当前值。
@immutable
class AiComposerOption {
  const AiComposerOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final FaIconData icon;
  final String label;

  /// 当前值（“自动”、人设名），写在行尾。
  final String value;

  /// null 时这一行停用（生成中不能改）。
  final VoidCallback? onPressed;
}

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
    this.options = const <AiComposerOption>[],
  });

  final DiaryCommentImagesController images;
  final bool enabled;
  final VoidCallback onPick;

  /// 拍照；null 时（不能拍照的平台）没有这一项。
  final VoidCallback? onTakePhoto;

  /// 附图之外的几行（范围、人设）；有时按钮为“＋”。
  final List<AiComposerOption> options;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListenableBuilder(
      listenable: images,
      builder: (context, _) {
        final canAdd = images.canAdd;
        final takePhoto = onTakePhoto;
        // 只有“从相册选择”一件事可做：不绕菜单，点了直接打开选择器。
        if (takePhoto == null && options.isEmpty) {
          return IconButton(
            tooltip: l10n.aiChatAttachImages,
            visualDensity: VisualDensity.compact,
            onPressed: enabled && canAdd ? onPick : null,
            icon: const FaIcon(FontAwesomeIcons.image, size: 16),
          );
        }
        final plus = options.isNotEmpty;
        return ExpressiveMenuAnchor(
          placement: ExpressiveMenuPlacement.start,
          menuChildren: <Widget>[
            // 满了或正在复制时附图两项停用，范围与人设照常能改。
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.images),
              onPressed: canAdd ? onPick : null,
              child: Text(l10n.diaryMediaFromLibrary),
            ),
            if (takePhoto != null)
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.camera),
                onPressed: canAdd ? takePhoto : null,
                child: Text(l10n.diaryMediaTakePhoto),
              ),
            for (final option in options)
              ExpressiveMenuItem(
                leadingIcon: FaIcon(option.icon),
                onPressed: option.onPressed,
                trailingIcon: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    option.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                child: Text(option.label),
              ),
          ],
          builder: (context, menu, _) => IconButton(
            tooltip: plus ? l10n.aiChatComposerAdd : l10n.aiChatAttachImages,
            visualDensity: VisualDensity.compact,
            onPressed: enabled && (plus || canAdd) ? menu.toggle : null,
            icon: FaIcon(
              plus ? FontAwesomeIcons.plus : FontAwesomeIcons.image,
              size: 16,
            ),
          ),
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
