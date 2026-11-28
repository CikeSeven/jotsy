import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'backup_constants.dart';
import 'diary_font_storage_service.dart';
import 'lan_sync/lan_sync_state_directory.dart';

/// 桌面端托管数据位置配置文件（位于系统默认应用支持目录下）。
const String dataLocationConfigFileName = 'data_location.json';

/// 桌面端窗口大小与位置记忆文件（位于系统默认应用支持目录下，纯本机状态、
/// 不随自定义数据目录迁移、不随备份导出、不参与同步）。
const String windowStateFileName = 'window_state.json';

/// 可执行文件同级目录下的可选数据位置配置：
/// - 安装程序（`jotsy.iss`）在用户自定义路径时写入 `defaultPath`，供当前系统下
///   首次启动的用户账号继承；
/// - 便携版可在同级目录放置带 `path` / `portable: true` 的配置以实现相对路径
///   携带。
const String executableDataLocationConfigFileName = 'jotsy_data_location.json';

/// 存放在数据根目录内的已绑定路径标记：当根目录路径发生外部变化（例如便携盘
/// 盘符变化或重装后指向原数据目录）时，启动引导据此自动重绑库内媒体绝对路径。
const String boundRootMarkerFileName = '.jotsy_data_root.json';

/// 桌面端随数据根目录一起迁移的托管子目录清单。
const List<String> managedDataDirectoryNames = <String>[
  ...backupMediaDirectories,
  ...backupSettingsMediaDirectories,
  DiaryFontStorageService.directoryName,
  lanSyncStateDirectoryName,
  'cloud_backup_state',
  'media_dedup_state',
];

/// 桌面端随数据根目录一起迁移的数据库文件清单。
const List<String> managedDatabaseFileNames = <String>[
  appDatabaseFileName,
  '$appDatabaseFileName-wal',
  '$appDatabaseFileName-shm',
  '$appDatabaseFileName-journal',
];

/// 把对象编码为带 UTF-8 BOM 的 JSON：Windows 安装程序（Inno Setup）的
/// `LoadStringsFromFile` 依赖 BOM 将非 ASCII 路径（如中文文件夹）按 UTF-8
/// 正确解码，不随系统 ANSI 代码页乱码。
String encodeDataLocationJson(Object? value) => '\uFEFF${jsonEncode(value)}';

