import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/storage_duplicates.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/storage/pages/storage_duplicates_page.dart';
import 'package:node_diary/ui/storage/pages/storage_page.dart';

import '../../support/storage_test_fixtures.dart';
import 'storage_test_app.dart';

/// 两组重复：一组公开（早餐 / 午餐，各 2 MB），一组只在私密日记里（各 1 MB）。
StorageDuplicates _sampleDuplicates() => StorageDuplicates(
  buildStorageDuplicateGroups(
    [
      [
        storageEntry(
          'diary_images/d1/a.jpg',
          bytes: 2 * mb,
          title: '早餐',
          diaryId: 11,
        ),
        storageEntry(
          'diary_images/d2/b.jpg',
          bytes: 2 * mb,
          title: '午餐',
          diaryId: 12,
        ),
      ],
      [
        storageEntry(
          'diary_images/p1/x.jpg',
          bytes: mb,
          title: '私密甲',
          diaryId: 13,
          visibility: StorageRefVisibility.private,
        ),
        storageEntry(
          'diary_images/p2/y.jpg',
          bytes: mb,
          title: '私密乙',
          diaryId: 14,
          visibility: StorageRefVisibility.private,
        ),
      ],
    ],
    {
      'diary_images/d1/a.jpg': 'meal',
      'diary_images/d2/b.jpg': 'meal',
      'diary_images/p1/x.jpg': 'secret',
      'diary_images/p2/y.jpg': 'secret',
    },
  ),
);

void main() {
  final l10n = storageL10n;

  FakeStorageMediaService serviceWithDuplicates() =>
      FakeStorageMediaService(sampleStorageReport())
        ..duplicates = _sampleDuplicates();

  Future<void> confirmMerge(WidgetTester tester, int copies) async {
    expect(find.text(l10n.storageMgmtMergeTitle(copies)), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.storageMgmtMerge),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the overview offers to merge duplicates in place', (
    tester,
  ) async {
    final service = serviceWithDuplicates();
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: service,
      size: const Size(400, 2400),
    );

    final subtitle = find.text(
      l10n.storageMgmtSuggestDuplicatesSubtitle(2, l10n.formatByteSize(3 * mb)),
    );
    expect(subtitle, findsOneWidget);
    final row = find.ancestor(of: subtitle, matching: find.byType(ListTile));
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, l10n.storageMgmtMerge),
      ),
    );
    await tester.pumpAndSettle();
    await confirmMerge(tester, 2);

    expect(service.merged.single, hasLength(2));
    expect(
      find.text(l10n.storageMgmtMerged(2, l10n.formatByteSize(3 * mb))),
      findsOneWidget,
    );
    // 合并后重新扫描，没有重复了，这一行随之消失。
    expect(subtitle, findsNothing);
  });

  testWidgets('cancelling the confirmation merges nothing', (tester) async {
    final service = serviceWithDuplicates();
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: service,
      size: const Size(400, 2400),
    );
    await tester.tap(
      find.widgetWithText(TextButton, l10n.storageMgmtMerge).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(service.merged, isEmpty);
  });

  testWidgets('the row opens the duplicates page', (tester) async {
    await pumpStoragePage(
      tester,
      const StoragePage(),
      service: serviceWithDuplicates(),
      size: const Size(400, 2400),
    );
    await tester.tap(find.text(l10n.storageMgmtSuggestDuplicates));
    await tester.pumpAndSettle();
    expect(find.byType(StorageDuplicatesPage), findsOneWidget);
  });

  testWidgets('groups list each copy; private ones stay masked until shown', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StorageDuplicatesPage(),
      service: serviceWithDuplicates(),
      size: const Size(400, 2400),
    );

    expect(
      find.text(
        l10n.storageMgmtDuplicatesSummary(2, l10n.formatByteSize(3 * mb)),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.storageMgmtDuplicateGroupSubtitle(
          2,
          l10n.formatByteSize(2 * mb),
          l10n.formatByteSize(2 * mb),
        ),
      ),
      findsOneWidget,
    );
    // 组头与第一行都是“早餐”（保留的那份），第二行是要并掉的“午餐”。
    expect(find.text('早餐'), findsNWidgets(2));
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text(l10n.storageMgmtDuplicateKept), findsNWidgets(2));
    expect(find.text('私密甲'), findsNothing);
    expect(find.text(l10n.storageMgmtPrivateHidden(2)), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, l10n.storageMgmtReveal));
    await tester.pumpAndSettle();
    expect(find.text('私密甲'), findsWidgets);
    expect(find.text(l10n.storageMgmtPrivateHidden(2)), findsNothing);
  });

  testWidgets('a group merges on its own', (tester) async {
    final service = serviceWithDuplicates();
    await pumpStoragePage(
      tester,
      const StorageDuplicatesPage(),
      service: service,
      size: const Size(400, 2400),
    );

    // 组按能释放的大小排列：第一个“合并”是早餐那组（各 2 MB）。
    await tester.tap(
      find.widgetWithText(TextButton, l10n.storageMgmtMerge).first,
    );
    await tester.pumpAndSettle();
    await confirmMerge(tester, 1);
    expect(service.merged.single.single.sha256, 'meal');
    // 合并后没有重复了：换成空状态。
    expect(find.text(l10n.storageMgmtDuplicatesEmpty), findsOneWidget);
  });

  testWidgets('merge all takes every group', (tester) async {
    final service = serviceWithDuplicates();
    await pumpStoragePage(
      tester,
      const StorageDuplicatesPage(),
      service: service,
      size: const Size(400, 2400),
    );
    await tester.tap(
      find.text(l10n.storageMgmtMergeAll(l10n.formatByteSize(3 * mb))),
    );
    await tester.pumpAndSettle();
    await confirmMerge(tester, 2);
    expect(service.merged.last, hasLength(2));
  });

  for (final brightness in Brightness.values) {
    testWidgets('the duplicates page fits 320dp with large text in '
        '$brightness', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpStoragePage(
        tester,
        const StorageDuplicatesPage(),
        service: serviceWithDuplicates(),
        brightness: brightness,
        size: const Size(320, 2400),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
