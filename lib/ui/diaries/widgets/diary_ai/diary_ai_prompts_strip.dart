// 写作灵感（DESIGN.md §5.29）：新建空白日记时标题下的一条，与模板建议条
// 同一位置、排在它后面；以及 `/` 菜单与 ⋮ 菜单打开的面板。
//
// 灵感条状态：收起（一枚“来点写作灵感”胶囊）→ 生成中 → 几个问题（点一个
// 插进正文；“换一批”重新生成）。标题或正文有字后整条收起（不再打扰）；
// 用户也可以点 × 收起，本次编辑不再出现。只在点了之后才请求。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../controllers/diary_editor_controller.dart';

class DiaryAiPromptsStrip extends StatefulWidget {
  const DiaryAiPromptsStrip({
    super.key,
    required this.title,
    required this.content,
    required this.onGenerate,
    required this.onPick,
    this.busy = false,
  });

  final TextEditingController title;
  final DiaryEditorController content;

  /// 生成问题；取消或失败为 null。
  final Future<List<String>?> Function() onGenerate;
  final ValueChanged<String> onPick;
  final bool busy;

  @override
  State<DiaryAiPromptsStrip> createState() => _DiaryAiPromptsStripState();
}

class _DiaryAiPromptsStripState extends State<DiaryAiPromptsStrip> {
  List<String>? _prompts;
  bool _loading = false;
  bool _dismissed = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final prompts = await widget.onGenerate();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (prompts != null && prompts.isNotEmpty) _prompts = prompts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[widget.title, widget.content]),
      builder: (BuildContext context, Widget? child) {
        final empty =
            widget.title.text.trim().isEmpty && !widget.content.hasContent;
        final visible = empty && !_dismissed;
        return AnimatedSize(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topLeft,
          child: visible
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _buildBody(context),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prompts = _prompts;
    if (prompts == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: _loading
              ? const ExpressiveLoadingIndicator(size: 16)
              : FaIcon(
                  FontAwesomeIcons.lightbulb,
                  size: 14,
                  color: colors.primary,
                ),
          label: Text(
            _loading ? l10n.aiPromptsLoading : l10n.aiPromptsStripLabel,
          ),
          onPressed: _loading || widget.busy ? null : _generate,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(FontAwesomeIcons.lightbulb, size: 14, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.aiPromptsHint,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: _loading || widget.busy ? null : _generate,
              child: Text(l10n.aiPromptsRefresh),
            ),
            IconButton(
              tooltip: l10n.aiPromptsClose,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _dismissed = true),
              icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final prompt in prompts)
              ActionChip(
                label: Text(prompt, maxLines: 3),
                onPressed: widget.busy ? null : () => widget.onPick(prompt),
              ),
          ],
        ),
      ],
    );
  }
}

/// `/` 菜单与 ⋮ 菜单的写作灵感面板（只负责挑选）：打开即生成，点一个
/// 问题返回它；“换一批”重新生成。
Future<String?> showDiaryAiPromptsSheet(
  BuildContext context, {
  required Future<List<String>?> Function() generate,
}) {
  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext sheetContext) => _PromptsSheet(generate: generate),
  );
}

class _PromptsSheet extends StatefulWidget {
  const _PromptsSheet({required this.generate});

  final Future<List<String>?> Function() generate;

  @override
  State<_PromptsSheet> createState() => _PromptsSheetState();
}

class _PromptsSheetState extends State<_PromptsSheet> {
  List<String>? _prompts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prompts = await widget.generate();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _prompts = prompts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prompts = _prompts ?? const <String>[];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.aiPromptsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _load,
                    child: Text(l10n.aiPromptsRefresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    const ExpressiveLoadingIndicator(size: 32),
                    const SizedBox(height: 12),
                    Text(
                      l10n.aiPromptsLoading,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else if (prompts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.aiPromptsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final prompt in prompts)
                ListTile(
                  titleAlignment: ListTileTitleAlignment.center,
                  leading: FaIcon(
                    FontAwesomeIcons.lightbulb,
                    size: 14,
                    color: colors.primary,
                  ),
                  title: Text(prompt),
                  onTap: () => Navigator.of(context).pop(prompt),
                ),
            if (!_loading && prompts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  l10n.aiPromptsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
