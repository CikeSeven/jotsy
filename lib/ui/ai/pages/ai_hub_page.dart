// AI 助手主页：问问你的日记（提问框与快捷问题）、回顾（本周 / 本月 / 今年
// 直接生成，更多范围进回顾页，下面是最近的回顾）与对话历史（置顶在前，
// 可搜索、改名、置顶、删除并撤销）。
//
// 入口：日记 Tab 顶栏、探索页 AI 卡片、AI 设置页。对话与回顾两个模块各自
// 关闭时对应的区块不出现（两个都关时入口本身就不出现）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/ai_chat_flows.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_recap_range.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../viewmodels/ai_labels.dart';
import '../widgets/ai_page_scaffold.dart';
import 'ai_chat_page.dart';
import 'ai_recap_page.dart';
import 'settings/ai_settings_page.dart';

class AiHubPage extends ConsumerStatefulWidget {
  const AiHubPage({super.key});

  @override
  ConsumerState<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends ConsumerState<AiHubPage> {
  final TextEditingController _ask = TextEditingController();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ask.dispose();
    _search.dispose();
    super.dispose();
  }

  void _push(Widget page) => unawaited(
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page)),
  );

  void _askQuestion([String? question]) {
    final text = (question ?? _ask.text).trim();
    if (text.isEmpty) return;
    if (question == null) _ask.clear();
    _push(AiChatPage(initialQuestion: text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chatOn = ref.watch(aiModuleAvailableProvider(AiModule.chat));
    final recapOn = ref.watch(aiModuleAvailableProvider(AiModule.recap));
    final recaps = recapOn
        ? ref.watch(aiRecapsProvider).value ?? const <AiResultRow>[]
        : const <AiResultRow>[];
    final chats = chatOn
        ? ref.watch(aiConversationsProvider(_query)).value
        : const <AiConversationRow>[];
    final quick = <String>[
      l10n.aiHubQuickMonth,
      l10n.aiHubQuickWorry,
      l10n.aiHubQuickLastYear,
      l10n.aiHubQuickHappy,
      l10n.aiHubQuickGrowth,
      l10n.aiHubQuickHelp,
    ];
    final glass = AppGlassField.of(context);
    return AiPageScaffold(
      title: l10n.aiHubTitle,
      area: AppBackgroundArea.other,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.aiHubOpenSettings,
          onPressed: () => _push(const AiSettingsPage()),
          icon: const FaIcon(FontAwesomeIcons.gear, size: 16),
        ),
      ],
      children: <Widget>[
        if (chatOn) ...<Widget>[
          AppCardSurface(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _ask,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l10n.aiHubAskHint,
                          filled: true,
                          fillColor: glass?.fill ?? colors.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: glass?.border ?? BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: glass?.border ?? BorderSide.none,
                          ),
                        ),
                        contextMenuBuilder: appTextContextMenuBuilder,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: l10n.aiHubSend,
                      onPressed: _askQuestion,
                      icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final question in quick)
                      ActionChip(
                        label: Text(question),
                        onPressed: () => _askQuestion(question),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (recapOn) ...<Widget>[
          SettingsCardGroup(
            title: l10n.aiHubRecapsGroup,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final preset in const <AiRecapPreset>[
                      AiRecapPreset.thisWeek,
                      AiRecapPreset.thisMonth,
                      AiRecapPreset.thisYear,
                    ])
                      ActionChip(
                        avatar: FaIcon(
                          FontAwesomeIcons.wandMagicSparkles,
                          size: 12,
                          color: colors.primary,
                        ),
                        label: Text(aiRecapPresetLabel(l10n, preset)),
                        onPressed: () => _push(
                          AiRecapPage(initialPreset: preset, autoStart: true),
                        ),
                      ),
                    ActionChip(
                      label: Text(l10n.aiHubRecapMore),
                      onPressed: () => _push(const AiRecapPage()),
                    ),
                  ],
                ),
              ),
              if (recaps.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    l10n.aiHubNoRecaps,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final row in recaps.take(3)) AiRecapTile(row: row),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (chatOn)
          SettingsCardGroup(
            title: l10n.aiHubChatsGroup,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (String value) =>
                      setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.aiHubSearchChats,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    filled: true,
                    fillColor: glass?.fill ?? colors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: glass?.border ?? BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: glass?.border ?? BorderSide.none,
                    ),
                  ),
                  contextMenuBuilder: appTextContextMenuBuilder,
                ),
              ),
              if (chats != null && chats.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text(
                    l10n.aiHubNoChats,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final row in chats ?? const <AiConversationRow>[])
                  _ChatTile(
                    key: ValueKey<String>(row.conversationId),
                    row: row,
                    onOpen: () =>
                        _push(AiChatPage(conversationId: row.conversationId)),
                  ),
            ],
          ),
      ],
    );
  }
}

/// 一段历史对话：标题、最后活动时间、置顶标记与菜单（改名、置顶、删除）。
class _ChatTile extends ConsumerWidget {
  const _ChatTile({super.key, required this.row, required this.onOpen});

  final AiConversationRow row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final time = row.updatedAt;
    final when = time.year == now.year
        ? (time.month == now.month && time.day == now.day
              ? DateFormat.Hm(l10n.localeName).format(time)
              : DateFormat.MMMd(l10n.localeName).format(time))
        : DateFormat.yMMMd(l10n.localeName).format(time);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      onTap: onOpen,
      leading: FaIcon(
        row.pinned ? FontAwesomeIcons.thumbtack : FontAwesomeIcons.comments,
        size: 16,
        color: colors.primary,
      ),
      title: Text(
        row.title.trim().isEmpty ? l10n.aiChatUntitled : row.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(when),
      trailing: ExpressiveMenuButton(
        tooltip: l10n.aiChatMore,
        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14),
        items: <Widget>[
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.pen),
            onPressed: () => unawaited(renameAiConversation(context, ref, row)),
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
            leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
            destructive: true,
            onPressed: () => unawaited(deleteAiConversation(context, ref, row)),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
