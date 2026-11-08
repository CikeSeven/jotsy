import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/ui/storage/viewmodels/storage_growth.dart';

import '../../support/storage_test_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 8);

  test('recent media is counted per month over the last 12 months', () {
    final series = StorageGrowthSeries.of([
      storageEntry(
        'diary_images/a.jpg',
        bytes: 3,
        createdAt: DateTime(2026, 11, 2),
      ),
      storageEntry(
        'diary_images/b.jpg',
        bytes: 5,
        createdAt: DateTime(2026, 3, 9),
      ),
      storageEntry(
        'diary_images/c.jpg',
        bytes: 4,
        createdAt: DateTime(2026, 3, 1),
      ),
      storageEntry(
        'diary_images/d.jpg',
        bytes: 1,
        createdAt: DateTime(2025, 12, 31),
      ),
    ], now)!;

    expect(series.yearly, isFalse);
    expect(series.points, hasLength(12));
    expect(series.points.first.start, DateTime(2025, 12));
    expect(series.points.last.start, DateTime(2026, 11));
    expect(series.points.first.bytes, 1);
    expect(series.points[3].bytes, 9);
    expect(series.peakIndex, 3);
  });

  test('older media is counted per year, gaps included, last 8 years', () {
    final series = StorageGrowthSeries.of([
      storageEntry(
        'diary_images/a.jpg',
        bytes: 2,
        createdAt: DateTime(2015, 6),
      ),
      storageEntry(
        'diary_images/b.jpg',
        bytes: 7,
        createdAt: DateTime(2020, 1),
      ),
      storageEntry(
        'diary_images/c.jpg',
        bytes: 4,
        createdAt: DateTime(2026, 2),
      ),
    ], now)!;

    expect(series.yearly, isTrue);
    expect(series.points.map((p) => p.start.year), [
      2019,
      2020,
      2021,
      2022,
      2023,
      2024,
      2025,
      2026,
    ]);
    expect(series.points[1].bytes, 7);
    expect(series.points[2].bytes, 0);
    expect(series.peakIndex, 1);
  });

  test('no media has no series', () {
    expect(StorageGrowthSeries.of(const <StorageMediaEntry>[], now), isNull);
  });

  test('system app stats replace the scanned total', () {
    final report = sampleStorageReport();
    final scanned = report.totalBytes;
    const space = StorageDeviceSpace(
      totalBytes: 100 * 1024 * mb,
      freeBytes: 40 * 1024 * mb,
      appCodeBytes: 90 * mb,
      appDataBytes: 500 * mb,
    );

    final merged = report.withDeviceSpace(space);

    expect(merged.bytesOf(StorageCategory.app), 90 * mb);
    expect(merged.totalBytes, 590 * mb);
    expect(storageAppTotal(scanned, space), 590 * mb);
    // 读不到应用统计时保持扫描到的数字。
    const plain = StorageDeviceSpace(totalBytes: 1, freeBytes: 0);
    expect(report.withDeviceSpace(plain).totalBytes, scanned);
    expect(storageAppTotal(scanned, plain), scanned);
    // 系统算的数据比扫描到的少（时机不同）时不倒扣。
    const small = StorageDeviceSpace(
      totalBytes: 1,
      freeBytes: 0,
      appCodeBytes: 10,
      appDataBytes: 1,
    );
    expect(report.withDeviceSpace(small).totalBytes, scanned + 10);
  });
}
