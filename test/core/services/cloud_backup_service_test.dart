import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';
import 'package:node_diary/core/services/cloud_backup_service.dart';
import 'package:node_diary/core/services/cloud_backup_settings_service.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// 编排层：授权后保存位置、令牌刷新落盘、临时文件清理、未配置密钥的网盘。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late CloudBackupSettingsService targets;
  late _FakeDrive drive;
  late CloudBackupService service;

  setUp(() async {
    fixture = await BackupTestFixture.create();
    targets = await CloudBackupSettingsService.create();
    drive = _FakeDrive();
    service = CloudBackupService(
      database: fixture.database,
      settingsService: fixture.settings,
      targets: targets,
      drives: {CloudBackupKind.googleDrive: drive},
      temporaryDirectory: () async => fixture.temporary,
    );
  });

  tearDown(() async {
    targets.dispose();
    await fixture.dispose();
  });

  test('authorization saves a verified target with the account name', () async {
    final session = service.beginAuthorization(CloudBackupKind.googleDrive);
    session.close();
    expect(session.method, isA<CloudCodePasteAuthorization>());

    final target = await service.completeAuthorization(
      kind: CloudBackupKind.googleDrive,
      token: const CloudOAuthToken(accessToken: 'a1', refreshToken: 'r1'),
    );

    expect(drive.remote.prepared, isTrue);
    expect(targets.targets.single.id, target.id);
    final credentials = CloudDriveCredentials.fromConfig(target.config);
    expect(credentials.account, 'me@example.com');
    expect(credentials.token.refreshToken, 'r1');
  });

  test(
    'authorization saves nothing when the backup folder is unusable',
    () async {
      drive.remote.prepareError = const CloudBackupException(
        CloudBackupFailure.unauthorized,
      );
      await expectLater(
        service.completeAuthorization(
          kind: CloudBackupKind.googleDrive,
          token: const CloudOAuthToken(accessToken: 'a1'),
        ),
        throwsA(isA<CloudBackupException>()),
      );
      expect(targets.targets, isEmpty);
    },
  );

  test('re-authorization keeps the id and the known account', () async {
    final existing = CloudBackupTarget.create(
      kind: CloudBackupKind.googleDrive,
      config: const CloudDriveCredentials(
        token: CloudOAuthToken(accessToken: 'old'),
        account: 'kept@example.com',
      ).toConfig(),
    );
    await targets.saveTarget(existing);
    drive.account = null;

    final target = await service.completeAuthorization(
      kind: CloudBackupKind.googleDrive,
      token: const CloudOAuthToken(accessToken: 'fresh'),
      existing: existing,
    );

    expect(target.id, existing.id);
    final credentials = CloudDriveCredentials.fromConfig(
      targets.targetById(existing.id)!.config,
    );
    expect(credentials.token.accessToken, 'fresh');
    expect(credentials.account, 'kept@example.com');
  });

  test('a refreshed token is persisted to the target', () async {
    final target = CloudBackupTarget.create(
      kind: CloudBackupKind.googleDrive,
      config: CloudDriveCredentials(
        token: CloudOAuthToken(
          accessToken: 'expiring',
          refreshToken: 'r1',
          expiresAt: DateTime.now().add(const Duration(seconds: 10)),
        ),
        account: 'me@example.com',
      ).toConfig(),
    );
    await targets.saveTarget(target);

    await service.listBackups(target);

    expect(drive.refreshes, 1);
    final saved = CloudDriveCredentials.fromConfig(
      targets.targetById(target.id)!.config,
    );
    expect(saved.token.accessToken, 'a2');
    expect(saved.token.refreshToken, 'r2');
    expect(saved.account, 'me@example.com');
    expect(drive.remote.closed, isTrue);
  });

  test(
    'upload sends a timestamped full backup and deletes the temp ZIP',
    () async {
      final target = CloudBackupTarget.create(
        kind: CloudBackupKind.googleDrive,
        config: const CloudDriveCredentials(
          token: CloudOAuthToken(accessToken: 'a1'),
        ).toConfig(),
      );

      final entry = await service.uploadCurrentBackup(
        target,
        now: DateTime(2026, 10, 16, 9, 5, 7),
      );

      expect(entry.fileName, 'jotsy_backup_20261016_090507.zip');
      expect(drive.remote.uploadedBytes, isNotEmpty);
      expect(await File(drive.remote.uploadedPath!).exists(), isFalse);

      // 上传失败同样清理临时 ZIP。
      drive.remote.uploadError = const CloudBackupException(
        CloudBackupFailure.storageFull,
      );
      await expectLater(
        service.uploadCurrentBackup(target),
        throwsA(isA<CloudBackupException>()),
      );
      expect(await File(drive.remote.uploadedPath!).exists(), isFalse);
    },
  );

  test('download lands in the temporary directory', () async {
    final target = CloudBackupTarget.create(
      kind: CloudBackupKind.googleDrive,
      config: const CloudDriveCredentials(
        token: CloudOAuthToken(accessToken: 'a1'),
      ).toConfig(),
    );
    final file = await service.downloadBackup(
      target,
      const CloudBackupEntry(fileName: '../evil.zip', remoteId: 'id'),
    );
    expect(p.dirname(file.path), fixture.temporary.path);
    expect(p.basename(file.path), endsWith('_evil.zip'));
    expect(await file.readAsBytes(), [1, 2, 3]);
  });

  test('drives without app keys are refused with appKeyMissing', () async {
    drive.available = false;
    expect(service.isDriveAvailable(CloudBackupKind.googleDrive), isFalse);
    expect(service.isDriveAvailable(CloudBackupKind.dropbox), isFalse);
    final target = CloudBackupTarget.create(
      kind: CloudBackupKind.googleDrive,
      config: const CloudDriveCredentials(
        token: CloudOAuthToken(accessToken: 'a1'),
      ).toConfig(),
    );
    for (final action in <Future<Object?> Function()>[
      () async => service.beginAuthorization(CloudBackupKind.googleDrive),
      () => service.listBackups(target),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<CloudBackupException>().having(
            (e) => e.failure,
            'failure',
            CloudBackupFailure.appKeyMissing,
          ),
        ),
      );
    }
  });
}

