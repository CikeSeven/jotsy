import 'package:meta/meta.dart';

/// AI 助手调用工具（智能体）的设置，存在 `AiPreferences.agent`（同一个
/// JSON 设置键里的 `agent` 字段，稀疏写入、逐字段容错）。
@immutable
class AiAgentOptions {
  const AiAgentOptions({
    this.enabled = true,
    this.maxSteps = defaultMaxSteps,
    this.allowChanges = true,
    this.confirmChanges = false,
  });

  static const AiAgentOptions defaults = AiAgentOptions();

  static const int defaultMaxSteps = 20;
  static const List<int> maxStepsChoices = <int>[10, 20, 40];

  /// 对话时让模型调用工具（查日记、统计、打开页面等）；关掉或模型不支持
  /// 工具时退回检索问答。
  final bool enabled;

  /// 一次回答里最多调用几轮工具；最后一轮不许再调用，让模型据已有结果作答。
  final int maxSteps;

  /// 允许 AI 改动数据（新建、修改、移入回收站等，都可撤销）。关掉后只有
  /// 查询与“前往”。
  final bool allowChanges;

  /// 每次改动前都在对话里确认（默认不确认、事后可撤销；删除类无论如何都
  /// 先确认）。
  final bool confirmChanges;

  AiAgentOptions copyWith({
    bool? enabled,
    int? maxSteps,
    bool? allowChanges,
    bool? confirmChanges,
  }) => AiAgentOptions(
    enabled: enabled ?? this.enabled,
    maxSteps: maxSteps ?? this.maxSteps,
    allowChanges: allowChanges ?? this.allowChanges,
    confirmChanges: confirmChanges ?? this.confirmChanges,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (enabled != defaults.enabled) 'enabled': enabled,
    if (maxSteps != defaults.maxSteps) 'maxSteps': maxSteps,
    if (allowChanges != defaults.allowChanges) 'allowChanges': allowChanges,
    if (confirmChanges != defaults.confirmChanges)
      'confirmChanges': confirmChanges,
  };

  static AiAgentOptions fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    bool read(String key, bool fallback) {
      final value = raw[key];
      return value is bool ? value : fallback;
    }

    final steps = raw['maxSteps'];
    return AiAgentOptions(
      enabled: read('enabled', defaults.enabled),
      maxSteps: steps is int && maxStepsChoices.contains(steps)
          ? steps
          : defaults.maxSteps,
      allowChanges: read('allowChanges', defaults.allowChanges),
      confirmChanges: read('confirmChanges', defaults.confirmChanges),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiAgentOptions &&
      other.enabled == enabled &&
      other.maxSteps == maxSteps &&
      other.allowChanges == allowChanges &&
      other.confirmChanges == confirmChanges;

  @override
  int get hashCode =>
      Object.hash(enabled, maxSteps, allowChanges, confirmChanges);
}
