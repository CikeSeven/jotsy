// 局域网同步的本机偏好、已配对设备与同步记录（docs/lan_sync.md §3）。
//
// 职责边界：
// - 输入：注入的状态目录 `stateDir`（不随系统备份克隆；测试注入临时目录）；
// - 输出：[LanSyncStore.data]（偏好 + 已配对设备）与 [LanSyncStore.sessions]
//   （最近 [kLanSyncSessionHistoryLimit] 次同步记录，新的在前）；
// - 副作用：读写 `stateDir/store.json` 与 `stateDir/sessions.json`。
//
// 为什么不放 SharedPreferences：已配对设备里有对方的身份公钥，偏好里有这台
// 设备的同步开关，都属于“这台设备”而不是“这份数据”——SharedPreferences 会
// 随应用自己的备份导出、随系统备份克隆到新手机，新手机就会冒用旧手机的
// 配对关系。状态目录只在本机。
//
// 读：文件缺失、损坏或不是 JSON 一律当作空并打印日志（等于一台没配对过的
// 设备，最坏是重新配对，不会丢日记）；逐字段容错见 lan_sync_store_models.dart。
// 写：内存里的值同步更新（调用方立刻读到新值），文件经串行队列写临时文件后
// 改名：写到一半断电只会留下旧文件或临时文件。连续多次修改时每次写最新的
// 整份内容，后一次写覆盖前一次。
//
// “覆盖恢复待确认”按设备记：覆盖恢复（[markRestoredPending]）时给当时全部
// 已配对设备置 `restoredPending`，与每台设备成功同步一次后各自清除——规格
// §3 要求“之后与每台设备的第一次同步”都走“以哪边为准”。恢复之后才配对的
// 设备本来就是首次同步，不需要这个标记。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'lan_sync_session_record.dart';
import 'lan_sync_store_models.dart';

export 'lan_sync_session_record.dart';
export 'lan_sync_store_models.dart';

/// 保留的同步记录条数（全部设备合计）。
const int kLanSyncSessionHistoryLimit = 50;

/// 偏好与已配对设备的快照。
@immutable
class LanSyncStoreData {
  LanSyncStoreData({
    this.prefs = const LanSyncPrefs(),
    List<LanSyncPairedDevice> peers = const <LanSyncPairedDevice>[],
  }) : peers = List<LanSyncPairedDevice>.unmodifiable(peers);

  final LanSyncPrefs prefs;

  /// 已配对设备，按配对时间先后。
  final List<LanSyncPairedDevice> peers;

