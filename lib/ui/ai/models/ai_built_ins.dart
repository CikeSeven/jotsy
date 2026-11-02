// 内置人设与内置写作指令。
//
// 名称、说明与提示词都来自 ARB：界面上显示用界面语言的 l10n，发给模型的
// 提示词用“输出语言”对应的 l10n（见 `AiPromptLocale`），所以这里的函数都
// 显式接收 l10n，而不是从 context 取。内置项的默认内容从不落盘；用户改写
// 内置指令的提示词只存差异（`AiPreferences.actionPrompts`），删除改写即
// 恢复默认。

import 'package:meta/meta.dart';

import '../../../l10n/app_localizations_gen.dart';
import 'ai_preference_parts.dart';
import 'ai_preferences.dart';

/// 内置人设。
enum AiBuiltInPersona {
  assistant('🤖'),
  listener('🫶'),
  friend('😊'),
  coach('🌱'),
  analyst('🧭'),
  counselor('🪴'),
  poet('🌙'),
  philosopher('🦉'),
  futureSelf('🕰️'),
  roast('🌶️');

  const AiBuiltInPersona(this.emoji);

  final String emoji;

  String get id => 'builtin.$name';

  static AiBuiltInPersona? fromId(String id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    assistant => l10n.aiPersonaAssistantName,
    listener => l10n.aiPersonaListenerName,
    friend => l10n.aiPersonaFriendName,
    coach => l10n.aiPersonaCoachName,
    analyst => l10n.aiPersonaAnalystName,
    counselor => l10n.aiPersonaCounselorName,
    poet => l10n.aiPersonaPoetName,
    philosopher => l10n.aiPersonaPhilosopherName,
    futureSelf => l10n.aiPersonaFutureSelfName,
    roast => l10n.aiPersonaRoastName,
  };

  String description(AppLocalizations l10n) => switch (this) {
    assistant => l10n.aiPersonaAssistantDesc,
    listener => l10n.aiPersonaListenerDesc,
    friend => l10n.aiPersonaFriendDesc,
    coach => l10n.aiPersonaCoachDesc,
    analyst => l10n.aiPersonaAnalystDesc,
    counselor => l10n.aiPersonaCounselorDesc,
    poet => l10n.aiPersonaPoetDesc,
    philosopher => l10n.aiPersonaPhilosopherDesc,
    futureSelf => l10n.aiPersonaFutureSelfDesc,
    roast => l10n.aiPersonaRoastDesc,
  };

  String prompt(AppLocalizations l10n) => switch (this) {
    assistant => l10n.aiPersonaAssistantPrompt,
    listener => l10n.aiPersonaListenerPrompt,
    friend => l10n.aiPersonaFriendPrompt,
    coach => l10n.aiPersonaCoachPrompt,
    analyst => l10n.aiPersonaAnalystPrompt,
    counselor => l10n.aiPersonaCounselorPrompt,
    poet => l10n.aiPersonaPoetPrompt,
    philosopher => l10n.aiPersonaPhilosopherPrompt,
    futureSelf => l10n.aiPersonaFutureSelfPrompt,
    roast => l10n.aiPersonaRoastPrompt,
  };

  /// 各用途的默认人设：回应用倾听者，对话与回顾用中性的助理。
  static AiBuiltInPersona defaultFor(AiPersonaUse use) => switch (use) {
    AiPersonaUse.reply => listener,
    AiPersonaUse.chat => assistant,
    AiPersonaUse.recap => assistant,
  };
}

/// 解析后的一个人设（内置或自建），界面与提示词构建共用。
@immutable
class AiPersonaInfo {
  const AiPersonaInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.prompt,
    this.description = '',
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String prompt;
  final String description;
  final bool builtIn;
}

/// 可选的人设：内置（未隐藏）在前，自建在后。[l10n] 决定名称与提示词的
/// 语言；[includeHidden] 用于设置页列出全部内置人设。
List<AiPersonaInfo> aiPersonas(
  AppLocalizations l10n,
  AiPreferences prefs, {
  bool includeHidden = false,
}) {
  return <AiPersonaInfo>[
    for (final persona in AiBuiltInPersona.values)
      if (includeHidden || !prefs.hiddenPersonas.contains(persona.id))
        AiPersonaInfo(
          id: persona.id,
          name: persona.label(l10n),
          emoji: persona.emoji,
          prompt: persona.prompt(l10n),
          description: persona.description(l10n),
          builtIn: true,
        ),
    for (final persona in prefs.personas)
      AiPersonaInfo(
        id: persona.id,
        name: persona.name,
        emoji: persona.emoji,
        prompt: persona.prompt,
      ),
  ];
}

/// 按 id 找人设；找不到（被删）时回到该用途的内置默认。
AiPersonaInfo aiPersonaById(
  AppLocalizations l10n,
  AiPreferences prefs,
  String? id, {
  AiPersonaUse use = AiPersonaUse.chat,
}) {
  if (id != null) {
    final builtIn = AiBuiltInPersona.fromId(id);
    if (builtIn != null) {
      return AiPersonaInfo(
        id: builtIn.id,
        name: builtIn.label(l10n),
        emoji: builtIn.emoji,
        prompt: builtIn.prompt(l10n),
        description: builtIn.description(l10n),
        builtIn: true,
      );
    }
    final custom = prefs.customPersona(id);
    if (custom != null) {
      return AiPersonaInfo(
        id: custom.id,
        name: custom.name,
        emoji: custom.emoji,
        prompt: custom.prompt,
      );
    }
  }
  final fallback = AiBuiltInPersona.defaultFor(use);
  return aiPersonaById(l10n, prefs, fallback.id);
}

