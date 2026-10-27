import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/diary_font_storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/pages/diary_typography_page.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/diary_typography_controller.dart';
import '../providers/diary_typography_provider.dart';
import '../widgets/diary_font_choices.dart';
import '../widgets/diary_typography_metrics_editor.dart';

/// 预览页的“字体与排版”快捷面板：边读边调，改动即时作用到面板后方的正文。
///
/// 遮罩比默认浅：调整时要能看清后方正文的变化。导入与删除字体只在设置页
/// 进行（需要文件选择与确认），面板底部提供入口。
Future<void> showDiaryTypographySheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.12),
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => const DiaryTypographySheet(),
  );
}

class DiaryTypographySheet extends ConsumerStatefulWidget {
  const DiaryTypographySheet({super.key});

  @override
  ConsumerState<DiaryTypographySheet> createState() =>
      _DiaryTypographySheetState();
}

class _DiaryTypographySheetState extends ConsumerState<DiaryTypographySheet> {
  late final DiaryTypographyController _controller = DiaryTypographyController(
    ref,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final typography = ref.watch(diaryTypographyProvider);
    final importedFonts =
        ref.watch(diaryImportedFontsProvider).asData?.value ??
        const <DiaryImportedFont>[];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: Text(
                l10n.diaryTypographyQuickTooltip,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DiaryFontChipBar(
              options: diaryFontOptions(l10n, importedFonts),
              selectedId: typography.fontId,
              onSelected: (String fontId) =>
                  _controller.commit(typography.copyWith(fontId: fontId)),
            ),
            DiaryTypographyMetricsEditor(
              typography: typography,
              onCommit: _controller.commit,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: typography.hasDefaultMetrics
                        ? null
                        : () => _controller.commit(
                            typography.withDefaultMetrics(),
                          ),
                    child: Text(l10n.diaryTypographyReset),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const DiaryTypographyPage(),
                      ),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.sliders, size: 14),
                    label: Text(l10n.diaryTypographyMoreSettings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
