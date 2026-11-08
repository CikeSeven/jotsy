import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/services/storage/storage_media_service.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/ui/storage/pages/storage_media_page.dart';
import 'package:node_diary/ui/storage/pages/storage_page.dart';

import '../../support/storage_test_fixtures.dart';
import 'storage_test_app.dart';

void main() {
  final l10n = storageL10n;

  testWidgets('shows the device, the app breakdown and what can be freed', (
    tester,
  ) async {
    final report = sampleStorageReport().withDeviceSpace(
      const StorageDeviceSpace(
        totalBytes: 64 * 1024 * mb,
        freeBytes: 20 * 1024 * mb,
        appCodeBytes: 100 * mb,
        appDataBytes: 400 * mb,
      ),
    );
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(report),
      size: const Size(400, 2400),
    );

    // 手机存储：总量、已用比例、本应用 / 其他 / 可用。
    expect(find.text(l10n.storageMgmtDeviceTitle), findsOneWidget);
    expect(find.text(l10n.storageMgmtDeviceTotal('64 GB')), findsOneWidget);
    expect(find.textContaining('69%'), findsOneWidget);
    expect(find.text(l10n.storageMgmtDeviceApp), findsOneWidget);
    expect(find.text(l10n.storageMgmtDeviceFree), findsOneWidget);
    expect(find.text('20 GB'), findsOneWidget);

    // 应用占用与系统统计一致：安装包 100 MB + 数据 400 MB。
    expect(report.totalBytes, 500 * mb);
    expect(find.text(l10n.formatByteSize(500 * mb)), findsWidgets);
    for (final label in [
      l10n.storageMgmtCategoryImages,
      l10n.storageMgmtCategoryVideos,
      l10n.storageMgmtCategoryUnused,
      l10n.storageMgmtCategoryApp,
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(
      find.text(l10n.storageMgmtCleanUpAll(l10n.formatByteSize(65 * mb))),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.storageMgmtSuggestCacheSubtitle(l10n.formatByteSize(40 * mb)),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.storageMgmtSuggestTrash), findsOneWidget);
    expect(find.text(l10n.storageMgmtSuggestCompress), findsOneWidget);
  });

  testWidgets('without device space there is no device card', (tester) async {
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(sampleStorageReport()),
    );

    expect(find.text(l10n.storageMgmtDeviceTitle), findsNothing);
    expect(find.text(l10n.storageMgmtAppTitle), findsOneWidget);
    expect(find.text(l10n.storageMgmtDeviceShareLabel), findsNothing);
  });

  testWidgets('largest files open their details; growth names the peak', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(sampleStorageReport()),
      size: const Size(400, 3200),
    );

    expect(find.text(l10n.storageMgmtTopTitle), findsOneWidget);
    expect(find.text(l10n.storageMgmtGrowthTitle), findsOneWidget);
    // 按月还是按年取决于今天（序列规则见 storage_growth_test），这里只看
    // 写出了新增最多的一段。
    expect(find.textContaining('新增最多'), findsOneWidget);

    await tester.tap(find.text('日落'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtUsedIn(1)), findsOneWidget);
    expect(find.text('sunset.jpg'), findsOneWidget);
  });

  testWidgets('clearing one suggestion only clears that kind', (tester) async {
    final service = FakeStorageMediaService(sampleStorageReport());
    await pumpStoragePage(tester, const StoragePage(), service: service);

    await tester.tap(
      find.widgetWithText(TextButton, l10n.storageMgmtClear).first,
    );
    await tester.pumpAndSettle();

    expect(service.cleanUps.single, (
      cache: true,
      orphans: false,
      database: false,
    ));
    expect(
      find.text(l10n.storageMgmtFreed(l10n.formatByteSize(40 * mb))),
      findsOneWidget,
    );
  });

  testWidgets('an open editor blocks cleaning with an explanation', (
    tester,
  ) async {
    final service = FakeStorageMediaService(sampleStorageReport())
      ..busy = StorageBusyReason.editing;
    await pumpStoragePage(tester, const StoragePage(), service: service);

    await tester.tap(
      find.text(l10n.storageMgmtCleanUpAll(l10n.formatByteSize(65 * mb))),
    );
    await tester.pumpAndSettle();

    expect(service.cleanUps, isEmpty);
    expect(find.text(l10n.storageMgmtBusyEditing), findsOneWidget);
  });

  testWidgets('no cleanup button or compress row when they would do nothing', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(
        sampleStorageReport(withReclaimable: false),
        supportsCompression: false,
      ),
    );

    expect(find.text(l10n.storageMgmtAllClean), findsNothing);
    expect(find.textContaining('一键清理'), findsNothing);
    // 平台不能压缩时没有压缩建议；回收站建议仍在，所以不是“已经很整洁”。
    expect(find.text(l10n.storageMgmtSuggestCompress), findsNothing);
    expect(find.text(l10n.storageMgmtSuggestTrash), findsOneWidget);
  });

  testWidgets('media rows open the media page with that category', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(sampleStorageReport()),
    );

    // 列表按需构建：先滚到“大文件”那块出现，再让它完整露出来。
    await tester.scrollUntilVisible(
      find.text(l10n.storageMgmtLargeFiles),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(l10n.storageMgmtLargeFiles));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.storageMgmtLargeFiles));
    await tester.pumpAndSettle();

    expect(find.byType(StorageMediaPage), findsOneWidget);
    expect(find.text('海边'), findsOneWidget);
    expect(find.text('日落'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp with large text in $brightness', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpStoragePage(
        tester,
        const StoragePage(),
        service: FakeStorageMediaService(sampleStorageReport()),
        brightness: brightness,
        size: const Size(320, 2400),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
