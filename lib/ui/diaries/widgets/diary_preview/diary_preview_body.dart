import 'package:flutter/material.dart';
import '../../controllers/diary_editor_controller.dart';
import '../diary_editor/diary_editor.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/precise_time_formatter.dart';
import '../../../../utils/relative_time_formatter.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../models/time_capsule.dart';
import '../../viewmodels/diary_text_appearance.dart';

/// 预览页正文：只读原生块文档，按真实文字/嵌入判断是否显示空正文提示。
/// 自定义正文颜色经 DefaultTextStyle 传入，字体、字号、行距与块渲染继续
/// 使用 DiaryEditor 的共用解析；待办只开放 checked 事务，保存由页面负责。
class DiaryPreviewBody extends StatelessWidget {
  const DiaryPreviewBody({
    super.key,
    required this.controller,
    required this.appearance,
    required this.onOpenImage,
    this.showEmptyHint = true,
    this.todoToggle = true,
    this.textSelection = true,
    this.longImageMode = DiaryPreviewLongImageMode.fold,
    this.textColor,
  });

  final DiaryEditorController controller;
  final DiaryTextAppearance appearance;

  /// 点按正文图片：来源与点按处抓取的共享元素。
  final void Function(String source, ImageViewerHero? hero) onOpenImage;
  final bool showEmptyHint;

  /// 允许勾选待办（关闭后勾选框只读）。
  final bool todoToggle;

  /// 允许长按选择文字。
  final bool textSelection;

  /// 正文长图折叠还是完整显示。
  final DiaryPreviewLongImageMode longImageMode;

  /// 通过对比度检查的自定义正文颜色；null 用主题正文色。
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final hasVisibleContent = controller.hasContent;
    Widget body;
    if (hasVisibleContent) {
      body = DiaryEditor(
        controller: controller,
        appearance: appearance,
        shrinkWrap: true,
        todoToggle: todoToggle,
        textSelection: textSelection,
        onImageOpen: onOpenImage,
        foldLongImages: longImageMode == DiaryPreviewLongImageMode.fold,
      );
    } else if (showEmptyHint) {
      body = Text(
        context.l10n.autoT0119,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: textColor),
      );
    } else {
      return const SizedBox.shrink();
    }
    final color = textColor;
    if (color == null) {
      return body;
    }
    return DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: body,
    );
  }
}

/// “最后编辑于 …”（没编辑过的日记返回 null，不占位）。
String? diaryPreviewEditedLabel(
  AppLocalizations l10n,
  Diary diary,
  DiaryPreviewEditedFormat format,
) {
  if (diary.updatedAt.isAtSameMomentAs(diary.createdAt)) {
    return null;
  }
  final now = DateTime.now();
  final updated = diary.updatedAt;
  final time = switch (format) {
    DiaryPreviewEditedFormat.precise => PreciseTimeFormatter.format(
      target: updated,
      now: now,
      l10n: l10n,
    ),
    DiaryPreviewEditedFormat.relative => RelativeTimeFormatter.formatUpdatedAt(
      updatedAt: updated,
      now: now,
      l10n: l10n,
    ),
    DiaryPreviewEditedFormat.full => l10n.diaryCardDateWithTime(
      l10n.formatFullDate(updated.toLocal()),
      DateFormat.Hm(l10n.localeName).format(updated.toLocal()),
    ),
  };
  return '${l10n.autoT0118} $time';
}

/// 页尾的“最后编辑于”一行。
class DiaryPreviewEditedLine extends StatelessWidget {
  const DiaryPreviewEditedLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
