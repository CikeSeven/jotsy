// 导出对话（对话页顶栏 ⋮ 与历史抽屉里一段对话的菜单进入）。只负责装配：
// 选项与勾选在本页，写出内容见 `ai_chat_export.dart`，去处见
// `ai_chat_export_flow.dart`。
//
// - 顶部选项卡片：格式（Markdown / 纯文本，`ExpressiveButtonGroup`）与包含
//   （思考过程、过程与操作，`FilterChip`）；选项本次运行内记住。
// - “选择消息 · 已选 N / 共 M 条”+ 全选开关；每条一行卡片：勾选框、头像
//   （问题为 `primaryContainer` 底的“你”，回答为人设 emoji）、署名与时间、
//   两行预览；点整行切换。默认全选。
// - 底栏：复制、分享（有系统文件分享时）、保存到文件；一条都没选时停用。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/form_width.dart';
import '../../widgets/select_all_button.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/ai_chat_export_flow.dart';
import '../models/ai_agent_steps.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../providers/ai_chat_export_provider.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../viewmodels/ai_chat_export.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_labels.dart';

class AiChatExportPage extends ConsumerStatefulWidget {
  const AiChatExportPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<AiChatExportPage> createState() => _AiChatExportPageState();
}

class _AiChatExportPageState extends ConsumerState<AiChatExportPage> {
  /// 选中的消息；消息第一次读出来时全选。
  Set<String>? _selected;

