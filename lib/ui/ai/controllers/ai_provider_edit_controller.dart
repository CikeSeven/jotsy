import 'package:flutter/foundation.dart';

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_provider_presets.dart';
import '../../../core/services/ai/ai_provider_store.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/http_cancel_token.dart';
import '../models/ai_ids.dart';

/// 编辑页表单里输入框的原文（由页面的 TextEditingController 提供）。
@immutable
class AiProviderFormText {
  const AiProviderFormText({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.proxy,
    required this.headers,
    required this.extraBody,
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final String proxy;
  final String headers;
  final String extraBody;
}

/// 表单校验失败的字段。
enum AiProviderFormError { name, baseUrl, extraBody }

/// 服务商编辑页的草稿与异步动作（拉取模型、测试连接、保存）。
///
/// 状态边界：
/// - 输入框的文字留在页面的控制器里，这里只放非文字的草稿（协议、模型、
///   开关、数值），[build] 时把两者合成一份配置；
/// - 拉取模型与测试连接各持有一个 [HttpCancelToken]，[dispose] 时取消，
///   回来的结果在已释放后一律丢弃；
/// - [dirty] 由页面比较“合成后的配置”与打开时的配置得出，这里不重复记账。
class AiProviderEditController extends ChangeNotifier {
  AiProviderEditController({
    required this.initial,
    required this.isNew,
    this.preset,
  }) : protocol = initial.protocol,
       models = List<AiModelConfig>.of(initial.models),
       stream = initial.stream,
       includeUsage = initial.includeUsage,
       sendTemperature = initial.sendTemperature,
       firstByteTimeoutSeconds = initial.firstByteTimeoutSeconds,
       retries = initial.retries,
       enabled = initial.enabled;

  /// 打开时的配置（新建时为预设生成的配置）。
  final AiProviderConfig initial;
  final bool isNew;
  final AiProviderPreset? preset;

  AiProtocol protocol;
  List<AiModelConfig> models;
  bool stream;
  bool includeUsage;
  bool sendTemperature;
  int firstByteTimeoutSeconds;
  int retries;
  bool enabled;

  bool fetching = false;
  bool testing = false;
  Object? lastError;
  String? testResult;

  HttpCancelToken? _fetchToken;
  HttpCancelToken? _testToken;
  bool _disposed = false;

  static const List<int> timeoutChoices = <int>[30, 60, 90, 180, 300];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setProtocol(AiProtocol value) {
    protocol = value;
    _changed();
  }

  void setStream(bool value) {
    stream = value;
    _changed();
  }

  void setIncludeUsage(bool value) {
    includeUsage = value;
    _changed();
  }

  void setSendTemperature(bool value) {
    sendTemperature = value;
    _changed();
  }

  void setTimeout(int seconds) {
    firstByteTimeoutSeconds = seconds;
    _changed();
  }

  void setRetries(int value) {
    retries = value.clamp(0, AiProviderConfig.maxRetries);
    _changed();
  }

  void setEnabled(bool value) {
    enabled = value;
    _changed();
  }

  /// 追加模型（同 id 的忽略）。
  void addModels(Iterable<AiModelConfig> added) {
    final ids = {for (final model in models) model.id};
    models = [
      ...models,
      for (final model in added)
        if (ids.add(model.id)) model,
    ];
    _changed();
  }

  void replaceModel(String id, AiModelConfig next) {
    models = [for (final model in models) model.id == id ? next : model];
    _changed();
  }

  void removeModel(String id) {
    models = [
      for (final model in models)
        if (model.id != id) model,
    ];
    _changed();
  }

  void moveModel(int oldIndex, int newIndex) {
    final next = [...models];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    models = next;
    _changed();
  }

  /// 校验表单，返回第一个出错的字段；没有错误时为 null。
  static AiProviderFormError? validate(AiProviderFormText text) {
    if (text.name.trim().isEmpty) return AiProviderFormError.name;
    final uri = Uri.tryParse(text.baseUrl.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return AiProviderFormError.baseUrl;
    }
    final extra = text.extraBody.trim();
    if (extra.isNotEmpty &&
        AiProviderConfig(
              id: 'x',
              name: 'x',
              protocol: AiProtocol.openAi,
              baseUrl: '',
              extraBody: extra,
            ).extraBodyMap ==
            null) {
      return AiProviderFormError.extraBody;
    }
    return null;
  }

  /// 把输入框原文与草稿合成一份配置（不校验）。
  AiProviderConfig build(AiProviderFormText text) {
    final proxy = text.proxy.trim();
    final extra = text.extraBody.trim();
    return initial.copyWith(
      name: text.name.trim(),
      protocol: protocol,
      baseUrl: text.baseUrl.trim(),
      apiKey: text.apiKey.trim(),
      proxy: proxy.isEmpty ? null : proxy,
      headers: parseAiHeaders(text.headers),
      extraBody: extra.isEmpty ? null : extra,
      stream: stream,
      includeUsage: includeUsage,
      sendTemperature: sendTemperature,
      firstByteTimeoutSeconds: firstByteTimeoutSeconds,
      retries: retries,
      models: models,
      enabled: enabled,
    );
  }

  /// 用当前表单拉取模型列表；失败时记下错误并返回 null。
  Future<List<AiRemoteModel>?> fetchModels(
    AiService service,
    AiProviderConfig config,
  ) async {
    _fetchToken?.cancel();
    final token = _fetchToken = HttpCancelToken();
    fetching = true;
    lastError = null;
    _changed();
    try {
      final models = await service.listModels(config, cancelToken: token);
      return _disposed || token.isCancelled ? null : models;
    } catch (error) {
      if (!_disposed && !token.isCancelled) lastError = error;
      return null;
    } finally {
      if (identical(_fetchToken, token)) {
        fetching = false;
        _changed();
      }
    }
  }

  /// 用当前表单与第一个模型测试连接。
  Future<void> test(
    AiService service,
    AiProviderConfig config,
    String Function(int ms) describe,
  ) async {
    if (config.models.isEmpty) return;
    _testToken?.cancel();
    final token = _testToken = HttpCancelToken();
    testing = true;
    lastError = null;
    testResult = null;
    _changed();
    try {
      final result = await service.testConnection(
        config,
        config.models.first,
        cancelToken: token,
      );
      if (!_disposed && !token.isCancelled) {
        testResult = describe(result.elapsed.inMilliseconds);
      }
    } catch (error) {
      if (!_disposed && !token.isCancelled) lastError = error;
    } finally {
      if (identical(_testToken, token)) {
        testing = false;
        _changed();
      }
    }
  }

  Future<void> save(AiProviderStore store, AiProviderConfig config) =>
      store.saveProvider(config);

  @override
  void dispose() {
    _disposed = true;
    _fetchToken?.cancel();
    _testToken?.cancel();
    super.dispose();
  }
}

/// 解析“每行一个 `名称: 值`”的请求头；没有冒号或名称为空的行忽略。
Map<String, String> parseAiHeaders(String text) {
  final headers = <String, String>{};
  for (final line in text.split('\n')) {
    final index = line.indexOf(':');
    if (index <= 0) continue;
    final name = line.substring(0, index).trim();
    if (name.isEmpty) continue;
    headers[name] = line.substring(index + 1).trim();
  }
  return headers;
}

String formatAiHeaders(Map<String, String> headers) => [
  for (final entry in headers.entries) '${entry.key}: ${entry.value}',
].join('\n');

/// 新服务商的本机 id。
String newAiProviderId() => newAiLocalId('provider');
