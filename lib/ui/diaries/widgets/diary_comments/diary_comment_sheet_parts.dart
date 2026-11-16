import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_comment_images_controller.dart';

// 写留言面板（diary_comment_sheet.dart）的几个小部件：添加图片按钮、选图
// 结果的一行小字、心情选项。

/// 底部左边的“添加图片”：色调按钮（玻璃时经 [AppGlassField.tonalButtonStyle]），
/// 已有图片时文字后面接“张数/上限”；满了或正在复制时不可点，满了时长按 /
/// 悬停给出上限说明。
class DiaryCommentAddImagesButton extends StatelessWidget {
  const DiaryCommentAddImagesButton({
    super.key,
    required this.count,
    required this.enabled,
    required this.onPressed,
  });

  final int count;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = count == 0
        ? l10n.diaryCommentAddImages
        : '${l10n.diaryCommentAddImages} $count/$kDiaryCommentMaxImages';
    final button = FilledButton.tonalIcon(
      style: AppGlassField.tonalButtonStyle(context),
      onPressed: enabled ? onPressed : null,
      icon: const FaIcon(FontAwesomeIcons.image, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    if (count < kDiaryCommentMaxImages) return button;
    return Tooltip(
      message: l10n.diaryCommentImagesFull(kDiaryCommentMaxImages),
      child: button,
    );
  }
}

/// 选图结果的一行小字：多选被截掉为次要色，失败与没有权限为 error 色。
class DiaryCommentPickNotice extends StatelessWidget {
  const DiaryCommentPickNotice({super.key, required this.result});

  final DiaryCommentImagePickResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (String text, Color color) = switch (result) {
      DiaryCommentImagePickResult.truncated => (
        l10n.diaryCommentImagesTruncated(kDiaryCommentMaxImages),
        scheme.onSurfaceVariant,
      ),
      DiaryCommentImagePickResult.permissionDenied => (
        l10n.diaryCommentImagePermissionDenied,
        scheme.error,
      ),
      _ => (l10n.diaryCommentImageAddFailed, scheme.error),
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

/// 一个可选的心情：选中时为主色容器底 + 主色描边的圆，选中态经
/// [ExpressiveStateBlend] 补间。未选中的底色与描边按 [AppGlassField] 跟随
/// “控件”材质（经典时透明底 + outlineVariant 细描边），选中色不变。
class DiaryCommentMoodChoice extends StatelessWidget {
  const DiaryCommentMoodChoice({
    super.key,
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final String mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glassField = AppGlassField.of(context);
    final restingFill =
        glassField?.fill ?? scheme.primaryContainer.withValues(alpha: 0);
    final restingSide =
        glassField?.border ?? BorderSide(color: scheme.outlineVariant);
    final selectedSide = BorderSide(color: scheme.primary, width: 1.5);
    return Semantics(
      button: true,
      selected: selected,
      label: mood,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                mood,
                style: const TextStyle(fontSize: 20, height: 1),
              ),
            ),
          ),
        ),
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: Color.lerp(restingFill, scheme.primaryContainer, t),
          shape: CircleBorder(
            side: BorderSide.lerp(restingSide, selectedSide, t),
          ),
          child: child,
        ),
      ),
    );
  }
}
