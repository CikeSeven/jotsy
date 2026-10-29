import 'package:flutter/foundation.dart';

/// 二维码面板当前显示的一张码（docs/lan_sync.md §5.2 扫码配对）。
///
/// 令牌 2 分钟有效、一次性：到期或被扫过即作废，控制器换发新的一张并经
/// `LanSyncUiController.qrTicket` 通知，面板据此重绘二维码、重置倒计时环。
@immutable
class LanSyncQrTicket {
  const LanSyncQrTicket({
    required this.payload,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// 编进二维码的完整文本（`jotsy-lan:v1:…`）。
  final String payload;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// 有效期总长（倒计时环的分母）。
  Duration get lifetime => expiresAt.difference(issuedAt);

  /// 距离 [now] 还剩多久；已过期为零。
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncQrTicket &&
      other.payload == payload &&
      other.issuedAt == issuedAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(payload, issuedAt, expiresAt);
}
