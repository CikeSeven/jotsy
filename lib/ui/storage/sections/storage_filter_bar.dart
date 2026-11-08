import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../models/storage_media_filter.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';

/// 媒体页列表上方：一行可横向滑动的筛选（类别单选 + 大文件 / 可压缩 /
/// 回收站三个可叠加的条件），下面是“共 N 项 · X”，有打码的私密项时再加
/// 一行说明与“显示”。
class StorageFilterBar extends StatelessWidget {
  const StorageFilterBar({
    super.key,
    required this.filter,
    required this.view,
    required this.canCompress,
    required this.padding,
    required this.onChanged,
    required this.onReveal,
  });

  final StorageMediaFilter filter;
  final StorageMediaListView view;
  final bool canCompress;
  final EdgeInsets padding;
  final ValueChanged<StorageMediaFilter> onChanged;

  /// 为 null 时没有可揭示的私密项（或已揭示）。
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget category(String label, StorageCategory? value) => Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
      child: ChoiceChip(
        label: Text(label),
        selected: filter.category == value,
        onSelected: (_) => onChanged(filter.copyWith(category: () => value)),
      ),
    );
    Widget toggle(String label, bool selected, StorageMediaFilter next) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
          child: FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onChanged(next),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DesktopHorizontalScroll(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: Row(
              children: <Widget>[
                category(l10n.storageMgmtFilterAll, null),
                for (final value in StorageMediaFilter.categories)
                  category(value.label(l10n), value),
                const SizedBox(width: AppSpacing.s),
                toggle(
                  l10n.storageMgmtFilterLarge,
                  filter.largeOnly,
                  filter.copyWith(largeOnly: !filter.largeOnly),
                ),
                if (canCompress)
                  toggle(
                    l10n.storageMgmtFilterCompressible,
                    filter.compressibleOnly,
                    filter.copyWith(compressibleOnly: !filter.compressibleOnly),
                  ),
                toggle(
                  l10n.storageMgmtFilterTrash,
                  filter.trashOnly,
                  filter.copyWith(trashOnly: !filter.trashOnly),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left + AppSpacing.xs,
            AppSpacing.s,
            padding.right,
            0,
          ),
          child: Text(
            l10n.storageMgmtListSummary(
              view.items.length,
              l10n.formatByteSize(view.totalBytes),
            ),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (onReveal != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left + AppSpacing.xs,
              AppSpacing.xs,
              padding.right,
              0,
            ),
            child: Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.lock,
                  size: 12,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    l10n.storageMgmtPrivateHidden(view.maskedPrivateCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onReveal,
                  child: Text(l10n.storageMgmtReveal),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
