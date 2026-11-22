import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/form_width.dart';
import '../../widgets/select_all_button.dart';

/// 草稿箱页的顶栏：平时是返回键 + “草稿箱”，多选时换成 ✕ + “已选择 N 项”
/// + 全选与删除；进出多选时两组按钮缩放淡入切换，标题淡入淡出。
///
/// 桌面上平时在动作区常驻“多选”按钮（[onEnterSelection]）：鼠标很少长按，
/// 没有它就找不到批量删除（#350）；手机上那里留空，多选仍由长按进入。
///
/// 只负责展示，选择状态与删除流程都在页面里；为 null 的回调表示对应按钮
/// 停用（如正在提交、没有可选的草稿、一份都没勾）。
class DiaryDraftsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DiaryDraftsTopBar({
    super.key,
    required this.selectionMode,
    required this.selectedCount,
    required this.allSelected,
    required this.onCancelSelection,
    required this.onEnterSelection,
    required this.onToggleSelectAll,
    required this.onDelete,
  });

  final bool selectionMode;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onCancelSelection;
  final VoidCallback? onEnterSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDelete;

  /// 与下面实际构建的 [AppTopBar] 同高（都不传 toolbarHeight / bottom）。
  @override
  Size get preferredSize => const AppTopBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onDelete = this.onDelete;
    return AppTopBar(
      contentMaxWidth: FormWidth.maxWidth,
      leading: ExpressiveIconSwap(
        switchKey: selectionMode,
        child: selectionMode
            ? IconButton(
                tooltip: l10n.commonCancel,
                onPressed: onCancelSelection,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              )
            : IconButton(
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
      ),
      title: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        child: Text(
          selectionMode
              ? l10n.autoT0099(selectedCount.toString())
              : l10n.diaryDraftsTitle,
          key: ValueKey<int>(selectionMode ? selectedCount : -1),
        ),
      ),
      actions: <Widget>[
        ExpressiveIconSwap(
          switchKey: selectionMode,
          child: selectionMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SelectAllButton(
                      allSelected: allSelected,
                      onPressed: onToggleSelectAll,
                    ),
                    // 停用时图标随按钮变灰，而不是一直显示错误色。
                    IconButton(
                      tooltip: l10n.commonDelete,
                      onPressed: onDelete,
                      icon: FaIcon(
                        FontAwesomeIcons.trashCan,
                        size: 16,
                        color: onDelete == null
                            ? null
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                )
              : AppPlatform.isDesktop
              ? IconButton(
                  tooltip: l10n.diaryDraftsSelect,
                  onPressed: onEnterSelection,
                  icon: const FaIcon(FontAwesomeIcons.listCheck, size: 16),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
