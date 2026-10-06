import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File file;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_file_open_test_');
    file = File(p.join(root.path, '中文 报告.pdf'));
    await file.writeAsBytes([1]);
  });

  tearDown(() async => root.delete(recursive: true));

  test(
    'local file and encoded file URI reach the native file handler',
    () async {
      final paths = <String>[];
      final service = FileOpenService(
        opener: (path) async {
          paths.add(path);
          return OpenResult();
        },
      );
      expect(await service.open(file.path), isNull);
      expect(await service.open(file.uri.toString()), isNull);
      expect(paths, [file.path, file.path]);
    },
  );

  test('missing files never invoke the native file handler', () async {
    var opened = false;
    final service = FileOpenService(
      opener: (_) async {
        opened = true;
        return OpenResult();
      },
    );
    expect(await service.open(''), FileOpenFailure.missingFile);
    expect(
      await service.open(p.join(root.path, 'missing.pdf')),
      FileOpenFailure.missingFile,
    );
    expect(opened, isFalse);
  });

  for (final entry in {
    ResultType.noAppToOpen: FileOpenFailure.noApp,
    ResultType.permissionDenied: FileOpenFailure.permissionDenied,
    ResultType.fileNotFound: FileOpenFailure.missingFile,
    ResultType.error: FileOpenFailure.failed,
  }.entries) {
    test(
      'native ${entry.key} returns a user-facing failure category',
      () async {
        final service = FileOpenService(
          opener: (_) async => OpenResult(type: entry.key),
        );
        expect(await service.open(file.path), entry.value);
      },
    );
  }

  test('native exceptions are reported without escaping into the UI', () async {
    final service = FileOpenService(
      opener: (_) async {
        throw PlatformException(code: 'unavailable');
      },
    );
    expect(await service.open(file.path), FileOpenFailure.failed);
  });
}
