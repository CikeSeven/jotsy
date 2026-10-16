import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/content_codec.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/precise_time_formatter.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/time_capsule.dart';
import '../../viewmodels/diary_quill_styles.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../diary_mobile_toolbar.dart';

/// 预览页正文：只读 Quill（可勾选待办），没有可见内容时显示空正文提示；
/// 编辑过的日记在末尾附“最后编辑于”。
///
/// 是否有正文不能只看 contentText（纯文本镜像），否则“仅图片正文”会被误判
/// 为空：统一按 Quill 文档是否存在可见内容判断，图片、视频与其他嵌入都算
/// 正文。Quill 样式必须在正文位置生成（[DiaryQuillStylesBuilder]），这里在
/// Scaffold 之下，取得到主题的正文样式。
class DiaryPreviewBody extends StatelessWidget {
  const DiaryPreviewBody({
    super.key,
    required this.diary,
    required this.controller,
    required this.appearance,
    required this.onOpenImage,
  });

  final Diary diary;
  final quill.QuillController controller;
  final DiaryTextAppearance appearance;

  /// 点按正文图片：来源与点按处抓取的共享元素。
  final void Function(String source, ImageViewerHero? hero) onOpenImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasBeenEdited = !diary.updatedAt.isAtSameMomentAs(diary.createdAt);
    final editedText = hasBeenEdited
        ? '${l10n.autoT0118} ${PreciseTimeFormatter.format(target: diary.updatedAt, now: DateTime.now(), l10n: l10n)}'
        : null;

    final hasVisibleContent = diaryDocumentHasVisibleContent(
      controller.document,
    );
    final contentBody = hasVisibleContent
        ? DiaryQuillStylesBuilder(
            appearance: appearance,
            builder: (BuildContext context, quill.DefaultStyles styles) {
              return quill.QuillEditor.basic(
                controller: controller,
                config: quill.QuillEditorConfig(
                  autoFocus: false,
                  scrollable: false,
                  padding: EdgeInsets.zero,
                  showCursor: false,
                  checkBoxReadOnly: false,
                  customStyles: styles,
                  embedBuilders: buildDiaryQuillEmbedBuilders(
                    onImageOpen: onOpenImage,
                  ),
                ),
              );
            },
          )
        : Text(l10n.autoT0119, style: Theme.of(context).textTheme.bodyLarge);

    if (editedText == null) {
      return contentBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        contentBody,
        const SizedBox(height: 16),
        Text(
          editedText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 已解封时间胶囊顶部的提示卡（未解封或不是胶囊时不占位）。
class DiaryPreviewCapsuleInsight extends StatelessWidget {
  const DiaryPreviewCapsuleInsight({
    super.key,
    required this.capsuleState,
    required this.moodEmoji,
  });

  final TimeCapsuleState capsuleState;
  final String? moodEmoji;

  @override
  Widget build(BuildContext context) {
    if (!capsuleState.isCapsule || capsuleState.isLocked) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final mood = moodEmoji;
    final message = mood != null
        ? l10n.timeCapsuleUnlockedInsight(mood)
        : l10n.timeCapsuleUnlockedInsightNoMood;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FaIcon(
            FontAwesomeIcons.unlockKeyhole,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
