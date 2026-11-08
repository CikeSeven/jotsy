part of 'ai_chat_controller.dart';

// 智能体的一轮（模型支持工具调用、且“让 AI 使用工具”开着时）：
// 1. 发送前确认：只看这个服务商的主机确认过没有（隐私设为“每次”时每轮问
//    一次）——工具可能连续读好几次日记，不按工具结果逐次弹；
// 2. 固定了一篇日记时把它放进上下文（私密日记只在用户允许时），时间范围
//    写成一句提示；其余的日记都由模型调工具按需去查；
// 3. 运行 `AiAgentLoop`，每一步经 `AiAgentTurn` 落库与显示；
// 4. 模型第一步就回 400 且被记为不支持工具（还没有任何输出）时，删掉占位
//    消息、返回 false，由调用方改走检索问答；
// 5. 第一轮结束后起标题。

extension _AiChatAgent on AiChatController {
  /// 返回 false 表示要改走检索问答。
  Future<bool> _sendAgent(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    AiPreferences prefs,
    String id,
    List<AiMessageRow> history,
    String text, {
    required AiResolvedModel model,
    required bool Function() current,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = context.l10n;
    final env = AiToolEnv(
      features: ref.read(appFeaturesProvider),
      prefs: prefs,
    );
    final tools = aiAvailableTools(env);
    // 使用指南（提示词语言的那一份）：目录放进系统提示词，正文由
    // read_guide 按需读取。读不出时照常对话，只是没有指南。
    var guide = AiGuideCatalog.empty;
    try {
      guide = await container.read(
        aiGuideCatalogProvider(aiGuideLanguage(kit.l10n.localeName)).future,
      );
    } catch (_) {
      // 资源缺失或损坏：没有指南也能对话。
    }
    final citations = AiCitationBook();
    final allowance = AiWordAllowance(prefs.privacy.contextBudget);

    // 固定一篇 / 时间范围。
    String? fixedDiary;
    String? scopeLine;
    var fixedWords = 0;
    switch (scope.kind) {
      case AiChatScopeKind.diary:
        final diary = await database.getAiDiary(scope.diaryId!);
        final allowed =
            diary != null &&
            (prefs.privacy.allowPrivate ||
                !(await database.isDiaryPrivate(diary.diaryId)));
        if (allowed) {
          final words =
              TextStats.countWords(diary.contentText) +
              TextStats.countWords(diary.title);
          fixedWords = allowance.take(words);
          final citation = citations.refFor(
            diary.diaryId,
            title: diary.title,
            date: diary.createdAt,
          );
          fixedDiary =
              '${kit.l10n.aiPromptAgentScopeDiary}\n\n'
              '${kit.diary(diary, ref: '[$citation]', maxWords: fixedWords < words ? fixedWords : null)}';
        }
      case AiChatScopeKind.range:
        scopeLine = kit.l10n.aiPromptAgentScopeRange(
          kit.date(scope.start!),
          kit.date(scope.end!),
        );
      case AiChatScopeKind.recent:
        final now = DateTime.now();
        scopeLine = kit.l10n.aiPromptAgentScopeRange(
          kit.date(DateTime(now.year, now.month, now.day - scope.days + 1)),
          kit.date(now),
        );
      case AiChatScopeKind.all || AiChatScopeKind.auto:
        break;
    }
    if (!current() || !context.mounted) return true;

    final ok = await confirmAiSend(
      context,
      ref,
      model: model,
      summary: AiSendSummary(
        words: fixedWords + TextStats.countWords(text),
        entries: fixedDiary == null ? 0 : 1,
        agent: true,
      ),
    );
    if (!current()) return true;
    if (!ok || !context.mounted) {
      _set(AiChatPhase.idle);
      return true;
    }

    final token = _agentToken = HttpCancelToken();
    final turn = AiAgentTurn(
      database: database,
      conversationId: id,
      model: model,
      tools: <String, AiTool>{for (final tool in tools) tool.name: tool},
      toolContext: AiToolContext(
        container: container,
        l10n: l10n,
        kit: kit,
        env: env,
        citations: citations,
        allowance: allowance,
        token: token,
        ui: _AgentToolUi(context, ref),
        guide: guide,
      ),
    );
    _agentTurn = turn;
    _set(AiChatPhase.working);
    await turn.begin();
    final persona = aiPersonaById(
      kit.l10n,
      prefs,
      personaId,
      use: AiPersonaUse.chat,
    );
    final request = aiAgentRequest(
      kit,
      history: history,
      question: text,
      now: DateTime.now(),
      persona: persona,
      tools: tools,
      scopeLine: scopeLine,
      fixedDiary: fixedDiary,
      guideIndex: guide.index,
    );
    var answered = true;
    try {
      final result = await AiAgentLoop(
        service: service,
        model: model,
        host: turn,
        maxSteps: prefs.agent.maxSteps,
      ).run(request, token);
      await turn.complete(result);
      _autoOpen = turn.autoOpen;
    } on AiException catch (error) {
      if (error.kind == AiFailureKind.cancelled || token.isCancelled) {
        await turn.stop();
      } else if (error.kind == AiFailureKind.badRequest &&
          !service.supportsTools(model) &&
          !turn.hasOutput) {
        await turn.discard();
        answered = false;
      } else {
        await turn.fail(error);
      }
    } catch (error) {
      await turn.fail(error);
    } finally {
      if (identical(_agentToken, token)) _agentToken = null;
    }
    if (!current()) return true;
    _agentTurn = null;
    turn.dispose();
    _set(AiChatPhase.idle);
    if (answered && history.isEmpty && context.mounted) {
      unawaited(
        _title(
          context,
          ref,
          id,
          service,
          kit,
          prefs,
          text,
          citations.length,
          current,
        ),
      );
    }
    return answered;
  }
}

/// 工具需要的界面能力，借对话页的 context 与 ref 实现；页面离开后一律当作
/// 拒绝（不在已卸载的页面上弹窗）。
class _AgentToolUi implements AiToolUi {
  _AgentToolUi(this._context, this._ref);

  final BuildContext _context;
  final WidgetRef _ref;

  @override
  Future<void> requestReminderPermission() async {
    if (!_context.mounted) return;
    await ensureTodoReminderPermission(_context, _ref);
  }
}
