// 局域网同步界面与同步引擎之间的唯一接口。
//
// 界面（同步页、配对 / 二维码 / 扫码面板、设备详情页、设置入口、自动同步
// 提示）只经这里读状态、发指令，不直接接触发现、握手、会话与数据库。
// 实现方负责：
// - 状态：[LanSyncUiController.state] 每次变化给出一份新的不可变快照；
// - 事件：[LanSyncUiController.events] 为广播流，只推给当前的监听者；
// - 线程：所有方法都在 UI isolate 上调用，返回的 Future 不抛出——失败一律
//   体现在状态或事件里（如配对失败为 `LanSyncPairingFailed`、同步失败为带
//   失败原因的 `LanSyncSessionFinishedEvent`），界面不需要 try/catch。

import 'package:flutter/foundation.dart';

import 'lan_sync_qr_ticket.dart';
import 'lan_sync_ui_events.dart';
import 'lan_sync_view_state.dart';

/// 同步界面的控制器接口；由 `lanSyncControllerProvider` 提供。
abstract interface class LanSyncUiController {
  /// 整页视图状态；同步页、设置入口副标题与设备详情页共用。
  ValueListenable<LanSyncViewState> get state;

  /// 一次性界面事件（广播流，不重放）。
  Stream<LanSyncUiEvent> get events;

  /// 同步页变为可见：发现切到快节奏（每 2 秒一次信标，docs §5.1），并开始
  /// 填充 `nearby`。与 [detachPage] 成对调用；重复调用按引用计数处理，
  /// 同时打开的同步页与设备详情页各计一次。
  void attachPage();

  /// 同步页不再可见（离开、被别的页面盖住或应用切到后台）：发现回到前台
  /// 自动模式的慢节奏，`nearby` 可以清空、`searching` 变为 false。
  void detachPage();

  /// 修改本机设备名（去掉首尾空白，最多 40 字；空名不调用）。新名称随下
  /// 一次信标与握手告诉对方。
  Future<void> renameDevice(String name);

  /// 是否广播自己、允许附近的设备发现。关闭后仍能主动连接已配对设备、
  /// 手动输入地址与扫码。
  Future<void> setDiscoverable(bool discoverable);

  /// 全局“自动同步”开关：应用在前台时与已配对设备自动同步。
  Future<void> setAutoSync(bool enabled);

  /// “同步设置”开关：两台设备都开启时才同步设置（docs §0）。
  Future<void> setSyncSettings(bool enabled);

  /// 立即与 [peerId] 同步（手动同步）。会话进度经 `LanSyncPeerView.session`，
  /// 需要确认时发 [LanSyncConfirmationEvent]，结束时发
  /// [LanSyncSessionFinishedEvent]。对方不在线或已在同步时不产生效果。
  Future<void> syncNow(String peerId);

  /// 取消与 [peerId] 正在进行的同步：已写入的部分保留，下次自动补齐。
  Future<void> cancelSync(String peerId);

  /// 再次发出 [peerId] 那次等待确认的同步的 [LanSyncConfirmationEvent]
  /// （设备行与自动同步提示上的“查看”）。没有等待确认的同步时不产生效果。
  void reviewPendingConfirmation(String peerId);

  /// 与附近的一台设备配对（核对码）：随即发出 [LanSyncPairingEvent]。
  Future<void> pairWith(String nearbyDeviceId);

  /// 按地址连接一台设备：已配对的直接同步，否则走核对码配对（发出
  /// [LanSyncPairingEvent]，连不上时其阶段为失败）。[host] 为 IP 或主机名。
  Future<void> connectManual(String host, int port);

  /// 处理扫到的二维码文本：是 Jotsy 配对码时开始扫码配对（发出
  /// [LanSyncPairingEvent]）并返回 true；不是时返回 false、什么都不做
  /// （扫码页据此只提示一次“这不是 Jotsy 的二维码”）。同步判断，不等待连接。
  bool connectQr(String payload);

  /// 开始显示二维码：签发一张一次性令牌并返回；之后到期或被扫过时自动换发，
  /// 新的一张经 [qrTicket] 通知。二维码面板关闭时须调用 [revokeQrTicket]。
  LanSyncQrTicket issueQrTicket();

  /// 当前有效的二维码；没有在显示二维码时为 null。
  ValueListenable<LanSyncQrTicket?> get qrTicket;

  /// 停止显示二维码：当前令牌立即作废，[qrTicket] 变为 null。
  void revokeQrTicket();

  /// 设置 [peerId] 的本机备注名；null 或空白为清除（显示对方自己的名字）。
  Future<void> setPeerAlias(String peerId, String? alias);

  /// 单设备的自动同步开关。
  Future<void> setPeerAutoSync(String peerId, bool enabled);

  /// 取消配对：忘掉对方的公钥与同步记录，不删除任何日记。
  Future<void> forgetPeer(String peerId);
}
