import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../widgets/expressive_reorder_proxy.dart';
import '../../../widgets/triple_bar_drag_handle.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import 'diary_card_style_labels.dart';

/// “排序”标签页：拖动调整卡片正文各区块（日期行、标题、标签、摘要、底栏）
/// 的上下顺序，两种布局共用。松手即写入，预览随之重排。
///
/// 拖拽手柄立即拖动、不经过长按，系统不会反馈；拿起时补一次触觉，与工具栏
/// 排序页一致。
class DiaryCardStyleOrderTab extends StatelessWidget {
  const DiaryCardStyleOrderTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  void _reorder(int oldIndex, int newIndex) {
    final style = controller.style;
    final blocks = List<DiaryCardBlock>.of(style.content.blocks);
    final moved = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, moved);
    controller.commit(
      style.copyWith(content: style.content.copyWith(blocks: blocks)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = controller.style;
    final blocks = style.content.blocks;
    final isDefaultOrder = _sameOrder(blocks, DiaryCardBlock.values);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
      buildDefaultDragHandles: false,
      proxyDecorator: expressiveReorderProxyDecorator,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Text(
          l10n.diaryCardStyleOrderHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: isDefaultOrder
                ? null
                : () => controller.commit(
                    style.copyWith(
                      content: style.content.copyWith(
                        blocks: DiaryCardBlock.values,
                      ),
                    ),
                  ),
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 14),
            label: Text(l10n.diaryCardStyleOrderReset),
          ),
        ),
      ),
      itemCount: blocks.length,
      onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
      onReorderItem: _reorder,
      itemBuilder: (BuildContext context, int index) {
        final block = blocks[index];
        final label = diaryCardBlockLabel(l10n, block);
        return Padding(
          key: ValueKey<DiaryCardBlock>(block),
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: ExpressiveSurfaces.cardColor(scheme),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: ExpressiveSurfaces.cardBorderSide(scheme),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 4,
              ),
              leading: FaIcon(diaryCardBlockIcon(block), size: 16),
              title: Text(label),
              trailing: Semantics(
                label: l10n.diaryCardStyleDragHandle(label),
                child: ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox(
                    width: 44,
                    height: 40,
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: Center(child: TripleBarDragHandle()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _sameOrder(List<DiaryCardBlock> a, List<DiaryCardBlock> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
