// 对话页顶栏：`<` 返回、对话标题（点按改名）、历史（宽窗口历史栏常驻时
// 没有）、新对话（已是空白新对话时禁用）、⋮（重命名、置顶 / 取消置顶、
// 导出对话、删除；空白新对话时为 AI 设置）。宽窗口时顶栏铺满（左侧是历史栏），否则按阅读列居中。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../controllers/ai_chat_flows.dart';

class AiChatTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AiChatTopBar({
    super.key,
    required this.title,
    required this.conversation,
    required this.docked,
    required this.blank,
    required this.onHistory,
    required this.onNewChat,
    required this.onDelete,
    required this.onExport,
    required this.onSettings,
  });

  final String title;

  /// 当前对话；还没有发出第一句时为 null（没有改名、置顶、删除）。
  final AiConversationRow? conversation;

  /// 宽窗口：历史栏常驻，不放历史按钮。
  final bool docked;

  /// 已是空白新对话（新对话按钮禁用）。
  final bool blank;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final row = conversation;
    return AppTopBar(
      contentMaxWidth: docked ? null : AppContentWidth.reading,
      title: GestureDetector(
        onTap: row == null
            ? null
            : () => unawaited(renameAiConversation(context, ref, row)),
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      leading: IconButton(
        tooltip: l10n.commonBack,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      actions: <Widget>[
        if (!docked)
          IconButton(
            tooltip: l10n.aiChatHistory,
            onPressed: onHistory,
            icon: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16),
          ),
        IconButton(
          tooltip: l10n.aiChatNewChat,
          onPressed: blank ? null : onNewChat,
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
        ),
        ExpressiveMenuButton(
          tooltip: l10n.aiChatMore,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
          items: <Widget>[
            if (row != null) ...<Widget>[
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.pen),
                onPressed: () =>
                    unawaited(renameAiConversation(context, ref, row)),
                child: Text(l10n.aiChatRename),
              ),
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.thumbtack),
                onPressed: () => unawaited(
                  ref
                      .read(appDatabaseProvider)
                      .updateAiConversation(
                        row.conversationId,
                        pinned: !row.pinned,
                      ),
                ),
                child: Text(row.pinned ? l10n.aiChatUnpin : l10n.aiChatPin),
              ),
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.fileExport),
                onPressed: onExport,
                child: Text(l10n.aiChatExport),
              ),
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                destructive: true,
                onPressed: onDelete,
                child: Text(l10n.commonDelete),
              ),
            ] else
              // 空白新对话只有 AI 设置（对话里从历史抽屉底部进入）。
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.gear),
                onPressed: onSettings,
                child: Text(l10n.aiChatOpenSettings),
              ),
          ],
        ),
      ],
    );
  }
}
