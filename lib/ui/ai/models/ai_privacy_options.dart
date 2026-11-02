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
    this.perDiaryLimit = defaultPerDiaryLimit,
    this.includeArchived = true,
    this.confirm = AiConfirmMode.multiDiary,
    this.allowPrivate = false,
  });

  static const AiPrivacyOptions defaults = AiPrivacyOptions();

  /// 多篇上下文最多发送的字数（`TextStats` 口径）。
  static const int defaultContextBudget = 24000;
  static const List<int> contextBudgetChoices = <int>[
    8000,
    16000,
    24000,
    48000,
    96000,
  ];

  /// 多篇上下文里每篇最多保留的字数；单篇操作（回应、写作）不受此限。
  static const int defaultPerDiaryLimit = 2000;
  static const List<int> perDiaryLimitChoices = <int>[500, 1000, 2000, 4000];

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
  final int perDiaryLimit;

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
    int? perDiaryLimit,
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
      perDiaryLimit: perDiaryLimit ?? this.perDiaryLimit,
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
      if (perDiaryLimit != d.perDiaryLimit) 'perDiary': perDiaryLimit,
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
    int choice(String key, List<int> choices, int fallback) {
      final value = raw[key];
      return value is int && choices.contains(value) ? value : fallback;
    }

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
      contextBudget: choice('budget', contextBudgetChoices, d.contextBudget),
      perDiaryLimit: choice('perDiary', perDiaryLimitChoices, d.perDiaryLimit),
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
