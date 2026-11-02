import 'dart:convert';

import 'package:meta/meta.dart';

import 'ai_models.dart';

/// 服务商配置与任务路由：只存本机（含 API 密钥），不随备份导出、不同步。
///
/// 编解码一律逐字段容错：某个字段类型不对只让它回到默认值，某个服务商或
/// 模型认不出（缺 id / 协议）只丢掉那一项，整份配置不因一处损坏而丢失。

/// 一个模型的本机设置。
@immutable
class AiModelConfig {
  const AiModelConfig({
    required this.id,
    this.name,
    this.vision,
    this.contextWindow,
    this.maxOutputTokens,
    this.reasoning = true,
  });

  /// 请求里写的模型名（如 `deepseek-chat`）。
  final String id;

  /// 显示名；为空时显示 [id]。
  final String? name;

  /// 是否支持图片输入；null 表示没指定，按支持处理（现在的主流模型几乎都
  /// 能看图）。模型实际不认图片时服务端回 400，`AiService` 去掉图片再试，
  /// 不会让请求失败。
  final bool? vision;

  /// 上下文长度（token）；null 表示未知，按保守值估算。
  final int? contextWindow;

  /// 单次最多输出（token）；null 时按协议默认值。
  final int? maxOutputTokens;

  /// 请求时让服务端返回思考过程，默认开启。模型不支持思考参数时服务端回
  /// 400，`AiService` 去掉思考再试（见 `AiService.stream`）。
  final bool reasoning;

  String get label => (name?.trim().isNotEmpty ?? false) ? name!.trim() : id;

  bool get supportsVision => vision ?? true;

  AiModelConfig copyWith({
    String? id,
    Object? name = _unset,
    Object? vision = _unset,
    Object? contextWindow = _unset,
    Object? maxOutputTokens = _unset,
    bool? reasoning,
  }) {
    return AiModelConfig(
      id: id ?? this.id,
      name: identical(name, _unset) ? this.name : name as String?,
      vision: identical(vision, _unset) ? this.vision : vision as bool?,
      contextWindow: identical(contextWindow, _unset)
          ? this.contextWindow
          : contextWindow as int?,
      maxOutputTokens: identical(maxOutputTokens, _unset)
          ? this.maxOutputTokens
          : maxOutputTokens as int?,
      reasoning: reasoning ?? this.reasoning,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (name != null) 'name': name,
    if (vision != null) 'vision': vision,
    if (contextWindow != null) 'contextWindow': contextWindow,
    if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
    if (!reasoning) 'reasoning': false,
  };

  static AiModelConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    return AiModelConfig(
      id: id.trim(),
      name: _string(raw['name']),
      vision: raw['vision'] is bool ? raw['vision'] as bool : null,
      contextWindow: _positiveInt(raw['contextWindow']),
      maxOutputTokens: _positiveInt(raw['maxOutputTokens']),
      reasoning: raw['reasoning'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiModelConfig &&
      other.id == id &&
      other.name == name &&
      other.vision == vision &&
      other.contextWindow == contextWindow &&
      other.maxOutputTokens == maxOutputTokens &&
      other.reasoning == reasoning;

  @override
  int get hashCode =>
      Object.hash(id, name, vision, contextWindow, maxOutputTokens, reasoning);
}

/// 一个服务商（一组地址 + 密钥 + 模型）。
@immutable
class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.presetId,
    this.apiKey = '',
    this.proxy,
    this.headers = const <String, String>{},
    this.extraBody,
    this.stream = true,
    this.includeUsage = true,
    this.sendTemperature = true,
    this.firstByteTimeoutSeconds = defaultFirstByteTimeoutSeconds,
    this.retries = defaultRetries,
    this.models = const <AiModelConfig>[],
    this.enabled = true,
  });

  static const int defaultFirstByteTimeoutSeconds = 90;
  static const int defaultRetries = 1;
  static const int maxRetries = 3;

  /// 本机生成的稳定 id，任务路由按它引用。
  final String id;
  final String name;
  final AiProtocol protocol;

  /// 接口根地址（如 `https://api.deepseek.com/v1`）。各协议在它后面拼路径。
  final String baseUrl;

  /// 从哪个预设创建；自定义为 null。只用于显示图标与“获取密钥”链接。
  final String? presetId;

  /// API 密钥。本地模型（Ollama、LM Studio）可以为空。
  final String apiKey;

  /// HTTP 代理 `host:port`；为空时直连（不读系统代理，见 `AiHttp`）。
  final String? proxy;

