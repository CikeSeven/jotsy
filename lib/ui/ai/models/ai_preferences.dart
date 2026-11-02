// AI 助手的偏好（设置 → AI 助手）。
//
// 职责：描述各模块开关、人设、写作指令、关于我与文风、输出、隐私、图片、
// 回应 / 灵感 / 回顾 / 对话的设置。不含任何密钥与服务商——那些只在本机的
// `AiProviderStore`。
//
// 存储：单个 JSON 设置键 `app.settings.ai_prefs`（经
// `SettingsService.setAiPrefsRaw`），随完整备份导出（字段 `aiPrefsRaw`）、
// 导入失败随设置快照回滚、随“同步设置”同步。稀疏写出：只写与默认不同的
// 字段，与默认完全相同时删除该键；读取逐字段容错，类型不对只让那一项回到
// 默认，认不出的字段忽略。

import 'dart:convert';

import 'package:meta/meta.dart';

import 'ai_preference_parts.dart';
import 'ai_privacy_options.dart';

@immutable
class AiPreferences {
  const AiPreferences({
    this.disabledModules = const <AiModule>{},
    this.enabledOptionalModules = const <AiModule>{},
    this.personas = const <AiPersona>[],
    this.hiddenPersonas = const <String>{},
    this.personaFor = const <AiPersonaUse, String>{},
    this.actionOrder = const <String>[],
    this.hiddenActions = const <String>{},
    this.actionPrompts = const <String, String>{},
    this.customActions = const <AiCustomAction>[],
    this.aboutMe = '',
    this.writingStyle = '',
    this.language = AiOutputLanguage.followDiary,
    this.customLanguage = '',
    this.length = AiResponseLength.medium,
    this.creativity = AiCreativity.balanced,
    this.privacy = AiPrivacyOptions.defaults,
    this.visionMaxImages = defaultVisionMaxImages,
    this.visionMaxSide = defaultVisionMaxSide,
    this.autoReply = false,
    this.promptsStrip = true,
    this.promptStyle = AiPromptInsertStyle.callout,
    this.promptsUseRecent = false,
    this.recapSections = AiRecapSection.defaults,
    this.recapNotebookId,
    this.retrieval = AiRetrievalMode.smart,
    this.recentDays = defaultRecentDays,
    this.maxCitations = defaultMaxCitations,
    this.showReasoning = true,
    this.showTokens = false,
    this.autoTitle = true,
    this.titleButton = true,
    this.autoSuggestOnPublish = false,
  });

  static const AiPreferences defaults = AiPreferences();

  static const int maxPersonas = 20;
  static const int maxCustomActions = 30;
  static const int maxAboutMeLength = 1000;
  static const int maxWritingStyleLength = 500;
  static const int defaultVisionMaxImages = 3;
  static const int maxVisionImages = 6;
  static const int defaultVisionMaxSide = 1024;
  static const List<int> visionMaxSideChoices = <int>[512, 1024, 1536];
  static const int defaultRecentDays = 30;
  static const List<int> recentDaysChoices = <int>[7, 30, 90, 365];
  static const int defaultMaxCitations = 20;
  static const List<int> maxCitationsChoices = <int>[10, 20, 40, 80];

  /// 默认开启却被用户关掉的模块。
  final Set<AiModule> disabledModules;

  /// 默认关闭却被用户打开的模块（目前只有图片理解）。
  final Set<AiModule> enabledOptionalModules;

  /// 用户自建的人设（最多 [maxPersonas] 个）。
  final List<AiPersona> personas;

  /// 隐藏的内置人设 id。
  final Set<String> hiddenPersonas;

  /// 回应 / 对话 / 回顾各自默认用的人设 id；没设置时用内置默认。
  final Map<AiPersonaUse, String> personaFor;

  /// 写作指令（内置 + 自定义）的顺序；没列出的按默认顺序排在后面。
  final List<String> actionOrder;
  final Set<String> hiddenActions;

  /// 内置指令被用户改写过的提示词。
  final Map<String, String> actionPrompts;
  final List<AiCustomAction> customActions;

  /// 关于我：注入提示词，让回应更贴近自己（可空）。
  final String aboutMe;

  /// 文风偏好：写作类指令遵循的风格说明（可空）。
  final String writingStyle;

  final AiOutputLanguage language;

  /// 指定语言时的语言名（如“日本語”“English”）。
  final String customLanguage;
  final AiResponseLength length;
  final AiCreativity creativity;
  final AiPrivacyOptions privacy;

