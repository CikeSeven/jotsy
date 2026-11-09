import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/ui/storage/models/storage_media_filter.dart';
import 'package:node_diary/ui/storage/pages/storage_media_page.dart';

import '../../support/storage_test_fixtures.dart';
import 'storage_test_app.dart';

void main() {
  final l10n = storageL10n;

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('lists media largest first and filters by category', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(),
      service: FakeStorageMediaService(sampleStorageReport()),
    );

    expect(top(tester, '海边'), lessThan(top(tester, '日落')));
    expect(top(tester, '日落'), lessThan(top(tester, '旧日记')));
    expect(
      find.text(l10n.storageMgmtListSummary(5, l10n.formatByteSize(199 * mb))),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(ChoiceChip, l10n.storageMgmtCategoryImages),
    );
    await tester.pumpAndSettle();
    expect(find.text('海边'), findsNothing);
    expect(find.text('日落'), findsOneWidget);

    final trash = find.widgetWithText(FilterChip, l10n.storageMgmtFilterTrash);
    await tester.ensureVisible(trash);
    await tester.pumpAndSettle();
    await tester.tap(trash);
    await tester.pumpAndSettle();
    expect(find.text('日落'), findsNothing);
    expect(find.text('旧日记'), findsOneWidget);
  });

  testWidgets('private media stays masked until shown', (tester) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(),
      service: FakeStorageMediaService(sampleStorageReport()),
    );

    expect(find.text('私密标题'), findsNothing);
    expect(find.text(l10n.storageMgmtMaskedPrivate), findsOneWidget);
    expect(find.text(l10n.storageMgmtPrivateHidden(1)), findsOneWidget);

    // 只在隐藏的日记本里：不必验证就能显示。
    await tester.tap(find.text(l10n.storageMgmtReveal));
    await tester.pumpAndSettle();
    expect(find.text('私密标题'), findsOneWidget);
    expect(find.text(l10n.storageMgmtPrivateHidden(1)), findsNothing);
  });

  testWidgets('sealed capsules are never shown', (tester) async {
    final report = sampleStorageReport();
    await pumpStoragePage(
      tester,
      const StorageMediaPage(),
      service: FakeStorageMediaService(
        StorageUsageReport(
          categoryBytes: report.categoryBytes,
          media: [
            storageEntry(
              'diary_images/m9/capsule.jpg',
              bytes: 5 * mb,
              title: '胶囊标题',
              visibility: StorageRefVisibility.capsule,
            ),
          ],
          orphanFiles: 0,
          orphanBytes: 0,
          clearableOrphanFiles: 0,
          clearableOrphanBytes: 0,
          cacheBytes: 0,
          clearableCacheBytes: 0,
        ),
      ),
    );

    expect(find.text('胶囊标题'), findsNothing);
    expect(find.text(l10n.storageMgmtMaskedCapsule), findsOneWidget);
    expect(find.text(l10n.storageMgmtReveal), findsNothing);
  });

  testWidgets('long press selects; delete asks first and lists the places', (
    tester,
  ) async {
    final service = FakeStorageMediaService(sampleStorageReport());
    await pumpStoragePage(tester, const StorageMediaPage(), service: service);

    await tester.longPress(find.text('日落'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtSelectedCount(1)), findsOneWidget);
    expect(
      find.text(
        l10n.storageMgmtSelectionSummary(1, l10n.formatByteSize(8 * mb)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtDeleteTitle(1)), findsOneWidget);
    expect(
      find.text('· ${l10n.storageMgmtDeleteFromDiaries(1)}'),
      findsOneWidget,
    );

    // 取消什么都不删，勾选保留。
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);
    expect(find.text(l10n.storageMgmtSelectedCount(1)), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(service.deleted.single, {'diary_images/m2/sunset.jpg'});
    expect(find.text(l10n.storageMgmtSelectedCount(1)), findsNothing);
  });

  testWidgets('an image sent in an AI chat says so and is listed on delete', (
    tester,
  ) async {
    final entry = storageEntry(
      'diary_images/m9/chat.jpg',
      bytes: 2 * mb,
      refs: [
        StorageAiMessageRef(
          messageLocalId: 7,
          conversationId: 'c1',
          conversationTitle: '海边对话',
          createdAt: DateTime(2026, 11, 9),
        ),
      ],
    );
    final service = FakeStorageMediaService(
      StorageUsageReport(
        categoryBytes: const {StorageCategory.images: 2 * mb},
        media: [entry],
        orphanFiles: 0,
        orphanBytes: 0,
        clearableOrphanFiles: 0,
        clearableOrphanBytes: 0,
        cacheBytes: 0,
        clearableCacheBytes: 0,
      ),
    );
    await pumpStoragePage(tester, const StorageMediaPage(), service: service);

    final label = l10n.storageMgmtRefAiChat('海边对话');
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtUsedIn(1)), findsOneWidget);
    expect(find.text(label), findsWidgets);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(
      find.text('· ${l10n.storageMgmtDeleteFromAiChats(1)}'),
      findsOneWidget,
    );
    expect(find.text(l10n.storageMgmtDeleteAiChatNote), findsOneWidget);
  });

  testWidgets('compress is offered only where the platform can compress', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(),
      service: FakeStorageMediaService(sampleStorageReport()),
    );
    await tester.longPress(find.text('日落'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtCompress), findsOneWidget);
    expect(find.text(l10n.storageMgmtFilterCompressible), findsOneWidget);

    await pumpStoragePage(
      tester,
      const StorageMediaPage(),
      service: FakeStorageMediaService(
        sampleStorageReport(),
        supportsCompression: false,
      ),
    );
    await tester.longPress(find.text('日落'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageMgmtCompress), findsNothing);
    expect(find.text(l10n.storageMgmtFilterCompressible), findsNothing);
  });

  testWidgets('tapping an item shows where it is used', (tester) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(
        initialFilter: StorageMediaFilter(category: StorageCategory.images),
      ),
      service: FakeStorageMediaService(sampleStorageReport()),
    );

    await tester.tap(find.text('日落'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.storageMgmtUsedIn(1)), findsOneWidget);
    expect(find.text('sunset.jpg'), findsOneWidget);
    expect(find.text('日落'), findsWidgets);
  });

  testWidgets('the compress button never cuts off how much it saves', (
    tester,
  ) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(
        initialFilter: StorageMediaFilter(category: StorageCategory.images),
      ),
      service: FakeStorageMediaService(sampleStorageReport()),
      size: const Size(320, 800),
    );

    await tester.tap(find.text('日落'));
    await tester.pumpAndSettle();

    final label = find.textContaining('约省');
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.text(l10n.commonDelete), findsOneWidget);
  });

  testWidgets('grid view is remembered for image categories', (tester) async {
    await pumpStoragePage(
      tester,
      const StorageMediaPage(
        initialFilter: StorageMediaFilter(category: StorageCategory.images),
      ),
      service: FakeStorageMediaService(sampleStorageReport()),
      preferences: {'app.settings.storage_manager': '{"view":"grid"}'},
    );

    // 网格只显示画面与大小，不显示日记标题。
    expect(find.text('日落'), findsNothing);
    expect(find.text(l10n.formatByteSize(8 * mb)), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.storageMgmtViewList));
    await tester.pumpAndSettle();
    expect(find.text('日落'), findsOneWidget);
  });
}
