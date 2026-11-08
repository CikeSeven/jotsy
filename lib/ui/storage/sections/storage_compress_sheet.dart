import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_compress_plan.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../viewmodels/storage_media_view.dart';

/// 压缩前选档位：照片与视频各三档，每档写明规格与这批文件压完的预计大小，
/// 底部汇总“原大小 → 预计大小”。选定后返回档位，取消返回 null。
///
/// 打开时以上次用的档位为初值；估算与“会跳过几项”随档位实时更新（换档
/// 可能让某些文件变得值得或不值得压）。
Future<StorageCompressContext?> showStorageCompressSheet(
  BuildContext context, {
  required List<StorageMediaEntry> entries,
  required StorageUsageReport report,
  required StorageCompressContext initial,
}) => showAppModalBottomSheet<StorageCompressContext>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      _CompressSheet(entries: entries, report: report, initial: initial),
);

class _CompressSheet extends StatefulWidget {
  const _CompressSheet({
    required this.entries,
    required this.report,
    required this.initial,
  });

  final List<StorageMediaEntry> entries;
  final StorageUsageReport report;
  final StorageCompressContext initial;

  @override
  State<_CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<_CompressSheet> {
  late StorageImagePreset _image = widget.initial.imagePreset;
  late StorageVideoPreset _video = widget.initial.videoPreset;

  StorageCompressContext get _choice => StorageCompressContext(
    supported: true,
    imagePreset: _image,
    videoPreset: _video,
  );

  List<StorageMediaEntry> _of(DiaryBlockMediaKind kind) => [
    for (final entry in widget.entries)
      if (entry.kind == kind) entry,
  ];

  /// 这批里能压的原大小与预计大小。
  ({int count, int before, int after}) _estimate(
    StorageCompressContext choice,
    Iterable<StorageMediaEntry> entries,
  ) {
    var count = 0;
    var before = 0;
    var after = 0;
    for (final entry in entries) {
      final estimate = choice.estimate(entry, widget.report);
      if (estimate == null) continue;
      count++;
      before += entry.bytes;
      after += estimate;
    }
    return (count: count, before: before, after: after);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final images = _of(DiaryBlockMediaKind.image);
    final videos = _of(DiaryBlockMediaKind.video);
    final total = _estimate(_choice, widget.entries);
    final skipped = widget.entries.length - total.count;
    String sizeOf(int bytes) => l10n.formatByteSize(bytes);

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.storageMgmtCompressTitle(widget.entries.length),
              style: theme.textTheme.titleLarge,
            ),
            if (images.isNotEmpty) ...<Widget>[
              sectionTitle(l10n.storageMgmtCompressImages),
              for (final preset in StorageImagePreset.values)
                ExpressiveChoiceTile(
                  label: _imageLabel(l10n, preset),
                  description: l10n.storageMgmtImagePresetDetail(
                    preset.maxSide,
                    preset.quality,
                    _estimateLine(
                      l10n,
                      _estimate(
                        StorageCompressContext(
                          supported: true,
                          imagePreset: preset,
                          videoPreset: _video,
                        ),
                        images,
                      ),
                    ),
                  ),
                  selected: _image == preset,
                  onTap: () => setState(() => _image = preset),
                ),
            ],
            if (videos.isNotEmpty) ...<Widget>[
              sectionTitle(l10n.storageMgmtCompressVideos),
              for (final preset in StorageVideoPreset.values)
                ExpressiveChoiceTile(
                  label: '${preset.shortSide}p',
                  description: _estimateLine(
                    l10n,
                    _estimate(
                      StorageCompressContext(
                        supported: true,
                        imagePreset: _image,
                        videoPreset: preset,
                      ),
                      videos,
                    ),
                  ),
                  selected: _video == preset,
                  onTap: () => setState(() => _video = preset),
                ),
            ],
            const SizedBox(height: AppSpacing.l),
            Text(
              total.count == 0
                  ? l10n.storageMgmtCompressNothing
                  : l10n.storageMgmtCompressSummary(
                      sizeOf(total.before),
                      sizeOf(total.after),
                      sizeOf(total.before - total.after),
                    ),
              style: theme.textTheme.titleSmall,
            ),
            if (skipped > 0 && total.count > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.storageMgmtCompressSkipped(skipped),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.storageMgmtCompressNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(
                  onPressed: total.count == 0
                      ? null
                      : () => Navigator.of(context).pop(_choice),
                  child: Text(l10n.storageMgmtCompressStart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _estimateLine(
    AppLocalizations l10n,
    ({int count, int before, int after}) estimate,
  ) => estimate.count == 0
      ? l10n.storageMgmtPresetNoGain
      : l10n.storageMgmtPresetEstimate(
          l10n.formatByteSize(estimate.before),
          l10n.formatByteSize(estimate.after),
        );

  static String _imageLabel(AppLocalizations l10n, StorageImagePreset preset) =>
      switch (preset) {
        StorageImagePreset.high => l10n.storageMgmtPresetHigh,
        StorageImagePreset.balanced => l10n.storageMgmtPresetBalanced,
        StorageImagePreset.compact => l10n.storageMgmtPresetCompact,
      };
}
