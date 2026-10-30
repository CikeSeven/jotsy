// 局域网同步引擎的失败原因（会话、配对与同步记录共用）。
//
// 纯数据，无副作用。引擎在 core 里、不引用界面模块，所以这里自成一套枚举；
// 界面适配层（任务 11 之后）把它换算成 `LanSyncFailureReason`，对照见
// lan_sync_service.dart 顶部的映射说明。枚举名即 sessions.json 里存的字符串，
// 改名会让旧记录读成 [LanSyncFailure.unknown]。

/// 同步或配对失败的原因。
enum LanSyncFailure {
  /// 连不上对方（地址不对、对方不在线、防火墙拦截）。
  unreachable,

  /// 连接中途断开（没有收到对方的结束或中止）。
  connectionLost,

  /// 对方在时限内没有任何消息（含配对确认超时）。
  timedOut,

  /// 对方拒绝：对方关闭了自动同步、对方用户拒绝了配对或取消了确认。
  declined,

  /// 本机用户取消（取消同步、确认对话框点了取消、配对面板关闭）。
  cancelled,

  /// 对方用户取消了这次同步（对方发来 `abort{cancelled}`）。
  peerCancelled,

  /// 两边的同步格式版本或实体集合不同（或握手协议版本不同）。
  incompatibleVersion,

  /// 对方不再信任本机，或本机不再信任对方：需要重新配对。
  untrusted,

  /// 扫码配对的令牌过期、已用过或不对。
  ticketExpired,

  /// 写入数据库或设置失败（事务已回滚）。
  writeFailed,

  /// 对方正在编辑（或正与另一台设备同步），拒绝了这次会话。
  busy,

  /// 本机有正在编辑的页面，手动同步不开始（自动同步遇到时静默跳过）。
  localEditing,

  /// 自动同步遇到需要用户确认的情况（以哪边为准 / 删除保护），已中止、什么
  /// 都没写；设备标记为“需要确认”。
  needsConfirmation,

  /// 撤销提示一直没有关闭，写入推迟（什么都没写），稍后再同步。
  deferred,

  /// 媒体文件传输失败（大小或 sha256 不符、文件在发送方已不存在）。
  transferFailed,

  /// 对方发来的消息不合协议（格式、顺序或取值不对）。
  protocolError,

  /// 其他原因。
  unknown;

  /// 按名称读取（sessions.json、`abort{reason}`）；认不出的为 [unknown]。
  static LanSyncFailure fromName(Object? name) =>
      name is String ? (values.asNameMap()[name] ?? unknown) : unknown;
}
