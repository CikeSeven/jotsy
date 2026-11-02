import 'dart:async';

import '../http_cancel_token.dart';
import 'ai_client.dart';
import 'ai_failure.dart';
import 'ai_http.dart';
import 'ai_models.dart';
import 'ai_provider_config.dart';
import 'ai_provider_store.dart';

typedef AiClientFactory =
    AiChatClient Function(AiProviderConfig config, AiHttp http);

/// AI 请求的编排出口：界面与各功能的控制器只经它发请求。
///
/// 职责：
/// - 解析任务该用哪个服务商与模型（[resolve]，规则见
///   [AiLocalConfig.resolveTask]）；
/// - 补上模型级的设置（最大输出、思考过程），模型标明不支持图片时去掉图片；
/// - 降级重试：图片与思考默认都发（现在的主流模型几乎都支持）。首块之前
///   收到 400（请求被拒）时，先去掉图片再试，仍被拒且带了思考参数（Claude、
///   Gemini、OpenAI Responses 才会发）时再去掉思考试一次；被拒过的模型记在
///   本服务的内存里，之后的请求直接不带（服务商配置变了会重建本服务）；
/// - 失败重试：只在**首块之前**、且错误可重试（网络、超时、429、5xx）时
///   按服务商的次数退避重试；首块之后再失败就交给调用方（已经显示了一半
///   的内容，不能悄悄重来）；
/// - 记账：每次请求结束（成功、失败或停止）都把用量记进本机账本，记账失败
///   不影响结果；
/// - 停止：调用方持有 [HttpCancelToken]，取消后连接被强制关闭，流以
///   [AiFailureKind.cancelled] 结束。
class AiService {
  AiService({
    required this._store,
    AiHttp? http,
    AiClientFactory? clientFactory,
    Duration Function(int attempt, AiFailureKind kind)? backoff,
  }) : _http = http ?? AiHttp(),
       _clientFactory = clientFactory ?? _defaultClientFactory,
       _backoff = backoff ?? _defaultBackoff;

  final AiProviderStore _store;
  final AiHttp _http;
  final AiClientFactory _clientFactory;
  final Duration Function(int attempt, AiFailureKind kind) _backoff;

  /// 拒收过图片 / 思考参数的模型（`服务商 id + 模型 id`）。
  final Set<String> _rejectsImages = <String>{};
  final Set<String> _rejectsReasoning = <String>{};

  static String _modelKey(AiResolvedModel target) =>
      '${target.provider.id}\u0000${target.model.id}';

  /// 这种协议会不会因为“思考”而在请求里多带参数（OpenAI Chat 兼容接口
  /// 只是读返回里的思考字段，请求不变，去掉也没用）。
  static bool _sendsReasoningParams(AiProtocol protocol) =>
      protocol != AiProtocol.openAi;

  static AiChatClient _defaultClientFactory(
    AiProviderConfig config,
    AiHttp http,
  ) => AiChatClient.forProvider(config, http: http);

  static Duration _defaultBackoff(int attempt, AiFailureKind kind) {
    final base = kind == AiFailureKind.rateLimited ? 2 : 1;
    return Duration(seconds: base << (attempt - 1));
  }

  AiLocalConfig get config => _store.config;

  /// 任务实际使用的模型；[override] 有效时优先（对话页当场切换的模型）。
  AiResolvedModel? resolve(AiTaskKind task, {AiModelRef? override}) {
    return config.resolveRef(override) ?? config.resolveTask(task);
  }

  /// 解析任务的模型，没有可用模型时抛 [AiFailureKind.notConfigured]。
  AiResolvedModel require(AiTaskKind task, {AiModelRef? override}) {
    final model = resolve(task, override: override);
    if (model == null) {
      throw const AiException(AiFailureKind.notConfigured);
    }
    return model;
  }

