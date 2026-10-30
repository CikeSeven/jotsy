// 加密信道的公开类型：错误、数据块与消息上限（由 lan_sync_channel.dart 导出）。
import 'dart:typed_data';

/// 单条控制消息（JSON 编码后）的上限。更大的载荷应作为数据块发送。
const int kLanSyncMaxMessageBytes = 32 * 1024 * 1024;

/// 信道终止或操作失败的原因。
enum LanSyncChannelError {
  /// 信道已关闭（本机或对方正常关闭），或数据块因此没有传完。
  closed,

  /// 连接断开（没收到关闭帧就结束、被重置）。
  connectionLost,

  /// 帧认证失败：被篡改、重放、乱序或截断。
  authenticationFailed,

  /// 帧内容不合协议（种类未知、数据块越界、消息不是合法 JSON 等）。
  protocolError,

  /// 对方放弃了这个数据块（只出现在该块的字节流上，信道照常）。
  blobAborted,
}

class LanSyncChannelException implements Exception {
  const LanSyncChannelException(this.error, [this.message]);

  final LanSyncChannelError error;
  final String? message;

  @override
  String toString() =>
      'LanSyncChannelException(${error.name}${message == null ? '' : ': $message'})';
}

/// 收到的一个数据块。[data] 只能监听一次；读完前信道不会交付后续帧。
class LanSyncBlob {
  const LanSyncBlob(this.id, this.length, this.data);

  final int id;

  /// 发送方声明的总字节数（数据流结束时已校验）。
  final int length;

  final Stream<Uint8List> data;
}
