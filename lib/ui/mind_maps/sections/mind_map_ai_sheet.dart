import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../ai/controllers/ai_privacy_gate.dart';
import '../../ai/controllers/ai_save_as_diary_flow.dart';
import '../../ai/controllers/ai_stream_run.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/viewmodels/ai_prompt_builder.dart';
import '../../ai/widgets/ai_error_view.dart';
import '../../ai/widgets/ai_markdown_view.dart';
import '../../ai/widgets/ai_tap_outside_unfocus.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/keyboard_visibility.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_ai_session.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../viewmodels/mind_map_ai_prompts.dart';
import '../viewmodels/mind_map_labels.dart';
import '../widgets/mind_map_thumbnail.dart';

/// 导图 AI 面板：生成整张导图、给主题添加子主题、由日记生成导图、总结导图
/// 共用一个面板。
///
/// 流程：（生成整张图时先填主题、层数与风格）→ 解析模型 → 按隐私设置确认
/// （`confirmAiSend`）→ 流式生成，预览随着文字长出主题（可停止）→ 用户确认
/// 后才写进导图（替换整棵树或插入子主题，都只占一步撤销）/ 打开新的导图
/// 日记 / 复制、写进备注、另存为日记。面板关闭即取消进行中的请求。
/// 私密判断由入口在打开面板前做完（见 `MindMapAiScope`）。
///
/// [controller]：生成、添加子主题与“写进备注”写入的导图；[nodeId]：添加
/// 子主题的位置；[document]：总结的导图（没有 [controller] 时只读）；
/// [diary]：由日记生成时的日记；[onOpenAsDiary]：由日记生成后打开新导图
/// 日记（由日记模块提供，导图模块不依赖日记的页面）。
Future<void> showMindMapAiSheet(
  BuildContext host, {
  required MindMapAiTask task,
  MindMapEditingController? controller,
  MindMapDocument? document,
  String? nodeId,
  AiContextDiary? diary,
  ValueChanged<MindMapDocument>? onOpenAsDiary,
}) {
  controller?.stopEditing();
  return showAppModalBottomSheet<void>(
    context: host,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(host)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext context) => _MindMapAiSheet(
      host: host,
      task: task,
      controller: controller,
      document: document ?? controller?.document,
      nodeId: nodeId,
      diary: diary,
      onOpenAsDiary: onOpenAsDiary,
    ),
  );
}

class _MindMapAiSheet extends ConsumerStatefulWidget {
  const _MindMapAiSheet({
    required this.host,
    required this.task,
    required this.controller,
    required this.document,
    required this.nodeId,
    required this.diary,
    required this.onOpenAsDiary,
  });

  final BuildContext host;
  final MindMapAiTask task;
  final MindMapEditingController? controller;
  final MindMapDocument? document;
  final String? nodeId;
  final AiContextDiary? diary;
  final ValueChanged<MindMapDocument>? onOpenAsDiary;

  @override
  ConsumerState<_MindMapAiSheet> createState() => _MindMapAiSheetState();
}

class _MindMapAiSheetState extends ConsumerState<_MindMapAiSheet> {
  late final MindMapAiSession _session = MindMapAiSession(widget.task);
  late final TextEditingController _topic = TextEditingController(
    text: widget.task == MindMapAiTask.generate
        ? (widget.document?.root.text.trim() ?? '')
        : '',
  );
  final TextEditingController _extra = TextEditingController();
  int _depth = 3;
  MindMapAiStyle _style = MindMapAiStyle.structured;

  /// 开始前的错误（没有可用模型）：与生成中的错误同样显示。
  Object? _setupError;

  /// 正在解析模型与确认（防止连点）。
  bool _preparing = false;

  bool get _started => _session.run.status != AiRunStatus.idle;

