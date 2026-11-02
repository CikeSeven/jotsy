// AI 回顾页：挑范围（预设或自定义日期）、日记本（日记本功能开着时；只列
// 可见性为 normal 的手动本与智能本，私密本永远不在列）、要写的部分与口吻，
// 然后生成。流程在 [AiRecapController]（页面持有，离开即停止）；完成后已
// 自动保存，可复制、分享、另存为日记或重新生成。页面末尾列出以前的回顾。
//
// [autoStart] 由探索页“生成本周回顾”与 AI 助手主页的快捷回顾打开：进入
// 后立即按默认设置生成一次（仍经发送前确认）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../diaries/controllers/diary_link_open_flow.dart';
import '../../notebooks/models/notebook_scope_resolver.dart';
import '../../notebooks/providers/notebook_insights_providers.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../controllers/ai_recap_controller.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_recap_range.dart';
import '../pages/settings/ai_personas_page.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../sections/ai_recap_result_view.dart';
import '../viewmodels/ai_labels.dart';
import '../widgets/ai_error_view.dart';
import '../widgets/ai_page_scaffold.dart';
import 'ai_recap_view_page.dart';

class AiRecapPage extends ConsumerStatefulWidget {
  const AiRecapPage({
    super.key,
    this.initialPreset = AiRecapPreset.thisWeek,
    this.autoStart = false,
  });

  final AiRecapPreset initialPreset;
  final bool autoStart;

  @override
  ConsumerState<AiRecapPage> createState() => _AiRecapPageState();
}

class _AiRecapPageState extends ConsumerState<AiRecapPage> {
  final AiRecapController _controller = AiRecapController();
  late AiRecapPreset _preset = widget.initialPreset;
  AiRecapRange? _custom;
  AiRecapScope _scope = const AiRecapScope.all();
  late Set<AiRecapSection> _sections;
  String? _personaId;

