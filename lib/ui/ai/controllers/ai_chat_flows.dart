// 对话的零散流程：改名、删除（带撤销）、删除一条消息、选范围、编辑问题。
// 面板与对话框只负责挑选，写库在这里。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../models/ai_chat_scope.dart';
import '../widgets/ai_dialogs.dart';

/// 范围胶囊上的文字。
String aiChatScopeLabel(AppLocalizations l10n, AiChatScope scope) {
  switch (scope.kind) {
    case AiChatScopeKind.auto:
      return l10n.aiChatScopeAuto;
    case AiChatScopeKind.recent:
      return l10n.aiChatScopeRecent(scope.days);
    case AiChatScopeKind.all:
      return l10n.aiChatScopeAll;
    case AiChatScopeKind.range:
      final format = DateFormat.yMMMd(l10n.localeName);
      return l10n.aiRecapPeriodRange(
        format.format(scope.start!),
        format.format(scope.end!),
      );
    case AiChatScopeKind.diary:
      final title = scope.diaryTitle?.trim() ?? '';
      return title.isEmpty ? l10n.aiChatScopeEntry : title;
  }
}

/// 选对话范围（只负责挑选）。固定一篇的范围只由“继续聊聊”给出，这里不能
/// 选，但当前是它时列在最前面、可以换掉。
Future<AiChatScope?> showAiChatScopeSheet(
  BuildContext context, {
  required AiChatScope current,
}) async {
  final picked = await showAppModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
      Widget tile(
        String title,
        Object value, {
        String? subtitle,
        bool selected = false,
      }) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: selected
            ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
            : null,
        onTap: () => Navigator.of(sheetContext).pop(value),
      );
      return SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.aiChatScopeTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (current.kind == AiChatScopeKind.diary)
              tile(aiChatScopeLabel(l10n, current), current, selected: true),
            tile(
              l10n.aiChatScopeAuto,
              const AiChatScope.auto(),
              subtitle: l10n.aiChatScopeAutoSubtitle,
              selected: current.kind == AiChatScopeKind.auto,
            ),
            for (final days in AiChatScope.recentChoices)
              tile(
                l10n.aiChatScopeRecent(days),
                AiChatScope.recent(days),
                selected:
                    current.kind == AiChatScopeKind.recent &&
                    current.days == days,
              ),
            tile(
              l10n.aiChatScopeAll,
              const AiChatScope.all(),
              selected: current.kind == AiChatScopeKind.all,
            ),
            tile(
              current.kind == AiChatScopeKind.range
                  ? aiChatScopeLabel(l10n, current)
                  : l10n.aiChatScopeRange,
              #range,
              selected: current.kind == AiChatScopeKind.range,
            ),
          ],
        ),
      );
    },
  );
  if (picked is AiChatScope) return picked;
  if (picked != #range || !context.mounted) return null;
  final now = DateTime.now();
  final range = await showDateRangePicker(
    context: context,
    helpText: context.l10n.aiChatRangeTitle,
    firstDate: DateTime(1970),
    lastDate: DateTime(now.year + 1, 12, 31),
    initialDateRange: current.kind == AiChatScopeKind.range
        ? DateTimeRange(start: current.start!, end: current.end!)
        : DateTimeRange(
            start: DateTime(now.year, now.month),
            end: DateTime(now.year, now.month, now.day),
          ),
  );
  return range == null ? null : AiChatScope.range(range.start, range.end);
}

/// 改名（空标题即“新对话”）。
Future<void> renameAiConversation(
  BuildContext context,
  WidgetRef ref,
  AiConversationRow row,
) async {
  final name = await _showTextDialog(
    context,
    title: context.l10n.aiChatRenameTitle,
    initial: row.title,
    maxLines: 1,
  );
  if (name == null) return;
  await ref
      .read(appDatabaseProvider)
      .updateAiConversation(row.conversationId, title: name.trim());
}

/// 编辑最后一个问题（只负责挑选），返回新的问题；取消或空白为 null。
Future<String?> showAiEditQuestionDialog(
  BuildContext context,
  String question,
) async {
  final text = await _showTextDialog(
    context,
    title: context.l10n.aiChatEditResend,
    initial: question,
    maxLines: 6,
  );
  return text == null || text.trim().isEmpty ? null : text.trim();
}

/// 删除整段对话：确认后删除，提示条带撤销。返回是否真的删了（对话页删的
/// 是正在看的这段时换成新对话）。
Future<bool> deleteAiConversation(
  BuildContext context,
  WidgetRef ref,
  AiConversationRow row,
) async {
  final l10n = context.l10n;
  final ok = await confirmAiAction(
    context,
    title: l10n.aiChatDeleteTitle,
    content: l10n.aiChatDeleteBody,
    action: l10n.commonDelete,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  final database = ref.read(appDatabaseProvider);
  final snapshot = await database.deleteAiConversation(row.conversationId);
  if (snapshot == null) return false;
  if (!context.mounted) return true;
  // 提示条在应用级的 ScaffoldMessenger 上，换页后仍在。
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        persist: false,
        content: Text(l10n.aiChatDeleted),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => unawaited(database.restoreAiConversation(snapshot)),
        ),
      ),
    ),
  );
  return true;
}

/// 删除一条消息（确认后）。
Future<void> deleteAiChatMessage(
  BuildContext context,
  WidgetRef ref,
  AiMessageRow row,
) async {
  final l10n = context.l10n;
  final ok = await confirmAiAction(
    context,
    title: l10n.aiChatDeleteMessageTitle,
    action: l10n.commonDelete,
    destructive: true,
  );
  if (!ok) return;
  await ref.read(appDatabaseProvider).deleteAiMessages([row.messageId]);
}

Future<String?> _showTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxLines,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _TextDialog(title: title, initial: initial, maxLines: maxLines),
  );
}

/// 一个输入框的对话框；输入框控制器随对话框的 State 释放（关闭动画期间
/// 仍在用）。
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.maxLines,
  });

  final String title;
  final String initial;
  final int maxLines;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final multiline = widget.maxLines > 1;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        contextMenuBuilder: appTextContextMenuBuilder,
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    );
  }
}
