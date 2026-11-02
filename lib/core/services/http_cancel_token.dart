import 'dart:async';
import 'dart:io';

/// 取消一组进行中的 HTTP 请求：强制关闭登记的连接，阻塞中的读写随即抛错。
///
/// 应用内更新（竞速下载）与 AI 助手（流式回答的“停止”）共用这一个原语：
/// - 请求方在建好 [HttpClient] 后 [attach]，结束时（无论成败）[detach]；
/// - [cancel] 只生效一次，之后 [attach] 的连接会被立即关闭，避免取消与
///   发起请求竞速时漏关；
/// - 各调用方按自己的错误类型抛出“已取消”（见 `AppUpdateCancelToken`）。
class HttpCancelToken {
  final Set<HttpClient> _clients = <HttpClient>{};
  final Completer<void> _whenCancelled = Completer<void>();

  bool get isCancelled => _whenCancelled.isCompleted;

  /// 取消时完成，用于结束仍在等待的竞速或空闲计时。
  Future<void> get whenCancelled => _whenCancelled.future;

  void cancel() {
    if (isCancelled) {
      return;
    }
    _whenCancelled.complete();
    for (final client in _clients.toList(growable: false)) {
      client.close(force: true);
    }
    _clients.clear();
  }

  /// 登记一个连接；已取消时立即关闭它。
  void attach(HttpClient client) {
    if (isCancelled) {
      client.close(force: true);
    } else {
      _clients.add(client);
    }
  }

  void detach(HttpClient client) => _clients.remove(client);
}
