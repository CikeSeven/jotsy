// 同步过程中的确认对话框（DESIGN.md §5.28“以哪边为准 / 删除保护对话框”）
// 与设备详情页的“取消配对”确认。只负责展示与收集选择，结果交给调用方：
// 以哪边为准 / 删除保护返回所选项，取消、点遮罩或返回键为 null；
// 取消配对返回是否确认。
//
// 版式：顶部 26dp 图标（以哪边为准为 `primary` 的 `rightLeft`，删除保护为
// `error` 的 `triangleExclamation`），标题 22 / w700 居中，说明 14 灰字居中，
// 选项为 [ExpressiveChoiceTile]；按钮右对齐：灰色“取消” + 加粗的确认键
// （删除保护为 `error` 色）。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../models/lan_sync_item_counts.dart';
import '../models/lan_sync_ui_events.dart';
import 'lan_sync_labels.dart';

/// 以哪边为准：默认选中“保留两份”。只有日记时说“有 N 篇日记……”，还有
/// 别的种类时逐项列出（“日记 2 · 标签 1”）。
Future<LanSyncSideChoice?> showLanSyncChooseSideDialog(
  BuildContext context, {
  required String peerName,
  required LanSyncItemCounts items,
}) {
  final l10n = context.l10n;
  final body = items.others == 0
      ? l10n.lanSyncChooseSideBody(peerName, items.diaries)
      : l10n.lanSyncChooseSideBodyItems(
          peerName,
          lanSyncItemCountsText(l10n, items),
        );
  return showAppDialog<LanSyncSideChoice>(
    context: context,
    builder: (BuildContext context) => _LanSyncChoiceDialog<LanSyncSideChoice>(
      icon: FontAwesomeIcons.rightLeft,
      danger: false,
      title: l10n.lanSyncChooseSideTitle,
      body: body,
      initial: LanSyncSideChoice.keepBoth,
      options: <_ChoiceOption<LanSyncSideChoice>>[
        _ChoiceOption<LanSyncSideChoice>(
          LanSyncSideChoice.keepBoth,
          l10n.lanSyncChooseKeepBoth,
          l10n.lanSyncChooseKeepBothDesc,
        ),
        _ChoiceOption<LanSyncSideChoice>(
          LanSyncSideChoice.preferLocal,
          l10n.lanSyncChoosePreferLocal,
          l10n.lanSyncChoosePreferLocalDesc,
        ),
        _ChoiceOption<LanSyncSideChoice>(
          LanSyncSideChoice.preferPeer,
          l10n.lanSyncChoosePreferPeer,
          l10n.lanSyncChoosePreferPeerDesc(peerName),
        ),
      ],
      note: l10n.lanSyncChooseSideNote,
    ),
  );
}

/// 删除保护：默认选中“保留，并恢复到另一台”——误点“继续同步”时不丢日记。
Future<LanSyncDeletionChoice?> showLanSyncDeletionGuardDialog(
  BuildContext context, {
  required String peerName,
  required int deleteCount,
  required LanSyncSide onSide,
}) {
  final l10n = context.l10n;
  return showAppDialog<LanSyncDeletionChoice>(
    context: context,
    builder: (BuildContext context) =>
        _LanSyncChoiceDialog<LanSyncDeletionChoice>(
          icon: FontAwesomeIcons.triangleExclamation,
          danger: true,
          title: l10n.lanSyncDeletionTitle,
          body: switch (onSide) {
            LanSyncSide.peer => l10n.lanSyncDeletionBodyPeer(
              peerName,
              deleteCount,
            ),
            LanSyncSide.local => l10n.lanSyncDeletionBodyLocal(
              peerName,
              deleteCount,
            ),
          },
          initial: LanSyncDeletionChoice.keepAndRestore,
          options: <_ChoiceOption<LanSyncDeletionChoice>>[
            _ChoiceOption<LanSyncDeletionChoice>(
              LanSyncDeletionChoice.syncDeletion,
              l10n.lanSyncDeletionSync,
              l10n.lanSyncDeletionSyncDesc,
            ),
            _ChoiceOption<LanSyncDeletionChoice>(
              LanSyncDeletionChoice.keepAndRestore,
              l10n.lanSyncDeletionKeep,
              l10n.lanSyncDeletionKeepDesc,
            ),
          ],
        ),
  );
}

/// 取消配对确认：说明不会删除任何日记，右侧 `error` 色“取消配对”。
Future<bool> showLanSyncForgetDialog(
  BuildContext context, {
  required String peerName,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final colors = Theme.of(context).colorScheme;
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.lanSyncForgetTitle(peerName)),
        content: Text(l10n.lanSyncForgetBody),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lanSyncForget),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _ChoiceOption<T> {
  const _ChoiceOption(this.value, this.label, this.description);

  final T value;
  final String label;
  final String description;
}

/// 单选对话框本体：选中项只在对话框内存里，确认时随 pop 返回。
class _LanSyncChoiceDialog<T> extends StatefulWidget {
  const _LanSyncChoiceDialog({
    required this.icon,
    required this.danger,
    required this.title,
    required this.body,
    required this.initial,
    required this.options,
    this.note,
  });

  final FaIconData icon;

  /// 删除保护：图标与确认键为 `error` 色。
  final bool danger;
  final String title;
  final String body;
  final T initial;
  final List<_ChoiceOption<T>> options;

  /// 选项下方 12.5 灰字说明。
  final String? note;

  @override
  State<_LanSyncChoiceDialog<T>> createState() =>
      _LanSyncChoiceDialogState<T>();
}

class _LanSyncChoiceDialogState<T> extends State<_LanSyncChoiceDialog<T>> {
  late T _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final accent = widget.danger ? colors.error : colors.primary;
    final note = widget.note;
    return AlertDialog(
      scrollable: true,
      icon: FaIcon(widget.icon, size: 26, color: accent),
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final option in widget.options)
            ExpressiveChoiceTile(
              label: option.label,
              description: option.description,
              selected: option.value == _selected,
              onTap: () => setState(() => _selected = option.value),
            ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              note,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(l10n.lanSyncContinueSync),
        ),
      ],
    );
  }
}
