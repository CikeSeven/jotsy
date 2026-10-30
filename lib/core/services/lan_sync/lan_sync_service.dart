// 局域网同步服务：应用生命周期内的一份编排（docs/lan_sync.md §5、§9）。
//
// 职责边界：
// - 输入（构造注入）：数据库、数据根目录、状态目录、设置服务（同步设置用）、
//   冲突副本标题后缀（界面层本地化后给出）、编辑会话接口、外部能力
//   [LanSyncServiceHooks]（套接字、发现、地址、时钟、计时器）与计时；
// - 输出：[state]（整体状态快照）、[events]（配对、确认、会话结束、自动同步
//   提示）、[qrTicket]；
// - 副作用：TCP 服务端、UDP 发现、出站连接、`stateDir` 里的身份 / store /
//   同步状态、经会话写库与媒体；在 `DataArchiveService` 登记覆盖恢复的监听。
//
// 生命周期：[start] 读身份（新身份 → 清空配对与同步状态）、清理过期暂存区；
// 服务端与发现只在前台、且同步页打开或至少有一台已配对设备时运行（没配对
// 过的用户不碰网络，docs §9），“可被发现”关闭时发现只听不发；
// [setForeground] 切到后台时全部停掉、取消自动同步计时，回来时恢复；
// [attachPage] / [detachPage] 按引用计数切换信标节奏（页面 2 秒、前台自动
// 5 秒）与附近设备列表；[dispose] 全部关闭。
// 同一时刻最多一个会话（任一方向）：会话期间同一个 `SyncLocalState` 只被它用。
//
// ─── 给界面适配层的对照（`EngineLanSyncUiController`）───
// 换算在 lib/ui/lan_sync/models/lan_sync_engine_mapping.dart 与
// lan_sync_engine_events.dart。
// 状态 `LanSyncViewState` ← [state]：
//   local.name / addresses / port / discoverable / discoveryListening
//     ← `LanSyncEngineState.local` 同名字段；platform ← `LanSyncPlatform
//     .fromName(local.platform)`；
//   peers[i] ← `LanSyncEngineState.peers[i]`：deviceId / name / alias /
//     pairedAt / lastSyncAt / autoSync ← `device`（`LanSyncPairedDevice`）；
//     platform ← `fromName(device.platform)`；online / address 同名；
//     needsAttention ← `LanSyncPeerState.needsAttention`；session ←
//     `session`（`LanSyncProgress`：stage 按下标对应 `LanSyncSessionStage`，
//     其余字段同名）；history ← `history`（`LanSyncSessionRecord`：at /
//     duration / automatic / receivedDiaries / sentDiaries / mediaBytes /
//     conflictCopies / firstSync 同名，failureReason ← failure 换算）；
//   nearby / autoSyncEnabled / syncSettingsEnabled / searching ← nearby /
//     autoSync / syncSettings / searching。
// 事件 `LanSyncUiEvent` ← [events]：
//   LanSyncPairingEvent ← [LanSyncPairingStarted]（direction ← incoming，
//     peerName / platform 同名，phase ← `pairing.state` 换算：connecting /
//     awaitingUser(code) / awaitingPeer(code) / succeeded(peerId) /
//     failed(reason)，respond ← `pairing.respond`）；
//   LanSyncChooseSideEvent / LanSyncDeletionGuardEvent ←
//     [LanSyncConfirmationRequested]（`LanSyncSideChoiceRequest.conflicts`、
//     `LanSyncDeletionGuardRequest.count / onLocalSide`；respond 换算后调用
//     请求的 respond：preferLocal / preferPeer ↔ `SyncSideChoice.preferLocal /
//     preferRemote`）；
//   LanSyncSessionFinishedEvent ← [LanSyncSessionEnded] 中本机发起的手动
//     会话（`result.role == initiator && !result.automatic`）：summary 的
//     received / sent ← `result.received / sent`（mediaCount ← mediaFiles），
//     conflictCopies ← `result.conflictCopies`，duration 同名；
//   LanSyncAutoSyncAppliedEvent ← [LanSyncAutoSyncApplied]；
//   LanSyncAutoSyncNeedsAttentionEvent ← [LanSyncAttentionNeeded]。
// 失败原因 `LanSyncFailureReason` ← [LanSyncFailure]：同名的直接对应（含
//   busy / localEditing / deferred / needsConfirmation）；peerCancelled →
//   declined，transferFailed → connectionLost，protocolError → unknown。
// 构造参数 conflictTitleSuffix ← 界面层用本地化文案生成“（冲突副本 · X）”：
//   X 是副本所保存版本那一台的设备名——引擎按败方传入本机设备名或对方的
//   显示名（备注名优先），界面层只负责拼文字。
// 指令：attachPage / detachPage / renameDevice / setDiscoverable /
//   setAutoSync / setSyncSettings / syncNow / cancelSync /
//   reviewPendingConfirmation / pairWith / connectManual / connectQr /
//   issueQrTicket / revokeQrTicket / qrTicket / setPeerAlias /
//   setPeerAutoSync / forgetPeer 与界面接口同名同义；生命周期另需
//   [setForeground]（应用前后台）。
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../data_archive_service.dart';
import '../editing_session_registry.dart';
import '../settings_service.dart';
import 'lan_sync_auto_scheduler.dart';
import 'lan_sync_crypto.dart';
import 'lan_sync_discovery.dart';
import 'lan_sync_handshake.dart';
import 'lan_sync_identity.dart';
import 'lan_sync_messages.dart';
import 'lan_sync_network.dart';
import 'lan_sync_qr_payload.dart';
import 'lan_sync_service_config.dart';
import 'lan_sync_session.dart';
import 'lan_sync_store.dart';
import 'sync/sync_apply.dart';
import 'sync/sync_local_state.dart';
import 'sync/sync_media.dart';
import 'sync/sync_media_index.dart';
import 'sync/sync_model.dart';