  /// 额外的请求头（如转发服务要求的 `HTTP-Referer`、或改写
  /// `anthropic-version`）。同名时覆盖内置的头。
  final Map<String, String> headers;

  /// 合并进请求体的额外 JSON 对象原文（如 `{"enable_thinking": false}`）。
  final String? extraBody;

  /// 使用流式响应；关闭时一次性请求（个别转发服务不支持 SSE）。
  final bool stream;

  /// OpenAI 兼容：流式时请求返回用量（`stream_options.include_usage`）。
  /// 部分服务不认识这个字段会报错，可以关掉。
  final bool includeUsage;

  /// 是否发送温度。较新的 Claude 模型会拒绝采样参数，Anthropic 预设默认关。
  final bool sendTemperature;

  /// 等待首个字节的最长时间。推理模型可能先想很久才开始输出。
  final int firstByteTimeoutSeconds;

  /// 首个字节之前失败（网络、5xx、429）时自动重试的次数。
  final int retries;

  final List<AiModelConfig> models;

  /// 停用后不出现在模型选择里，但配置保留。
  final bool enabled;

  bool get hasModels => models.isNotEmpty;

  /// 能直接用：启用、有地址、有模型。密钥可以为空（本地服务）。
  bool get usable => enabled && baseUrl.trim().isNotEmpty && hasModels;

  AiModelConfig? modelById(String modelId) {
    for (final model in models) {
      if (model.id == modelId) return model;
    }
    return null;
  }

  /// 地址里的主机名，用于“将发送到 xxx”的确认提示。
  String get host {
    final uri = Uri.tryParse(baseUrl.trim());
    return (uri?.host.isNotEmpty ?? false) ? uri!.host : baseUrl.trim();
  }

  /// 解析 [extraBody]；不是 JSON 对象时返回 null（编辑页另行提示）。
  Map<String, Object?>? get extraBodyMap {
    final raw = extraBody?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      return null;
    }
    return null;
  }

  AiProviderConfig copyWith({
    String? id,
    String? name,
    AiProtocol? protocol,
    String? baseUrl,
    Object? presetId = _unset,
    String? apiKey,
    Object? proxy = _unset,
    Map<String, String>? headers,
    Object? extraBody = _unset,
    bool? stream,
    bool? includeUsage,
    bool? sendTemperature,
    int? firstByteTimeoutSeconds,
    int? retries,
    List<AiModelConfig>? models,
    bool? enabled,
  }) {
    return AiProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      presetId: identical(presetId, _unset)
          ? this.presetId
          : presetId as String?,
      apiKey: apiKey ?? this.apiKey,
      proxy: identical(proxy, _unset) ? this.proxy : proxy as String?,
      headers: headers ?? this.headers,
      extraBody: identical(extraBody, _unset)
          ? this.extraBody
          : extraBody as String?,
      stream: stream ?? this.stream,
      includeUsage: includeUsage ?? this.includeUsage,
      sendTemperature: sendTemperature ?? this.sendTemperature,
      firstByteTimeoutSeconds:
          firstByteTimeoutSeconds ?? this.firstByteTimeoutSeconds,
      retries: retries ?? this.retries,
      models: models ?? this.models,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'baseUrl': baseUrl,
    if (presetId != null) 'presetId': presetId,
    if (apiKey.isNotEmpty) 'apiKey': apiKey,
    if (proxy?.trim().isNotEmpty ?? false) 'proxy': proxy!.trim(),
    if (headers.isNotEmpty) 'headers': headers,
    if (extraBody?.trim().isNotEmpty ?? false) 'extraBody': extraBody,
    if (!stream) 'stream': false,
    if (!includeUsage) 'includeUsage': false,
    if (!sendTemperature) 'sendTemperature': false,
    if (firstByteTimeoutSeconds != defaultFirstByteTimeoutSeconds)
      'firstByteTimeoutSeconds': firstByteTimeoutSeconds,
    if (retries != defaultRetries) 'retries': retries,
    'models': [for (final model in models) model.toJson()],
    if (!enabled) 'enabled': false,
  };

  static AiProviderConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final protocol = AiProtocol.fromName(raw['protocol']);
    if (id is! String || id.isEmpty || protocol == null) return null;
    final headers = <String, String>{};
    final rawHeaders = raw['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && key.trim().isNotEmpty && value is String) {
          headers[key.trim()] = value;
        }
      }
    }
    final models = <AiModelConfig>[];
    final seen = <String>{};
    final rawModels = raw['models'];
    if (rawModels is List) {
      for (final item in rawModels) {
        final model = AiModelConfig.fromJson(item);
        if (model != null && seen.add(model.id)) models.add(model);
      }
    }
    final timeout = _positiveInt(raw['firstByteTimeoutSeconds']);
    final retries = raw['retries'];
    return AiProviderConfig(
      id: id,
      name: _string(raw['name']) ?? id,
      protocol: protocol,
      baseUrl: _string(raw['baseUrl']) ?? '',
      presetId: _string(raw['presetId']),
      apiKey: raw['apiKey'] is String ? raw['apiKey'] as String : '',
      proxy: _string(raw['proxy']),
      headers: headers,
      extraBody: _string(raw['extraBody']),
      stream: raw['stream'] is bool ? raw['stream'] as bool : true,
      includeUsage: raw['includeUsage'] is bool
          ? raw['includeUsage'] as bool
          : true,
      sendTemperature: raw['sendTemperature'] is bool
          ? raw['sendTemperature'] as bool
          : true,
      firstByteTimeoutSeconds: timeout == null
          ? defaultFirstByteTimeoutSeconds
          : timeout.clamp(10, 600),
      retries: retries is int ? retries.clamp(0, maxRetries) : defaultRetries,
      models: models,
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiProviderConfig && jsonEncode(other) == jsonEncode(this);

  @override
  int get hashCode => jsonEncode(this).hashCode;
}

