// `sessions.json` 里的一条同步记录（docs/lan_sync.md §3），字段与界面的
// 同步记录（`LanSyncHistoryEntryView`）一一对应。
//
// 纯数据，无副作用：不可变、按值比较，JSON 逐字段容错（字段类型不对按默认值，
// 缺 peerId 或时间的整条丢弃）。时间存 UTC 毫秒。
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'lan_sync_failure.dart';

/// 一次同步的记录（`sessions.json`，字段与界面的同步记录一一对应）。
@immutable
class LanSyncSessionRecord {
  const LanSyncSessionRecord({
    required this.peerId,
    required this.at,
    this.duration,
    this.automatic = false,
    this.receivedDiaries = 0,
    this.sentDiaries = 0,
    this.receivedOthers = 0,
    this.sentOthers = 0,
    this.mediaBytes = 0,
    this.conflictCopies = 0,
    this.firstSync = false,
    this.failure,
  });

  static LanSyncSessionRecord? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final peer = json['peerId'];
    final at = _time(json['at']);
    if (peer is! String || peer.isEmpty || at == null) return null;
    final duration = json['durationMs'];
    final failure = json['failure'];
    return LanSyncSessionRecord(
      peerId: peer,
      at: at,
      duration: duration is int && duration >= 0
          ? Duration(milliseconds: duration)
          : null,
      automatic: _bool(json['automatic'], false),
      receivedDiaries: _count(json['received']),
      sentDiaries: _count(json['sent']),
      receivedOthers: _count(json['receivedOthers']),
      sentOthers: _count(json['sentOthers']),
      mediaBytes: _count(json['mediaBytes']),
      conflictCopies: _count(json['conflictCopies']),
      firstSync: _bool(json['firstSync'], false),
      failure: failure == null ? null : LanSyncFailure.fromName(failure),
    );
  }

  final String peerId;

  /// 同步开始的时间。
  final DateTime at;

  /// 用时；失败时为 null。
  final Duration? duration;
  final bool automatic;

  /// 本机收到 / 对方收到的日记篇数（新增 + 更新 + 删除）。
  final int receivedDiaries;
  final int sentDiaries;

  /// 本机收到 / 对方收到的日记以外的变化条数（标签、日记本、留言、设置等）。
  final int receivedOthers;
  final int sentOthers;

  /// 两个方向合计传输的媒体字节数。
  final int mediaBytes;
  final int conflictCopies;

  /// 是否为配对后的第一次同步。
  final bool firstSync;

  /// 失败原因；成功为 null。
  final LanSyncFailure? failure;

  bool get succeeded => failure == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'peerId': peerId,
    'at': at.millisecondsSinceEpoch,
    'durationMs': duration?.inMilliseconds,
    'automatic': automatic,
    'received': receivedDiaries,
    'sent': sentDiaries,
    'receivedOthers': receivedOthers,
    'sentOthers': sentOthers,
    'mediaBytes': mediaBytes,
    'conflictCopies': conflictCopies,
    'firstSync': firstSync,
    'failure': failure?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is LanSyncSessionRecord &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

int _count(Object? value) => value is int && value >= 0 ? value : 0;

DateTime? _time(Object? value) => value is int && value >= 0
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : null;