export 'lan_sync_service_config.dart';
export 'lan_sync_session.dart'
    show
        LanSyncConfirmationRequest,
        LanSyncCopyInfo,
        LanSyncChangeTally,
        LanSyncDeletionDecision,
        LanSyncDeletionGuardRequest,
        LanSyncFailure,
        LanSyncProgress,
        LanSyncSessionResult,
        LanSyncSessionTimeouts,
        LanSyncSideChoiceRequest,
        LanSyncStage;
export 'lan_sync_store.dart';

part 'lan_sync_service_discovery.dart';
part 'lan_sync_service_lifecycle.dart';
part 'lan_sync_service_outgoing.dart';
part 'lan_sync_service_pairing.dart';
part 'lan_sync_service_server.dart';
part 'lan_sync_service_sessions.dart';
part 'lan_sync_service_types.dart';

class LanSyncService {
  LanSyncService({
    required this.database,
    required this.dataRoot,
    required this.stateDir,
    required this.conflictTitleSuffix,
    this.settings,
    this.appVersion = '',
    LanSyncEditingGate? editing,
    EditingSessionRegistry? registry,
    this.hooks = const LanSyncServiceHooks(),
    this.timings = const LanSyncServiceTimings(),
  }) : registry = registry ?? EditingSessionRegistry.instance,
       _editingOverride = editing {
    _state = ValueNotifier<LanSyncEngineState>(
      LanSyncEngineState(
        local: LanSyncLocalDevice(
          deviceId: '',
          name: '',
          platform: hooks.platformId(),
        ),
      ),
    );
  }

  final AppDatabase database;
  final Directory dataRoot;
  final Directory stateDir;

  /// 设置服务；为 null 时不同步设置（“同步设置”开关照常记录）。
  final SettingsService? settings;