  LanSyncPairedDevice? peer(String deviceId) {
    for (final peer in peers) {
      if (peer.deviceId == deviceId) return peer;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncStoreData &&
      other.prefs == prefs &&
      listEquals(other.peers, peers);

  @override
  int get hashCode => Object.hash(prefs, Object.hashAll(peers));
}

class LanSyncStore {
  LanSyncStore._(this.stateDir, LanSyncStoreData data, this._sessionList)
    : _data = ValueNotifier<LanSyncStoreData>(data),
      _sessions = ValueNotifier<List<LanSyncSessionRecord>>(
        List<LanSyncSessionRecord>.unmodifiable(_sessionList),
      );

  static const String storeFile = 'store.json';
  static const String sessionsFile = 'sessions.json';
  static const int _version = 1;

  final Directory stateDir;
  final ValueNotifier<LanSyncStoreData> _data;
  final ValueNotifier<List<LanSyncSessionRecord>> _sessions;
  final List<LanSyncSessionRecord> _sessionList;
  Future<void> _writes = Future<void>.value();

  /// 读出 `store.json` 与 `sessions.json`（不存在或损坏时为空）。
  static Future<LanSyncStore> open(Directory stateDir) async {
    final store = await _readJson(stateDir, storeFile);
    final prefs = LanSyncPrefs.fromJson(store?['prefs']);
    final peers = <LanSyncPairedDevice>[];
    final seen = <String>{};
    final rawPeers = store?['peers'];
    if (rawPeers is List) {
      for (final item in rawPeers) {
        final peer = LanSyncPairedDevice.tryFromJson(item);
        if (peer != null && seen.add(peer.deviceId)) peers.add(peer);
      }
    }
    final sessions = <LanSyncSessionRecord>[];
    final rawSessions = (await _readJson(stateDir, sessionsFile))?['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        final record = LanSyncSessionRecord.tryFromJson(item);
        if (record != null) sessions.add(record);
        if (sessions.length == kLanSyncSessionHistoryLimit) break;
      }
    }
    return LanSyncStore._(
      stateDir,
      LanSyncStoreData(prefs: prefs, peers: peers),
      sessions,
    );
  }

  /// 偏好与已配对设备（每次修改给出新快照）。
  ValueListenable<LanSyncStoreData> get data => _data;

  /// 同步记录，新的在前。
  ValueListenable<List<LanSyncSessionRecord>> get sessions => _sessions;

  LanSyncPrefs get prefs => _data.value.prefs;

  LanSyncPairedDevice? peer(String deviceId) => _data.value.peer(deviceId);

  Future<void> updatePrefs(LanSyncPrefs Function(LanSyncPrefs prefs) change) {
    final data = _data.value;
    return _setData(
      LanSyncStoreData(prefs: change(data.prefs), peers: data.peers),
    );
  }

  /// 新增或替换（按 deviceId）一台已配对设备；新增的排在最后。
  Future<void> upsertPeer(LanSyncPairedDevice device) {
    final data = _data.value;
    final peers = <LanSyncPairedDevice>[...data.peers];
    final index = peers.indexWhere((p) => p.deviceId == device.deviceId);
    if (index < 0) {
      peers.add(device);
    } else {
      peers[index] = device;
    }
    return _setData(LanSyncStoreData(prefs: data.prefs, peers: peers));
  }

  /// 修改一台已配对设备；不存在（期间被取消配对）时什么也不做。
  Future<void> updatePeer(
    String deviceId,
    LanSyncPairedDevice Function(LanSyncPairedDevice device) change,
  ) {
    final current = peer(deviceId);
    if (current == null) return _writes;
    return upsertPeer(change(current));
  }

  /// 取消配对：忘掉对方的公钥与它的同步记录（不删除任何日记）。
  Future<void> removePeer(String deviceId) {
    final data = _data.value;
    _sessionList.removeWhere((record) => record.peerId == deviceId);
    _publishSessions();
    return _setData(
      LanSyncStoreData(
        prefs: data.prefs,
        peers: [
          for (final peer in data.peers)
            if (peer.deviceId != deviceId) peer,
        ],
      ),
      sessionsChanged: true,
    );
  }

  /// 覆盖恢复之后：当时全部已配对设备的下一次同步走“以哪边为准”。
  Future<void> markRestoredPending() {
    final data = _data.value;
    return _setData(
      LanSyncStoreData(
        prefs: data.prefs,
        peers: [
          for (final peer in data.peers) peer.copyWith(restoredPending: true),
        ],
      ),
    );
  }

  /// 记一次同步（新的在前，最多保留 [kLanSyncSessionHistoryLimit] 条）。
  Future<void> addSession(LanSyncSessionRecord record) {
    _sessionList.insert(0, record);
    if (_sessionList.length > kLanSyncSessionHistoryLimit) {
      _sessionList.removeRange(
        kLanSyncSessionHistoryLimit,
        _sessionList.length,
      );
    }
    _publishSessions();
    return _schedule(sessions: true);
  }

  /// 本机身份新建（`identity.json` 缺失或损坏）后调用：已配对设备与同步记录
  /// 全部清空——对方存的是旧公钥，这些配对已经不成立。偏好保留。
  Future<void> clearPairing() {
    _sessionList.clear();
    _publishSessions();
    return _setData(LanSyncStoreData(prefs: prefs), sessionsChanged: true);
  }

  /// 等排队中的写入全部完成（测试与退出前用）。
  Future<void> flush() => _writes;

  void dispose() {
    _data.dispose();
    _sessions.dispose();
  }

  Future<void> _setData(LanSyncStoreData data, {bool sessionsChanged = false}) {
    _data.value = data;
    return _schedule(store: true, sessions: sessionsChanged);
  }

  void _publishSessions() {
    _sessions.value = List<LanSyncSessionRecord>.unmodifiable(_sessionList);
  }

  /// 排队写文件；写的是执行那一刻的最新内容。写失败只打印日志：内存里的值
  /// 照常生效，下一次修改会再写一遍整份。
  Future<void> _schedule({bool store = false, bool sessions = false}) {
    final next = _writes.then((_) async {
      try {
        if (store) {
          final data = _data.value;
          await _writeJson(storeFile, <String, Object?>{
            'v': _version,
            'prefs': data.prefs.toJson(),
            'peers': [for (final peer in data.peers) peer.toJson()],
          });
        }
        if (sessions) {
          await _writeJson(sessionsFile, <String, Object?>{
            'v': _version,
            'sessions': [for (final record in _sessionList) record.toJson()],
          });
        }
      } catch (error) {
        debugPrint('LAN sync store write failed: $error');
      }
    });
    return _writes = next;
  }

  Future<void> _writeJson(String name, Map<String, Object?> json) async {
    await stateDir.create(recursive: true);
    final target = File(p.join(stateDir.path, name));
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(target.path);
  }

  static Future<Map<dynamic, dynamic>?> _readJson(
    Directory stateDir,
    String name,
  ) async {
    final file = File(p.join(stateDir.path, name));
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is Map && json['v'] == _version) return json;
      debugPrint('LAN sync $name has an unknown shape, ignored');
    } catch (error) {
      debugPrint('LAN sync $name unreadable, ignored: $error');
    }
    return null;
  }
}
