import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_presets.dart';
import 'package:node_diary/core/services/cloud_backup_service.dart';
import 'package:node_diary/core/services/cloud_backup_settings_service.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/cloud_backup_page.dart';
import 'package:node_diary/ui/settings/pages/cloud_backup_target_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 网盘备份页面的交互回归：表单对齐、草稿在保存前不落盘、寻址锁定、
/// 位置列表与添加面板。
void main() {
  late CloudBackupSettingsService targets;
  late AppDatabase database;
  late CloudBackupService service;

  // 服务必须在测试体（FakeAsync 区域）内创建：串行写入链上的 Future 若诞生
  // 在 setUp 的真实区域，其微任务不会随 tester.pump 推进，保存会一直挂起。
  Future<void> createServices() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    targets = await CloudBackupSettingsService.create();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = CloudBackupService(
      database: database,
      settingsService: await SettingsService.create(),
      targets: targets,
      // 测试包没有配置任何网盘的应用密钥。
      drives: const <CloudBackupKind, CloudDriveProvider>{},
    );
    addTearDown(() async {
      targets.dispose();
      await database.close();
    });
  }

  Future<void> pumpPage(WidgetTester tester, Widget home) async {
    await createServices();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudBackupSettingsServiceProvider.overrideWith(
            (ref) async => targets,
          ),
          cloudBackupServiceProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CloudBackupTarget draft(CloudBackupPreset preset) => CloudBackupTarget.create(
    kind: preset.kind,
    config: preset.initialConfig(),
    presetId: preset.id,
  );

  Finder fieldWithLabel(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  testWidgets('WebDAV form prefix icons share one horizontal center', (
    tester,
  ) async {
    await pumpPage(
      tester,
      CloudBackupTargetPage(target: draft(customWebDavPreset), isNew: true),
    );

    final centers = <double>[
      for (final icon in const <FaIconData>[
        FontAwesomeIcons.link,
        FontAwesomeIcons.user,
        FontAwesomeIcons.lock,
        FontAwesomeIcons.folder,
      ])
        tester.getCenter(find.byIcon(icon.data)).dx,
    ];
    for (final dx in centers.skip(1)) {
      expect((dx - centers.first).abs(), lessThan(0.5), reason: '$centers');
    }
  });

  testWidgets('preset draft is only persisted after a valid save', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final jianguoyun = webDavPresets.firstWhere((p) => p.id == 'jianguoyun');
    await pumpPage(
      tester,
      CloudBackupTargetPage(target: draft(jianguoyun), isNew: true),
    );

    // 预设预填了坚果云的固定地址，但草稿还没有写入。
    expect(find.text('https://dav.jianguoyun.com/dav/'), findsOneWidget);
    expect(targets.targets, isEmpty);
    // 新草稿没有“移除此备份位置”入口。
    expect(find.byTooltip(l10n.cloudBackupRemoveTarget), findsNothing);

    // 缺少用户名时保存失败，提示配置问题且不落盘。
    await tester.tap(find.text(l10n.cloudBackupSaveConfig));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.cloudBackupOperationFailed(l10n.cloudBackupErrorConfig)),
      findsOneWidget,
    );
    expect(targets.targets, isEmpty);

    await tester.enterText(
      fieldWithLabel(l10n.webDavUsername),
      'me@example.com',
    );
    await tester.enterText(fieldWithLabel(l10n.webDavPassword), 'app-password');
    await tester.tap(find.text(l10n.cloudBackupSaveConfig));
    await tester.pumpAndSettle();

    expect(find.text(l10n.cloudBackupConfigSaved), findsOneWidget);
    final saved = targets.targets.single;
    expect(saved.kind, CloudBackupKind.webDav);
    expect(saved.presetId, 'jianguoyun');
    expect(saved.config['username'], 'me@example.com');
    expect(saved.config['serverUrl'], 'https://dav.jianguoyun.com/dav/');
    expect(find.byTooltip(l10n.cloudBackupRemoveTarget), findsOneWidget);
  });

  testWidgets('virtual-host-only S3 presets lock path-style access off', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final oss = s3Presets.firstWhere((p) => p.id == 'aliyunOss');
    await pumpPage(
      tester,
      CloudBackupTargetPage(target: draft(oss), isNew: true),
    );

    final locked = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(locked.value, isFalse);
    expect(locked.onChanged, isNull);
    expect(find.text(l10n.s3PathStyleLocked), findsOneWidget);
    expect(find.text(l10n.cloudBackupHintAliyunOss), findsOneWidget);
  });

  testWidgets('custom S3 lets the user enable path-style access', (
    tester,
  ) async {
    await pumpPage(
      tester,
      CloudBackupTargetPage(target: draft(customS3Preset), isNew: true),
    );

    final toggle = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });

  testWidgets('location list shows saved targets and hides unkeyed drives', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await pumpPage(tester, const CloudBackupPage());
    expect(find.text(l10n.cloudBackupEmpty), findsOneWidget);

    await targets.saveTarget(
      CloudBackupTarget.create(
        kind: CloudBackupKind.s3,
        presetId: 'cloudflareR2',
        config: const {'bucket': 'diary', 'region': 'auto'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.cloudBackupEmpty), findsNothing);
    expect(find.text('Cloudflare R2'), findsOneWidget);
    expect(find.text('diary · auto'), findsOneWidget);

    await tester.tap(find.text(l10n.cloudBackupAdd));
    await tester.pumpAndSettle();
    expect(find.text(l10n.cloudBackupSheetTitle), findsOneWidget);
    // 没有配置应用密钥时，授权类网盘整组不出现。
    expect(find.text(l10n.cloudBackupGroupDrives), findsNothing);
    expect(find.text('Google Drive'), findsNothing);
    expect(find.text(l10n.cloudBackupJianguoyun), findsOneWidget);
  });
}
