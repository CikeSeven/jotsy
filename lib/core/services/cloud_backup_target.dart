import 'dart:convert';
import 'dart:math';

import 'cloud_backup_models.dart';

/// 一个已配置的备份位置（某个网盘账号或某个 WebDAV / S3 连接）。
///
/// [config] 是该类型客户端自己解析的配置：WebDAV 为 `WebDavConfig`、S3 为
/// `S3BackupConfig`、授权类网盘为 `CloudDriveCredentials` 的 JSON。凭据与
/// 配置同存，只保存在本机偏好里，不进入备份 ZIP。
class CloudBackupTarget {
  const CloudBackupTarget({
    required this.id,
    required this.kind,
    required this.config,
    this.presetId,
    this.createdAt,
  });

  /// 新建一个备份位置，id 随机生成，避免删除后重建复用旧 id。
  factory CloudBackupTarget.create({
    required CloudBackupKind kind,
    required Map<String, Object?> config,
    String? presetId,
    DateTime? now,
  }) {
    final random = Random.secure();
    final suffix = List<String>.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return CloudBackupTarget(
      id: '${kind.id}_$suffix',
      kind: kind,
      config: config,
      presetId: presetId,
      createdAt: now ?? DateTime.now(),
    );
  }

  /// 坏条目（未知类型、缺 id）返回 null，由调用方跳过，不影响其他位置。
  static CloudBackupTarget? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final kind = CloudBackupKind.fromId(raw['kind']);
    final config = raw['config'];
    if (id is! String || id.isEmpty || kind == null) return null;
    return CloudBackupTarget(
      id: id,
      kind: kind,
      config: config is Map
          ? config.cast<String, Object?>()
          : const <String, Object?>{},
      presetId: raw['preset'] is String ? raw['preset'] as String : null,
      createdAt: raw['createdAt'] is String
          ? DateTime.tryParse(raw['createdAt'] as String)
          : null,
    );
  }

  final String id;
  final CloudBackupKind kind;
  final Map<String, Object?> config;

  /// WebDAV / S3 预设（坚果云、Cloudflare R2 等）的 id，只用于展示名称与
  /// 图标；连接参数以 [config] 为准。
  final String? presetId;
  final DateTime? createdAt;

  CloudBackupTarget copyWith({Map<String, Object?>? config}) {
    return CloudBackupTarget(
      id: id,
      kind: kind,
      config: config ?? this.config,
      presetId: presetId,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.id,
    if (presetId != null) 'preset': presetId,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    'config': config,
  };

  static String encodeList(List<CloudBackupTarget> targets) =>
      jsonEncode(targets.map((target) => target.toJson()).toList());

  /// 整体解析失败（被改坏）时返回空列表；单个坏条目只跳过它自己。
  static List<CloudBackupTarget> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <CloudBackupTarget>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <CloudBackupTarget>[];
      return decoded
          .map(tryParse)
          .whereType<CloudBackupTarget>()
          .toList(growable: false);
    } on FormatException {
      return const <CloudBackupTarget>[];
    }
  }
}
