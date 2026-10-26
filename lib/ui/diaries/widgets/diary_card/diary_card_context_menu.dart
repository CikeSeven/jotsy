import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../models/time_capsule.dart';

/// 日记卡片右键菜单的动作，由各列表页（日记页、搜索、归档）接到自己现有
/// 的流程上；为 null 的一项不显示。
///
/// 写入与撤销都走各页原有的路径（与多选栏、预览页同一批写库方法），这里只
/// 描述“有哪几项、点了交给谁”。
@immutable
class DiaryCardMenuActions {
  const DiaryCardMenuActions({
    this.onEdit,
    this.onTogglePin,
    this.onNotebooks,
    this.notebooksMovesDiary = false,
    this.onToggleArchive,
    this.onDelete,
  });

  /// 编辑这篇；未解封的时间胶囊不能编辑，菜单里不给这一项。
  final ValueChanged<DiaryWithTags>? onEdit;

  /// 置顶 / 取消置顶（按这篇当前是否置顶显示文字）。
  final ValueChanged<DiaryWithTags>? onTogglePin;

  /// 日记本：在普通日记本里是“移动到日记本…”（[notebooksMovesDiary] 为
  /// true），其他列表里是“收进日记本…”。日记本功能关闭时调用方传 null。
  final ValueChanged<DiaryWithTags>? onNotebooks;
  final bool notebooksMovesDiary;

  /// 归档 / 取消归档（按这篇当前是否已归档显示文字与图标）。
  final ValueChanged<DiaryWithTags>? onToggleArchive;

  /// 删除（确认与撤销由调用方的流程负责）。
  final ValueChanged<DiaryWithTags>? onDelete;
}

/// 桌面上日记卡片的右键菜单：右键（副键点按）在指针处打开，焦点在卡片上
/// 时菜单键或 Shift+F10 在卡片中央打开（焦点落在第一项）。
///
/// 输入：这篇日记、动作 [actions] 与是否可用 [enabled]（多选模式下不响应，
/// 右键不做特别处理）；输出：包住 [child] 的同一张卡片，没有其他副作用。
///
/// 只在桌面上由 `DiariesListSection` 包上；手机上卡片结构不变。菜单本身是
/// 共用的 [ExpressiveMenuAnchor]（[ExpressiveMenuAnchorState.openAt]），表面、
/// 定位夹取、动效、Esc / 方向键与焦点交还都与其他弹出菜单一致。
class DiaryCardContextMenu extends StatelessWidget {
  const DiaryCardContextMenu({
    super.key,
    required this.diary,
    required this.actions,
    required this.enabled,
    required this.child,
  });

  final DiaryWithTags diary;
  final DiaryCardMenuActions actions;
  final bool enabled;
  final Widget child;

  List<Widget> _items(BuildContext context) {
    final l10n = context.l10n;
    final entry = diary.diary;
    // 未解封的胶囊：与封存页一致，不能编辑；置顶、归档、收录与删除照常
    // （多选栏与左滑同样允许）。
    final locked = TimeCapsuleState.fromFields(
      lockedAt: entry.capsuleLockedAt,
      unlockAt: entry.capsuleUnlockAt,
      now: DateTime.now(),
    ).isLocked;
    final onEdit = actions.onEdit;
    final onTogglePin = actions.onTogglePin;
    final onNotebooks = actions.onNotebooks;
    final onToggleArchive = actions.onToggleArchive;
    final onDelete = actions.onDelete;
    return <Widget>[
      if (onEdit != null && !locked)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.pen),
          onPressed: () => onEdit(diary),
          child: Text(l10n.commonEdit),
        ),
      if (onTogglePin != null)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.thumbtack),
          onPressed: () => onTogglePin(diary),
          child: Text(
            entry.isPinned ? l10n.diaryUnpinSelected : l10n.diaryPinSelected,
          ),
        ),
      if (onNotebooks != null)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.bookBookmark),
          onPressed: () => onNotebooks(diary),
          child: Text(
            actions.notebooksMovesDiary
                ? l10n.diaryCardMenuMoveToNotebook
                : l10n.diaryCardMenuAddToNotebook,
          ),
        ),
      if (onToggleArchive != null)
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            entry.isArchived
                ? FontAwesomeIcons.boxOpen
                : FontAwesomeIcons.boxArchive,
          ),
          onPressed: () => onToggleArchive(diary),
          child: Text(entry.isArchived ? l10n.autoT0101 : l10n.autoT0140),
        ),
      if (onDelete != null)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: () => onDelete(diary),
          child: Text(l10n.commonDelete),
        ),
    ];
  }

  /// 键盘打开：位置取卡片中央（没有指针位置可用）。
  static void _openFromKeyboard(
    BuildContext context,
    ExpressiveMenuAnchorState menu,
  ) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    menu.openAt(
      box.localToGlobal(box.size.center(Offset.zero)),
      focusFirstItem: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpressiveMenuAnchor(
      menuChildren: _items(context),
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? card) {
            // 副键点按由这里接住：卡片的 InkWell 只认主键，两者不在手势竞技场
            // 里相争。菜单键 / Shift+F10 要求焦点在卡片里（Tab 移到卡片上）。
            // 不可用时只清空绑定与回调、结构不变：进出多选不会重建卡片子树
            // （选中反馈的动画才能完整播放）。
            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                if (enabled) ...<ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
                      _openFromKeyboard(context, menu),
                  const SingleActivator(
                    LogicalKeyboardKey.f10,
                    shift: true,
                  ): () =>
                      _openFromKeyboard(context, menu),
                },
              },
              child: GestureDetector(
                onSecondaryTapUp: enabled
                    ? (TapUpDetails details) =>
                          menu.openAt(details.globalPosition)
                    : null,
                child: card,
              ),
            );
          },
      child: child,
    );
  }
}