  /// 每周起始日：在 build 里经 [watchGoalFirstWeekday] 取得（它须在 build
  /// 期间调用），生成与另存时直接用这里的值。
  int _firstWeekday = DateTime.monday;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(aiPreferencesProvider);
    _sections = {...prefs.recapSections};
    _personaId = prefs.personaFor[AiPersonaUse.recap];
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_generate());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AiRecapRange _range() {
    if (_preset == AiRecapPreset.custom && _custom != null) return _custom!;
    return AiRecapRange.preset(
      _preset,
      now: DateTime.now(),
      firstWeekday: _firstWeekday,
    );
  }

  /// 当前日记本换算成的查询范围；本子已不在（被删或变成私密）时退回全部。
  DiaryListScope _listScope() {
    final id = _scope.notebookId;
    if (id == null) return DiaryListScope.all;
    final tree = ref.read(notebookTreeProvider);
    final view = tree?[id];
    if (view == null || view.isPrivate) {
      setState(() => _scope = const AiRecapScope.all());
      return DiaryListScope.all;
    }
    return notebookStatsScope(view, tree: tree);
  }

  Future<void> _generate() async {
    final range = _range();
    final spec = AiRecapSpec(
      range: range,
      scope: _scope,
      listScope: _listScope(),
      sections: [
        for (final section in AiRecapSection.values)
          if (_sections.contains(section)) section,
      ],
      personaId: _personaId,
    );
    await _controller.generate(context, ref, spec);
  }

  Future<void> _pickPreset(AiRecapPreset preset) async {
    if (preset != AiRecapPreset.custom) {
      setState(() => _preset = preset);
      return;
    }
    final now = DateTime.now();
    final current = _custom;
    final picked = await showDateRangePicker(
      context: context,
      helpText: context.l10n.aiRecapCustomRange,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current == null
          ? DateTimeRange(
              start: DateTime(now.year, now.month),
              end: DateTime(now.year, now.month, now.day),
            )
          : DateTimeRange(start: current.start, end: current.lastDay),
    );
    // 取消时保持原来的范围，不切到一个空的“自定义”。
    if (!mounted || picked == null) return;
    setState(() {
      _preset = AiRecapPreset.custom;
      _custom = AiRecapRange.days(picked.start, picked.end);
    });
  }

  Future<void> _pickNotebook() async {
    final tree = ref.read(notebookTreeProvider);
    final candidates = <NotebookView>[
      for (final view in tree?.depthFirst ?? const <NotebookView>[])
        if (!view.isPrivate && !view.isClosed) view,
    ];
    final picked = await showAppModalBottomSheet<AiRecapScope>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext sheetContext) =>
          _NotebookSheet(candidates: candidates, selected: _scope),
    );
    if (!mounted || picked == null) return;
    setState(() => _scope = picked);
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
        _personaId,
        use: AiPersonaUse.recap,
      ).id,
      title: l10n.aiRecapPersona,
    );
    if (!mounted || picked == null) return;
    setState(() => _personaId = picked);
  }

  void _openCitation(String ref) {
    final diaryId = _controller.refs[ref];
    if (diaryId == null) return;
    unawaited(
      openDiaryLinkTarget(context, this.ref, DiaryLinkTarget.diary(diaryId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prefs = ref.watch(aiPreferencesProvider);
    final notebooksOn = ref.watch(
      appFeaturesProvider.select((f) => f.notebooks),
    );
    _firstWeekday = watchGoalFirstWeekday(context, ref);
    final range = _range();
    final persona = aiPersonaById(
      l10n,
      prefs,
      _personaId,
      use: AiPersonaUse.recap,
    );
    final recaps = ref.watch(aiRecapsProvider).value ?? const <AiResultRow>[];
    return AiPageScaffold(
      title: l10n.aiRecapTitle,
      area: AppBackgroundArea.other,
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.aiRecapRange,
          footer: aiRecapRangeText(l10n, range),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final preset in AiRecapPreset.values)
                    ChoiceChip(
                      label: Text(aiRecapPresetLabel(l10n, preset)),
                      selected: _preset == preset,
                      onSelected: _controller.busy
                          ? null
                          : (_) => unawaited(_pickPreset(preset)),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            if (notebooksOn)
              AiNavTile(
                icon: FontAwesomeIcons.book,
                title: l10n.aiRecapNotebook,
                subtitle: _scope.notebookName ?? l10n.aiRecapAllNotebooks,
                onTap: _controller.busy ? null : _pickNotebook,
              ),
            AiNavTile(
              icon: FontAwesomeIcons.masksTheater,
              title: l10n.aiRecapPersona,
              subtitle: '${persona.emoji} ${persona.name}',
              onTap: _controller.busy ? null : _pickPersona,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiRecapSections,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final section in AiRecapSection.values)
                    FilterChip(
                      label: Text(aiRecapSectionLabel(l10n, section)),
                      selected: _sections.contains(section),
                      onSelected: _controller.busy
                          ? null
                          : (bool on) => setState(() {
                              if (on) {
                                _sections.add(section);
                              } else if (_sections.length > 1) {
                                _sections.remove(section);
                              }
                            }),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _controller,
            _controller.run,
          ]),
          builder: (BuildContext context, Widget? child) =>
              _buildResult(context, colors, theme),
        ),
        if (recaps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          SettingsCardGroup(
            title: l10n.aiRecapHistory,
            children: <Widget>[
              for (final row in recaps.take(20)) AiRecapTile(row: row),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final l10n = context.l10n;
    final controller = _controller;
    final run = controller.run;
    final busy = controller.busy;
    final button = Align(
      child: busy
          ? OutlinedButton.icon(
              onPressed: controller.stop,
              icon: const FaIcon(FontAwesomeIcons.stop, size: 14),
              label: Text(l10n.aiPanelStop),
            )
          : FilledButton.icon(
              onPressed: () => unawaited(_generate()),
              icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 14),
              label: Text(
                controller.phase == AiRecapPhase.done
                    ? l10n.aiReplyRegenerate
                    : l10n.aiRecapGenerate,
              ),
            ),
    );
    final status = switch (controller.phase) {
      AiRecapPhase.reading => l10n.aiRecapReading(
        controller.chunkIndex,
        controller.chunkTotal,
      ),
      AiRecapPhase.writing when !run.hasText =>
        run.reasoning.isEmpty ? l10n.aiRecapWriting : l10n.aiPanelThinking,
      _ => null,
    };
    final message = switch (controller.phase) {
      AiRecapPhase.empty => l10n.aiRecapNoEntries,
      AiRecapPhase.stopped => l10n.aiRecapStopped,
      _ => null,
    };
    final showText =
        run.hasText &&
        (controller.phase == AiRecapPhase.writing ||
            controller.phase == AiRecapPhase.done);
    final done = controller.phase == AiRecapPhase.done;
    final text = run.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        button,
        if (status != null) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const ExpressiveLoadingIndicator(size: 20),
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
        ],
        if (message != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (controller.phase == AiRecapPhase.failed &&
            controller.error != null) ...<Widget>[
          const SizedBox(height: 16),
          AiErrorView(
            error: controller.error!,
            onRetry: () => unawaited(_generate()),
          ),
        ],
        if (showText) ...<Widget>[
          const SizedBox(height: 16),
          AiRecapResultView(
            markdown: text,
            stats: controller.stats,
            reasoning: ref.watch(aiPreferencesProvider).showReasoning
                ? run.reasoning
                : '',
            onCitation: _openCitation,
            actions: done
                ? <Widget>[
                    AiRecapAction(
                      icon: FontAwesomeIcons.copy,
                      label: l10n.aiPanelCopy,
                      onPressed: () => unawaited(copyAiText(context, text)),
                    ),
                    AiRecapAction(
                      icon: FontAwesomeIcons.shareNodes,
                      label: l10n.aiRecapShare,
                      onPressed: () => unawaited(shareAiText(context, text)),
                    ),
                    AiRecapAction(
                      icon: FontAwesomeIcons.filePen,
                      label: l10n.aiRecapSaveAsDiary,
                      onPressed: () => unawaited(
                        saveAiTextAsDiary(
                          context,
                          ref,
                          title: l10n.aiRecapDiaryTitle(
                            aiRecapRangeText(l10n, _range()),
                          ),
                          markdown: text,
                          notebookId: ref
                              .read(aiPreferencesProvider)
                              .recapNotebookId,
                        ),
                      ),
                    ),
                  ]
                : const <Widget>[],
          ),
        ],
      ],
    );
  }
}

/// 日记本面板（只负责挑选）：全部日记 + 可见的日记本（按树序缩进）。
class _NotebookSheet extends StatelessWidget {
  const _NotebookSheet({required this.candidates, required this.selected});

  final List<NotebookView> candidates;
  final AiRecapScope selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget tile({
      required FaIconData icon,
      required String title,
      required bool checked,
      required AiRecapScope value,
      int depth = 0,
    }) => ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: 24.0 + depth * 20,
        end: 16,
      ),
      leading: FaIcon(icon, size: 16, color: colors.primary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: checked
          ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(value),
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.aiRecapNotebookPick,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            tile(
              icon: FontAwesomeIcons.layerGroup,
              title: l10n.aiRecapAllNotebooks,
              checked: selected.isAll,
              value: const AiRecapScope.all(),
            ),
            for (final view in candidates)
              tile(
                icon: view.kind == NotebookKind.smart
                    ? FontAwesomeIcons.wandMagicSparkles
                    : view.icon.data,
                title: view.name,
                checked: selected.notebookId == view.id,
                value: AiRecapScope.notebook(
                  notebookId: view.id,
                  notebookName: view.name,
                ),
                depth: view.depth,
              ),
          ],
        ),
      ),
    );
  }
}

