// 与日记对话：顶部三个胶囊（范围、人设、模型）、消息列表、底部输入栏。
//
// 消息来自数据库（`aiMessagesProvider`），正在生成的这一轮由
// [AiChatController] 单独画在末尾（检索中的状态行、流式文字与引用胶囊），
// 生成结束落库后由列表接手。宽度取阅读列（`AppContentWidth.reading`），
// 消息列表铺满、留白在两侧。桌面上 Enter 发送、Shift + Enter 换行。
//
// 入口：AI 助手主页（提问、快捷问题、历史对话）与预览页回应卡片的“继续
// 聊聊”（[seedReply]：以那篇日记为固定范围，把那条回应作为对话的开头）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../diaries/controllers/diary_link_open_flow.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/ai_chat_flows.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../controllers/ai_stream_run.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_chat_scope.dart';
import '../models/ai_preference_parts.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../sections/ai_chat_message_view.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_task_prompts.dart';
import '../widgets/ai_tap_outside_unfocus.dart';
import 'settings/ai_model_routing_page.dart';
import 'settings/ai_personas_page.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({
    super.key,
    this.conversationId,
    this.scope = const AiChatScope.auto(),
    this.initialQuestion,
    this.seedReply,
  });

  final String? conversationId;
  final AiChatScope scope;

  /// 打开后立即发出的问题（主页的提问框与快捷问题）。
  final String? initialQuestion;

  /// “继续聊聊”：那条回应（`ai_results` 行），对话以它开头。
  final AiResultRow? seedReply;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  late final AiChatController _controller;
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  /// 对话行读出来之前（打开已有对话时）不让发送，免得用默认范围发出去。
  bool _ready = true;

  @override
  void initState() {
    super.initState();
    _controller = AiChatController(
      database: ref.read(appDatabaseProvider),
      conversationId: widget.conversationId,
      scope: widget.scope,
      personaId: ref.read(aiPreferencesProvider).personaFor[AiPersonaUse.chat],
    );
    _controller.addListener(_onControllerChanged);
    _controller.run.addListener(_followBottom);
    if (widget.conversationId != null) {
      _ready = false;
      unawaited(_loadConversation(widget.conversationId!));
    } else if (widget.seedReply != null) {
      _ready = false;
      // 要用到本地化文案（对话标题），等第一帧之后再建。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_seed(widget.seedReply!));
      });
    } else if (widget.initialQuestion case final question?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_send(question));
      });
    }
  }

  Future<void> _loadConversation(String id) async {
    final row = await ref.read(appDatabaseProvider).getAiConversation(id);
    if (!mounted) return;
    if (row != null) {
      _controller
        ..scope = AiChatScope.decode(row.scope)
        ..personaId = row.personaId;
    }
    setState(() => _ready = true);
    _jumpToBottom();
  }

  /// “继续聊聊”：新建一段固定在那篇日记上的对话，把回应作为第一条回答。
  Future<void> _seed(AiResultRow reply) async {
    final l10n = context.l10n;
    final database = ref.read(appDatabaseProvider);
    final diaryId = reply.diaryId;
    if (diaryId == null) {
      setState(() => _ready = true);
      return;
    }
    final diary = await database.getAiDiary(diaryId);
    final title = (diary?.title.trim().isNotEmpty ?? false)
        ? diary!.title.trim()
        : (diary == null
              ? ''
              : DateFormat.yMMMd(l10n.localeName).format(diary.createdAt));
    final scope = AiChatScope.diary(diaryId: diaryId, diaryTitle: title);
    final id = await database.createAiConversation(
      title: title.isEmpty ? '' : l10n.aiChatAboutEntry(title),
      personaId: reply.personaId,
      scopeJson: scope.encode(),
    );
    await database.addAiMessage(
      conversationId: id,
      role: AiMessageRole.assistant,
      content: reply.content,
      metaJson: reply.meta,
    );
    if (!mounted) return;
    _controller
      ..conversationId = id
      ..scope = scope
      ..personaId = reply.personaId;
    setState(() => _ready = true);
    _inputFocus.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.run.removeListener(_followBottom);
    _controller.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    _followBottom();
  }

  /// 生成中贴着底部的话跟到底；用户往上翻了就不打扰。
  void _followBottom() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 160) return;
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send([String? question]) async {
    final text = (question ?? _input.text).trim();
    if (text.isEmpty || _controller.busy || !_ready) return;
    if (question == null) _input.clear();
    _jumpToBottom();
    await _controller.send(context, ref, text);
  }

  void _openCitation(List<AiCitation> citations, String ref) {
    for (final citation in citations) {
      if (citation.ref == ref) {
        unawaited(
          openDiaryLinkTarget(
            context,
            this.ref,
            DiaryLinkTarget.diary(citation.diaryId),
          ),
        );
        return;
      }
    }
  }

  Future<void> _pickScope() async {
    final picked = await showAiChatScopeSheet(
      context,
      current: _controller.scope,
    );
    if (!mounted || picked == null) return;
    await _controller.updateScope(picked);
  }

  Future<void> _pickPersona() async {
    final l10n = context.l10n;
    final prefs = ref.read(aiPreferencesProvider);
    final picked = await showAiPersonaPicker(
      context,
      personas: aiPersonas(l10n, prefs),
      selectedId: aiPersonaById(
        l10n,
        prefs,
        _controller.personaId,
        use: AiPersonaUse.chat,
      ).id,
      title: l10n.aiChatPersona,
    );
    if (!mounted || picked == null) return;
    await _controller.updatePersona(picked);
  }

  Future<void> _pickModel() async {
    final l10n = context.l10n;
    final config = ref.read(aiLocalConfigProvider);
    final fallback = config.resolveTask(AiTaskKind.chat);
    final picked = await showAiModelChoiceSheet(
      context,
      title: l10n.aiChatModel,
      models: config.usableModels,
      current: config.resolveRef(_controller.modelRef)?.ref,
      followLabel: l10n.aiChatModelDefault(
        fallback == null ? '—' : aiModelDisplay(fallback),
      ),
    );
    if (!mounted || picked == null) return;
    _controller.updateModel(picked.ref);
  }

  Future<void> _editLast(String question) async {
    final edited = await showAiEditQuestionDialog(context, question);
    if (!mounted || edited == null) return;
    _input.clear();
    await _controller.editLast(context, ref, edited);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final id = _controller.conversationId;
    final conversation = id == null
        ? null
        : ref.watch(aiConversationProvider(id)).value;
    final messages = id == null
        ? const <AiMessageRow>[]
        : ref.watch(aiMessagesProvider(id)).value ?? const <AiMessageRow>[];
    final prefs = ref.watch(aiPreferencesProvider);
    final config = ref.watch(aiLocalConfigProvider);
    final persona = aiPersonaById(
      l10n,
      prefs,
      _controller.personaId,
      use: AiPersonaUse.chat,
    );
    final model =
        config.resolveRef(_controller.modelRef) ??
        config.resolveTask(AiTaskKind.chat);
    final title = conversation?.title.trim().isNotEmpty ?? false
        ? conversation!.title
        : l10n.aiChatUntitled;
    final lastUser = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.user,
    );
    final lastAssistant = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.assistant,
    );
    final busy = _controller.busy;
    return AppPageBackground(
      area: AppBackgroundArea.other,
      // 点输入框以外的地方收起键盘（发送 / 停止按钮算作输入框的一部分）。
      child: Builder(
        builder: (BuildContext context) => AiTapOutsideUnfocus(
          child: Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: AppContentWidth.reading,
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
              actions: <Widget>[
                if (conversation != null)
                  ExpressiveMenuButton(
                    tooltip: l10n.aiChatMore,
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 16,
                    ),
                    items: <Widget>[
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.pen),
                        onPressed: () => unawaited(
                          renameAiConversation(context, ref, conversation),
                        ),
                        child: Text(l10n.aiChatRename),
                      ),
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.thumbtack),
                        onPressed: () => unawaited(
                          ref
                              .read(appDatabaseProvider)
                              .updateAiConversation(
                                conversation.conversationId,
                                pinned: !conversation.pinned,
                              ),
                        ),
                        child: Text(
                          conversation.pinned
                              ? l10n.aiChatUnpin
                              : l10n.aiChatPin,
                        ),
                      ),
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                        destructive: true,
                        onPressed: () {
                          _controller.stop();
                          unawaited(
                            deleteAiConversation(
                              context,
                              ref,
                              conversation,
                              popPage: true,
                            ),
                          );
                        },
                        child: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
              ],
            ),
            body: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final side = AppContentWidth.gutter(
                  constraints.maxWidth,
                  AppContentWidth.reading,
                );
                return Column(
                  children: <Widget>[
                    DesktopHorizontalScroll(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(side, 4, side, 8),
                        child: Row(
                          children: <Widget>[
                            _ChipButton(
                              icon: FontAwesomeIcons.magnifyingGlass,
                              label: aiChatScopeLabel(l10n, _controller.scope),
                              onPressed: busy ? null : _pickScope,
                            ),
                            const SizedBox(width: 8),
                            _ChipButton(
                              emoji: persona.emoji,
                              label: persona.name,
                              onPressed: busy ? null : _pickPersona,
                            ),
                            const SizedBox(width: 8),
                            _ChipButton(
                              icon: FontAwesomeIcons.microchip,
                              label: model == null
                                  ? l10n.aiChatModel
                                  : model.model.label,
                              onPressed: busy ? null : _pickModel,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(side, 8, side, 24),
                        children: <Widget>[
                          if (messages.isEmpty && !busy)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                children: <Widget>[
                                  FaIcon(
                                    FontAwesomeIcons.comments,
                                    size: 32,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.aiChatEmptyHint,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (var i = 0; i < messages.length; i++)
                            AiChatMessageView(
                              key: ValueKey<String>(messages[i].messageId),
                              message: messages[i],
                              showReasoning: prefs.showReasoning,
                              showTokens: prefs.showTokens,
                              onCitation: (citations, ref) =>
                                  _openCitation(citations, ref),
                              onEdit: !busy && i == lastUser
                                  ? () => unawaited(
                                      _editLast(messages[i].content),
                                    )
                                  : null,
                              onRegenerate:
                                  !busy && i == lastAssistant && i > lastUser
                                  ? () => unawaited(
                                      _controller.regenerate(context, ref),
                                    )
                                  : null,
                              onCopy: (text) =>
                                  unawaited(copyAiText(context, text)),
                              onSaveAsDiary: (text) => unawaited(
                                saveAiTextAsDiary(
                                  context,
                                  ref,
                                  title: title,
                                  markdown: text,
                                ),
                              ),
                              onDelete: busy
                                  ? null
                                  : () => unawaited(
                                      deleteAiChatMessage(
                                        context,
                                        ref,
                                        messages[i],
                                      ),
                                    ),
                            ),
                          // 每收到一块只重建正在生成的这一条，不动整个列表。
                          if (busy)
                            ListenableBuilder(
                              listenable: _controller.run,
                              builder: (BuildContext context, Widget? _) =>
                                  _buildPending(context),
                            ),
                        ],
                      ),
                    ),
                    _ChatInput(
                      controller: _input,
                      focusNode: _inputFocus,
                      side: side,
                      busy: busy,
                      enabled: _ready,
                      onSend: () => unawaited(_send()),
                      onStop: _controller.stop,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 正在进行的这一轮：检索中的状态行，或流式的回答。
  Widget _buildPending(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final run = _controller.run;
    final status = switch (_controller.phase) {
      AiChatPhase.planning => l10n.aiChatPlanning,
      AiChatPhase.searching => l10n.aiChatSearching,
      AiChatPhase.answering when !run.hasText => l10n.aiPanelThinking,
      _ => null,
    };
    final citations = _controller.pendingCitations;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (status != null)
            Row(
              children: <Widget>[
                const ExpressiveLoadingIndicator(size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    status,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          if (run.hasText || run.reasoning.isNotEmpty)
            AiChatAnswerBody(
              text: run.text,
              reasoning: ref.watch(aiPreferencesProvider).showReasoning
                  ? run.reasoning
                  : '',
              onCitation: (ref) => _openCitation(citations, ref),
            ),
          if (_controller.phase == AiChatPhase.answering &&
              run.status == AiRunStatus.running &&
              citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.aiChatCitations(citations.length),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 顶部一枚胶囊按钮（范围 / 人设 / 模型）。
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.emoji,
  });

  final String label;
  final VoidCallback? onPressed;
  final FaIconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: emoji != null
          ? Text(emoji!)
          : FaIcon(icon, size: 12, color: colors.primary),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onPressed: onPressed,
    );
  }
}

/// 底部输入栏：多行输入（普通文字键盘）与发送 / 停止按钮。桌面上 Enter
/// 发送、Shift + Enter 换行；手机上回车换行，点按钮发送。
class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.side,
    required this.busy,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double side;
  final bool busy;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final glass = AppGlassField.of(context);
    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      minLines: 1,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: l10n.aiChatInputHint,
        filled: true,
        fillColor: glass?.fill ?? colors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: glass?.border ?? BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: glass?.border ?? BorderSide.none,
        ),
      ),
      contextMenuBuilder: appTextContextMenuBuilder,
    );
    if (AppPlatform.isDesktop) {
      field = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): onSend,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): onSend,
        },
        child: field,
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 4, side, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: field),
            const SizedBox(width: 8),
            // 算作输入框的一部分：点发送不收起键盘，接着就能写下一句。
            TextFieldTapRegion(
              child: busy
                  ? IconButton.outlined(
                      tooltip: l10n.aiPanelStop,
                      onPressed: onStop,
                      icon: const FaIcon(FontAwesomeIcons.stop, size: 16),
                    )
                  : IconButton.filled(
                      tooltip: l10n.aiPanelSend,
                      onPressed: enabled ? onSend : null,
                      icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
