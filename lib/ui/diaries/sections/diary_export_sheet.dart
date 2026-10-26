import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../export/diary_export_format.dart';
import '../viewmodels/diary_export_messages.dart';
import '../widgets/diary_sheet_controls.dart';

enum DiaryExportAction { save, share }

/// 导出面板的选择：格式与开关，以及保存还是分享。
@immutable
class DiaryExportRequest {
  const DiaryExportRequest(
    this.options,
    this.action, {
    this.bookStructure = true,
  });

  final DiaryExportOptions options;
  final DiaryExportAction action;

  /// 导出成书时是否写出扉页、目录与章节标题；不是成书时没有意义。
  final bool bookStructure;
}

/// 打开导出面板，返回用户的选择；关闭面板返回 null。
///
/// 面板只负责挑选，生成与保存由 `runDiaryExportFlow` 在面板关闭后执行。
/// 格式与开关每次改动即经 [onOptionsChanged] 交给调用方保存，下次打开沿用。
///
/// [isBook] 为 true（导出成书）时：先后顺序由书决定，不显示排序；能写出
/// 结构的格式在“选项”最前多一个“书籍结构”开关（默认开），表格与日记文件
/// 照常导出、不显示它。这个开关只对本次有效，不写进导出选项。
Future<DiaryExportRequest?> showDiaryExportSheet(
  BuildContext context, {
  required int diaryCount,
  required DiaryExportOptions initialOptions,
  required ValueChanged<DiaryExportOptions> onOptionsChanged,
  bool isBook = false,
}) {
  return showModalBottomSheet<DiaryExportRequest>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 七种格式加选项常超过默认 9/16 屏高，按内容撑高，放不下时面板内滚动。
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryExportSheet(
      diaryCount: diaryCount,
      initialOptions: initialOptions,
      onOptionsChanged: onOptionsChanged,
      isBook: isBook,
    ),
  );
}

class DiaryExportSheet extends StatefulWidget {
  const DiaryExportSheet({
    super.key,
    required this.diaryCount,
    required this.initialOptions,
    required this.onOptionsChanged,
    this.isBook = false,
  });

  final int diaryCount;
  final DiaryExportOptions initialOptions;
  final ValueChanged<DiaryExportOptions> onOptionsChanged;

  /// 导出成书（见 [showDiaryExportSheet]）。
  final bool isBook;

  @override
  State<DiaryExportSheet> createState() => _DiaryExportSheetState();
}

class _DiaryExportSheetState extends State<DiaryExportSheet> {
  late DiaryExportOptions _options = widget.initialOptions;
  bool _bookStructure = true;

  void _update(DiaryExportOptions next) {
    if (next == _options) {
      return;
    }
    setState(() => _options = next);
    widget.onOptionsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = _options.format;
    final showOrder =
        !widget.isBook && widget.diaryCount > 1 && format.supportsOrder;
    final showBookStructure = widget.isBook && format.supportsBookStructure;
    final hasOptions =
        format.supportsMediaToggle ||
        format.supportsMetaToggle ||
        showOrder ||
        showBookStructure;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.diaryExportSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            DiarySheetSectionHeader(
              icon: FontAwesomeIcons.fileExport,
              label: l10n.diaryExportFormatSection,
              trailing: l10n.diaryExportSheetCount(widget.diaryCount),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final value in DiaryExportFormat.values)
              ExpressiveChoiceTile(
                label: diaryExportFormatName(l10n, value),
                description: diaryExportFormatDescription(l10n, value),
                selected: value == format,
                onTap: () => _update(_options.copyWith(format: value)),
              ),
            // 换格式时可用的选项随之增减，高度平滑过渡。
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: hasOptions
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.l),
                      child: _buildOptions(
                        l10n,
                        showOrder: showOrder,
                        showBookStructure: showBookStructure,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                // share_plus 在 Linux 上不能分享文件：只保留“保存到文件”。
                if (AppPlatform.supportsSystemFileShare) ...<Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        DiaryExportRequest(
                          _options,
                          DiaryExportAction.share,
                          bookStructure: _bookStructure,
                        ),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 16),
                      label: Text(l10n.commonShare),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      DiaryExportRequest(
                        _options,
                        DiaryExportAction.save,
                        bookStructure: _bookStructure,
                      ),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.download, size: 16),
                    label: Text(l10n.diaryExportSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(
    AppLocalizations l10n, {
    required bool showOrder,
    required bool showBookStructure,
  }) {
    final format = _options.format;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DiarySheetSectionHeader(
          icon: FontAwesomeIcons.sliders,
          label: l10n.diaryExportOptionsSection,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (showBookStructure)
          DiarySheetSwitch(
            label: l10n.diaryExportBookStructure,
            description: l10n.diaryExportBookStructureDescription,
            value: _bookStructure,
            onChanged: (bool value) => setState(() => _bookStructure = value),
          ),
        if (format.supportsMediaToggle)
          DiarySheetSwitch(
            label: diaryExportMediaToggleLabel(l10n, format),
            value: _options.includeMedia,
            onChanged: (bool value) =>
                _update(_options.copyWith(includeMedia: value)),
          ),
        if (format.supportsMetaToggle)
          DiarySheetSwitch(
            label: l10n.diaryExportIncludeMeta,
            value: _options.includeMeta,
            onChanged: (bool value) =>
                _update(_options.copyWith(includeMeta: value)),
          ),
        if (showOrder) ...<Widget>[
          const SizedBox(height: AppSpacing.s),
          ExpressiveButtonGroup<DiaryExportOrder>(
            segments: <ButtonSegment<DiaryExportOrder>>[
              ButtonSegment<DiaryExportOrder>(
                value: DiaryExportOrder.oldestFirst,
                icon: const FaIcon(FontAwesomeIcons.arrowUpWideShort, size: 16),
                label: Text(l10n.diaryExportOrderOldest),
              ),
              ButtonSegment<DiaryExportOrder>(
                value: DiaryExportOrder.newestFirst,
                icon: const FaIcon(
                  FontAwesomeIcons.arrowDownWideShort,
                  size: 16,
                ),
                label: Text(l10n.diaryExportOrderNewest),
              ),
            ],
            selected: <DiaryExportOrder>{_options.order},
            onSelectionChanged: (Set<DiaryExportOrder> selection) =>
                _update(_options.copyWith(order: selection.single)),
          ),
        ],
      ],
    );
  }
}
