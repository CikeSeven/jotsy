import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ZIP import paths avoid reading entire backup into memory', () async {
    final source =
        await File(
          'lib/core/services/data_archive_service.dart',
        ).readAsString();

    expect(source, isNot(contains('sourceZip.readAsBytes()')));
    expect(source, isNot(contains('zipFile.readAsBytes()')));
  });

  test('diary restore preserves time capsule fields', () async {
    final source =
        await File(
          'lib/core/services/data_archive_service.dart',
        ).readAsString();

    expect(
      source,
      contains('capsuleUnlockAt: Value<DateTime?>(row.capsuleUnlockAt)'),
    );
    expect(
      source,
      contains('capsuleLockedAt: Value<DateTime?>(row.capsuleLockedAt)'),
    );
  });
}