/// 解析可能带 UTF-8 BOM 的 JSON 对象；损坏或非 Map 时返回 null。
Map<String, Object?>? decodeJsonObjectWithOptionalBom(String raw) {
  final cleaned = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  final trimmed = cleaned.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// `data_location.json` 的配置快照。
@immutable
class AppDataLocationConfig {
  const AppDataLocationConfig({
    this.version = 1,
    this.path,
    this.pendingTargetPath,
    this.useDefault = false,
  });

  final int version;
  final String? path;
  final String? pendingTargetPath;
  final bool useDefault;

  static AppDataLocationConfig? tryParse(String raw) {
    final json = decodeJsonObjectWithOptionalBom(raw);
    if (json == null) return null;
    final pathRaw = json['path'];
    final pendingRaw = json['pendingTargetPath'];
    final path = pathRaw is String && pathRaw.trim().isNotEmpty
        ? pathRaw.trim()
        : null;
    final pending = pendingRaw is String && pendingRaw.trim().isNotEmpty
        ? pendingRaw.trim()
        : null;
    final useDefault = json['useDefault'] == true || path == null;
    return AppDataLocationConfig(
      version: json['version'] is int ? json['version'] as int : 1,
      path: path,
      pendingTargetPath: pending,
      useDefault: useDefault,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'path': path,
    if (useDefault && path == null) 'useDefault': true,
    if (pendingTargetPath != null) 'pendingTargetPath': pendingTargetPath,
  };
}

/// 可执行文件旁 `jotsy_data_location.json` 的配置快照。
@immutable
class ExecutableDataLocationConfig {
  const ExecutableDataLocationConfig({
    this.path,
    this.defaultPath,
    this.portable = false,
  });

  final String? path;
  final String? defaultPath;
  final bool portable;

  static ExecutableDataLocationConfig? tryParse(String raw) {
    final json = decodeJsonObjectWithOptionalBom(raw);
    if (json == null) return null;
    final pathRaw = json['path'];
    final defaultRaw = json['defaultPath'];
    return ExecutableDataLocationConfig(
      path: pathRaw is String && pathRaw.trim().isNotEmpty
          ? pathRaw.trim()
          : null,
      defaultPath: defaultRaw is String && defaultRaw.trim().isNotEmpty
          ? defaultRaw.trim()
          : null,
      portable: json['portable'] == true,
    );
  }
}

/// 当前解析出的桌面数据位置详情。
@immutable
class AppDataLocationResolution {
  const AppDataLocationResolution({
    required this.defaultRoot,
    required this.activeRoot,
    required this.isCustomLocation,
    required this.isPortableConfig,
    this.pendingTargetPath,
  });

  final Directory defaultRoot;
  final Directory activeRoot;
  final bool isCustomLocation;
  final bool isPortableConfig;
  final String? pendingTargetPath;
}

/// 选择目标文件夹的校验结论。
enum AppDataLocationTargetStatus {
  validEmpty,
  validExistingJotsyData,
  invalidEmpty,
  invalidRelative,
  invalidDriveRoot,
  invalidSameAsCurrent,
  invalidNestedWithCurrent,
  invalidInsideAppBundle,
  invalidNotWritable,
  invalidNonEmptyOther,
}

@immutable
class AppDataLocationTargetCheck {
  const AppDataLocationTargetCheck({required this.status, this.normalizedPath});

  final AppDataLocationTargetStatus status;
  final String? normalizedPath;

  bool get isValid =>
      status == AppDataLocationTargetStatus.validEmpty ||
      status == AppDataLocationTargetStatus.validExistingJotsyData;
}

/// 桌面数据存储位置解析、校验与引导配置持久化。
class AppDataLocationStore {
  AppDataLocationStore({
    Future<Directory> Function()? supportDirectoryProvider,
    Directory? Function()? executableDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _executableDirectoryProvider =
           executableDirectoryProvider ?? defaultExecutableDirectory;

  static final AppDataLocationStore instance = AppDataLocationStore();

  final Future<Directory> Function() _supportDirectoryProvider;
  final Directory? Function() _executableDirectoryProvider;

  /// 按 `supportDir.path` 缓存解析结果：测试切换 `path_provider` 沙盒路径时天然
  /// 不命中旧缓存，修改配置后经 [invalidateCache] 失效。
  final Map<String, AppDataLocationResolution> _cache =
      <String, AppDataLocationResolution>{};

  static Directory? defaultExecutableDirectory() {
    try {
      final exe = Platform.resolvedExecutable;
      if (exe.trim().isEmpty) return null;
      return File(exe).parent;
    } catch (_) {
      return null;
    }
  }

  void invalidateCache() => _cache.clear();

  /// 解析当前桌面数据根目录详情。
  Future<AppDataLocationResolution> resolve() async {
    final supportDir = Directory(
      p.normalize((await _supportDirectoryProvider()).path),
    );
    final cached = _cache[supportDir.path];
    if (cached != null) return cached;

    final userConfigFile = File(
      p.join(supportDir.path, dataLocationConfigFileName),
    );
    final userConfig = await _readUserConfig(userConfigFile);
    final exeDir = _executableDirectoryProvider();

    Directory active = supportDir;
    var isPortable = false;
    String? pendingTarget = userConfig?.pendingTargetPath;
    if (pendingTarget != null) {
      pendingTarget = _resolveOptionalAbsolutePath(pendingTarget, exeDir);
    }

    if (userConfig != null) {
      if (userConfig.path != null) {
        final candidate = p.normalize(userConfig.path!);
        if (p.isAbsolute(candidate) &&
            !_conflictsWithAppBundle(candidate, exeDir)) {
          active = Directory(candidate);
        }
      }
    } else if (!await File(
      p.join(supportDir.path, appDatabaseFileName),
    ).exists()) {
      final exeConfig = await _readExecutableConfig(exeDir);
      final rawSeed = exeConfig?.path ?? exeConfig?.defaultPath;
      if (rawSeed != null && exeDir != null) {
        final candidate = _resolveConfigPath(rawSeed, exeDir);
        if (candidate != null && !_conflictsWithAppBundle(candidate, exeDir)) {
          active = Directory(candidate);
          isPortable = exeConfig!.portable || exeConfig.path != null;
        }
      }
    }

    final activeNorm = p.normalize(active.path);
    final defaultNorm = p.normalize(supportDir.path);
    final resolution = AppDataLocationResolution(
      defaultRoot: supportDir,
      activeRoot: active,
      isCustomLocation: !p.equals(activeNorm, defaultNorm),
      isPortableConfig: isPortable,
      pendingTargetPath: pendingTarget,
    );
    _cache[supportDir.path] = resolution;
    return resolution;
  }

  /// 返回（并按需创建）当前应使用的数据根目录。
  Future<Directory> resolveDirectory({bool ensureExists = true}) async {
    final resolution = await resolve();
    if (ensureExists) {
      await resolution.activeRoot.create(recursive: true);
    }
    return resolution.activeRoot;
  }

  /// 读取 `<root>/.jotsy_data_root.json` 中记录的上次绑定路径；不存在或损坏为 null。
  Future<String?> readBoundRootMarker(Directory root) async {
    final file = File(p.join(root.path, boundRootMarkerFileName));
    if (!await file.exists()) return null;
    try {
      final json = decodeJsonObjectWithOptionalBom(await file.readAsString());
      final bound = json?['boundRoot'];
      return bound is String && bound.trim().isNotEmpty
          ? p.normalize(bound.trim())
          : null;
    } on Object {
      return null;
    }
  }

  /// 写入 `<root>/.jotsy_data_root.json`，用于识别便携盘盘符变更或外部迁移。
  Future<void> writeBoundRootMarker(Directory root) async {
    await root.create(recursive: true);
    final file = File(p.join(root.path, boundRootMarkerFileName));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      encodeDataLocationJson(<String, Object?>{
        'version': 1,
        'boundRoot': p.normalize(root.path),
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  /// 保存用户级路径配置（传入 null 表示回到系统默认应用支持目录）。
  Future<void> saveUserConfig({
    required Directory supportDir,
    required String? targetPath,
    String? pendingTargetPath,
  }) async {
    await supportDir.create(recursive: true);
    final normalizedTarget = targetPath == null || targetPath.trim().isEmpty
        ? null
        : p.normalize(targetPath.trim());
    final isDefault =
        normalizedTarget == null ||
        p.equals(normalizedTarget, p.normalize(supportDir.path));
    final config = AppDataLocationConfig(
      path: isDefault ? null : normalizedTarget,
      pendingTargetPath: pendingTargetPath == null
          ? null
          : p.normalize(pendingTargetPath),
      useDefault: isDefault,
    );
    final file = File(p.join(supportDir.path, dataLocationConfigFileName));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      encodeDataLocationJson(config.toJson()),
      flush: true,
    );
    await temp.rename(file.path);

    // 若之前使用便携模式配置文件，同步更新可执行文件同级配置以便移动便携包。
    final exeDir = _executableDirectoryProvider();
    if (exeDir != null && !isDefault) {
      await _tryUpdatePortableConfig(exeDir, normalizedTarget);
    }
    invalidateCache();
  }

  /// 校验目标路径是否可迁移 / 切换。
  Future<AppDataLocationTargetCheck> inspectTarget(
    String rawPath, {
    required String currentRoot,
    required String defaultRoot,
  }) async {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return const AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidEmpty,
      );
    }
    if (!p.isAbsolute(trimmed)) {
      return const AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidRelative,
      );
    }
    final normalized = p.normalize(trimmed);
    if (p.dirname(normalized) == normalized) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidDriveRoot,
        normalizedPath: normalized,
      );
    }
    final currentNorm = p.normalize(currentRoot);
    final defaultNorm = p.normalize(defaultRoot);
    if (p.equals(normalized, currentNorm)) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidSameAsCurrent,
        normalizedPath: normalized,
      );
    }
    if (p.isWithin(currentNorm, normalized) ||
        p.isWithin(normalized, currentNorm)) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidNestedWithCurrent,
        normalizedPath: normalized,
      );
    }
    final exeDir = _executableDirectoryProvider();
    if (_conflictsWithAppBundle(normalized, exeDir)) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidInsideAppBundle,
        normalizedPath: normalized,
      );
    }
    if (!await _probeWritable(normalized)) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidNotWritable,
        normalizedPath: normalized,
      );
    }

    final dir = Directory(normalized);
    if (!await dir.exists()) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.validEmpty,
        normalizedPath: normalized,
      );
    }
    if (await File(p.join(normalized, appDatabaseFileName)).exists()) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.validExistingJotsyData,
        normalizedPath: normalized,
      );
    }

    final isDefault = p.equals(normalized, defaultNorm);
    if (await _hasBlockingEntries(dir, isDefaultSupportDir: isDefault)) {
      return AppDataLocationTargetCheck(
        status: AppDataLocationTargetStatus.invalidNonEmptyOther,
        normalizedPath: normalized,
      );
    }
    return AppDataLocationTargetCheck(
      status: AppDataLocationTargetStatus.validEmpty,
      normalizedPath: normalized,
    );
  }

  Future<AppDataLocationConfig?> _readUserConfig(File file) async {
    if (!await file.exists()) return null;
    try {
      return AppDataLocationConfig.tryParse(await file.readAsString());
    } on Object catch (error) {
      debugPrint('Failed to read data_location.json: $error');
      return null;
    }
  }

  Future<ExecutableDataLocationConfig?> _readExecutableConfig(
    Directory? exeDir,
  ) async {
    if (exeDir == null) return null;
    final file = File(
      p.join(exeDir.path, executableDataLocationConfigFileName),
    );
    if (!await file.exists()) return null;
    try {
      return ExecutableDataLocationConfig.tryParse(await file.readAsString());
    } on Object catch (error) {
      debugPrint('Failed to read executable data config: $error');
      return null;
    }
  }

  Future<void> _tryUpdatePortableConfig(
    Directory exeDir,
    String targetPath,
  ) async {
    final file = File(
      p.join(exeDir.path, executableDataLocationConfigFileName),
    );
    if (!await file.exists()) return;
    try {
      final parsed = ExecutableDataLocationConfig.tryParse(
        await file.readAsString(),
      );
      if (parsed == null || (!parsed.portable && parsed.path == null)) {
        return;
      }
      final exeNorm = p.normalize(exeDir.path);
      final encodedPath = p.isWithin(exeNorm, targetPath)
          ? p.relative(targetPath, from: exeNorm)
          : targetPath;
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        encodeDataLocationJson(<String, Object?>{
          'version': 1,
          'portable': true,
          'path': encodedPath,
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } on Object {
      // 安装目录可能只读，用户级 data_location.json 已写入，此处静默跳过。
    }
  }

  static String? _resolveConfigPath(String raw, Directory exeDir) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return p.isAbsolute(trimmed)
        ? p.normalize(trimmed)
        : p.normalize(p.join(exeDir.path, trimmed));
  }

  static String? _resolveOptionalAbsolutePath(String raw, Directory? exeDir) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (p.isAbsolute(trimmed)) return p.normalize(trimmed);
    if (exeDir == null) return null;
    return p.normalize(p.join(exeDir.path, trimmed));
  }

  static bool _conflictsWithAppBundle(String candidate, Directory? exeDir) {
    if (exeDir == null) return false;
    final exeNorm = p.normalize(exeDir.path);
    final bundleData = p.normalize(p.join(exeNorm, 'data'));
    if (p.equals(candidate, exeNorm) ||
        p.equals(candidate, bundleData) ||
        p.isWithin(bundleData, candidate)) {
      return true;
    }
    // Inno Setup 安装版会在程序目录生成 unins*.exe 且升级会清理安装目录，禁止
    // 把数据放在安装目录下。便携版无卸载程序时允许在同级建独立子目录（非 data）。
    final hasInstallerUninstaller = File(
      p.join(exeNorm, 'unins000.exe'),
    ).existsSync();
    if (hasInstallerUninstaller && p.isWithin(exeNorm, candidate)) {
      return true;
    }
    return false;
  }

  static Future<bool> _probeWritable(String normalizedPath) async {
    var probeDir = Directory(normalizedPath);
    while (!await probeDir.exists()) {
      final parent = probeDir.parent;
      if (p.equals(p.normalize(parent.path), p.normalize(probeDir.path))) {
        return false;
      }
      probeDir = parent;
    }
    final probeFile = File(
      p.join(
        probeDir.path,
        '.jotsy_write_probe_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    try {
      await probeFile.writeAsString('ok', flush: true);
      await probeFile.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<bool> _hasBlockingEntries(
    Directory dir, {
    required bool isDefaultSupportDir,
  }) async {
    const osMeta = <String>{'desktop.ini', 'thumbs.db', '.ds_store'};
    const supportFiles = <String>{
      'shared_preferences.json',
      dataLocationConfigFileName,
      boundRootMarkerFileName,
      windowStateFileName,
      '$windowStateFileName.tmp',
    };
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final lower = name.toLowerCase();
      if (osMeta.contains(lower)) continue;
      if (lower.startsWith('.jotsy_write_probe_')) continue;
      if (isDefaultSupportDir && supportFiles.contains(name)) continue;
      return true;
    }
    return false;
  }
}
