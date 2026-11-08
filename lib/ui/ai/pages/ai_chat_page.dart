// AI 对话页（DESIGN §5.29“对话页”）：进入 AI 助手的落点。只负责装配——
// 顶栏、历史抽屉 / 宽屏侧栏、消息列表与输入栏；一轮问答的流程在
// [AiChatController]，打开页面与对象在 `ai_chat_links.dart`。
//
// - 顶栏：`<` 返回、对话标题（点按改名）、历史（宽屏常驻侧栏时没有）、新对话
//   （已是空白新对话时禁用）、⋮（重命名、置顶、删除、AI 设置）。
// - 历史：手机与中宽为左侧抽屉（只由按钮打开，免得与系统返回手势冲突），
//   宽窗口（≥ 1024）为左侧 300 宽的常驻栏；点一段对话在本页原地换过去，
//   生成中先停止（已有的部分按“已停止”保存）。
// - 消息：空白新对话为欢迎页；回答按 `buildAiAnswerSegments` 分段（思考过程
//   折叠，前往 / 改动 / 确认卡片与正文露在外面）。滚动由
//   [AiChatScrollController] 管（贴底跟随，用户往上翻就放手）。
// - 输入栏放在 Scaffold 的 bottomNavigationBar（`KeyboardInsetPadding` 让开
//   键盘），浮动提示条停在它上方。胶囊依次为范围、人设、模型 · 思考，改动
//   写进这段对话。
// - 进入：新对话在路由入场结束后聚焦输入框（进来就能打字）；打开已有对话
//   不聚焦。模型与思考强度每段对话各自记住，新对话沿用最近那段的选择。
// - “继续聊聊”（[seedReply]）：以那篇日记为固定范围，把那条回应作为对话的
//   开头。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/keyboard_visibility.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/ai_agent_undo_flow.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/ai_chat_flows.dart';
import '../controllers/ai_chat_links.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_chat_scope.dart';
import '../models/ai_conversation_options.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_recap_range.dart';
import '../providers/ai_chat_return_provider.dart';
import '../providers/ai_chat_view_memory_provider.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../sections/ai_chat_message_view.dart';
import '../sections/chat/ai_answer_actions.dart';
import '../sections/chat/ai_chat_composer.dart';
import '../sections/chat/ai_chat_history_panel.dart';
import '../sections/chat/ai_chat_model_sheet.dart';
import '../sections/chat/ai_chat_welcome.dart';
import '../sections/chat/ai_pending_answer.dart';
import '../sections/chat/ai_chat_history_drawer.dart';
import '../sections/chat/ai_chat_top_bar.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_task_prompts.dart';
import '../widgets/ai_chat_scroll_controller.dart';
import '../widgets/ai_tap_outside_unfocus.dart';
import 'ai_recap_page.dart';
import 'settings/ai_personas_page.dart';
import 'settings/ai_settings_page.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({
    super.key,
    this.conversationId,
    this.scope = const AiChatScope.auto(),
    this.initialQuestion,
    this.seedReply,
    this.restoreView = false,
  });

  final String? conversationId;
  final AiChatScope scope;

  /// 打开后立即发出的问题（新对话；选项读出来之后再发）。
  final String? initialQuestion;

  /// “继续聊聊”：那条回应（`ai_results` 行），对话以它开头。
  final AiResultRow? seedReply;

  /// 回到对话：恢复离开前的滚动位置与展开状态（`aiChatViewMemoryProvider`），
  /// 而不是从底部开始。
  final bool restoreView;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  /// 宽窗口常驻历史栏的宽度。
  static const double _dockWidth = 300;

  late final AiChatController _controller;
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final AiChatScrollController _scroll = AiChatScrollController();
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  /// 对话行 / 上次的选项读出来之前不让发送，免得用默认值发出去。
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 回到了对话（或从别处打开了对话）：返回键恢复原来的行为。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(aiChatReturnProvider.notifier).disarm();
    });
    _controller = AiChatController(
      database: ref.read(appDatabaseProvider),
      conversationId: widget.conversationId,
      scope: widget.scope,
      personaId: _defaultPersonaId,
    );
    _controller.addListener(_onControllerChanged);
    _scroll.restoreSaved = widget.restoreView;
    if (widget.conversationId case final id?) {
      unawaited(_load(id));
    } else if (widget.seedReply != null) {
      // 要用到本地化文案（对话标题），等第一帧之后再建。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_seed(widget.seedReply!));
      });
    } else {
      unawaited(_prepareNew());
      // 进来就能打字：路由入场结束后再聚焦，键盘不与页面滑入叠在一起。
      if (widget.initialQuestion == null) {
        _entrance.schedule(this, _inputFocus.requestFocus);
      }
    }
  }

  String? get _defaultPersonaId =>
      ref.read(aiPreferencesProvider).personaFor[AiPersonaUse.chat];

  /// 准备一段新对话（沿用最近那段的模型与思考强度），带着问题时随即发出。
  Future<void> _prepareNew() async {
    await _controller.startNew(defaultPersonaId: _defaultPersonaId);
    if (!mounted) return;
    setState(() => _ready = true);
    if (widget.initialQuestion case final question?) {
      unawaited(_send(question));
    }
  }

  Future<void> _load(String id) async {
    await _controller.openConversation(id);
    if (!mounted) return;
    setState(() => _ready = true);
    // 回到对话时由列表按记下的位置恢复；其余（打开、换对话）从底部开始。
    if (!_scroll.restoreSaved) _scroll.jumpToBottom();
  }

  /// “继续聊聊”：以那条回应开头的新对话。
  Future<void> _seed(AiResultRow reply) async {
    await _controller.seedFromReply(context.l10n, reply);
    if (!mounted) return;
    setState(() => _ready = true);
    _inputFocus.requestFocus();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    // 用户明确说了“打开…”：这一轮结束后自动打开那个页面。
    if (!_controller.busy) {
      final navigation = _controller.takeAutoOpen();
      if (navigation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(
              openAiNavigation(
                context,
                ref,
                navigation,
                conversationId: _controller.conversationId,
              ),
            );
          }
        });
      }
    }
  }

  // ------------------------------------------------------------ 动作

  Future<void> _send([String? question]) async {
    final text = (question ?? _input.text).trim();
    if (text.isEmpty || _controller.busy || !_ready) return;
    if (question == null) _input.clear();
    // 发问就回到底部并重新跟随：随后加入的问题与回答都贴着底部出现。
    _scroll.jumpToBottom();
    await _controller.send(context, ref, text);
  }

  void _closeDrawer() {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState!.closeDrawer();
    }
  }

  Future<void> _openConversation(String id) async {
    _closeDrawer();
    if (id == _controller.conversationId) return;
    _scroll.restoreSaved = false;
    setState(() => _ready = false);
    await _load(id);
  }

  Future<void> _startNew() async {
    _closeDrawer();
    _scroll.restoreSaved = false;
    _inputFocus.requestFocus();
    await _controller.startNew(defaultPersonaId: _defaultPersonaId);
    if (mounted) setState(() => _ready = true);
  }

  void _onDeleted(String id) {
    ref.read(aiChatViewMemoryProvider).forget(id);
    if (id == _controller.conversationId) unawaited(_startNew());
  }

  /// 顶栏 ⋮ 的删除：先停下生成，删掉后换成新对话。
  Future<void> _deleteCurrent(AiConversationRow? row) async {
    if (row == null) return;
    _controller.stop();
    final deleted = await deleteAiConversation(context, ref, row);
    if (deleted) _onDeleted(row.conversationId);
  }

  void _openRecap([AiRecapPreset? preset]) {
    _closeDrawer();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => preset == null
              ? const AiRecapPage()
              : AiRecapPage(initialPreset: preset, autoStart: true),
        ),
      ),
    );
  }

  void _openSettings() {
    _closeDrawer();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
      ),
    );
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

  Future<void> _pickModel() {
    final config = ref.read(aiLocalConfigProvider);
    return showAiChatModelSheet(
      context,
      models: config.usableModels,
      defaultModel: config.resolveTask(AiTaskKind.chat),
      options: _controller.options,
      onChanged: (value) => unawaited(_controller.updateOptions(value)),
    );
  }

  Future<void> _editLast(String question) async {
    final edited = await showAiEditQuestionDialog(context, question);
    if (!mounted || edited == null) return;
    await _controller.editLast(context, ref, edited);
  }

  AiAnswerActions _actions({
    required List<AiCitation> citations,
    void Function(String callId, bool approved)? onDecide,
    void Function(Set<String>? callIds)? onUndo,
  }) {
    final id = _controller.conversationId;
    return AiAnswerActions(
      onCitation: (refText) {
        for (final citation in citations) {
          if (citation.ref == refText) {
            unawaited(
              openAiSubject(
                context,
                ref,
                aiCitationSubject(citation),
                conversationId: id,
              ),
            );
            return;
          }
        }
      },
      onOpenPage: (navigation) => unawaited(
        openAiNavigation(context, ref, navigation, conversationId: id),
      ),
      onOpenSubject: (subject) =>
          unawaited(openAiSubject(context, ref, subject, conversationId: id)),
      onUndo: onUndo,
      onDecide: onDecide,
    );
  }

  // ------------------------------------------------------------ 界面

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = _controller.conversationId;
    final conversation = id == null
        ? null
        : ref.watch(aiConversationProvider(id)).value;
    final title = conversation?.title.trim().isNotEmpty ?? false
        ? conversation!.title
        : l10n.aiChatUntitled;
    final busy = _controller.busy;
    final blank = id == null && !busy;
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        // 点输入框以外的地方收起键盘（发送 / 停止按钮算作输入框的一部分）。
        builder: (BuildContext context) => AiTapOutsideUnfocus(
          child: WidthLayoutBuilder(
            builder: (BuildContext context, double width) {
              final docked =
                  AppBreakpoints.classOf(width) == AppWindowClass.expanded;
              final chatWidth = docked ? width - _dockWidth - 1 : width;
              final side = AppContentWidth.gutter(
                chatWidth,
                AppContentWidth.reading,
              );
              final panel = AiChatHistoryPanel(
                currentId: id,
                onSelect: (value) => unawaited(_openConversation(value)),
                onNewChat: () => unawaited(_startNew()),
                onSettings: _openSettings,
                onDeleted: _onDeleted,
                onRecaps: ref.watch(aiModuleAvailableProvider(AiModule.recap))
                    ? _openRecap
                    : null,
              );
              return Scaffold(
                key: _scaffold,
                backgroundColor: AppPageBackdrop.pageColorOf(context),
                drawer: docked
                    ? null
                    : AiChatHistoryDrawer(pageWidth: width, child: panel),
                drawerEnableOpenDragGesture: false,
                appBar: AiChatTopBar(
                  title: title,
                  conversation: conversation,
                  docked: docked,
                  blank: blank,
                  onHistory: () => _scaffold.currentState?.openDrawer(),
                  onNewChat: () => unawaited(_startNew()),
                  onDelete: () => unawaited(_deleteCurrent(conversation)),
                  onSettings: _openSettings,
                ),
                body: docked
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(width: _dockWidth, child: panel),
                          VerticalDivider(
                            width: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          Expanded(child: _messages(context, side, docked)),
                        ],
                      )
                    : _messages(context, side, docked),
                // 输入栏放在 bottomNavigationBar：浮动提示条停在它上方。
                // Scaffold 不替底栏让开键盘，由 KeyboardInsetPadding 垫高
                // （只有这一层随键盘逐帧重建）。
                bottomNavigationBar: KeyboardInsetPadding(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: docked ? _dockWidth + 1 : 0,
                    ),
                    child: _composer(context, side, busy),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 消息区放进这段对话的存储桶：滚动位置、展开过的思考过程与工具详情
  /// 在列表回收、换页回来后都还在。
  Widget _messages(BuildContext context, double side, bool docked) =>
      PageStorage(
        bucket: ref
            .read(aiChatViewMemoryProvider)
            .bucketFor(_controller.conversationId),
        child: _messageList(context, side, docked),
      );

  Widget _messageList(BuildContext context, double side, bool docked) {
    final id = _controller.conversationId;
    final loaded = id == null ? null : ref.watch(aiMessagesProvider(id)).value;
    // 打开已有对话、消息还没读出来：先什么都不画（不闪欢迎页或空列表；
    // 回到对话时列表要等内容齐了再建，才能按记下的位置恢复）。
    if (id != null && loaded == null && !_controller.busy) {
      return const SizedBox.shrink();
    }
    final rows = loaded ?? const <AiMessageRow>[];
    // 智能体这一轮的消息行边做边落库，进行中由末尾的“进行中”一项显示。
    final pendingRow = _controller.agentTurn?.messageId;
    final messages = pendingRow == null
        ? rows
        : [
            for (final row in rows)
              if (row.messageId != pendingRow) row,
          ];
    final l10n = context.l10n;
    final prefs = ref.watch(aiPreferencesProvider);
    final persona = aiPersonaById(
      l10n,
      prefs,
      _controller.personaId,
      use: AiPersonaUse.chat,
    );
    final busy = _controller.busy;
    final lastUser = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.user,
    );
    final lastAssistant = messages.lastIndexWhere(
      (m) => m.role == AiMessageRole.assistant,
    );
    // 欢迎页只属于还没开始的新对话（打开旧对话、消息还没读出来时不闪一下
    // 欢迎页）；它从顶部读起，不用贴底跟随的滚动控制器。
    if (id == null && !busy) {
      return SingleChildScrollView(
        key: const ValueKey<String>('chat-welcome'),
        padding: EdgeInsets.fromLTRB(side, 8, side, 24),
        child: AiChatWelcome(
          persona: persona,
          agent: prefs.agent.enabled,
          recapOn: ref.watch(aiModuleAvailableProvider(AiModule.recap)),
          onAsk: (question) => unawaited(_send(question)),
          onOpenConversation: (value) => unawaited(_openConversation(value)),
          onShowAll: docked ? null : () => _scaffold.currentState?.openDrawer(),
          onRecap: _openRecap,
        ),
      );
    }
    return ListView.builder(
      // 换对话时整段列表重来（展开状态、元素复用不串到别的对话）。
      key: PageStorageKey<String>('chat-${id ?? 'new'}'),
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(side, 8, side, 24),
      itemCount: messages.length + (busy ? 1 : 0),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        if (key.value == 'ai-pending') return busy ? messages.length : null;
        final index = messages.indexWhere(
          (message) => message.messageId == key.value,
        );
        return index < 0 ? null : index;
      },
      itemBuilder: (context, i) {
        if (i == messages.length) {
          return ListenableBuilder(
            key: const ValueKey<String>('ai-pending'),
            listenable: Listenable.merge(<Listenable?>[
              _controller.run,
              _controller.agentTurn,
            ]),
            builder: (context, _) => AiPendingAnswer(
              controller: _controller,
              persona: persona,
              showReasoning: prefs.showReasoning,
              actionsFor: _actions,
            ),
          );
        }
        final message = messages[i];
        final citations = AiCitation.decodeList(message.citations);
        return AiChatMessageView(
          key: ValueKey<String>(message.messageId),
          message: message,
          persona: persona,
          showReasoning: prefs.showReasoning,
          showTokens: prefs.showTokens,
          actions: _actions(
            citations: citations,
            onUndo: busy
                ? null
                : (ids) => unawaited(
                    undoAiAgentCalls(context, ref, message, callIds: ids),
                  ),
          ),
          onCopy: (text) => unawaited(copyAiText(context, text)),
          onSaveAsDiary: (text) => unawaited(
            saveAiTextAsDiary(
              context,
              ref,
              title: ref.read(aiConversationProvider(id!)).value?.title ?? '',
              markdown: text,
            ),
          ),
          onEdit: !busy && i == lastUser
              ? () => unawaited(_editLast(message.content))
              : null,
          onRegenerate: !busy && i == lastAssistant && i > lastUser
              ? () => unawaited(_controller.regenerate(context, ref))
              : null,
          onDelete: busy
              ? null
              : () => unawaited(deleteAiChatMessage(context, ref, message)),
        );
      },
    );
  }

  Widget _composer(BuildContext context, double side, bool busy) {
    final l10n = context.l10n;
    final prefs = ref.watch(aiPreferencesProvider);
    final config = ref.watch(aiLocalConfigProvider);
    final persona = aiPersonaById(
      l10n,
      prefs,
      _controller.personaId,
      use: AiPersonaUse.chat,
    );
    final options = _controller.options;
    final model =
        config.resolveRef(options.model) ?? config.resolveTask(AiTaskKind.chat);
    final thinking = aiThinkingLevelLabel(l10n, options.thinking);
    return AiChatComposer(
      controller: _input,
      focusNode: _inputFocus,
      side: side,
      busy: busy,
      enabled: _ready,
      onSend: () => unawaited(_send()),
      onStop: _controller.stop,
      chips: <Widget>[
        AiComposerChip(
          icon: FontAwesomeIcons.magnifyingGlass,
          label: aiChatScopeLabel(l10n, _controller.scope),
          custom: _controller.scope.kind != AiChatScopeKind.auto,
          tooltip: l10n.aiChatScope,
          onPressed: busy ? null : _pickScope,
        ),
        AiComposerChip(
          emoji: persona.emoji,
          label: persona.name,
          custom: _controller.personaId != _defaultPersonaId,
          tooltip: l10n.aiChatPersona,
          onPressed: busy ? null : _pickPersona,
        ),
        AiComposerChip(
          icon: FontAwesomeIcons.microchip,
          label: model == null
              ? l10n.aiChatModel
              : '${model.model.label} · $thinking',
          custom: options != AiConversationOptions.defaults,
          tooltip: l10n.aiChatModelSheetTitle,
          onPressed: busy ? null : () => unawaited(_pickModel()),
        ),
      ],
    );
  }
}