  /// 冲突副本标题后缀：参数是副本所保存版本那一台设备的名字（本机版本为
  /// 本机设备名，对方版本为对方的显示名），返回本地化好的文字（如
  /// “（冲突副本 · ThinkPad）”）。引擎没有本地化，由界面层提供。
  final String Function(String deviceName) conflictTitleSuffix;
  final String appVersion;
  final EditingSessionRegistry registry;
  final LanSyncServiceHooks hooks;
  final LanSyncServiceTimings timings;
  final LanSyncEditingGate? _editingOverride;
  late final LanSyncEditingGate editing =
      _editingOverride ?? LanSyncEditingGate.of(registry);

  late final ValueNotifier<LanSyncEngineState> _state;
  final StreamController<LanSyncEngineEvent> _events =
      StreamController<LanSyncEngineEvent>.broadcast();
  final ValueNotifier<LanSyncIssuedQr?> _qr = ValueNotifier<LanSyncIssuedQr?>(
    null,
  );

  late final LanSyncIdentity _identity;
  late final LanSyncStore _store;
  late final SyncLocalState _syncState;
  late final SyncMediaIndex _mediaIndex;
  late final SyncMediaLibrary _mediaLibrary;
  late final SyncApplier _applier;
  late final LanSyncAutoScheduler _auto;
  String _defaultName = '';
  bool _started = false;
  bool _disposed = false;
  bool _foreground = true;
  int _attachments = 0;
  StreamSubscription<Set<TableUpdate>>? _tableUpdates;

  // 以下由各 part 使用：会话与配对（sessions / outgoing / server）、服务端
  // （server）、发现 / 地址 / 二维码（discovery）。
  _ActiveSession? _active;
  LanSyncPairing? _pairing;
  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  int? _port;
  int _handshakesInFlight = 0;
  Future<void> _networkOp = Future<void>.value();
  LanSyncDiscovery? _discovery;
  Map<String, LanSyncPresence> _presence = const <String, LanSyncPresence>{};
  List<String> _addresses = const <String>[];
  Timer? _addressTimer;
  LanSyncQrToken? _token;
  Timer? _qrTimer;

  /// 整体状态（每次变化给出新快照）。
  ValueListenable<LanSyncEngineState> get state => _state;

  /// 一次性事件（广播，不重放）。
  Stream<LanSyncEngineEvent> get events => _events.stream;

  /// 当前显示的二维码；没在显示时为 null。
  ValueListenable<LanSyncIssuedQr?> get qrTicket => _qr;

  /// 本机身份（[start] 之后可用）。
  LanSyncIdentity get identity => _identity;

  DateTime _now() => hooks.clock();

  String get _deviceName =>
      truncateLanSyncDeviceName(_store.prefs.deviceName ?? _defaultName);

  /// 启动：身份（新身份即清空配对与同步状态，规格 §3“身份”）、店、同步部件、
  /// 清理过期暂存区；前台时起服务端与发现。重复调用无效。
  Future<void> start() => _start();

  /// 关闭：取消会话、停服务端与发现、写完 store。
  Future<void> dispose() => _dispose();

  /// 应用前后台（`AppLifecycleState`）：后台停服务端与发现、取消自动同步
  /// 计时；回到前台恢复并按“回到前台”触发自动同步。
  void setForeground(bool foreground) => _setForeground(foreground);

  /// 同步页（或设备详情页）变为可见 / 不再可见：引用计数，切换信标节奏
  /// （页面 2 秒、前台自动 5 秒）、附近设备列表与是否接受传入的核对码配对。
  void attachPage() => _attachPage();

  void detachPage() => _detachPage();

  /// 改设备名（去掉首尾空白、最多 40 字；空名忽略）。下一拍信标与之后的
  /// 握手带上新名字。
  Future<void> renameDevice(String name) async {
    final trimmed = truncateLanSyncDeviceName(name);
    if (trimmed.isEmpty) return;
    await _store.updatePrefs((p) => p.copyWith(deviceName: () => trimmed));
  }

  /// 关闭后发现只听不发：别人看不到本机，本机仍能看到已配对设备在线。
  Future<void> setDiscoverable(bool discoverable) =>
      _store.updatePrefs((p) => p.copyWith(discoverable: discoverable));