  ({String title, String fileName, String text, AiChatExportFormat format})?
  _compose(List<AiMessageRow> messages) {
    final selected = _selected ?? const <String>{};
    final picked = [
      for (final message in messages)
        if (selected.contains(message.messageId)) message,
    ];
    if (picked.isEmpty) return null;
    final l10n = context.l10n;
    final conversation = ref
        .read(aiConversationProvider(widget.conversationId))
        .value;
    final title = (conversation?.title.trim().isNotEmpty ?? false)
        ? conversation!.title.trim()
        : l10n.aiChatUntitled;
    final persona = aiPersonaById(
      l10n,
      ref.read(aiPreferencesProvider),
      conversation?.personaId,
      use: AiPersonaUse.chat,
    );
    final options = ref.read(aiChatExportOptionsProvider);
    final now = DateTime.now();
    return (
      title: title,
      fileName: aiChatExportFileName(title, now, options.format),
      text: aiChatExportText(
        l10n: l10n,
        title: title,
        messages: picked,
        assistantName: persona.name,
        options: options,
        now: now,
      ),
      format: options.format,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final messages = ref.watch(aiMessagesProvider(widget.conversationId)).value;
    if (messages != null && _selected == null) {
      _selected = {for (final message in messages) message.messageId};
    }
    final selected = _selected ?? const <String>{};
    final options = ref.watch(aiChatExportOptionsProvider);
    final conversation = ref
        .watch(aiConversationProvider(widget.conversationId))
        .value;
    final persona = aiPersonaById(
      l10n,
      ref.watch(aiPreferencesProvider),
      conversation?.personaId,
      use: AiPersonaUse.chat,
    );
    final all = messages ?? const <AiMessageRow>[];
    final allSelected = all.isNotEmpty && selected.length == all.length;
    final ready = all.any((m) => selected.contains(m.messageId));
    void update(AiChatExportOptions value) =>
        ref.read(aiChatExportOptionsProvider.notifier).update(value);
    final section = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.aiChatExport),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: WidthLayoutBuilder(
            builder: (context, width) {
              final side = FormWidth.gutter(width);
              if (messages == null) return const SizedBox.shrink();
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(side, 8, side, 24),
                itemCount: all.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return AppCardSurface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(l10n.aiChatExportFormat, style: section),
                          const SizedBox(height: 10),
                          ExpressiveButtonGroup<AiChatExportFormat>(
                            minSegmentWidth: 96,
                            segments: <ButtonSegment<AiChatExportFormat>>[
                              ButtonSegment<AiChatExportFormat>(
                                value: AiChatExportFormat.markdown,
                                label: Text(l10n.aiChatExportMarkdown),
                              ),
                              ButtonSegment<AiChatExportFormat>(
                                value: AiChatExportFormat.text,
                                label: Text(l10n.aiChatExportPlain),
                              ),
                            ],
                            selected: <AiChatExportFormat>{options.format},
                            onSelectionChanged: (picked) =>
                                update(options.copyWith(format: picked.single)),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.aiChatExportInclude, style: section),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilterChip(
                                label: Text(l10n.aiChatExportReasoning),
                                selected: options.reasoning,
                                onSelected: (value) =>
                                    update(options.copyWith(reasoning: value)),
                              ),
                              FilterChip(
                                label: Text(l10n.aiChatExportSteps),
                                selected: options.steps,
                                onSelected: (value) =>
                                    update(options.copyWith(steps: value)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 0, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l10n.aiChatExportMessages,
                              style: section,
                            ),
                          ),
                          Text(
                            l10n.aiChatExportSelected(
                              selected.length,
                              all.length,
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          SelectAllButton(
                            allSelected: allSelected,
                            onPressed: all.isEmpty
                                ? null
                                : () => setState(
                                    () => _selected = allSelected
                                        ? <String>{}
                                        : {for (final m in all) m.messageId},
                                  ),
                          ),
                        ],
                      ),
                    );
                  }
                  final message = all[index - 2];
                  final checked = selected.contains(message.messageId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MessageRow(
                      key: ValueKey<String>(message.messageId),
                      message: message,
                      persona: persona,
                      checked: checked,
                      onChanged: () => setState(() {
                        final next = {...selected};
                        if (!next.remove(message.messageId)) {
                          next.add(message.messageId);
                        }
                        _selected = next;
                      }),
                    ),
                  );
                },
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: FormWidthBar(
              sideInset: 16,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: AppGlassField.tonalButtonStyle(context),
                        onPressed: ready
                            ? () {
                                final out = _compose(all);
                                if (out != null) {
                                  unawaited(
                                    copyAiChatExport(context, out.text),
                                  );
                                }
                              }
                            : null,
                        icon: const FaIcon(FontAwesomeIcons.copy, size: 14),
                        label: Text(l10n.aiPanelCopy),
                      ),
                    ),
                    if (AppPlatform.supportsSystemFileShare) ...<Widget>[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: AppGlassField.tonalButtonStyle(context),
                          onPressed: ready
                              ? () {
                                  final out = _compose(all);
                                  if (out == null) return;
                                  unawaited(
                                    shareAiChatExport(
                                      context,
                                      text: out.text,
                                      fileName: out.fileName,
                                      format: out.format,
                                    ),
                                  );
                                }
                              : null,
                          icon: const FaIcon(
                            FontAwesomeIcons.shareNodes,
                            size: 14,
                          ),
                          label: Text(l10n.commonShare),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: ready
                            ? () {
                                final out = _compose(all);
                                if (out == null) return;
                                unawaited(
                                  saveAiChatExport(
                                    context,
                                    text: out.text,
                                    fileName: out.fileName,
                                    format: out.format,
                                  ),
                                );
                              }
                            : null,
                        icon: const FaIcon(
                          FontAwesomeIcons.fileArrowDown,
                          size: 14,
                        ),
                        label: Text(l10n.aiChatExportSave),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 选择列表里的一条消息。
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.message,
    required this.persona,
    required this.checked,
    required this.onChanged,
  });

  final AiMessageRow message;
  final AiPersonaInfo persona;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = message.role == AiMessageRole.user;
    final time = DateFormat.MMMd(
      l10n.localeName,
    ).add_Hm().format(message.createdAt);
    final preview = _preview(l10n);
    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(value: checked, onChanged: (_) => onChanged()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: user
                        ? colors.primaryContainer
                        : colors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 28,
                    child: Center(
                      child: user
                          ? Text(
                              l10n.aiChatExportYou,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              persona.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${user ? l10n.aiChatExportYou : persona.name} · $time',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: checked ? null : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 两行预览：正文（去掉引用编号、折成一行）；没有正文时写出错原因、
  /// 调用个数或“已停止”。
  String _preview(AppLocalizations l10n) {
    final text = aiStripCitations(
      message.content,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) return text;
    if (aiMessageError(message) case final error?) {
      return aiErrorMessage(l10n, error);
    }
    final calls = AiAgentStepRecord.decodeList(
      message.steps,
    ).fold<int>(0, (sum, step) => sum + step.calls.length);
    return calls > 0 ? l10n.aiProcessTools(calls) : l10n.aiChatStoppedLabel;
  }
}