  final int visionMaxImages;
  final int visionMaxSide;

  /// 发表新日记后自动生成读后回应。
  final bool autoReply;

  /// 新建空白日记时显示写作灵感条（点了才生成）。
  final bool promptsStrip;
  final AiPromptInsertStyle promptStyle;

  /// 生成灵感时参考最近几篇日记的主题（会发送它们的摘录）。
  final bool promptsUseRecent;

  final Set<AiRecapSection> recapSections;

  /// 回顾另存为日记时默认放进的日记本；null 为不放进任何本子。
  final String? recapNotebookId;

  final AiRetrievalMode retrieval;
  final int recentDays;
  final int maxCitations;
  final bool showReasoning;
  final bool showTokens;

  /// 第一轮问答后自动给对话起标题。
  final bool autoTitle;

  /// 编辑页标题为空、正文有内容时在标题旁显示“AI 生成标题”。
  final bool titleButton;

  /// 进入发布页时自动给出标题、标签与心情的建议。
  final bool autoSuggestOnPublish;

  bool isModuleEnabled(AiModule module) => module.enabledByDefault
      ? !disabledModules.contains(module)
      : enabledOptionalModules.contains(module);

  AiPreferences withModule(AiModule module, bool enabled) {
    if (module.enabledByDefault) {
      final next = {...disabledModules};
      enabled ? next.remove(module) : next.add(module);
      return copyWith(disabledModules: next);
    }
    final next = {...enabledOptionalModules};
    enabled ? next.add(module) : next.remove(module);
    return copyWith(enabledOptionalModules: next);
  }

  AiPersona? customPersona(String id) {
    for (final persona in personas) {
      if (persona.id == id) return persona;
    }
    return null;
  }

  AiCustomAction? customAction(String id) {
    for (final action in customActions) {
      if (action.id == id) return action;
    }
    return null;
  }

  AiPreferences copyWith({
    Set<AiModule>? disabledModules,
    Set<AiModule>? enabledOptionalModules,
    List<AiPersona>? personas,
    Set<String>? hiddenPersonas,
    Map<AiPersonaUse, String>? personaFor,
    List<String>? actionOrder,
    Set<String>? hiddenActions,
    Map<String, String>? actionPrompts,
    List<AiCustomAction>? customActions,
    String? aboutMe,
    String? writingStyle,
    AiOutputLanguage? language,
    String? customLanguage,
    AiResponseLength? length,
    AiCreativity? creativity,
    AiPrivacyOptions? privacy,
    int? visionMaxImages,
    int? visionMaxSide,
    bool? autoReply,
    bool? promptsStrip,
    AiPromptInsertStyle? promptStyle,
    bool? promptsUseRecent,
    Set<AiRecapSection>? recapSections,
    Object? recapNotebookId = _unset,
    AiRetrievalMode? retrieval,
    int? recentDays,
    int? maxCitations,
    bool? showReasoning,
    bool? showTokens,
    bool? autoTitle,
    bool? titleButton,
    bool? autoSuggestOnPublish,
  }) {
    return AiPreferences(
      disabledModules: disabledModules ?? this.disabledModules,
      enabledOptionalModules:
          enabledOptionalModules ?? this.enabledOptionalModules,
      personas: personas ?? this.personas,
      hiddenPersonas: hiddenPersonas ?? this.hiddenPersonas,
      personaFor: personaFor ?? this.personaFor,
      actionOrder: actionOrder ?? this.actionOrder,
      hiddenActions: hiddenActions ?? this.hiddenActions,
      actionPrompts: actionPrompts ?? this.actionPrompts,
      customActions: customActions ?? this.customActions,
      aboutMe: aboutMe ?? this.aboutMe,
      writingStyle: writingStyle ?? this.writingStyle,
      language: language ?? this.language,
      customLanguage: customLanguage ?? this.customLanguage,
      length: length ?? this.length,
      creativity: creativity ?? this.creativity,
      privacy: privacy ?? this.privacy,
      visionMaxImages: visionMaxImages ?? this.visionMaxImages,
      visionMaxSide: visionMaxSide ?? this.visionMaxSide,
      autoReply: autoReply ?? this.autoReply,
      promptsStrip: promptsStrip ?? this.promptsStrip,
      promptStyle: promptStyle ?? this.promptStyle,
      promptsUseRecent: promptsUseRecent ?? this.promptsUseRecent,
      recapSections: recapSections ?? this.recapSections,
      recapNotebookId: identical(recapNotebookId, _unset)
          ? this.recapNotebookId
          : recapNotebookId as String?,
      retrieval: retrieval ?? this.retrieval,
      recentDays: recentDays ?? this.recentDays,
      maxCitations: maxCitations ?? this.maxCitations,
      showReasoning: showReasoning ?? this.showReasoning,
      showTokens: showTokens ?? this.showTokens,
      autoTitle: autoTitle ?? this.autoTitle,
      titleButton: titleButton ?? this.titleButton,
      autoSuggestOnPublish: autoSuggestOnPublish ?? this.autoSuggestOnPublish,
    );
  }

