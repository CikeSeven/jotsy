import 'dart:convert';

import 'package:meta/meta.dart';

import 'ai_models.dart';

/// 某月某模型的累计用量。
@immutable
class AiUsageEntry {
  const AiUsageEntry({
    required this.providerName,
    required this.model,
    this.requests = 0,
    this.failures = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  /// 记账时的服务商名称快照（服务商删掉后仍能看懂）。
  final String providerName;
  final String model;
  final int requests;
  final int failures;
  final int inputTokens;
  final int outputTokens;

  int get totalTokens => inputTokens + outputTokens;

  AiUsageEntry add({required bool failed, AiUsage? usage}) => AiUsageEntry(
    providerName: providerName,
    model: model,
    requests: requests + 1,
    failures: failures + (failed ? 1 : 0),
    inputTokens: inputTokens + (usage?.inputTokens ?? 0),
    outputTokens: outputTokens + (usage?.outputTokens ?? 0),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'p': providerName,
    'm': model,
    'r': requests,
    if (failures > 0) 'f': failures,
    if (inputTokens > 0) 'i': inputTokens,
    if (outputTokens > 0) 'o': outputTokens,
  };

  static AiUsageEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final provider = raw['p'];
    final model = raw['m'];
    if (provider is! String || model is! String) return null;
    int count(Object? value) => value is int && value > 0 ? value : 0;
    return AiUsageEntry(
      providerName: provider,
      model: model,
      requests: count(raw['r']),
      failures: count(raw['f']),
      inputTokens: count(raw['i']),
      outputTokens: count(raw['o']),
    );
  }
}

/// 本机的 AI 用量账本：按月份（`YYYY-MM`）→（服务商 id + 模型）累计请求数与
/// token。只存本机，最多保留 [maxMonths] 个月，不随备份导出。
@immutable
class AiUsageLedger {
  const AiUsageLedger(this.months);

  static const int maxMonths = 24;
  static const AiUsageLedger empty = AiUsageLedger(
    <String, Map<String, AiUsageEntry>>{},
  );

  /// 月份 → 键（`providerId|model`）→ 用量。
  final Map<String, Map<String, AiUsageEntry>> months;

  static String monthKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}';

  /// 月份从新到旧。
  List<String> get monthKeys =>
      months.keys.toList()..sort((a, b) => b.compareTo(a));

  List<AiUsageEntry> entriesOf(String month) {
    final entries = months[month]?.values.toList() ?? <AiUsageEntry>[];
    entries.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
    return entries;
  }

  AiUsageLedger record({
    required DateTime at,
    required String providerId,
    required String providerName,
    required String model,
    required bool failed,
    AiUsage? usage,
  }) {
    final month = monthKey(at);
    final key = '$providerId|$model';
    final next = <String, Map<String, AiUsageEntry>>{
      for (final entry in months.entries) entry.key: {...entry.value},
    };
    final bucket = next.putIfAbsent(month, () => <String, AiUsageEntry>{});
    final current = bucket[key];
    // 名称快照取最新的：服务商改过名时账本跟着显示新名字。
    bucket[key] = AiUsageEntry(
      providerName: providerName,
      model: model,
      requests: current?.requests ?? 0,
      failures: current?.failures ?? 0,
      inputTokens: current?.inputTokens ?? 0,
      outputTokens: current?.outputTokens ?? 0,
    ).add(failed: failed, usage: usage);
    final keys = next.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final stale in keys.skip(maxMonths)) {
      next.remove(stale);
    }
    return AiUsageLedger(next);
  }

  String encode() => jsonEncode(<String, Object?>{
    for (final month in months.entries)
      month.key: {
        for (final entry in month.value.entries)
          entry.key: entry.value.toJson(),
      },
  });

  static AiUsageLedger decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map) return empty;
    final months = <String, Map<String, AiUsageEntry>>{};
    for (final month in decoded.entries) {
      final key = month.key;
      final value = month.value;
      if (key is! String || value is! Map) continue;
      final bucket = <String, AiUsageEntry>{};
      for (final item in value.entries) {
        final entry = AiUsageEntry.fromJson(item.value);
        if (item.key is String && entry != null) {
          bucket[item.key as String] = entry;
        }
      }
      if (bucket.isNotEmpty) months[key] = bucket;
    }
    return AiUsageLedger(months);
  }
}
