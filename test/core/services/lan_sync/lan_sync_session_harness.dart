import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_session.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:path/path.dart' as p;

import '../../../support/lan_sync_two_devices.dart';
import 'lan_sync_fake_channel.dart';

/// 测试用的短计时：静默超时足够长、不会误报；ping 很密。
const LanSyncSessionTimeouts kTestSessionTimeouts = LanSyncSessionTimeouts(
  silence: Duration(seconds: 5),
  keepAlive: Duration(milliseconds: 50),
  confirmation: Duration(seconds: 5),
  progressInterval: Duration.zero,
);

LanSyncSessionContext sessionContextOf(
  LanSyncTestDevice device,
  LanSyncTestClock clock, {
  bool Function()? isEditing,
}) => LanSyncSessionContext(
  deviceId: device.deviceId,
  state: device.state,
  applier: device.applier,
  media: device.media,
  mediaIndex: device.index,
  dataRoot: device.dataRoot,
  flushAll: () async {},
  isEditing: isEditing ?? () => false,
  clock: clock.call,
  appVersion: 'test',
);

/// 一次会话的两端与结果。
class SessionRun {
  SessionRun(this.initiatorChannel, this.responderChannel);

  final FakeLanSyncChannel initiatorChannel;
  final FakeLanSyncChannel responderChannel;
  late final LanSyncSession initiator;
  late final LanSyncSession responder;
  late final LanSyncSessionResult initiatorResult;
  late final LanSyncSessionResult responderResult;
  final List<LanSyncConfirmationRequest> requests = [];
}

/// 用一对内存信道跑一次完整会话。[answer] 应答确认请求（默认保留两份 /
/// 照常删除）；[setup] 在开始前拿到两端的信道与会话，可注入断线或取消。
Future<SessionRun> runSession(
  LanSyncTestDevice a,
  LanSyncTestDevice b,
  LanSyncTestClock clock, {
  bool automatic = false,
  bool firstSync = false,
  bool responderEditing = false,
  bool acceptAutomatic = true,
  bool responderBusy = false,
  void Function(LanSyncConfirmationRequest request)? answer,
  void Function(SessionRun run)? setup,
  LanSyncSessionTimeouts timeouts = kTestSessionTimeouts,
}) async {
  final (ic, rc) = FakeLanSyncChannel.pair();
  final run = SessionRun(ic, rc);
  run.initiator = LanSyncSession.initiator(
    channel: ic,
    context: sessionContextOf(a, clock),
    peer: LanSyncSessionPeer(deviceId: b.deviceId, firstSync: firstSync),
    automatic: automatic,
    syncSettings: false,
    localLoserTitleSuffix: ' (copy · ${a.deviceId})',
    remoteLoserTitleSuffix: ' (copy · ${b.deviceId})',
    onConfirmation: (request) {
      run.requests.add(request);
      (answer ?? _defaultAnswer)(request);
    },
    timeouts: timeouts,
  );
  run.responder = LanSyncSession.responder(
    channel: rc,
    context: sessionContextOf(b, clock, isEditing: () => responderEditing),
    peer: LanSyncSessionPeer(deviceId: a.deviceId),
    syncSettings: false,
    acceptAutomatic: acceptAutomatic,
    busy: responderBusy,
    timeouts: timeouts,
  );
  setup?.call(run);
  final results = await Future.wait([run.initiator.run(), run.responder.run()]);
  run.initiatorResult = results[0];
  run.responderResult = results[1];
  return run;
}

void _defaultAnswer(LanSyncConfirmationRequest request) {
  switch (request) {
    case LanSyncSideChoiceRequest():
      request.respond(SyncSideChoice.keepBoth);
    case LanSyncDeletionGuardRequest():
      request.respond(LanSyncDeletionDecision.syncDeletion);
  }
}

/// 暂存区里还剩的会话目录（应当总是没有）。
List<String> leftoverStaging(LanSyncTestDevice device) {
  final root = Directory(p.join(device.dataRoot.path, kSyncStagingDirName));
  if (!root.existsSync()) return const [];
  return [for (final entry in root.listSync()) p.basename(entry.path)];
}

String docOf(String text) => jsonEncode({
  'document': {
    'type': 'page',
    'children': [
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': text},
          ],
        },
      },
    ],
  },
});

String docWithImage(String text, String imagePath) => jsonEncode({
  'document': {
    'type': 'page',
    'children': [
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': text},
          ],
        },
      },
      {
        'type': 'image',
        'data': {'url': imagePath},
      },
    ],
  },
});

DateTime atSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// 插入一篇日记（时间按秒）。
Future<int> seedDiary(
  AppDatabase db,
  String id, {
  String title = '',
  String? content,
  int updated = 1700000100,
}) => db
    .into(db.diaries)
    .insert(
      DiariesCompanion.insert(
        diaryId: id,
        title: Value(title),
        content: content ?? docOf(title),
        contentText: '',
        createdAt: atSeconds(1700000000),
        updatedAt: atSeconds(updated),
      ),
    );

Future<void> setTitle(
  AppDatabase db,
  String id,
  String title, {
  required int updated,
}) => db.customStatement(
  "UPDATE diaries SET title = '$title', updated_at = $updated "
  "WHERE diary_id = '$id'",
);

Future<Set<String>> diaryIds(LanSyncTestDevice device) async => {
  for (final row in await device.db.select(device.db.diaries).get())
    row.diaryId,
};