  /// 稀疏写出；与默认完全相同时为空对象。
  Map<String, Object?> toJson() {
    const d = defaults;
    final privacyJson = privacy.toJson();
    return <String, Object?>{
      if (disabledModules.isNotEmpty)
        'off': [for (final module in disabledModules) module.name]..sort(),
      if (enabledOptionalModules.isNotEmpty)
        'on': [for (final module in enabledOptionalModules) module.name]
          ..sort(),
      if (personas.isNotEmpty)
        'personas': [for (final persona in personas) persona.toJson()],
      if (hiddenPersonas.isNotEmpty)
        'hiddenPersonas': hiddenPersonas.toList()..sort(),
      if (personaFor.isNotEmpty)
        'personaFor': {
          for (final entry in personaFor.entries) entry.key.name: entry.value,
        },
      if (actionOrder.isNotEmpty) 'actionOrder': actionOrder,
      if (hiddenActions.isNotEmpty)
        'hiddenActions': hiddenActions.toList()..sort(),
      if (actionPrompts.isNotEmpty) 'actionPrompts': actionPrompts,
      if (customActions.isNotEmpty)
        'actions': [for (final action in customActions) action.toJson()],
      if (aboutMe.isNotEmpty) 'aboutMe': aboutMe,
      if (writingStyle.isNotEmpty) 'style': writingStyle,
      if (language != d.language) 'language': language.name,
      if (customLanguage.isNotEmpty) 'customLanguage': customLanguage,
      if (length != d.length) 'length': length.name,
      if (creativity != d.creativity) 'creativity': creativity.name,
      if (privacyJson.isNotEmpty) 'privacy': privacyJson,
      if (visionMaxImages != d.visionMaxImages) 'visionImages': visionMaxImages,
      if (visionMaxSide != d.visionMaxSide) 'visionSide': visionMaxSide,
      if (autoReply != d.autoReply) 'autoReply': autoReply,
      if (promptsStrip != d.promptsStrip) 'promptsStrip': promptsStrip,
      if (promptStyle != d.promptStyle) 'promptStyle': promptStyle.name,
      if (promptsUseRecent != d.promptsUseRecent)
        'promptsRecent': promptsUseRecent,
      if (!_sameSet(recapSections, d.recapSections))
        'recapSections': [for (final section in recapSections) section.name]
          ..sort(),
      if (recapNotebookId != null) 'recapNotebook': recapNotebookId,
      if (retrieval != d.retrieval) 'retrieval': retrieval.name,
      if (recentDays != d.recentDays) 'recentDays': recentDays,
      if (maxCitations != d.maxCitations) 'maxCitations': maxCitations,
      if (showReasoning != d.showReasoning) 'reasoning': showReasoning,
      if (showTokens != d.showTokens) 'tokens': showTokens,
      if (autoTitle != d.autoTitle) 'autoTitle': autoTitle,
      if (titleButton != d.titleButton) 'titleButton': titleButton,
      if (autoSuggestOnPublish != d.autoSuggestOnPublish)
        'autoSuggest': autoSuggestOnPublish,
    };
  }

  /// 设置原文；与默认相同时为 null（删除设置键）。
  String? encode() {
    final json = toJson();
    return json.isEmpty ? null : jsonEncode(json);
  }

  static AiPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final map = node;
    const d = defaults;

    bool read(String key, bool fallback) =>
        map[key] is bool ? map[key] as bool : fallback;
    String text(String key, int max) {
      final value = map[key];
      if (value is! String) return '';
      return value.length <= max ? value : value.substring(0, max);
    }

