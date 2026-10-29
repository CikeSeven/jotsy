// 扫码页的识别判断（与相机无关，便于测试）。
//
// - 输入：相机每一帧识别出的码的原文（可能一次多枚，也可能为空）；
// - 输出：认出 Jotsy 配对码时回调 [onJotsy]（只回调一次，之后的帧一律
//   忽略，避免关闭页面的动画期间重复进入连接）；别的码回调 [onOther]，
//   带上不认的原因；
// - 副作用：无。
//
// 不认的码只提示一次：相机对着同一枚码每秒会识别十几次，同一原文不再重复
// 回调；换了一枚码才再提示。是否 Jotsy 码只经 `LanSyncQrPayload.decode` 的
// 严格校验判断，与连接时的解析同一口径。

import '../../../core/services/lan_sync/lan_sync_qr_payload.dart';

/// 见文件头注释。
class LanSyncScanDetector {
  LanSyncScanDetector({required this.onJotsy, required this.onOther});

  final void Function(String payload) onJotsy;
  final void Function(LanSyncQrError error) onOther;

  bool _done = false;
  String? _lastRejected;

  /// 是否已经认出 Jotsy 码（之后不再处理任何帧）。
  bool get done => _done;

  /// 处理一帧识别结果。
  void handle(Iterable<String?> values) {
    if (_done) return;
    for (final raw in values) {
      if (raw == null || raw.isEmpty) continue;
      try {
        LanSyncQrPayload.decode(raw);
      } on LanSyncQrFormatException catch (error) {
        if (raw == _lastRejected) continue;
        _lastRejected = raw;
        onOther(error.error);
        continue;
      }
      _done = true;
      onJotsy(raw);
      return;
    }
  }
}