  /// 流式生成。[request] 里的模型名会被换成 [target] 的模型。
  Stream<AiChunk> stream(
    AiResolvedModel target,
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async* {
    final client = _clientFactory(target.provider, _http);
    final key = _modelKey(target);
    var effective = prepareRequest(target, request);
    if (_rejectsImages.contains(key)) effective = _withoutImages(effective);
    if (_rejectsReasoning.contains(key)) {
      effective = effective.copyWith(reasoning: false);
    }
    var usage = const AiUsage();
    var started = false;
    var failed = false;
    var attempt = 0;
    try {
      while (true) {
        try {
          await for (final chunk in client.stream(
            effective,
            cancelToken: cancelToken,
          )) {
            started = true;
            if (chunk.usage case final chunkUsage?) {
              usage = usage.merge(chunkUsage);
            }
            yield chunk;
          }
          if (cancelToken?.isCancelled ?? false) {
            throw const AiException(AiFailureKind.cancelled);
          }
          break;
        } on AiException catch (error) {
          final cancelled = cancelToken?.isCancelled ?? false;
          if (!started &&
              !cancelled &&
              error.kind == AiFailureKind.badRequest) {
            if (effective.hasImages) {
              _rejectsImages.add(key);
              effective = _withoutImages(effective);
              continue;
            }
            if (effective.reasoning &&
                _sendsReasoningParams(target.provider.protocol)) {
              _rejectsReasoning.add(key);
              effective = effective.copyWith(reasoning: false);
              continue;
            }
          }
          if (!started &&
              !cancelled &&
              error.kind.retryable &&
              attempt < target.provider.retries) {
            attempt++;
            await _wait(_backoff(attempt, error.kind), cancelToken);
            continue;
          }
          rethrow;
        }
      }
    } on AiException catch (error) {
      failed = error.kind != AiFailureKind.cancelled;
      rethrow;
    } catch (error) {
      failed = true;
      throw mapAiTransportError(error, cancelToken);
    } finally {
      unawaited(
        _store
            .recordUsage(
              model: target,
              failed: failed,
              usage: usage.totalTokens > 0 ? usage : null,
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// 一次性拿到完整结果（智能填写、检索计划等短任务）。
  Future<AiCompletion> complete(
    AiResolvedModel target,
    AiRequest request, {
    HttpCancelToken? cancelToken,
  }) async {
    final text = StringBuffer();
    final reasoning = StringBuffer();
    AiUsage? usage;
    AiFinishReason? finish;
    await for (final chunk in stream(
      target,
      request,
      cancelToken: cancelToken,
    )) {
      text.write(chunk.text);
      reasoning.write(chunk.reasoning);
      if (chunk.usage case final chunkUsage?) {
        usage = (usage ?? const AiUsage()).merge(chunkUsage);
      }
      finish = chunk.finishReason ?? finish;
    }
    if (finish == AiFinishReason.filtered && text.isEmpty) {
      throw const AiException(AiFailureKind.contentFiltered);
    }
    return AiCompletion(
      text: text.toString(),
      reasoning: reasoning.toString(),
      usage: usage,
      finishReason: finish,
    );
  }

  /// 拉取服务商的模型列表（编辑页用，不记账）。
  Future<List<AiRemoteModel>> listModels(
    AiProviderConfig provider, {
    HttpCancelToken? cancelToken,
  }) {
    return _clientFactory(provider, _http).listModels(cancelToken: cancelToken);
  }

  /// 测试连接：发一句极短的请求，返回耗时与回复。按正常请求记账。
  Future<AiConnectionTestResult> testConnection(
    AiProviderConfig provider,
    AiModelConfig model, {
    HttpCancelToken? cancelToken,
  }) async {
    final watch = Stopwatch()..start();
    final completion = await complete(
      AiResolvedModel(provider, model),
      AiRequest(
        model: model.id,
        messages: <AiMessage>[AiMessage.text(AiRole.user, 'Reply with: OK')],
        maxOutputTokens: model.reasoning ? null : 256,
      ),
      cancelToken: cancelToken,
    );
    watch.stop();
    return AiConnectionTestResult(
      elapsed: watch.elapsed,
      reply: completion.text.trim(),
      usage: completion.usage,
    );
  }

  /// 补上模型级设置；模型标明不支持图片时把图片去掉（只留文字，避免 400）。
  static AiRequest prepareRequest(AiResolvedModel target, AiRequest request) {
    final model = target.model;
    final prepared = AiRequest(
      model: model.id,
      system: request.system,
      messages: request.messages,
      temperature: request.temperature,
      maxOutputTokens: request.maxOutputTokens ?? model.maxOutputTokens,
      reasoning: request.reasoning || model.reasoning,
    );
    return model.supportsVision ? prepared : _withoutImages(prepared);
  }

  /// 去掉所有图片，只留文字。
  static AiRequest _withoutImages(AiRequest request) {
    if (!request.hasImages) return request;
    return request.copyWith(
      messages: [
        for (final message in request.messages)
          AiMessage(message.role, [
            for (final part in message.parts)
              if (part is AiTextPart) part,
          ]),
      ],
    );
  }

  static Future<void> _wait(
    Duration delay,
    HttpCancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await Future<void>.delayed(delay);
      return;
    }
    await Future.any<void>(<Future<void>>[
      Future<void>.delayed(delay),
      cancelToken.whenCancelled,
    ]);
    if (cancelToken.isCancelled) {
      throw const AiException(AiFailureKind.cancelled);
    }
  }
}

/// 测试连接的结果。
class AiConnectionTestResult {
  const AiConnectionTestResult({
    required this.elapsed,
    required this.reply,
    this.usage,
  });

  final Duration elapsed;
  final String reply;
  final AiUsage? usage;
}
