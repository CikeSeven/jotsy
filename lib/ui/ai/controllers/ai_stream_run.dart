import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/ai/ai_failure.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/http_cancel_token.dart';

/// 一次流式生成的状态。
enum AiRunStatus {
  /// 还没开始。
  idle,

  /// 已发出请求、正在接收。
  running,

  /// 正常结束。
  done,

  /// 用户停止（已收到的部分保留）。
  stopped,

  /// 出错（已收到的部分保留，[AiStreamRun.error] 为原因）。
  failed,
}

/// 一次流式生成的通用状态机，写作面板、读后回应、回顾与对话共用。
///
/// 状态边界：
/// - [start] 取消上一次未完成的生成，从 [AiRunStatus.running] 开始累积
///   正文与思考增量，结束时转为 done / stopped / failed；
/// - [stop] 取消令牌：连接立即断开，流以“已取消”结束，转为 stopped，已收到
///   的文字保留；
/// - [dispose] 同样取消；之后到达的数据一律丢弃，不再通知（异步回调里
///   页面可能已经离开）。
class AiStreamRun extends ChangeNotifier {
  AiRunStatus _status = AiRunStatus.idle;
  final StringBuffer _text = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();
  AiUsage? _usage;
  AiFinishReason? _finish;
  Object? _error;
  HttpCancelToken? _token;
  int _generation = 0;
  bool _disposed = false;

  AiRunStatus get status => _status;
  String get text => _text.toString();
  String get reasoning => _reasoning.toString();
  AiUsage? get usage => _usage;
  AiFinishReason? get finishReason => _finish;
  Object? get error => _error;

  bool get running => _status == AiRunStatus.running;

  /// 已经收到正文（没有正文时只显示“正在思考”）。
  bool get hasText => _text.isNotEmpty;

  /// 有可用的结果：结束或停止时已经收到正文。
  bool get hasResult =>
      hasText &&
      (_status == AiRunStatus.done || _status == AiRunStatus.stopped);

  /// 开始一次生成。[open] 用给定的令牌发出请求并返回流；这里负责累积、
  /// 结束与出错。返回时生成已经结束（含被下一次 [start] 取代）。
  Future<void> start(
    Stream<AiChunk> Function(HttpCancelToken token) open,
  ) async {
    _token?.cancel();
    final token = _token = HttpCancelToken();
    final generation = ++_generation;
    _status = AiRunStatus.running;
    _text.clear();
    _reasoning.clear();
    _usage = null;
    _finish = null;
    _error = null;
    _notify();
    bool current() => !_disposed && generation == _generation;
    try {
      await for (final chunk in open(token)) {
        if (!current()) return;
        _text.write(chunk.text);
        _reasoning.write(chunk.reasoning);
        if (chunk.usage case final usage?) {
          _usage = (_usage ?? const AiUsage()).merge(usage);
        }
        _finish = chunk.finishReason ?? _finish;
        _notify();
      }
      if (!current()) return;
      if (_finish == AiFinishReason.filtered && _text.isEmpty) {
        _error = const AiException(AiFailureKind.contentFiltered);
        _status = AiRunStatus.failed;
      } else {
        _status = AiRunStatus.done;
      }
    } on AiException catch (error) {
      if (!current()) return;
      if (error.kind == AiFailureKind.cancelled) {
        _status = AiRunStatus.stopped;
      } else {
        _error = error;
        _status = AiRunStatus.failed;
      }
    } catch (error) {
      if (!current()) return;
      _error = error;
      _status = AiRunStatus.failed;
    } finally {
      if (current()) {
        _token = null;
        _notify();
      }
    }
  }

  /// 停止正在进行的生成（没有时什么都不做）。
  void stop() => _token?.cancel();

  /// 回到初始状态（丢弃结果）。
  void reset() {
    _token?.cancel();
    _token = null;
    _generation++;
    _status = AiRunStatus.idle;
    _text.clear();
    _reasoning.clear();
    _usage = null;
    _finish = null;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}

/// 收拾模型输出：去掉把整段包起来的代码围栏、`<text>` 标签与引号（有的
/// 模型不听“只输出结果”），其余原样。
String aiCleanOutput(String raw) {
  var text = raw.trim();
  final fence = RegExp(r'^```[\w-]*\n([\s\S]*?)\n?```$');
  final fenced = fence.firstMatch(text);
  if (fenced != null) text = fenced.group(1)!.trim();
  final tagged = RegExp(r'^<text>\s*([\s\S]*?)\s*</text>$').firstMatch(text);
  if (tagged != null) text = tagged.group(1)!.trim();
  const pairs = <(String, String)>[('"', '"'), ('“', '”'), ('「', '」')];
  for (final (open, close) in pairs) {
    if (text.length > 1 &&
        text.startsWith(open) &&
        text.endsWith(close) &&
        !text.substring(1, text.length - 1).contains(close)) {
      text = text.substring(1, text.length - 1).trim();
    }
  }
  return text;
}
