import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'cloud_backup_options.dart';

/// 网盘增量备份的远端格式（docs/cloud_backup.md「增量备份」）：文件命名、
/// 索引模型与指纹。
///
/// 全部文件平铺在备份位置原有的目录里（7 种网盘都不必支持子目录），且都
/// 不以 `.zip` 结尾，旧版应用列表时看不到它们：
/// - 媒体包 `jotsy_pack_<链>_<yyyyMMddHHmmss>_<随机8>.pack`：ZIP（STORE），
///   条目名是内容的 sha256；
/// - 快照 `jotsy_inc_<yyyyMMdd_HHmmss>_<链>.snap`：ZIP，只有
///   [incrementalSnapshotEntryName]（载荷 JSON 的 gzip）；
/// - 索引 `jotsy_inc_<yyyyMMdd_HHmmss>_<链>.idx`：ZIP，只有
///   [incrementalIndexEntryName]（[IncrementalIndex]）。
///
/// 写入顺序是包 → 快照 → 索引：索引是“这份备份已完整”的提交标记，没有
/// 索引的快照与包都是垃圾，由清理按宽限期删除。快照、索引与包都用同一条
/// 链的密码加密（WinZip AES，与完整备份同一套）。
///
/// 快照里的载荷刻意不叫 `backup_data.json`：旧版应用与“数据管理 → 导入”
/// 以缺少该文件拒绝它，不会把没有媒体的快照当完整备份覆盖恢复（与日记包
/// 改名同一理由）。

const String incrementalSnapshotEntryName = 'snapshot_data.json.gz';
const String incrementalIndexEntryName = 'snapshot_index.json';
const int incrementalIndexVersion = 1;

const String _snapshotPrefix = 'jotsy_inc_';
const String _packPrefix = 'jotsy_pack_';
const String snapshotExtension = '.snap';
const String indexExtension = '.idx';
const String packExtension = '.pack';

enum IncrementalFileKind { snapshot, indexFile, pack }

/// 解析出的增量备份文件名。
@immutable
class IncrementalFileName {
  const IncrementalFileName._(this.kind, this.chain, this.time, this.stem);

  final IncrementalFileKind kind;
  final String chain;

  /// 文件名里的本地时间（精确到秒）。
  final DateTime time;

  /// 快照与索引共用的主干（`jotsy_inc_<时间>_<链>`）；包为去掉扩展名的
  /// 文件名。同一份备份的 `.snap` 与 `.idx` 主干相同。
  final String stem;

  static final RegExp _snapshotPattern = RegExp(
    r'^(jotsy_inc_(\d{8})_(\d{6})_([0-9a-f]{8}))\.(snap|idx)$',
  );
  static final RegExp _packPattern = RegExp(
    r'^(jotsy_pack_([0-9a-f]{8})_(\d{8})(\d{6})_[0-9a-f]{8})\.pack$',
  );

  /// 不是增量备份文件（含被网盘自动改名的副本）时为 null。
  static IncrementalFileName? parse(String fileName) {
    final snapshot = _snapshotPattern.firstMatch(fileName);
    if (snapshot != null) {
      final time = _parseTime(snapshot.group(2)!, snapshot.group(3)!);
      if (time == null) return null;
      return IncrementalFileName._(
        snapshot.group(5) == 'snap'
            ? IncrementalFileKind.snapshot
            : IncrementalFileKind.indexFile,
        snapshot.group(4)!,
        time,
        snapshot.group(1)!,
      );
    }
    final pack = _packPattern.firstMatch(fileName);
    if (pack != null) {
      final time = _parseTime(pack.group(3)!, pack.group(4)!);
      if (time == null) return null;
      return IncrementalFileName._(
        IncrementalFileKind.pack,
        pack.group(2)!,
        time,
        pack.group(1)!,
      );
    }
    return null;
  }

