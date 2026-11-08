part of 'ai_chat_controller.dart';

// 检索问答（模型不支持工具调用、或关掉了“让 AI 使用工具”时）：按对话范围与
// AI 设置的检索方式找日记，放进这一轮的上下文。顺序与边界见
// `ai_chat_controller.dart` 开头的说明。

extension _AiChatRetrieval on AiChatController {
  Future<List<AiBudgetedDiary>> _retrieve(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    AiPreferences prefs,
    String question, {
    required AiResolvedModel model,
    required bool Function() current,
  }) async {
    final privacy = prefs.privacy;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<List<AiContextDiary>> query({
      DateTime? start,
      DateTime? end,
      List<String> keywords = const <String>[],
    }) => database.getAiContextDiaries(
      start: start,
      end: end,
      keywords: keywords,
      excludedNotebookIds: privacy.excludedNotebookIds,
      excludedTagNames: privacy.excludedTagNames,
      includeArchived: privacy.includeArchived,
      newestFirst: true,
      limit: 400,
    );

    DateTime daysAgo(int days) =>
        DateTime(today.year, today.month, today.day - days + 1);
    DateTime dayAfter(DateTime day) =>
        DateTime(day.year, day.month, day.day + 1);

    Future<List<AiContextDiary>> recent(int days) =>
        query(start: daysAgo(days), end: dayAfter(today));

    /// 按关键词查，查不到退回最近 N 天。
    Future<List<AiContextDiary>> byKeywords(List<String> keywords) async {
      if (keywords.isNotEmpty) {
        final found = await query(keywords: keywords);
        if (found.isNotEmpty) return found;
      }
      return recent(prefs.recentDays);
    }

    var keywords = aiQueryKeywords(question);
    List<AiContextDiary> candidates;
    switch (scope.kind) {
      case AiChatScopeKind.diary:
        final diary = await database.getAiDiary(scope.diaryId!);
        final allowed =
            diary != null &&
            (privacy.allowPrivate ||
                !(await database.isDiaryPrivate(diary.diaryId)));
        if (!allowed) return const <AiBudgetedDiary>[];
        // 整篇发送，只受总字数限制；maxWords 取实际字数，确认面板里的
        // “发送字数”才不会显示成整个预算。
        final words =
            TextStats.countWords(diary.contentText) +
            TextStats.countWords(diary.title);
        return [
          AiBudgetedDiary(
            diary: diary,
            ref: 'D1',
            maxWords: words < privacy.contextBudget
                ? words
                : privacy.contextBudget,
          ),
        ];
      case AiChatScopeKind.range:
        candidates = await query(start: scope.start, end: dayAfter(scope.end!));
      case AiChatScopeKind.recent:
        candidates = await recent(scope.days);
      case AiChatScopeKind.all:
        candidates = await byKeywords(keywords);
      case AiChatScopeKind.auto:
        switch (prefs.retrieval) {
          case AiRetrievalMode.recent:
            candidates = await recent(prefs.recentDays);
          case AiRetrievalMode.keyword:
            candidates = await byKeywords(keywords);
          case AiRetrievalMode.smart:
            if (!context.mounted) return const <AiBudgetedDiary>[];
            final plan = await _plan(
              context,
              ref,
              service,
              kit,
              question,
              model,
              current,
            );
            if (!current()) return const <AiBudgetedDiary>[];
            _set(AiChatPhase.searching);
            if (plan != null) {
              keywords = {...plan.keywords, ...keywords}.take(16).toList();
            }
            if (plan != null && plan.hasDates) {
              candidates = await query(
                start: plan.from,
                end: plan.to == null ? null : dayAfter(plan.to!),
              );
            } else {
              candidates = await byKeywords(keywords);
            }
        }
    }
    final ranked = aiRankDiaries(
      candidates,
      keywords,
      now: now,
    ).take(prefs.maxCitations).toList();
    final kept = aiBudgetDiaries(ranked, budget: privacy.contextBudget)
      ..sort((a, b) => a.diary.createdAt.compareTo(b.diary.createdAt));
    return [
      for (var i = 0; i < kept.length; i++)
        AiBudgetedDiary(
          diary: kept[i].diary,
          ref: 'D${i + 1}',
          maxWords: kept[i].maxWords,
        ),
    ];
  }

  /// 智能检索的计划；读不出或请求失败（取消除外）时为 null。
  Future<AiRetrievalPlan?> _plan(
    BuildContext context,
    WidgetRef ref,
    AiService service,
    AiPromptKit kit,
    String question,
    AiResolvedModel model,
    bool Function() current,
  ) async {
    final utility = service.resolve(AiTaskKind.utility) ?? model;
    final token = _planToken = HttpCancelToken();
    try {
      final request = aiRetrievalPlanRequest(
        kit,
        question: question,
        today: DateTime.now(),
      );
      // 检索计划同样包含问题与“关于我”，必须在第一字节发出前确认它的
      // 实际模型。取消不能当成计划失败后继续检索，否则仍可能发送回答请求。
      final ok = await confirmAiSend(
        context,
        ref,
        model: utility,
        summary: AiSendSummary(
          words: TextStats.countWords(
            '${request.system}\n${request.messages.single.text}',
          ),
        ),
      );
      if (!ok || !current() || !context.mounted || token.isCancelled) {
        throw const AiException(AiFailureKind.cancelled);
      }
      final completion = await service.complete(
        utility,
        request,
        cancelToken: token,
      );
      return AiRetrievalPlan.parse(completion.text);
    } on AiException catch (error) {
      if (error.kind == AiFailureKind.cancelled) rethrow;
      return null;
    } catch (_) {
      return null;
    } finally {
      if (identical(_planToken, token)) _planToken = null;
    }
  }
}