/// 某用途当前选中的人设。
AiPersonaInfo aiPersonaFor(
  AppLocalizations l10n,
  AiPreferences prefs,
  AiPersonaUse use,
) => aiPersonaById(l10n, prefs, prefs.personaFor[use], use: use);

/// 写作指令作用在哪段文字上。
enum AiActionScope {
  /// 光标前的内容（续写）。
  beforeCaret,

  /// 选中的文字；没有选区时退回当前段落。
  selection,
}

/// 内置写作指令。
enum AiWritingAction {
  continueWriting('✍️', AiActionOutput.insertBelow, AiActionScope.beforeCaret),
  polish('✨', AiActionOutput.replace, AiActionScope.selection),
  expand('🌿', AiActionOutput.replace, AiActionScope.selection),
  shorten('✂️', AiActionOutput.replace, AiActionScope.selection),
  proofread('🔍', AiActionOutput.replace, AiActionScope.selection),
  toneFormal('👔', AiActionOutput.replace, AiActionScope.selection),
  toneCasual('☕', AiActionOutput.replace, AiActionScope.selection),
  toneWarm('🌤️', AiActionOutput.replace, AiActionScope.selection),
  toneHumor('😄', AiActionOutput.replace, AiActionScope.selection),
  toneLiterary('📖', AiActionOutput.replace, AiActionScope.selection),
  translate('🌐', AiActionOutput.insertBelow, AiActionScope.selection),
  summarize('📝', AiActionOutput.insertBelow, AiActionScope.selection),
  bulletPoints('📌', AiActionOutput.replace, AiActionScope.selection),
  extractTodos('✅', AiActionOutput.insertBelow, AiActionScope.selection),
  poem('🎐', AiActionOutput.insertBelow, AiActionScope.selection);

  const AiWritingAction(this.emoji, this.output, this.scope);

  final String emoji;
  final AiActionOutput output;
  final AiActionScope scope;

  String get id => 'builtin.$name';

  static AiWritingAction? fromId(String id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    continueWriting => l10n.aiActionContinue,
    polish => l10n.aiActionPolish,
    expand => l10n.aiActionExpand,
    shorten => l10n.aiActionShorten,
    proofread => l10n.aiActionProofread,
    toneFormal => l10n.aiActionToneFormal,
    toneCasual => l10n.aiActionToneCasual,
    toneWarm => l10n.aiActionToneWarm,
    toneHumor => l10n.aiActionToneHumor,
    toneLiterary => l10n.aiActionToneLiterary,
    translate => l10n.aiActionTranslate,
    summarize => l10n.aiActionSummarize,
    bulletPoints => l10n.aiActionBulletPoints,
    extractTodos => l10n.aiActionExtractTodos,
    poem => l10n.aiActionPoem,
  };

  String defaultPrompt(AppLocalizations l10n) => switch (this) {
    continueWriting => l10n.aiActionContinuePrompt,
    polish => l10n.aiActionPolishPrompt,
    expand => l10n.aiActionExpandPrompt,
    shorten => l10n.aiActionShortenPrompt,
    proofread => l10n.aiActionProofreadPrompt,
    toneFormal => l10n.aiActionToneFormalPrompt,
    toneCasual => l10n.aiActionToneCasualPrompt,
    toneWarm => l10n.aiActionToneWarmPrompt,
    toneHumor => l10n.aiActionToneHumorPrompt,
    toneLiterary => l10n.aiActionToneLiteraryPrompt,
    translate => l10n.aiActionTranslatePrompt,
    summarize => l10n.aiActionSummarizePrompt,
    bulletPoints => l10n.aiActionBulletPointsPrompt,
    extractTodos => l10n.aiActionExtractTodosPrompt,
    poem => l10n.aiActionPoemPrompt,
  };
}

/// 解析后的一个写作指令（内置或自建）。
@immutable
class AiActionInfo {
  const AiActionInfo({
    required this.id,
    required this.label,
    required this.emoji,
    required this.prompt,
    required this.output,
    this.scope = AiActionScope.selection,
    this.builtIn = false,
    this.customized = false,
  });

  final String id;
  final String label;
  final String emoji;

  /// 提示词（内置指令为改写后的或默认的；自建为用户写的）。
  final String prompt;
  final AiActionOutput output;
  final AiActionScope scope;
  final bool builtIn;

  /// 内置指令的提示词被用户改过。
  final bool customized;
}

/// 全部写作指令，按用户排序（没排过的按默认顺序接在后面）。
/// [labels] 决定名称的语言，[prompts] 决定默认提示词的语言。
List<AiActionInfo> aiWritingActions(
  AppLocalizations labels,
  AppLocalizations prompts,
  AiPreferences prefs, {
  bool includeHidden = false,
}) {
  final all = <String, AiActionInfo>{
    for (final action in AiWritingAction.values)
      action.id: AiActionInfo(
        id: action.id,
        label: action.label(labels),
        emoji: action.emoji,
        prompt: prefs.actionPrompts[action.id] ?? action.defaultPrompt(prompts),
        output: action.output,
        scope: action.scope,
        builtIn: true,
        customized: prefs.actionPrompts.containsKey(action.id),
      ),
    for (final action in prefs.customActions)
      action.id: AiActionInfo(
        id: action.id,
        label: action.name,
        emoji: action.emoji,
        prompt: action.prompt,
        output: action.output,
      ),
  };
  final ordered = <AiActionInfo>[
    for (final id in prefs.actionOrder)
      if (all.remove(id) case final action?) action,
    ...all.values,
  ];
  return [
    for (final action in ordered)
      if (includeHidden || !prefs.hiddenActions.contains(action.id)) action,
  ];
}
