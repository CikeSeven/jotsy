// 本机的局域网同步身份：deviceId（UUID v4）与 Ed25519 身份密钥，存于状态目录
// 的 `identity.json`（docs/lan_sync.md §3、§5.2、§8）。
//
// 职责边界：
// - 输入：注入的状态目录 `stateDir`（不随系统备份克隆；测试注入临时目录）；
// - 输出：[LanSyncIdentity]，以及“这次是否新建”；
// - 副作用：读写 `identity.json`（写临时文件后原子改名）。
//
// 不使用静态 X25519：握手每次都用临时 X25519，身份只靠 Ed25519 签名证明，
// 文件里因此只有一枚私钥种子。私钥只在这个文件里，不进备份、不进 SharedPreferences。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../database/app_database.dart';
import 'lan_sync_crypto.dart';

/// 本机身份。
class LanSyncIdentity {
  LanSyncIdentity({
    required this.deviceId,
    required SimpleKeyPairData signingKey,
    required this.createdAt,
  }) : _signingKey = signingKey,
       publicKey = Uint8List.fromList(signingKey.publicKey.bytes);

  /// 设备的业务 id（UUID v4），信标、hello 与配对记录里的 deviceId。
  final String deviceId;

  /// Ed25519 身份公钥（32 字节）。
  final Uint8List publicKey;

  final DateTime createdAt;

  final SimpleKeyPairData _signingKey;

  /// 指纹：sha256(公钥) 十六进制（64 字符），二维码里用它。
  String get fingerprint => lanSyncFingerprint(publicKey);

  /// 短指纹：前 8 字节十六进制，信标与界面核对用。
  String get shortFingerprint => lanSyncShortFingerprint(publicKey);

  /// 用身份私钥签名。
  Future<Uint8List> sign(List<int> message) async {
    final signature = await Ed25519().sign(message, keyPair: _signingKey);
    return Uint8List.fromList(signature.bytes);
  }

  /// 新建一个随机身份。
  static Future<LanSyncIdentity> generate({DateTime? now}) {
    return fromSeed(
      deviceId: AppDatabase.newBusinessId(),
      seed: lanSyncRandomBytes(32),
      createdAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  /// 由私钥种子还原身份。
  static Future<LanSyncIdentity> fromSeed({
    required String deviceId,
    required List<int> seed,
    required DateTime createdAt,
  }) async {
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    return LanSyncIdentity(
      deviceId: deviceId,
      signingKey: await keyPair.extract(),
      createdAt: createdAt,
    );
  }

  Map<String, Object?> _toJson() => {
    'v': 1,
    'deviceId': deviceId,
    'ed25519Seed': base64.encode(_signingKey.bytes),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}

/// [LanSyncIdentityStore.loadOrCreate] 的结果。
typedef LanSyncIdentityLoad = ({LanSyncIdentity identity, bool created});

/// `identity.json` 的读写。
class LanSyncIdentityStore {
  LanSyncIdentityStore(this.stateDir);

  static const String fileName = 'identity.json';

  final Directory stateDir;

  File get _file => File('${stateDir.path}${Platform.pathSeparator}$fileName');

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// 读出本机身份；文件缺失或内容损坏时新建并写入。
  ///
  /// 契约：`created == true` 表示本机成了“一台新设备”（身份与之前不同或从未
  /// 有过），调用方必须清空已配对设备与全部同步状态（§3“身份”）——对方存的
  /// 是旧公钥，旧的检查点与历史也不再属于这个身份。读文件本身失败（权限等 I/O
  /// 错误）照常抛出，不当作损坏：那种情况下静默重建会无故丢掉所有配对。
  Future<LanSyncIdentityLoad> loadOrCreate() async {
    final file = _file;
    String? raw;
    try {
      raw = await file.readAsString();
    } on PathNotFoundException {
      raw = null;
    }
    if (raw != null) {
      final identity = await _decode(raw);
      if (identity != null) return (identity: identity, created: false);
    }
    final identity = await LanSyncIdentity.generate();
    await _write(identity);
    return (identity: identity, created: true);
  }

  /// 解析文件内容；任何字段缺失或格式不对都返回 null（视为损坏）。
  Future<LanSyncIdentity?> _decode(String raw) async {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> || json['v'] != 1) return null;
      final deviceId = json['deviceId'];
      final seedText = json['ed25519Seed'];
      final createdAt = json['createdAt'];
      if (deviceId is! String ||
          !_uuidPattern.hasMatch(deviceId) ||
          seedText is! String ||
          createdAt is! int) {
        return null;
      }
      final seed = base64.decode(seedText);
      if (seed.length != 32) return null;
      return await LanSyncIdentity.fromSeed(
        deviceId: deviceId,
        seed: seed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }

  /// 写临时文件再改名：写到一半断电不会留下半个 identity.json（那会在下次启动
  /// 时被当作损坏而重建，丢掉所有配对）。
  Future<void> _write(LanSyncIdentity identity) async {
    await stateDir.create(recursive: true);
    final target = _file;
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(identity._toJson()), flush: true);
    await temp.rename(target.path);
  }
}
