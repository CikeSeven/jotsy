import 'dart:async';
import 'dart:io';

import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_handshake.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_identity.dart';

/// 一对已连接的回环套接字：(连接方, 监听方)。
Future<(Socket, Socket)> loopbackPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final client = await Socket.connect(
    InternetAddress.loopbackIPv4,
    server.port,
  );
  final serverSide = await accepted;
  await server.close();
  return (client, serverSide);
}

/// 测试用的短超时握手。
LanSyncHandshake testHandshake(
  LanSyncIdentity identity,
  String name, {
  Duration stepTimeout = const Duration(seconds: 5),
  Duration sasTimeout = const Duration(seconds: 5),
}) {
  return LanSyncHandshake(
    identity: identity,
    local: LanSyncLocalInfo(name: name, platform: 'linux', formatVersion: 1),
    stepTimeout: stepTimeout,
    sasTimeout: sasTimeout,
    lingerTimeout: const Duration(milliseconds: 500),
  );
}

/// 已配对设备表：deviceId → 公钥指纹。
class TrustList {
  final Map<String, String> _trusted = {};

  void add(LanSyncIdentity identity) =>
      _trusted[identity.deviceId] = identity.fingerprint;

  bool check(String deviceId, List<int> publicKey) =>
      _trusted[deviceId] == lanSyncFingerprint(publicKey);
}

/// 不接受任何配对的响应方策略（只做同步）。
LanSyncResponderPolicy syncOnlyPolicy(TrustList trust) {
  return LanSyncResponderPolicy(
    isTrusted: trust.check,
    confirmSas: (_, _) async => false,
    consumeQrToken: (_) => false,
  );
}

/// 在两个握手都结束后返回各自的结果或异常，避免一方的失败让另一方的 future
/// 无人等待。
Future<(Object, Object)> both(
  Future<LanSyncHandshakeResult> a,
  Future<LanSyncHandshakeResult> b,
) async {
  Future<Object> settle(Future<LanSyncHandshakeResult> f) =>
      f.then<Object>((value) => value, onError: (Object error) => error);
  final results = await Future.wait([settle(a), settle(b)]);
  return (results[0], results[1]);
}
