// AI 模块里枚举、预设与错误到界面文案的换算。新增服务商预设时，中英文名
// 称不同的在 [aiPresetLabel] 里补一行，其余直接用品牌名。

import 'package:intl/intl.dart';

import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_provider_presets.dart';
import '../../../l10n/app_localizations_gen.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_recap_range.dart';

String aiPresetLabel(AppLocalizations l10n, AiProviderPreset preset) =>
    switch (preset.id) {
      AiPresetIds.dashscope => l10n.aiPresetNameDashscope,
      AiPresetIds.moonshot => l10n.aiPresetNameMoonshot,
      AiPresetIds.zhipu => l10n.aiPresetNameZhipu,
      AiPresetIds.volcengine => l10n.aiPresetNameVolcengine,
      AiPresetIds.siliconflow => l10n.aiPresetNameSiliconflow,
      AiPresetIds.hunyuan => l10n.aiPresetNameHunyuan,
      AiPresetIds.customOpenAi => l10n.aiPresetNameCustomOpenAi,
      AiPresetIds.customOpenAiResponses =>
        l10n.aiPresetNameCustomOpenAiResponses,
      AiPresetIds.customAnthropic => l10n.aiPresetNameCustomAnthropic,
      AiPresetIds.customGemini => l10n.aiPresetNameCustomGemini,
      _ => preset.brand,
    };

String aiPresetGroupLabel(AppLocalizations l10n, AiPresetGroup group) =>
    switch (group) {
      AiPresetGroup.china => l10n.aiPresetGroupChina,
      AiPresetGroup.international => l10n.aiPresetGroupInternational,
      AiPresetGroup.local => l10n.aiPresetGroupLocal,
      AiPresetGroup.custom => l10n.aiPresetGroupCustom,
    };

String aiProtocolLabel(AppLocalizations l10n, AiProtocol protocol) =>
    switch (protocol) {
      AiProtocol.openAi => l10n.aiProtocolOpenAi,
      AiProtocol.openAiResponses => l10n.aiProtocolOpenAiResponses,
      AiProtocol.anthropic => l10n.aiProtocolAnthropic,
      AiProtocol.gemini => l10n.aiProtocolGemini,
    };

String aiTaskLabel(AppLocalizations l10n, AiTaskKind task) => switch (task) {
  AiTaskKind.writing => l10n.aiTaskWriting,
  AiTaskKind.suggest => l10n.aiTaskSuggest,
  AiTaskKind.reply => l10n.aiTaskReply,
  AiTaskKind.prompts => l10n.aiTaskPrompts,
  AiTaskKind.recap => l10n.aiTaskRecap,
  AiTaskKind.chat => l10n.aiTaskChat,
  AiTaskKind.vision => l10n.aiTaskVision,
  AiTaskKind.utility => l10n.aiTaskUtility,
};

String aiModuleLabel(AppLocalizations l10n, AiModule module) =>
    switch (module) {
      AiModule.writing => l10n.aiModuleWriting,
      AiModule.suggest => l10n.aiModuleSuggest,
      AiModule.reply => l10n.aiModuleReply,
      AiModule.prompts => l10n.aiModulePrompts,
      AiModule.recap => l10n.aiModuleRecap,
      AiModule.chat => l10n.aiModuleChat,
      AiModule.vision => l10n.aiModuleVision,
    };

String aiModuleSubtitle(AppLocalizations l10n, AiModule module) =>
    switch (module) {
      AiModule.writing => l10n.aiModuleWritingSubtitle,
      AiModule.suggest => l10n.aiModuleSuggestSubtitle,
      AiModule.reply => l10n.aiModuleReplySubtitle,
      AiModule.prompts => l10n.aiModulePromptsSubtitle,
      AiModule.recap => l10n.aiModuleRecapSubtitle,
      AiModule.chat => l10n.aiModuleChatSubtitle,
      AiModule.vision => l10n.aiModuleVisionSubtitle,
    };

String aiPersonaUseLabel(AppLocalizations l10n, AiPersonaUse use) =>
    switch (use) {
      AiPersonaUse.reply => l10n.aiPersonaUseReply,
      AiPersonaUse.chat => l10n.aiPersonaUseChat,
      AiPersonaUse.recap => l10n.aiPersonaUseRecap,
    };

String aiRecapSectionLabel(AppLocalizations l10n, AiRecapSection section) =>
    switch (section) {
      AiRecapSection.mood => l10n.aiRecapSectionMood,
      AiRecapSection.events => l10n.aiRecapSectionEvents,
      AiRecapSection.people => l10n.aiRecapSectionPeople,
      AiRecapSection.gratitude => l10n.aiRecapSectionGratitude,
      AiRecapSection.growth => l10n.aiRecapSectionGrowth,
      AiRecapSection.quotes => l10n.aiRecapSectionQuotes,
      AiRecapSection.suggestions => l10n.aiRecapSectionSuggestions,
    };