  static DateTime? _parseTime(String date, String time) {
    final parsed = DateTime.tryParse(
      '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}T'
      '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}',
    );
    return parsed;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _date(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}${_two(local.month)}'
    '${_two(local.day)}';

String _clock(DateTime local) =>
    '${_two(local.hour)}${_two(local.minute)}${_two(local.second)}';

/// 一份增量备份的主干名：`.snap` 与 `.idx` 各自加上扩展名。
String incrementalSnapshotStem(DateTime now, String chain) {
  final local = now.toLocal();
  return '$_snapshotPrefix${_date(local)}_${_clock(local)}_$chain';
}

/// 媒体包文件名；[random] 为 8 位小写十六进制。上传重试时换一个随机后缀，
/// 上一次可能已经落到网盘上的半成品留给清理删除，不与新文件同名。
String incrementalPackName(DateTime now, String chain, String random) {
  final local = now.toLocal();
  return '$_packPrefix${chain}_${_date(local)}${_clock(local)}_'
      '$random$packExtension';
}

/// 一个媒体文件在快照里的记录。
@immutable
class IncrementalMediaRef {
  const IncrementalMediaRef(this.sha256, this.size);

  final String sha256;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is IncrementalMediaRef &&
      other.sha256 == sha256 &&
      other.size == size;

  @override
  int get hashCode => Object.hash(sha256, size);
}

/// 一份增量备份的索引：载荷的指纹、全部媒体（键 → 内容哈希）与每个哈希
/// 所在的媒体包。恢复与去重只读它，不必下载载荷。
@immutable
class IncrementalIndex {
  const IncrementalIndex({
    required this.chain,
    required this.createdAt,
    required this.encrypted,
    required this.payloadSha256,
    required this.snapshotSize,
    required this.media,
    required this.packs,
  });

  final String chain;
  final DateTime createdAt;
  final bool encrypted;

  /// 载荷去掉 `generatedAt` 后的 sha256（[incrementalPayloadSha256]）。
  final String payloadSha256;

  /// `.snap` 文件的大小（字节），列表据此显示“这份备份本身多大”。
  final int snapshotSize;

  /// 媒体键（`diary_images/…`、`app_backgrounds/…`）→ 内容。
  final Map<String, IncrementalMediaRef> media;

  /// 内容 sha256 → 所在媒体包的文件名；覆盖 [media] 里的每个哈希。
  final Map<String, String> packs;

  Set<String> get packNames => packs.values.toSet();

  /// 与本机扫描结果比较用的整体指纹（[incrementalFingerprint]）。
  String get fingerprint => incrementalFingerprint(payloadSha256, media);

  /// 去重后的媒体总大小（同一内容只算一次）。
  int get mediaBytes {
    final sizes = <String, int>{
      for (final ref in media.values) ref.sha256: ref.size,
    };
    return sizes.values.fold(0, (sum, size) => sum + size);
  }

  String encode() => jsonEncode(<String, Object?>{
    'v': incrementalIndexVersion,
    'chain': chain,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'encrypted': encrypted,
    'payloadSha256': payloadSha256,
    'snapshotSize': snapshotSize,
    'media': <String, Object?>{
      for (final entry in media.entries)
        entry.key: <Object?>[entry.value.sha256, entry.value.size],
    },
    'packs': packs,
  });

  /// 解析索引；版本不对、缺字段或任一媒体条目不完整都抛 [FormatException]：
  /// 索引是恢复的依据，残缺的索引宁可整份不用，也不能恢复出缺了媒体的数据。
  static IncrementalIndex decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map || json['v'] != incrementalIndexVersion) {
      throw const FormatException('不支持的增量备份索引');
    }
    final chain = json['chain'];
    final createdAt = json['createdAt'];
    final payloadSha = json['payloadSha256'];
    final snapshotSize = json['snapshotSize'];
    final mediaJson = json['media'];
    final packsJson = json['packs'];
    if (chain is! String ||
        !isValidCloudChainId(chain) ||
        createdAt is! String ||
        payloadSha is! String ||
        snapshotSize is! int ||
        mediaJson is! Map ||
        packsJson is! Map) {
      throw const FormatException('增量备份索引缺少字段');
    }
    final media = <String, IncrementalMediaRef>{};
    for (final entry in mediaJson.entries) {
      final value = entry.value;
      if (entry.key is! String ||
          value is! List ||
          value.length != 2 ||
          value[0] is! String ||
          !isSha256Hex(value[0] as String) ||
          value[1] is! int) {
        throw const FormatException('增量备份索引的媒体条目损坏');
      }
      media[entry.key as String] = IncrementalMediaRef(
        value[0] as String,
        value[1] as int,
      );
    }
    final packs = <String, String>{};
    for (final entry in packsJson.entries) {
      final key = entry.key;
      final value = entry.value;
      // 哈希会用作解包时的文件名、包名会用作下载地址的一部分：都按格式
      // 严格校验，挡住被篡改的索引。
      if (key is! String ||
          !isSha256Hex(key) ||
          value is! String ||
          IncrementalFileName.parse(value)?.kind != IncrementalFileKind.pack) {
        throw const FormatException('增量备份索引的媒体包条目损坏');
      }
      packs[entry.key as String] = entry.value as String;
    }
    for (final ref in media.values) {
      if (!packs.containsKey(ref.sha256)) {
        throw const FormatException('增量备份索引缺少媒体包');
      }
    }
    return IncrementalIndex(
      chain: chain,
      createdAt: DateTime.tryParse(createdAt)?.toLocal() ?? DateTime(1970),
      encrypted: json['encrypted'] == true,
      payloadSha256: payloadSha,
      snapshotSize: snapshotSize,
      media: media,
      packs: packs,
    );
  }
}

/// 小写十六进制的 sha256。
bool isSha256Hex(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

/// 载荷的 sha256：去掉每次都会变的 `generatedAt` 后按紧凑 JSON 计算，数据
/// 没变时两次备份得到同一个值。
String incrementalPayloadSha256(Map<String, Object?> payload) {
  final stable = <String, Object?>{...payload}..remove('generatedAt');
  return sha256.convert(utf8.encode(jsonEncode(stable))).toString();
}

/// 载荷与媒体的整体指纹：数据没有任何变化时两次相同，用来跳过上传。
String incrementalFingerprint(
  String payloadSha256,
  Map<String, IncrementalMediaRef> media,
) {
  final buffer = StringBuffer(payloadSha256)..write('\n');
  final keys = media.keys.toList()..sort();
  for (final key in keys) {
    final ref = media[key]!;
    buffer
      ..write(key)
      ..write('\t')
      ..write(ref.sha256)
      ..write('\t')
      ..write(ref.size)
      ..write('\n');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}
