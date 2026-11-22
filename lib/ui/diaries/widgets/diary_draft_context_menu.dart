import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_menu/expressive_menu.dart';

/// 桌面上草稿行的右键菜单：继续写、删除（2 项单行动作，经
/// [ExpressiveMenuAnchorState.openAt] 在指针处打开）。
///
/// 只在桌面由草稿箱页包上；手机上同样的操作走点按续写与左滑删除。删除的
/// 撤销与收起由页面负责，这里只描述“有哪几项、点了交给谁”。
///
/// [enabled] 为 false（多选模式）时右键不响应，结构保持不变：进出多选不会
/// 重建行卡片，勾选框的展开动画才能完整播放。
class DiaryDraftContextMenu extends StatelessWidget {
  const DiaryDraftContextMenu({
    super.key,
    required this.enabled,
    required this.onContinue,
    required this.onDelete,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onContinue;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.pen),
          onPressed: onContinue,
          child: Text(l10n.diaryDraftContinue),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: onDelete,
          child: Text(l10n.commonDelete),
        ),
      ],
      // 副键点按由这里接住：行卡片的 InkWell 只认主键，两者不在手势竞技场
      // 里相争。
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? row) =>
              GestureDetector(
                onSecondaryTapUp: enabled
                    ? (TapUpDetails details) =>
                          menu.openAt(details.globalPosition)
                    : null,
                child: row,
              ),
      child: child,
    );
  }
}
