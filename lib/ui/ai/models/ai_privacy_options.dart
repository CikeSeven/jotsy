import 'package:meta/meta.dart';

import 'ai_preference_parts.dart';

/// 发给 AI 的内容范围。私密日记本、回收站与未解封的胶囊在数据库层就被
/// 排除（`getAiContextDiaries`），这里只管用户还能再收紧的部分。
@immutable
class AiPrivacyOptions {
  const AiPrivacyOptions({
    this.sendDate = true,
    this.sendMood = true,
    this.sendTags = true,
    this.sendWeather = true,
    this.sendLocation = false,
    this.excludedNotebookIds = const <String>{},
    this.excludedTagNames = const <String>{},
    this.contextBudget = defaultContextBudget,
    this.includeArchived = true,
    this.confirm = AiConfirmMode.multiDiary,
    this.allowPrivate = false,
  });

  static const AiPrivacyOptions defaults = AiPrivacyOptions();

  /// 一次请求最多发送的日记字数（`TextStats` 口径）。这是唯一的上限：
  /// 每篇日记都整篇发送，只有总数超过它时，放不下的那篇才截到剩余字数
  /// （多篇上下文、回顾的每一块、单篇操作都按它）。
  ///
  /// 默认 10 万字：主流模型的上下文已在 128K token 以上（很多是 1M），
  /// 10 万个汉字在常见分词器下约 6–13 万 token，128K 的模型也放得下；
  /// 想把更多日记一次交给 1M 上下文的模型时可调到 100 万字。
  static const int defaultContextBudget = 100000;
  static const List<int> contextBudgetChoices = <int>[
    10000,
    20000,
    50000,
    100000,
    200000,
    500000,
    1000000,
  ];

  /// 旧版的档位（当时最高 96000 字）。读到它们时换成最接近的新档位，
  /// 用户调过的设置不至于退回默认；其余不认识的值仍按默认。
  static const List<int> _legacyContextBudgets = <int>[
    8000,
    16000,
    24000,
    48000,
    96000,
  ];

  static int _readContextBudget(Object? value) {
    if (value is! int) return defaultContextBudget;
    if (contextBudgetChoices.contains(value)) return value;
    if (!_legacyContextBudgets.contains(value)) return defaultContextBudget;
    var best = contextBudgetChoices.first;
    for (final choice in contextBudgetChoices) {
      if ((choice - value).abs() < (best - value).abs()) best = choice;
    }
    return best;
  }

  final bool sendDate;
  final bool sendMood;
  final bool sendTags;
  final bool sendWeather;

  /// 地点默认不发（最敏感的元数据）。
  final bool sendLocation;

  /// 不参与多篇上下文（对话、回顾）的日记本（业务 id）。
  final Set<String> excludedNotebookIds;

  /// 带这些标签的日记不参与多篇上下文（按名称，跨设备可用）。
  final Set<String> excludedTagNames;

  final int contextBudget;

  /// 多篇上下文是否包含已归档的日记。
  final bool includeArchived;

  final AiConfirmMode confirm;

  /// 允许对私密日记本里的日记使用单篇 AI 功能（写作、回应）。关闭时这些
  /// 日记的 AI 入口不出现。多篇上下文无论如何都不含私密日记。
  final bool allowPrivate;

  AiPrivacyOptions copyWith({
    bool? sendDate,
    bool? sendMood,
    bool? sendTags,
    bool? sendWeather,
    bool? sendLocation,
    Set<String>? excludedNotebookIds,
    Set<String>? excludedTagNames,
    int? contextBudget,
    bool? includeArchived,
    AiConfirmMode? confirm,
    bool? allowPrivate,
  }) {
    return AiPrivacyOptions(
      sendDate: sendDate ?? this.sendDate,
      sendMood: sendMood ?? this.sendMood,
      sendTags: sendTags ?? this.sendTags,
      sendWeather: sendWeather ?? this.sendWeather,
      sendLocation: sendLocation ?? this.sendLocation,
      excludedNotebookIds: excludedNotebookIds ?? this.excludedNotebookIds,
      excludedTagNames: excludedTagNames ?? this.excludedTagNames,
      contextBudget: contextBudget ?? this.contextBudget,
      includeArchived: includeArchived ?? this.includeArchived,
      confirm: confirm ?? this.confirm,
      allowPrivate: allowPrivate ?? this.allowPrivate,
    );
  }

  /// 稀疏写出：只写与默认不同的字段。
  Map<String, Object?> toJson() {
    const d = defaults;
    return <String, Object?>{
      if (sendDate != d.sendDate) 'date': sendDate,
      if (sendMood != d.sendMood) 'mood': sendMood,
      if (sendTags != d.sendTags) 'tags': sendTags,
      if (sendWeather != d.sendWeather) 'weather': sendWeather,
      if (sendLocation != d.sendLocation) 'location': sendLocation,
      if (excludedNotebookIds.isNotEmpty)
        'excludedNotebooks': excludedNotebookIds.toList()..sort(),
      if (excludedTagNames.isNotEmpty)
        'excludedTags': excludedTagNames.toList()..sort(),
      if (contextBudget != d.contextBudget) 'budget': contextBudget,
      if (includeArchived != d.includeArchived) 'archived': includeArchived,
      if (confirm != d.confirm) 'confirm': confirm.name,
      if (allowPrivate != d.allowPrivate) 'allowPrivate': allowPrivate,
    };
  }

  static AiPrivacyOptions fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    const d = defaults;
    bool read(String key, bool fallback) =>
        raw[key] is bool ? raw[key] as bool : fallback;
    // 旧版另有“每篇最多”（'perDiary'），现在每篇不设上限：读取时忽略，
    // 下次写出时自然去掉。

    Set<String> strings(String key) => <String>{
      if (raw[key] case final List<Object?> list)
        for (final item in list)
          if (item is String && item.isNotEmpty) item,
    };

    return AiPrivacyOptions(
      sendDate: read('date', d.sendDate),
      sendMood: read('mood', d.sendMood),
      sendTags: read('tags', d.sendTags),
      sendWeather: read('weather', d.sendWeather),
      sendLocation: read('location', d.sendLocation),
      excludedNotebookIds: strings('excludedNotebooks'),
      excludedTagNames: strings('excludedTags'),
      contextBudget: _readContextBudget(raw['budget']),
      includeArchived: read('archived', d.includeArchived),
      confirm: enumByName(AiConfirmMode.values, raw['confirm'], d.confirm),
      allowPrivate: read('allowPrivate', d.allowPrivate),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiPrivacyOptions && _equalJson(other.toJson(), toJson());

  @override
  int get hashCode => toJson().toString().hashCode;
}

bool _equalJson(Map<String, Object?> a, Map<String, Object?> b) =>
    a.toString() == b.toString();