/// 可以分别指定模型的任务。
enum AiTaskKind {
  /// 编辑器里的写作指令（续写、润色……）。
  writing,

  /// 智能填写：标题、标签、心情。
  suggest,

  /// 读后回应。
  reply,

  /// 写作灵感。
  prompts,

  /// 回顾总结。
  recap,

  /// 与日记对话。
  chat,

  /// 图片理解（描述图片）。
  vision,

  /// 内部的小任务：给对话起标题、生成检索计划、长回顾的分块摘要。
  utility;

  static AiTaskKind? fromName(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  /// 没单独指定时优先用“快速模型”的任务：输出短、要快，不需要最强的模型。
  bool get prefersFastModel =>
      this == suggest || this == prompts || this == utility;
}

/// 对某个服务商下某个模型的引用。
@immutable
class AiModelRef {
  const AiModelRef(this.providerId, this.modelId);

  final String providerId;
  final String modelId;

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': providerId,
    'model': modelId,
  };

  static AiModelRef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final provider = raw['provider'];
    final model = raw['model'];
    if (provider is! String || provider.isEmpty) return null;
    if (model is! String || model.isEmpty) return null;
    return AiModelRef(provider, model);
  }

  @override
  bool operator ==(Object other) =>
      other is AiModelRef &&
      other.providerId == providerId &&
      other.modelId == modelId;

  @override
  int get hashCode => Object.hash(providerId, modelId);

  @override
  String toString() => 'AiModelRef($providerId/$modelId)';
}

/// 解析后可以直接发请求的（服务商, 模型）。
@immutable
class AiResolvedModel {
  const AiResolvedModel(this.provider, this.model);

  final AiProviderConfig provider;
  final AiModelConfig model;

  AiModelRef get ref => AiModelRef(provider.id, model.id);
}

/// 本机 AI 配置：服务商列表 + 任务路由 + 已确认过的发送目标。
@immutable
class AiLocalConfig {
  const AiLocalConfig({
    this.providers = const <AiProviderConfig>[],
    this.defaultModel,
    this.fastModel,
    this.taskModels = const <AiTaskKind, AiModelRef>{},
    this.acknowledgedHosts = const <String>{},
  });

  static const AiLocalConfig empty = AiLocalConfig();

  final List<AiProviderConfig> providers;

  /// 没单独指定的任务都用它；为 null 时取第一个可用服务商的第一个模型。
  final AiModelRef? defaultModel;

  /// 短任务优先使用的模型（见 [AiTaskKind.prefersFastModel]）。
  final AiModelRef? fastModel;

  /// 单独指定了模型的任务。
  final Map<AiTaskKind, AiModelRef> taskModels;

  /// 用户已在“发送前确认”里勾过“不再提示”的主机。
  final Set<String> acknowledgedHosts;

