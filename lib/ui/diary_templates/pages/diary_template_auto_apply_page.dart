import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/diary_templates_controller.dart';
import '../models/diary_template_auto_rule.dart';
import '../providers/diary_template_providers.dart';
import '../sections/diary_template_auto_apply_groups.dart';
import '../sections/diary_template_auto_rule_sheet.dart';
import '../sections/diary_template_choice_sheet.dart';
import '../viewmodels/diary_template_library.dart';

/// 自动套用页（模板管理页 →“自动套用”）：按时间段套用的规则与其他时间的
/// 默认模板。
///
/// 读：实时模板库（含偏好）；写：经 [DiaryTemplatesController]，每次都从设置
/// 原文重新解码，面板打开期间别处的改动不会被覆盖。删除时间段带 4 秒撤销。
/// 页面只负责组合与打开面板。
class DiaryTemplateAutoApplyPage extends ConsumerStatefulWidget {
  const DiaryTemplateAutoApplyPage({super.key});

  @override
  ConsumerState<DiaryTemplateAutoApplyPage> createState() =>
      _DiaryTemplateAutoApplyPageState();
}

class _DiaryTemplateAutoApplyPageState
    extends ConsumerState<DiaryTemplateAutoApplyPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(title: Text(l10n.diaryTemplatesAutoApply)),
      body: settings == null
          ? const DelayedLoadingIndicator()
          : _buildBody(context, settings),
    );
  }

  Widget _buildBody(BuildContext context, SettingsService settings) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = createDiaryTemplatesController(ref, settings);
    final library = watchDiaryTemplateLibrary(ref, l10n, live: true).library;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.m,
        bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Text(
            l10n.diaryTemplatesAutoApplyIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DiaryTemplateAutoRulesGroup(
          library: library,
          onEdit: (rule) => _editRule(controller, library, rule),
          onAdd: () => _editRule(controller, library, null),
        ),
        // 分组间距与设置二级页一致。
        const SizedBox(height: AppSpacing.l),
        DiaryTemplateAutoDefaultGroup(
          library: library,
          onTap: () => _pickDefault(controller, library),
        ),
        // 与分组卡片的附注对齐：卡片外边距 16 + 附注缩进 12。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l + AppSpacing.m,
            AppSpacing.s,
            AppSpacing.l,
            0,
          ),
          child: Text(
            l10n.diaryTemplatesAutoApplyOverlapHint,
            style: hintStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _editRule(
    DiaryTemplatesController controller,
    DiaryTemplateLibrary library,
    DiaryTemplateAutoRule? rule,
  ) async {
    final result = await showDiaryTemplateAutoRuleSheet(
      context,
      library: library,
      initial: rule,
    );
    if (result == null || !mounted) return;
    final saved = result.rule;
    if (saved != null) {
      await controller.saveAutoRule(saved, replacing: rule);
      return;
    }
    if (rule == null) return;
    final deleted = await controller.deleteAutoRule(rule);
    if (deleted == null || !mounted) return;
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: context.l10n.diaryTemplatesAutoApplyRuleDeleted,
        onUndo: () => unawaited(controller.restoreAutoRule(deleted)),
      ),
    );
  }

  Future<void> _pickDefault(
    DiaryTemplatesController controller,
    DiaryTemplateLibrary library,
  ) async {
    final l10n = context.l10n;
    final picked = await showDiaryTemplateChoiceSheet(
      context,
      library: library,
      selectedId: library.autoTemplate?.id,
      title: l10n.diaryTemplatesAutoApplyDefault,
      hint: l10n.diaryTemplatesAutoApplyHint,
    );
    if (picked == null) return;
    await controller.setAutoTemplate(picked.id);
  }
}
