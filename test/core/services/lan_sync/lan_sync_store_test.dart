import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_failure.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jotsy_lan_store_');
  });

  tearDown(() => dir.delete(recursive: true));

  LanSyncPairedDevice peer(String id, {int keyByte = 1}) => LanSyncPairedDevice(
    deviceId: id,
    name: 'Phone $id',
    platform: 'android',
    publicKey: List<int>.filled(32, keyByte),
    pairedAt: DateTime.utc(2026, 10, 1),
  );

  test('往返：偏好、已配对设备、同步记录写进文件再读出相同', () async {
    final store = await LanSyncStore.open(dir);
    await store.updatePrefs(
      (prefs) => prefs.copyWith(
        deviceName: () => 'ThinkPad',
        discoverable: false,
        syncSettings: true,
      ),
    );
    await store.upsertPeer(
      peer('a').copyWith(
        lastSyncAt: () => DateTime.utc(2026, 10, 2),
        lastHost: () => '192.168.1.5',
        lastPort: () => 47562,
        alias: () => '客厅',
        needsAttention: true,
      ),
    );
    await store.upsertPeer(peer('b', keyByte: 2));
    await store.addSession(
      LanSyncSessionRecord(
        peerId: 'a',
        at: DateTime.utc(2026, 10, 2),
        duration: const Duration(seconds: 3),
        receivedDiaries: 2,
        sentDiaries: 1,
        receivedOthers: 3,
        sentOthers: 4,
        mediaBytes: 99,
        conflictCopies: 1,
        firstSync: true,
      ),
    );
    await store.addSession(
      LanSyncSessionRecord(
        peerId: 'b',
        at: DateTime.utc(2026, 10, 3),
        automatic: true,
        failure: LanSyncFailure.connectionLost,
      ),
    );
    await store.flush();

    final reopened = await LanSyncStore.open(dir);
    expect(reopened.data.value, store.data.value);
    expect(reopened.sessions.value, store.sessions.value);
    final first = reopened.sessions.value.singleWhere((r) => r.peerId == 'a');
    expect(first.receivedOthers, 3);
    expect(first.sentOthers, 4);
    expect(reopened.prefs.deviceName, 'ThinkPad');
    expect(reopened.peer('a')!.alias, '客厅');
    expect(reopened.peer('a')!.needsAttention, isTrue);
    expect(
      reopened.sessions.value.first.failure,
      LanSyncFailure.connectionLost,
    );
    expect(reopened.peer('b')!.matches('b', List<int>.filled(32, 2)), isTrue);
  });

  test('容错：坏字段回到默认值，缺身份的设备整条丢弃，坏文件当作空', () async {
    await File(p.join(dir.path, LanSyncStore.storeFile)).writeAsString(
      jsonEncode({
        'v': 1,
        'prefs': {'deviceName': 42, 'discoverable': 'yes', 'autoSync': false},
        'peers': [
          {
            'deviceId': 'ok',
            'publicKey': base64.encode(List<int>.filled(32, 7)),
            'name': 5,
            'lastPort': 999999,
            'autoSync': 'no',
          },
          {'deviceId': 'no-key'},
          {
            'deviceId': 'short-key',
            'publicKey': base64.encode([1, 2]),
          },
          'garbage',
        ],
      }),
    );
    await File(
      p.join(dir.path, LanSyncStore.sessionsFile),
    ).writeAsString('{not json');
    final store = await LanSyncStore.open(dir);
    expect(store.prefs.deviceName, isNull);
    expect(store.prefs.discoverable, isTrue);
    expect(store.prefs.autoSync, isFalse);
    expect(store.data.value.peers.map((d) => d.deviceId), ['ok']);
    final ok = store.peer('ok')!;
    expect(ok.name, 'ok');
    expect(ok.lastPort, isNull);
    expect(ok.autoSync, isTrue);
    expect(store.sessions.value, isEmpty);
  });

  test('原子写入：只留目标文件，不留临时文件；同步记录最多 50 条', () async {
    final store = await LanSyncStore.open(dir);
    for (var i = 0; i < 60; i++) {
      await store.addSession(
        LanSyncSessionRecord(peerId: 'a', at: DateTime.utc(2026, 1, 1, 0, i)),
      );
    }
    await store.flush();
    final names = dir.listSync().map((e) => p.basename(e.path)).toSet();
    expect(names, {LanSyncStore.sessionsFile});
    final reopened = await LanSyncStore.open(dir);
    expect(reopened.sessions.value, hasLength(kLanSyncSessionHistoryLimit));
    expect(reopened.sessions.value.first.at, DateTime.utc(2026, 1, 1, 0, 59));
  });

  test('新身份：清空已配对设备与同步记录，偏好保留', () async {
    final store = await LanSyncStore.open(dir);
    await store.updatePrefs((prefs) => prefs.copyWith(autoSync: false));
    await store.upsertPeer(peer('a'));
    await store.addSession(
      LanSyncSessionRecord(peerId: 'a', at: DateTime.utc(2026)),
    );
    await store.clearPairing();
    await store.flush();
    final reopened = await LanSyncStore.open(dir);
    expect(reopened.data.value.peers, isEmpty);
    expect(reopened.sessions.value, isEmpty);
    expect(reopened.prefs.autoSync, isFalse);
  });

  test('取消配对删掉它的同步记录；覆盖恢复给全部设备置待确认', () async {
    final store = await LanSyncStore.open(dir);
    await store.upsertPeer(peer('a'));
    await store.upsertPeer(peer('b', keyByte: 2));
    await store.addSession(
      LanSyncSessionRecord(peerId: 'a', at: DateTime.utc(2026)),
    );
    await store.addSession(
      LanSyncSessionRecord(peerId: 'b', at: DateTime.utc(2026)),
    );
    await store.markRestoredPending();
    expect(store.data.value.peers.every((d) => d.restoredPending), isTrue);
    await store.removePeer('a');
    expect(store.peer('a'), isNull);
    expect(store.sessions.value.map((r) => r.peerId), ['b']);
  });
}
