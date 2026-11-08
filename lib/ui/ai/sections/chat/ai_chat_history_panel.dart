// 对话记录（DESIGN §5.29“历史抽屉”）：手机与中宽窗口是对话页的左侧抽屉，
// 宽窗口（≥ 1024）是常驻的左侧栏，内容相同。
//
// 自上而下：标题“对话记录”、胶囊搜索框（按标题与消息内容）、填充色调的
// “新对话”、“AI 回顾”入口（回顾开启时）；然后是分组列表——置顶 / 今天 /
// 昨天 / 最近 7 天 / 最近 30 天 / 按月份——每行标题与时间，当前对话
// `secondaryContainer` 16 圆角高亮并在行尾放 ⋮；任意一行长按或右键弹同一
// 菜单（重命名、置顶 / 取消置顶、导出对话、删除）。最底下一行“AI 设置”。
//
// 点一行由对话页在原地换到那段对话（不另开页面）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_menu/expressive_menu_anchor.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../../widgets/search_pill_field.dart';
import '../../controllers/ai_chat_flows.dart';
import '../../providers/ai_records_providers.dart';

/// 列表里对话的时间：今天写时分，今年写月日，更早写年月日。
String aiConversationTime(AppLocalizations l10n, DateTime time) {
  final now = DateTime.now();
  final locale = l10n.localeName;
  if (time.year != now.year) return DateFormat.yMMMd(locale).format(time);
  if (time.month == now.month && time.day == now.day) {
    return DateFormat.Hm(locale).format(time);
  }
  return DateFormat.MMMd(locale).format(time);
}

enum AiHistoryBucket { pinned, today, yesterday, week, month, older }

/// 一组对话：[month] 只在 [AiHistoryBucket.older] 时有（按月份分）。
class AiHistoryGroup {
  AiHistoryGroup(this.bucket, {this.month});

  final AiHistoryBucket bucket;
  final DateTime? month;
  final List<AiConversationRow> rows = <AiConversationRow>[];
}

/// 按最后活动时间分组（置顶的单独在最前；输入已按置顶、时间排好）。
List<AiHistoryGroup> aiHistoryGroups(
  List<AiConversationRow> rows,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final groups = <AiHistoryGroup>[];
  for (final row in rows) {
    final time = row.updatedAt;
    final day = DateTime(time.year, time.month, time.day);
    final age = today.difference(day).inDays;
    final bucket = row.pinned
        ? AiHistoryBucket.pinned
        : age <= 0
        ? AiHistoryBucket.today
        : age == 1
        ? AiHistoryBucket.yesterday
        : age < 7
        ? AiHistoryBucket.week
        : age < 30
        ? AiHistoryBucket.month
        : AiHistoryBucket.older;
    final month = bucket == AiHistoryBucket.older
        ? DateTime(time.year, time.month)
        : null;
    final last = groups.lastOrNull;
    if (last != null && last.bucket == bucket && last.month == month) {
      last.rows.add(row);
    } else {
      groups.add(AiHistoryGroup(bucket, month: month)..rows.add(row));
    }
  }
  return groups;
}

class AiChatHistoryPanel extends ConsumerStatefulWidget {
  const AiChatHistoryPanel({
    super.key,
    required this.currentId,
    required this.onSelect,
    required this.onNewChat,
    required this.onSettings,
    required this.onDeleted,
    required this.onExport,
    this.onRecaps,
  });

  final String? currentId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  /// 删掉了一段对话（删的是当前这段时，对话页换成新对话）。
  final ValueChanged<String> onDeleted;

  /// 导出某段对话。
  final ValueChanged<String> onExport;

  /// 打开回顾页；回顾模块关闭时为 null。
  final VoidCallback? onRecaps;

  @override
  ConsumerState<AiChatHistoryPanel> createState() => _AiChatHistoryPanelState();
}