  AiProviderConfig? providerById(String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// 把引用解析成可用的模型；服务商被删、停用或模型已移除时返回 null。
  AiResolvedModel? resolveRef(AiModelRef? ref) {
    if (ref == null) return null;
    final provider = providerById(ref.providerId);
    if (provider == null || !provider.usable) return null;
    final model = provider.modelById(ref.modelId);
    if (model == null) return null;
    return AiResolvedModel(provider, model);
  }

  /// 第一个可用服务商的第一个模型。
  AiResolvedModel? get firstUsable {
    for (final provider in providers) {
      if (provider.usable) {
        return AiResolvedModel(provider, provider.models.first);
      }
    }
    return null;
  }

  /// 有至少一个能用的模型。
  bool get isReady => firstUsable != null;

  /// 某任务实际使用的模型：单独指定 → 快速模型（短任务）→ 默认模型 →
  /// 第一个可用的。任一级引用失效（服务商删了）就往下一级退。
  AiResolvedModel? resolveTask(AiTaskKind task) {
    final explicit = resolveRef(taskModels[task]);
    if (explicit != null) return explicit;
    if (task.prefersFastModel) {
      final fast = resolveRef(fastModel);
      if (fast != null) return fast;
    }
    return resolveRef(defaultModel) ?? firstUsable;
  }

  /// 所有可用的模型，按服务商顺序。
  List<AiResolvedModel> get usableModels => [
    for (final provider in providers)
      if (provider.usable)
        for (final model in provider.models) AiResolvedModel(provider, model),
  ];

  AiLocalConfig copyWith({
    List<AiProviderConfig>? providers,
    Object? defaultModel = _unset,
    Object? fastModel = _unset,
    Map<AiTaskKind, AiModelRef>? taskModels,
    Set<String>? acknowledgedHosts,
  }) {
    return AiLocalConfig(
      providers: providers ?? this.providers,
      defaultModel: identical(defaultModel, _unset)
          ? this.defaultModel
          : defaultModel as AiModelRef?,
      fastModel: identical(fastModel, _unset)
          ? this.fastModel
          : fastModel as AiModelRef?,
      taskModels: taskModels ?? this.taskModels,
      acknowledgedHosts: acknowledgedHosts ?? this.acknowledgedHosts,
    );
  }

  /// 删除一个服务商，并一并去掉指向它的路由。
  AiLocalConfig withoutProvider(String providerId) {
    bool keep(AiModelRef? ref) => ref != null && ref.providerId != providerId;
    return AiLocalConfig(
      providers: [
        for (final provider in providers)
          if (provider.id != providerId) provider,
      ],
      defaultModel: keep(defaultModel) ? defaultModel : null,
      fastModel: keep(fastModel) ? fastModel : null,
      taskModels: {
        for (final entry in taskModels.entries)
          if (keep(entry.value)) entry.key: entry.value,
      },
      acknowledgedHosts: acknowledgedHosts,
    );
  }

  String encode() => jsonEncode(<String, Object?>{
    'v': 1,
    'providers': [for (final provider in providers) provider.toJson()],
    if (defaultModel != null) 'default': defaultModel!.toJson(),
    if (fastModel != null) 'fast': fastModel!.toJson(),
    if (taskModels.isNotEmpty)
      'tasks': {
        for (final entry in taskModels.entries)
          entry.key.name: entry.value.toJson(),
      },
    if (acknowledgedHosts.isNotEmpty)
      'acknowledged': (acknowledgedHosts.toList()..sort()),
  });

  static AiLocalConfig decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map) return empty;
    final providers = <AiProviderConfig>[];
    final seen = <String>{};
    final rawProviders = decoded['providers'];
    if (rawProviders is List) {
      for (final item in rawProviders) {
        final provider = AiProviderConfig.fromJson(item);
        if (provider != null && seen.add(provider.id)) providers.add(provider);
      }
    }
    final tasks = <AiTaskKind, AiModelRef>{};
    final rawTasks = decoded['tasks'];
    if (rawTasks is Map) {
      for (final entry in rawTasks.entries) {
        final task = AiTaskKind.fromName(entry.key);
        final ref = AiModelRef.fromJson(entry.value);
        if (task != null && ref != null) tasks[task] = ref;
      }
    }
    final hosts = <String>{};
    final rawHosts = decoded['acknowledged'];
    if (rawHosts is List) {
      for (final host in rawHosts) {
        if (host is String && host.isNotEmpty) hosts.add(host);
      }
    }
    return AiLocalConfig(
      providers: providers,
      defaultModel: AiModelRef.fromJson(decoded['default']),
      fastModel: AiModelRef.fromJson(decoded['fast']),
      taskModels: tasks,
      acknowledgedHosts: hosts,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiLocalConfig && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

const Object _unset = Object();

String? _string(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _positiveInt(Object? raw) {
  if (raw is int && raw > 0) return raw;
  if (raw is double && raw > 0 && raw.isFinite) return raw.round();
  return null;
}