/// 一份已保存的回顾（回顾页末尾与 AI 助手主页共用）：范围与日记本，下一行
/// 摘录；点按打开。
class AiRecapTile extends StatelessWidget {
  const AiRecapTile({super.key, required this.row});

  final AiResultRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final decoded = AiRecapScope.decode(row.scope);
    final preset = decoded.preset;
    final heading = [
      if (preset != null && preset != AiRecapPreset.custom)
        aiRecapPresetLabel(l10n, preset),
      row.title,
      ?decoded.scope.notebookName,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return AiNavTile(
      icon: FontAwesomeIcons.calendarCheck,
      title: heading,
      subtitle: aiRecapExcerpt(row.content),
      onTap: () => unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => AiRecapViewPage(resultId: row.resultId),
          ),
        ),
      ),
    );
  }
}

/// 回顾的一行摘录：去掉 Markdown 标记与引用编号，压成一行。
String aiRecapExcerpt(String markdown, {int max = 80}) {
  final plain = markdown
      .replaceAll(RegExp(r'\[\s*D\d{1,3}(?:\s*[,，、]\s*D\d{1,3})*\s*\]'), '')
      .replaceAll(
        RegExp(r'^\s{0,3}(?:#{1,6}|[-*+]|\d+[.)]|>)\s*', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'[*_`~]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.length <= max ? plain : '${plain.substring(0, max)}…';
}