class _AiChatHistoryPanelState extends ConsumerState<AiChatHistoryPanel> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _groupLabel(AppLocalizations l10n, AiHistoryGroup group) =>
      switch (group.bucket) {
        AiHistoryBucket.pinned => l10n.aiChatGroupPinned,
        AiHistoryBucket.today => l10n.aiChatGroupToday,
        AiHistoryBucket.yesterday => l10n.aiChatGroupYesterday,
        AiHistoryBucket.week => l10n.aiChatGroupWeek,
        AiHistoryBucket.month => l10n.aiChatGroupMonth,
        AiHistoryBucket.older => DateFormat.yMMM(
          l10n.localeName,
        ).format(group.month!),
      };

  Future<void> _delete(AiConversationRow row) async {
    final deleted = await deleteAiConversation(context, ref, row);
    if (deleted) widget.onDeleted(row.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = ref.watch(aiConversationsProvider(_query)).value;
    final groups = rows == null
        ? const <AiHistoryGroup>[]
        : aiHistoryGroups(rows, DateTime.now());
    final isLight = theme.brightness == Brightness.light;
    return SafeArea(
      right: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Text(
              l10n.aiChatHistory,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchPillField(
              controller: _search,
              focusNode: _searchFocus,
              hintText: l10n.aiHubSearchChats,
              onChanged: (value) => setState(() => _query = value.trim()),
              onClear: () => setState(() => _query = ''),
              fill: isLight
                  ? ExpressiveSurfaces.cardColor(colors)
                  : colors.surfaceContainerHigh,
              idleOutline: ExpressiveSurfaces.cardBorderColor(colors),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilledButton.tonalIcon(
              style: AppGlassField.tonalButtonStyle(context),
              onPressed: widget.onNewChat,
              icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14),
              label: Text(l10n.aiChatNewChat),
            ),
          ),
          if (widget.onRecaps case final onRecaps?)
            _PanelLink(
              icon: FontAwesomeIcons.wandMagicSparkles,
              label: l10n.aiRecapTitle,
              onTap: onRecaps,
            ),
          const SizedBox(height: 4),
          Expanded(
            child: rows == null
                ? const SizedBox.shrink()
                : rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? l10n.aiChatHistoryEmpty
                          : l10n.aiChatHistoryNoMatch,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    children: <Widget>[
                      for (final group in groups) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Text(
                            _groupLabel(l10n, group),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final row in group.rows)
                          _HistoryRow(
                            key: ValueKey<String>(row.conversationId),
                            row: row,
                            selected: row.conversationId == widget.currentId,
                            onTap: () => widget.onSelect(row.conversationId),
                            onRename: () => unawaited(
                              renameAiConversation(context, ref, row),
                            ),
                            onPin: () => unawaited(
                              ref
                                  .read(appDatabaseProvider)
                                  .updateAiConversation(
                                    row.conversationId,
                                    pinned: !row.pinned,
                                  ),
                            ),
                            onExport: () => widget.onExport(row.conversationId),
                            onDelete: () => unawaited(_delete(row)),
                          ),
                      ],
                    ],
                  ),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          _PanelLink(
            icon: FontAwesomeIcons.gear,
            label: l10n.aiChatOpenSettings,
            onTap: widget.onSettings,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PanelLink extends StatelessWidget {
  const _PanelLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 20,
                child: FaIcon(icon, size: 15, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onPin,
    required this.onExport,
    required this.onDelete,
  });

  final AiConversationRow row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onPin;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.pen),
          onPressed: onRename,
          child: Text(l10n.aiChatRename),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.thumbtack),
          onPressed: onPin,
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
      ],
      builder: (context, menu, _) => GestureDetector(
        onLongPressStart: (details) => menu.openAt(details.globalPosition),
        onSecondaryTapDown: (details) => menu.openAt(details.globalPosition),
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, selected ? 0 : 12, 10),
              child: Row(
                children: <Widget>[
                  if (row.pinned) ...<Widget>[
                    FaIcon(
                      FontAwesomeIcons.thumbtack,
                      size: 11,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      row.title.trim().isEmpty
                          ? l10n.aiChatUntitled
                          : row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
                        color: selected ? colors.onSecondaryContainer : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    aiConversationTime(l10n, row.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colors.onSecondaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  if (selected)
                    IconButton(
                      tooltip: l10n.aiChatMore,
                      visualDensity: VisualDensity.compact,
                      onPressed: menu.open,
                      icon: FaIcon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 14,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