  Future<void> setAutoSync(bool enabled) async {
    await _store.updatePrefs((p) => p.copyWith(autoSync: enabled));
    if (!enabled) _auto.pause();
  }

  Future<void> setSyncSettings(bool enabled) =>
      _store.updatePrefs((p) => p.copyWith(syncSettings: enabled));

  Future<void> setPeerAlias(String peerId, String? alias) {
    final trimmed = alias?.trim();
    return _store.updatePeer(
      peerId,
      (d) => d.copyWith(
        alias: () => trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  Future<void> setPeerAutoSync(String peerId, bool enabled) =>
      _store.updatePeer(peerId, (d) => d.copyWith(autoSync: enabled));

  /// 取消配对：忘掉对方的公钥与同步记录（不删除任何日记）；正在与它同步时
  /// 先取消。
  Future<void> forgetPeer(String peerId) async {
    final active = _active;
    if (active != null && active.peerId == peerId) active.cancel();
    await _store.removePeer(peerId);
  }

  /// 立即与 [peerId] 同步（手动）。返回会话结果；不是已配对设备或已有会话
  /// 在进行时为 null（不产生效果）。需要确认时发 [LanSyncConfirmationRequested]。
  Future<LanSyncSessionResult?> syncNow(String peerId) =>
      _syncWith(peerId, automatic: false);

  /// 取消与 [peerId] 正在进行的同步（已写入的部分保留，下次补齐）。
  void cancelSync(String peerId) {
    final active = _active;
    if (active != null && active.peerId == peerId) active.cancel();
  }

  /// “查看”：再发一次正在等的确认，或为自动同步留下的“需要确认”发起手动
  /// 同步（重新规划后再问）。
  void reviewPendingConfirmation(String peerId) => _review(peerId);

  /// 与附近的一台设备核对码配对；它已不在线时返回 null。
  LanSyncPairing? pairWith(String nearbyDeviceId) {
    final presence = _presence[nearbyDeviceId];
    if (presence == null) return null;
    return _startOutgoingPairing(
      name: presence.beacon.name,
      platform: presence.beacon.platform,
      targets: [(presence.address.address, presence.beacon.port)],
      initiation: _sasInitiation,
    );
  }

  /// 按地址连接：已配对的直接同步，否则核对码配对（失败以配对事件告知）。
  Future<void> connectManual(String host, int port) =>
      _connectManual(host.trim(), port);

  /// 处理扫到的文字：是 Jotsy 配对码时开始扫码配对并返回 true；不是返回
  /// false。同步判断，不等连接。
  bool connectQr(String payload) => _connectQr(payload);

  /// 开始显示二维码：签发一张一次性令牌；之后到期或被扫过自动换发（经
  /// [qrTicket] 通知）。没有局域网地址或服务端没起来时为 null。
  LanSyncIssuedQr? issueQrTicket() => _issueQrTicket();

  /// 停止显示二维码：当前令牌立即作废。
  void revokeQrTicket() => _revokeQrTicket();

  /// 覆盖恢复（`DataArchiveService` 的 replaceAll）成功后由它调用：取消正在
  /// 进行的会话，删掉检查点 / 历史 / 墓碑 / 改名 / 哈希缓存，给当时全部
  /// 已配对设备置“覆盖恢复待确认”（之后与每台的第一次同步走“以哪边为准”）。
  ///
  /// 不等会话结束：这个回调在备份的串行队列里执行，会话的写入也排在同一个
  /// 队列里，等它就会互相等待。若会话已排队等写入，恢复之后它的写入照常经
  /// 前置条件比对——更新与删除因哈希不符被跳过、新增照写，不会丢数据；标记
  /// 保留到下一次成功同步。
  Future<void> noteDataReplacedByRestore() async {
    if (!_started || _disposed) return;
    _active?.cancel();
    await _syncState.resetAfterRestore();
    await _store.markRestoredPending();
  }

  void _emit(LanSyncEngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