    int choice(String key, List<int> choices, int fallback) {
      final value = map[key];
      return value is int && choices.contains(value) ? value : fallback;
    }

    List<String> strings(String key) => <String>[
      if (map[key] case final List<Object?> list)
        for (final item in list)
          if (item is String && item.isNotEmpty) item,
    ];

    Set<AiModule> modules(String key, bool optional) => <AiModule>{
      for (final name in strings(key))
        if (AiModule.fromName(name) case final module?)
          if (module.enabledByDefault != optional) module,
    };

    final personas = <AiPersona>[];
    final personaIds = <String>{};
    if (map['personas'] case final List<Object?> list) {
      for (final item in list) {
        final persona = AiPersona.fromJson(item);
        if (persona != null &&
            personaIds.add(persona.id) &&
            personas.length < maxPersonas) {
          personas.add(persona);
        }
      }
    }
    final actions = <AiCustomAction>[];
    final actionIds = <String>{};
    if (map['actions'] case final List<Object?> list) {
      for (final item in list) {
        final action = AiCustomAction.fromJson(item);
        if (action != null &&
            actionIds.add(action.id) &&
            actions.length < maxCustomActions) {
          actions.add(action);
        }
      }
    }
    final personaFor = <AiPersonaUse, String>{
      if (map['personaFor'] case final Map<Object?, Object?> raw)
        for (final entry in raw.entries)
          if (entry.value is String && (entry.value as String).isNotEmpty)
            for (final use in AiPersonaUse.values)
              if (use.name == entry.key) use: entry.value as String,
    };
    final actionPrompts = <String, String>{
      if (map['actionPrompts'] case final Map<Object?, Object?> raw)
        for (final entry in raw.entries)
          if (entry.key is String &&
              entry.value is String &&
              (entry.value as String).trim().isNotEmpty)
            entry.key as String: entry.value as String,
    };
    final sections = <AiRecapSection>{
      for (final name in strings('recapSections'))
        for (final section in AiRecapSection.values)
          if (section.name == name) section,
    };
    final images = map['visionImages'];
    final notebook = map['recapNotebook'];

    return AiPreferences(
      disabledModules: modules('off', false),
      enabledOptionalModules: modules('on', true),
      personas: personas,
      hiddenPersonas: strings('hiddenPersonas').toSet(),
      personaFor: personaFor,
      actionOrder: strings('actionOrder'),
      hiddenActions: strings('hiddenActions').toSet(),
      actionPrompts: actionPrompts,
      customActions: actions,
      aboutMe: text('aboutMe', maxAboutMeLength),
      writingStyle: text('style', maxWritingStyleLength),
      language: enumByName(
        AiOutputLanguage.values,
        map['language'],
        d.language,
      ),
      customLanguage: text('customLanguage', 40),
      length: enumByName(AiResponseLength.values, map['length'], d.length),
      creativity: enumByName(
        AiCreativity.values,
        map['creativity'],
        d.creativity,
      ),
      privacy: AiPrivacyOptions.fromJson(map['privacy']),
      visionMaxImages: images is int && images >= 1 && images <= maxVisionImages
          ? images
          : d.visionMaxImages,
      visionMaxSide: choice(
        'visionSide',
        visionMaxSideChoices,
        d.visionMaxSide,
      ),
      autoReply: read('autoReply', d.autoReply),
      promptsStrip: read('promptsStrip', d.promptsStrip),
      promptStyle: enumByName(
        AiPromptInsertStyle.values,
        map['promptStyle'],
        d.promptStyle,
      ),
      promptsUseRecent: read('promptsRecent', d.promptsUseRecent),
      recapSections: map.containsKey('recapSections')
          ? sections
          : d.recapSections,
      recapNotebookId: notebook is String && notebook.isNotEmpty
          ? notebook
          : null,
      retrieval: enumByName(
        AiRetrievalMode.values,
        map['retrieval'],
        d.retrieval,
      ),
      recentDays: choice('recentDays', recentDaysChoices, d.recentDays),
      maxCitations: choice('maxCitations', maxCitationsChoices, d.maxCitations),
      showReasoning: read('reasoning', d.showReasoning),
      showTokens: read('tokens', d.showTokens),
      autoTitle: read('autoTitle', d.autoTitle),
      titleButton: read('titleButton', d.titleButton),
      autoSuggestOnPublish: read('autoSuggest', d.autoSuggestOnPublish),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiPreferences && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

const Object _unset = Object();

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