class _FakeDrive extends CloudDriveProvider {
  bool available = true;
  String? account = 'me@example.com';
  int refreshes = 0;
  final _FakeRemote remote = _FakeRemote();

  @override
  CloudBackupKind get kind => CloudBackupKind.googleDrive;

  @override
  bool get isAvailable => available;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) =>
      CloudCodePasteAuthorization(
        authorizeUri: Uri.parse('https://example.com/authorize'),
        exchange: (code) async => CloudOAuthToken(accessToken: code),
      );

  @override
  Future<CloudOAuthToken> refresh(
    CloudBackupHttp http,
    CloudOAuthToken token,
  ) async {
    refreshes++;
    return CloudOAuthToken(
      accessToken: 'a2',
      refreshToken: 'r2',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<String?> fetchAccount(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) async {
    final name = account;
    if (name == null) {
      throw const CloudBackupException(CloudBackupFailure.network);
    }
    return name;
  }

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) => remote..session = session;
}

class _FakeRemote implements CloudBackupRemote {
  late CloudOAuthSession session;
  bool prepared = false;
  bool closed = false;
  CloudBackupException? prepareError;
  CloudBackupException? uploadError;
  List<int> uploadedBytes = const [];
  String? uploadedPath;

  @override
  Future<void> prepare() async {
    await session.accessToken();
    if (prepareError != null) throw prepareError!;
    prepared = true;
  }

  @override
  Future<List<CloudBackupEntry>> list() async {
    await session.accessToken();
    return const [];
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    uploadedPath = file.path;
    if (uploadError != null) throw uploadError!;
    uploadedBytes = await file.readAsBytes();
    return CloudBackupEntry(
      fileName: fileName,
      remoteId: fileName,
      createdAt: cloudBackupCreatedAtFromFileName(fileName),
    );
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) => target.writeAsBytes(const [1, 2, 3]);

  @override
  Future<void> delete(CloudBackupEntry entry) async {}

  @override
  void close() => closed = true;
}
