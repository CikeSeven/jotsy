import 'package:meta/meta.dart';

/// AI 助手调用工具（智能体）的设置，存在 `AiPreferences.agent`（同一个
/// JSON 设置键里的 `agent` 字段，稀疏写入、逐字段容错）。
@immutable
class AiAgentOptions {
  const AiAgentOptions({this.enabled = true, this.maxSteps = defaultMaxSteps});

  static const AiAgentOptions defaults = AiAgentOptions();

  static const int defaultMaxSteps = 20;
  static const List<int> maxStepsChoices = <int>[10, 20, 40];

  /// 对话时让模型调用工具（查日记、统计、打开页面等）；关掉或模型不支持
  /// 工具时退回检索问答。
  final bool enabled;

  /// 一次回答里最多调用几轮工具；最后一轮不许再调用，让模型据已有结果作答。
  final int maxSteps;

  AiAgentOptions copyWith({bool? enabled, int? maxSteps}) => AiAgentOptions(
    enabled: enabled ?? this.enabled,
    maxSteps: maxSteps ?? this.maxSteps,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (enabled != defaults.enabled) 'enabled': enabled,
    if (maxSteps != defaults.maxSteps) 'maxSteps': maxSteps,
  };

  static AiAgentOptions fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final enabled = raw['enabled'];
    final steps = raw['maxSteps'];
    return AiAgentOptions(
      enabled: enabled is bool ? enabled : defaults.enabled,
      maxSteps: steps is int && maxStepsChoices.contains(steps)
          ? steps
          : defaults.maxSteps,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiAgentOptions &&
      other.enabled == enabled &&
      other.maxSteps == maxSteps;

  @override
  int get hashCode => Object.hash(enabled, maxSteps);
}
