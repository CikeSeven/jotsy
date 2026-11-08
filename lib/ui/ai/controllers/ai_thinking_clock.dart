/// 思考计时：从收到第一段思考增量起计，收到正文或工具调用（模型开始“说话”）
/// 时停；同一段流里可以先后思考几次，时长累加。
///
/// 只用墙钟时间（`Stopwatch`），不依赖服务商返回的思考 token 数（不是每家
/// 都给）。界面在 [running] 时每秒刷新一次显示“正在思考 · N 秒”，结束后
/// [elapsedMs] 存进消息 meta / 步骤记录，折叠块显示“思考了 N 秒”。
class AiThinkingClock {
  final Stopwatch _watch = Stopwatch();
  int _doneMs = 0;

  /// 正在思考（收到了思考、还没开始输出）。
  bool get running => _watch.isRunning;

  /// 累计的思考时长（毫秒，含正在进行的这一段）。
  int get elapsedMs => _doneMs + _watch.elapsedMilliseconds;

  /// 记一个流式增量：[reasoning] 为这块带着思考文字，[output] 为这块带着
  /// 正文或工具调用。
  void onDelta({required bool reasoning, required bool output}) {
    if (output) {
      stop();
      return;
    }
    if (reasoning && !_watch.isRunning) _watch.start();
  }

  /// 停下正在计的这一段（流结束、出错、停止时）。
  void stop() {
    if (!_watch.isRunning) return;
    _watch.stop();
    _doneMs += _watch.elapsedMilliseconds;
    _watch.reset();
  }

  void reset() {
    _watch
      ..stop()
      ..reset();
    _doneMs = 0;
  }
}
