import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_discovery.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_network.dart';

LanSyncBeacon _beacon(String id, {int port = 47562}) => LanSyncBeacon(
  deviceId: id,
  name: 'device-$id',
  platform: 'linux',
  port: port,
  fingerprint: '0123456789abcdef',
  formatVersion: 1,
);

/// 信标间隔取很长：测试只依赖启动时的那一次与收到新设备时的单播回复，
/// 不等计时器。
const Duration _longInterval = Duration(hours: 1);

/// 只发给本机回环上的 [port]，不碰广播与组播。
LanSyncDiscovery _loopback({
  List<int> targetPorts = const [],
  DateTime Function()? now,
}) => LanSyncDiscovery(
  port: 0,
  targets: [
    for (final port in targetPorts)
      (address: InternetAddress.loopbackIPv4, port: port),
  ],
  joinMulticast: false,
  nativeChannel: LanSyncNativeChannel(isAndroid: false),
  now: now,
  sweepInterval: _longInterval,
);

/// 等到 [listenable] 的值满足 [predicate]；超时即失败（不是固定等待）。
Future<void> _until<T>(
  ValueListenable<T> listenable,
  bool Function(T value) predicate,
) {
  if (predicate(listenable.value)) {
    return Future<void>.value();
  }
  final completer = Completer<void>();
  void listener() {
    if (!completer.isCompleted && predicate(listenable.value)) {
      completer.complete();
    }
  }

  listenable.addListener(listener);
  return completer.future
      .timeout(const Duration(seconds: 3))
      .whenComplete(() => listenable.removeListener(listener));
}

void main() {
  test('双方经启动信标与单播回复互相发现', () async {
    final b = _loopback();
    addTearDown(b.dispose);
    await b.start(beacon: () => _beacon('b'), interval: _longInterval);
    expect(b.status.value.running, isTrue);
    expect(b.status.value.listening, isTrue);
    final bPort = b.status.value.boundPort!;

    // A 只知道 B 的端口；B 并不知道 A，只能靠收到新设备时的单播回复让 A 看到。
    final a = _loopback(targetPorts: [bPort]);
    addTearDown(a.dispose);
    await a.start(
      beacon: () => _beacon('a', port: 50000),
      interval: _longInterval,
    );

    await _until(b.peers, (peers) => peers.containsKey('a'));
    await _until(a.peers, (peers) => peers.containsKey('b'));

    final seenByB = b.peers.value['a']!;
    expect(seenByB.beacon, _beacon('a', port: 50000));
    expect(seenByB.address, InternetAddress.loopbackIPv4);
    expect(a.peers.value['b']!.beacon.name, 'device-b');
  });

  test('忽略自己的信标', () async {
    final a = _loopback();
    addTearDown(a.dispose);
    final handled = Completer<void>();
    // 端口在 start 之后才知道，所以由第二个实例冒用同一个 deviceId 发包，
    // 等同于收到了自己经广播 / 组播回环回来的信标。
    await a.start(beacon: () => _beacon('same'), interval: _longInterval);
    final sub = a.onDatagramHandled.listen((_) {
      if (!handled.isCompleted) handled.complete();
    });
    addTearDown(sub.cancel);

    final impostor = _loopback(targetPorts: [a.status.value.boundPort!]);
    addTearDown(impostor.dispose);
    await impostor.start(
      beacon: () => _beacon('same'),
      interval: _longInterval,
    );

    await handled.future.timeout(const Duration(seconds: 3));
    expect(a.peers.value, isEmpty);
  });

  test('超过 8 秒没收到信标即离线，之后再收到算新设备', () async {
    var now = DateTime(2026, 10, 29, 12);
    final b = _loopback(now: () => now);
    addTearDown(b.dispose);
    await b.start(beacon: () => _beacon('b'), interval: _longInterval);
    final bPort = b.status.value.boundPort!;

    final a = _loopback(targetPorts: [bPort]);
    addTearDown(a.dispose);
    await a.start(beacon: () => _beacon('a'), interval: _longInterval);
    await _until(b.peers, (peers) => peers.containsKey('a'));

    now = now.add(const Duration(seconds: 8));
    b.sweepNow();
    expect(b.peers.value.containsKey('a'), isTrue, reason: '恰好 8 秒仍在线');

    now = now.add(const Duration(milliseconds: 1));
    b.sweepNow();
    expect(b.peers.value, isEmpty);

    // 重新启动 A 会立即再发一次信标，B 重新记入在线表。
    await a.stop();
    await a.start(beacon: () => _beacon('a'), interval: _longInterval);
    await _until(b.peers, (peers) => peers.containsKey('a'));
    expect(b.peers.value['a']!.lastSeen, now);
  });

  test('停止后清空在线表与状态，可再次启动', () async {
    final b = _loopback();
    addTearDown(b.dispose);
    await b.start(beacon: () => _beacon('b'), interval: _longInterval);
    final a = _loopback(targetPorts: [b.status.value.boundPort!]);
    addTearDown(a.dispose);
    await a.start(beacon: () => _beacon('a'), interval: _longInterval);
    await _until(b.peers, (peers) => peers.isNotEmpty);

    await b.stop();
    expect(b.peers.value, isEmpty);
    expect(b.status.value, LanSyncDiscoveryStatus.stopped);

    await b.start(beacon: () => _beacon('b'), interval: _longInterval);
    expect(b.status.value.running, isTrue);
    b.setInterval(kLanSyncBeaconIntervalPage);
    expect(b.interval, kLanSyncBeaconIntervalPage);
  });

  test('发现端口被占用时退到随机端口并报告未监听', () async {
    final blocker = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: false,
    );
    addTearDown(blocker.close);
    final discovery = LanSyncDiscovery(
      port: blocker.port,
      targets: const [],
      joinMulticast: false,
      nativeChannel: LanSyncNativeChannel(isAndroid: false),
    );
    addTearDown(discovery.dispose);
    await discovery.start(beacon: () => _beacon('a'), interval: _longInterval);
    final status = discovery.status.value;
    expect(status.running, isTrue);
    expect(status.listening, isFalse);
    expect(status.boundPort, isNot(blocker.port));
  });
}