  @override
  void initState() {
    super.initState();
    _topic.addListener(_onTopic);
    // 除了“生成整张图”要先填主题，其余打开即开始（入口已表明了意图）。
    if (widget.task != MindMapAiTask.generate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void dispose() {
    _topic
      ..removeListener(_onTopic)
      ..dispose();
    _extra.dispose();
    _session.dispose();
    super.dispose();
  }

  void _onTopic() => setState(() {});

  /// 这次要发出去的文字（确认面板的字数与“跟随日记”的语言判断都用它）。
  String _material() => switch (widget.task) {
    MindMapAiTask.generate => '${_topic.text}\n${_extra.text}',
    MindMapAiTask.expand ||
    MindMapAiTask.summarize => mindMapOutlineText(widget.document!),
    MindMapAiTask.fromDiary => widget.diary!.contentText,
  };

  Future<void> _start() async {
    if (_preparing || _session.run.running) return;
    final topic = _topic.text.trim();
    if (widget.task == MindMapAiTask.generate && topic.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _preparing = true;
      _setupError = null;
    });
    try {
      final service = await ref.read(aiServiceProvider.future);
      if (!mounted) return;
      final model = service.resolve(AiTaskKind.writing);
      if (model == null) {
        setState(
          () => _setupError = const AiException(AiFailureKind.notConfigured),
        );
        return;
      }
      final material = _material();
      final ok = await confirmAiSend(
        context,
        ref,
        model: model,
        summary: AiSendSummary(words: TextStats.countWords(material)),
      );
      if (!ok || !mounted) return;
      final kit = AiPromptKit.resolve(
        prefs: ref.read(aiPreferencesProvider),
        appLocale: Localizations.localeOf(context),
        sample: material,
      );
      final request = switch (widget.task) {
        MindMapAiTask.generate => mindMapAiGenerateRequest(
          kit,
          topic: topic,
          depth: _depth,
          style: _style,
          extra: _extra.text,
        ),
        MindMapAiTask.expand => mindMapAiExpandRequest(
          kit,
          document: widget.document!,
          nodeId: widget.nodeId!,
          untitled: kit.l10n.mindMapUntitled,
        ),
        MindMapAiTask.fromDiary => mindMapAiFromDiaryRequest(
          kit,
          diary: widget.diary!,
        ),
        MindMapAiTask.summarize => mindMapAiSummaryRequest(
          kit,
          document: widget.document!,
          untitled: kit.l10n.mindMapUntitled,
        ),
      };
      setState(() => _preparing = false);
      await _session.start(
        service: service,
        model: model,
        request: request,
        topic: widget.task == MindMapAiTask.generate ? topic : '',
      );
    } finally {
      if (mounted && _preparing) setState(() => _preparing = false);
    }
  }

  // ---------------- 结果的去处 ----------------

  void _close() => Navigator.of(context).pop();

  void _hint(String message) {
    final host = widget.host;
    if (!host.mounted) return;
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: host,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  /// 生成整张图：替换当前导图（保留结构与配色），一步撤销。
  void _useMap() {
    final controller = widget.controller;
    final root = _session.map;
    if (controller == null || root == null) return;
    controller
      ..stopEditing()
      ..commit(MindMapOps.replaceRoot(controller.document, root), select: '');
    _close();
  }

  /// 添加子主题：依次插在选中主题的末尾，收起的先展开，一步撤销。
  void _addBranches() {
    final controller = widget.controller;
    final id = widget.nodeId;
    if (controller == null || id == null) return;
    var next = controller.document;
    for (final branch in _session.branches) {
      next = MindMapOps.insertSubtree(next, id, branch).$1;
    }
    if (next.index[id]?.collapsed ?? false) {
      next = MindMapOps.updateNode(
        next,
        id,
        (node) => node.copyWith(collapsed: false),
      );
    }
    controller.commit(next, select: id);
    _close();
  }

  void _openAsDiary() {
    final root = _session.map;
    final open = widget.onOpenAsDiary;
    if (root == null || open == null) return;
    final map = MindMapOps.replaceRoot(MindMapDocument.blank(), root);
    _close();
    open(map);
  }

  void _copySummary() {
    final text = _session.run.text.trim();
    _close();
    if (widget.host.mounted) copyAiText(widget.host, text);
  }

  /// 总结追加到中心主题的备注（与已有备注空一行，受备注长度上限约束）。
  void _summaryToNote() {
    final controller = widget.controller;
    if (controller == null) return;
    final summary = _session.run.text.trim();
    controller.updateNode(controller.document.root.id, (node) {
      final existing = node.note?.trim() ?? '';
      var note = existing.isEmpty ? summary : '$existing\n\n$summary';
      if (note.length > kMindMapMaxTextLength) {
        note = note.substring(0, kMindMapMaxTextLength);
      }
      return node.copyWith(note: note);
    });
    _close();
    _hint(context.l10n.mindMapAiNoteAdded);
  }

  void _saveSummary() {
    final document = widget.document;
    if (document == null) return;
    final title = mindMapTitle(context.l10n, document.root.text);
    final text = _session.run.text.trim();
    _close();
    // 面板的退场动画结束前 ref 仍可用；另存为日记在第一次 await 之前就
    // 读完了 provider。
    if (widget.host.mounted) {
      saveAiTextAsDiary(widget.host, ref, title: title, markdown: text);
    }
  }

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;
    final (String title, String? subtitle) = switch (task) {
      MindMapAiTask.generate => (
        l10n.mindMapAiGenerate,
        widget.document == null || mindMapHasOnlyRoot(widget.document!)
            ? null
            : l10n.mindMapAiReplaceHint,
      ),
      MindMapAiTask.expand => (
        l10n.mindMapAiExpand,
        l10n.mindMapAiExpandHint(_nodeTitle(l10n)),
      ),
      MindMapAiTask.fromDiary => (
        l10n.mindMapAiFromDiary,
        l10n.mindMapAiFromDiaryHint,
      ),
      MindMapAiTask.summarize => (l10n.mindMapAiSummarize, null),
    };
    return AiTapOutsideUnfocus(
      child: KeyboardInsetPadding(
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _session,
            builder: (BuildContext context, Widget? _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Header(title: title, subtitle: subtitle),
                  const SizedBox(height: 16),
                  if (task == MindMapAiTask.generate) ...<Widget>[
                    _GenerateOptions(
                      topic: _topic,
                      extra: _extra,
                      depth: _depth,
                      style: _style,
                      enabled: !_session.run.running && !_preparing,
                      onDepth: (value) => setState(() => _depth = value),
                      onStyle: (value) => setState(() => _style = value),
                      onSubmit: _start,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AnimatedSize(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.spatial,
                    alignment: Alignment.topCenter,
                    child: _started
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: task == MindMapAiTask.summarize
                                ? _SummaryPreview(run: _session.run)
                                : _MapPreview(document: _previewDocument()),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  _StatusLine(
                    session: _session,
                    preparing: _preparing,
                    setupError: _setupError,
                    onRetry: _start,
                    errorColor: scheme.error,
                  ),
                  const SizedBox(height: 8),
                  _actions(l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _nodeTitle(AppLocalizations l10n) {
    final text = widget.document?.index[widget.nodeId ?? '']?.text ?? '';
    final line = text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (line.isNotEmpty) return line;
    return widget.nodeId == widget.document?.root.id
        ? l10n.mindMapRootPlaceholder
        : l10n.mindMapNodePlaceholder;
  }

  /// 预览的导图：整张图为生成的中心主题；添加子主题为“选中的主题 + 新的
  /// 子主题”。沿用当前导图的结构与配色，看起来与放进画布后一致。
  MindMapDocument _previewDocument() {
    final base = widget.document ?? MindMapDocument.blank();
    switch (widget.task) {
      case MindMapAiTask.expand:
        final node = base.index[widget.nodeId ?? ''];
        return base.copyWith(
          root: MindMapNode(
            id: 'preview',
            text: node?.text ?? '',
            children: _withIds(_session.branches),
          ),
        );
      case MindMapAiTask.generate || MindMapAiTask.fromDiary:
        final root = _session.map;
        return base.copyWith(
          root: root == null
              ? MindMapNode(id: 'preview', text: _topic.text.trim())
              : _withIds(<MindMapNode>[root]).single,
        );
      case MindMapAiTask.summarize:
        return base;
    }
  }

  /// 解析出的节点 id 只在一次解析内唯一；预览按位置补一遍（布局按 id 缓存）。
  List<MindMapNode> _withIds(List<MindMapNode> nodes, [String prefix = 'p']) =>
      <MindMapNode>[
        for (var i = 0; i < nodes.length; i++)
          nodes[i].copyWith(
            id: '$prefix.$i',
            children: _withIds(nodes[i].children, '$prefix.$i'),
          ),
      ];

  Widget _actions(AppLocalizations l10n) {
    final run = _session.run;
    final running = run.running || _preparing;
    final result = _session.hasUsableResult;
    final buttons = <Widget>[];
    if (running) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _preparing ? null : _session.stop,
          icon: const FaIcon(FontAwesomeIcons.stop, size: 12),
          label: Text(l10n.aiPanelStop),
        ),
      );
    } else if (widget.task == MindMapAiTask.generate && !_started) {
      buttons.add(
        FilledButton.icon(
          onPressed: _topic.text.trim().isEmpty ? null : _start,
          icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 14),
          label: Text(l10n.mindMapAiRun),
        ),
      );
    } else {
      if (_started || _setupError != null) {
        buttons.add(
          TextButton(onPressed: _start, child: Text(l10n.mindMapAiRegenerate)),
        );
      }
      if (result) {
        switch (widget.task) {
          case MindMapAiTask.generate:
            buttons.add(
              FilledButton(onPressed: _useMap, child: Text(l10n.mindMapAiUse)),
            );
          case MindMapAiTask.expand:
            buttons.add(
              FilledButton(
                onPressed: _addBranches,
                child: Text(l10n.mindMapAiAdd),
              ),
            );
          case MindMapAiTask.fromDiary:
            buttons.add(
              FilledButton(
                onPressed: _openAsDiary,
                child: Text(l10n.mindMapAiOpenAsDiary),
              ),
            );
          case MindMapAiTask.summarize:
            buttons.addAll(<Widget>[
              TextButton(
                onPressed: _copySummary,
                child: Text(l10n.aiPanelCopy),
              ),
              if (widget.controller != null && !widget.controller!.readOnly)
                TextButton(
                  onPressed: _summaryToNote,
                  child: Text(l10n.mindMapAiToNote),
                ),
              FilledButton(
                onPressed: _saveSummary,
                child: Text(l10n.aiRecapSaveAsDiary),
              ),
            ]);
        }
      }
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: buttons,
    );
  }
}

/// 标题行：40dp `primaryContainer` 方块里的魔杖 + 标题 + 一行说明。
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = this.subtitle;
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(
            FontAwesomeIcons.wandMagicSparkles,
            size: 16,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 生成整张图的选项：主题、层数、风格与补充要求。
class _GenerateOptions extends StatelessWidget {
  const _GenerateOptions({
    required this.topic,
    required this.extra,
    required this.depth,
    required this.style,
    required this.enabled,
    required this.onDepth,
    required this.onStyle,
    required this.onSubmit,
  });

  final TextEditingController topic;
  final TextEditingController extra;
  final int depth;
  final MindMapAiStyle style;
  final bool enabled;
  final ValueChanged<int> onDepth;
  final ValueChanged<MindMapAiStyle> onStyle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: topic,
          enabled: enabled,
          autofocus: topic.text.isEmpty,
          maxLength: kMindMapMaxTextLength,
          contextMenuBuilder: appTextContextMenuBuilder,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => onSubmit(),
          style: theme.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: l10n.mindMapAiTopicHint,
            counterText: '',
            prefixIcon: const Padding(
              padding: EdgeInsetsDirectional.only(start: 14, end: 10),
              child: FaIcon(FontAwesomeIcons.sitemap, size: 15),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
          ),
        ),
        const SizedBox(height: 16),
        label(l10n.mindMapAiDepth),
        ExpressiveButtonGroup<int>(
          segments: <ButtonSegment<int>>[
            for (final value in kMindMapAiDepths)
              ButtonSegment<int>(value: value, label: Text('$value')),
          ],
          selected: <int>{depth},
          minSegmentWidth: 56,
          onSelectionChanged: enabled ? (value) => onDepth(value.first) : null,
        ),
        const SizedBox(height: 14),
        label(l10n.mindMapAiStyle),
        ExpressiveButtonGroup<MindMapAiStyle>(
          segments: <ButtonSegment<MindMapAiStyle>>[
            ButtonSegment<MindMapAiStyle>(
              value: MindMapAiStyle.divergent,
              label: Text(l10n.mindMapAiStyleDivergent),
            ),
            ButtonSegment<MindMapAiStyle>(
              value: MindMapAiStyle.structured,
              label: Text(l10n.mindMapAiStyleStructured),
            ),
            ButtonSegment<MindMapAiStyle>(
              value: MindMapAiStyle.study,
              label: Text(l10n.mindMapAiStyleStudy),
            ),
          ],
          selected: <MindMapAiStyle>{style},
          // 放不下三段（窄屏、大字号）时纵向连接，标签不会被挤出去。
          minSegmentWidth: 96,
          onSelectionChanged: enabled ? (value) => onStyle(value.first) : null,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: extra,
          enabled: enabled,
          maxLength: 500,
          minLines: 1,
          maxLines: 3,
          contextMenuBuilder: appTextContextMenuBuilder,
          decoration: InputDecoration(
            hintText: l10n.mindMapAiExtraHint,
            counterText: '',
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// 导图预览：随生成长出的缩略图（`surfaceContainerLow`，18 圆角）。
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.document});

  final MindMapDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: MindMapThumbnail(
        document: document,
        padding: const EdgeInsets.all(18),
        maxScale: 1,
      ),
    );
  }
}

/// 总结的文字：流式 Markdown，区内滚动（最高 320）。
class _SummaryPreview extends StatelessWidget {
  const _SummaryPreview({required this.run});

  final AiStreamRun run;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!run.hasText) return const SizedBox(width: double.infinity);
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: AiMarkdownView(markdown: run.text, streaming: run.running),
      ),
    );
  }
}

/// 状态行：准备 / 思考 / 生成中（主题数）/ 出错 / 读不出主题。
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.session,
    required this.preparing,
    required this.setupError,
    required this.onRetry,
    required this.errorColor,
  });

  final MindMapAiSession session;
  final bool preparing;
  final Object? setupError;
  final VoidCallback onRetry;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final run = session.run;
    final error = setupError ?? run.error;
    if (error != null && !run.running && !preparing) {
      return AiErrorView(error: error, onRetry: onRetry);
    }
    if (session.finishedEmpty) {
      return Text(
        l10n.mindMapAiEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(color: errorColor),
      );
    }
    if (!preparing && !run.running) return const SizedBox.shrink();
    final String text;
    if (preparing || !run.hasText) {
      text = l10n.aiPanelThinking;
    } else if (session.task == MindMapAiTask.summarize) {
      text = l10n.mindMapAiGenerating;
    } else {
      text =
          '${l10n.mindMapAiGenerating} · '
          '${l10n.mindMapTopicCount(session.topicCount)}';
    }
    return Row(
      children: <Widget>[
        const ExpressiveLoadingIndicator(size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
