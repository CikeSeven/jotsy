import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/widgets/publish_diary_preview.dart';
import '../models/diary_template.dart';
import '../models/diary_template_selection.dart';
import '../models/diary_template_variables.dart';
import '../viewmodels/diary_template_application.dart';
import '../viewmodels/diary_template_variable_values.dart';
import '../widgets/diary_template_preset_summary.dart';

/// 模板面板的预览步：按这篇日记的日期把变量替换好，用与发布页相同的只读
/// 预览（同一套正文排版）展示标题与正文，下方列出预设；用到“今日一问”时
/// 可以换一题。“使用这个模板”带着换题偏移返回。
class DiaryTemplatePickerPreview extends StatefulWidget {
  const DiaryTemplatePickerPreview({
    super.key,
    required this.template,
    required this.diaryDate,
    required this.onBack,
    required this.onUse,
  });

  final DiaryTemplate template;
  final DateTime diaryDate;
  final VoidCallback onBack;
  final ValueChanged<DiaryTemplateSelection> onUse;

  @override
  State<DiaryTemplatePickerPreview> createState() =>
      _DiaryTemplatePickerPreviewState();
}

class _DiaryTemplatePickerPreviewState
    extends State<DiaryTemplatePickerPreview> {
  int _questionShift = 0;

  bool get _usesQuestion {
    final variables = <DiaryTemplateVariable>{
      ...diaryTemplateVariablesIn(widget.template.titlePattern),
      ...diaryTemplateVariablesIn(widget.template.bodyJson),
    };
    return variables.contains(DiaryTemplateVariable.question);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final application = DiaryTemplateApplication.resolve(
      widget.template,
      DiaryTemplateVariableValues.compute(
        l10n: l10n,
        diaryDate: widget.diaryDate,
        now: DateTime.now(),
        questionShift: _questionShift,
      ),
    );
    final bodyJson = jsonEncode(application.document);
    final name = widget.template.name.isEmpty
        ? l10n.diaryTemplateUntitled
        : widget.template.name;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.l,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.commonBack,
                onPressed: widget.onBack,
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // 不接面板的拖动控制器：列表与预览切换时两者会短暂同时挂载，同一个
          // 控制器不能挂两处。预览里拖动只滚动内容，收起面板用顶部拖动条。
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l,
            ),
            children: <Widget>[
              Text(
                l10n.diaryTemplatePickerPreviewHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              DiaryTemplatePresetSummary(
                template: widget.template,
                padding: const EdgeInsets.only(top: AppSpacing.m),
              ),
              const SizedBox(height: AppSpacing.m),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ExpressiveSurfaces.cardColor(colorScheme),
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  border: Border.fromBorderSide(
                    ExpressiveSurfaces.cardBorderSide(colorScheme),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  child: PublishDiaryPreview(
                    // 换题后正文变了：按内容换 key，让预览重新解析文档。
                    key: ValueKey<String>('${application.title}|$bodyJson'),
                    draft: NewDiaryDraft(
                      title: application.title,
                      contentDocJson: bodyJson,
                      contentText: '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.l + bottomInset,
          ),
          child: Row(
            children: <Widget>[
              if (_usesQuestion) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: () => setState(() => _questionShift++),
                  icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
                  label: Text(l10n.diaryTemplatePickerShuffle),
                ),
                const SizedBox(width: AppSpacing.s),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onUse(
                    DiaryTemplateSelection(
                      widget.template,
                      questionShift: _questionShift,
                    ),
                  ),
                  child: Text(l10n.diaryTemplatePickerUse),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
