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

  testWidgets('shows the total, the breakdown and what can be freed', (
    tester,
  ) async {
    final report = sampleStorageReport(
      deviceSpace: const StorageDeviceSpace(
        totalBytes: 64 * 1024 * mb,
        freeBytes: 20 * 1024 * mb,
      ),
    );
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: FakeStorageMediaService(report),
    );

    expect(find.text(l10n.formatByteSize(report.totalBytes)), findsOneWidget);
    expect(
      find.text(l10n.storageMgmtDeviceSpace('20 GB', '64 GB')),
      findsOneWidget,
    );
    for (final label in [
      l10n.storageMgmtCategoryImages,
      l10n.storageMgmtCategoryVideos,
      l10n.storageMgmtCategoryUnused,
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