String aiOutputLabel(AppLocalizations l10n, AiActionOutput output) =>
    switch (output) {
      AiActionOutput.replace => l10n.aiOutputReplace,
      AiActionOutput.insertBelow => l10n.aiOutputInsertBelow,
      AiActionOutput.preview => l10n.aiOutputPreview,
    };

/// 用户看得懂的错误说明。
String aiFailureMessage(AppLocalizations l10n, AiFailureKind kind) =>
    switch (kind) {
      AiFailureKind.notConfigured => l10n.aiErrorNotConfigured,
      AiFailureKind.network => l10n.aiErrorNetwork,
      AiFailureKind.timeout => l10n.aiErrorTimeout,
      AiFailureKind.unauthorized => l10n.aiErrorUnauthorized,
      AiFailureKind.forbidden => l10n.aiErrorForbidden,
      AiFailureKind.modelNotFound => l10n.aiErrorModelNotFound,
      AiFailureKind.rateLimited => l10n.aiErrorRateLimited,
      AiFailureKind.quota => l10n.aiErrorQuota,
      AiFailureKind.contextTooLong => l10n.aiErrorContextTooLong,
      AiFailureKind.contentFiltered => l10n.aiErrorContentFiltered,
      AiFailureKind.badRequest => l10n.aiErrorBadRequest,
      AiFailureKind.server => l10n.aiErrorServer,
      AiFailureKind.badResponse => l10n.aiErrorBadResponse,
      AiFailureKind.cancelled => l10n.aiErrorCancelled,
    };

/// 任意异常的说明（非 [AiException] 一律按网络问题说明）。
String aiErrorMessage(AppLocalizations l10n, Object error) => aiFailureMessage(
  l10n,
  error is AiException ? error.kind : AiFailureKind.network,
);

/// 错误的原文细节，给“查看详情”。
String? aiErrorDetail(Object error) {
  if (error is! AiException) return '$error';
  final parts = <String>[
    if (error.statusCode != null) 'HTTP ${error.statusCode}',
    if (error.providerMessage != null) error.providerMessage!,
    if (error.detail != null) error.detail!,
  ];
  return parts.isEmpty ? null : parts.join('\n');
}

/// 失败是否值得引导用户去设置页（密钥、模型、地址、额度这类配置问题）。
bool aiErrorNeedsSettings(Object error) {
  if (error is! AiException) return false;
  return switch (error.kind) {
    AiFailureKind.notConfigured ||
    AiFailureKind.unauthorized ||
    AiFailureKind.forbidden ||
    AiFailureKind.modelNotFound ||
    AiFailureKind.badRequest ||
    AiFailureKind.badResponse => true,
    _ => false,
  };
}

/// 模型的显示名：`服务商 / 模型`。
String aiModelDisplay(AiResolvedModel model) =>
    '${model.provider.name} / ${model.model.label}';

/// token 数的紧凑写法（1234 → 1.2k，1234567 → 1.2M）。
String aiCompactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    return '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)}k';
  }
  return '${(value / 1000000).toStringAsFixed(1)}M';
}

/// 回顾预设的名称。
String aiRecapPresetLabel(AppLocalizations l10n, AiRecapPreset preset) =>
    switch (preset) {
      AiRecapPreset.thisWeek => l10n.aiRecapThisWeek,
      AiRecapPreset.lastWeek => l10n.aiRecapLastWeek,
      AiRecapPreset.thisMonth => l10n.aiRecapThisMonth,
      AiRecapPreset.lastMonth => l10n.aiRecapLastMonth,
      AiRecapPreset.thisYear => l10n.aiRecapThisYear,
      AiRecapPreset.custom => l10n.aiRecapCustom,
    };

/// 回顾范围的日期写法：`2026年11月2日 – 11月8日`（一天时只写一个日期）。
String aiRecapRangeText(AppLocalizations l10n, AiRecapRange range) {
  final first = range.start;
  final last = range.lastDay;
  final full = DateFormat.yMMMd(l10n.localeName);
  if (first == last) return full.format(first);
  final end = first.year == last.year
      ? DateFormat.MMMd(l10n.localeName).format(last)
      : full.format(last);
  return l10n.aiRecapPeriodRange(full.format(first), end);
}

/// 思考强度在界面上的名称（null 为“自动”）。
String aiThinkingLevelLabel(AppLocalizations l10n, AiThinkingLevel? level) =>
    switch (level) {
      null => l10n.aiThinkingAuto,
      AiThinkingLevel.off => l10n.aiThinkingOff,
      AiThinkingLevel.low => l10n.aiThinkingLow,
      AiThinkingLevel.medium => l10n.aiThinkingMedium,
      AiThinkingLevel.high => l10n.aiThinkingHigh,
    };
