import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_media_transaction.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory documents;
  late Directory staging;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_swap_');
    documents = await Directory(p.join(root.path, 'documents')).create();
    staging = await documents.createTemp('.backup_import_');
    for (final name in ['diary_covers', 'diary_images']) {
      final original = File(p.join(documents.path, name, 'original.bin'));
      await original.parent.create();
      await original.writeAsBytes([1, 2, 3]);
      final incoming = File(p.join(staging.path, name, 'incoming.bin'));
      await incoming.parent.create();
      await incoming.writeAsBytes([4, 5, 6]);
    }
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'a directory move failure reverses earlier swaps and the saved failing directory',
    () async {
      var failOnce = true;
      final transaction = BackupMediaTransaction.withDirectoryMover(
        documents: documents,
        staging: staging,
        renameDirectory: (source, target) {
          if (failOnce && source.path == p.join(staging.path, 'diary_images')) {
            failOnce = false;
            throw const FileSystemException('simulated move failure');
          }
          return source.rename(target);
        },
      );
      await expectLater(
        transaction.install(),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(
          p.join(documents.path, 'diary_covers', 'incoming.bin'),
        ).exists(),
        isTrue,
      );
      await transaction.rollback();
      for (final name in ['diary_covers', 'diary_images']) {
        expect(
          await File(
            p.join(documents.path, name, 'original.bin'),
          ).readAsBytes(),
          [1, 2, 3],
        );
        expect(
          await File(p.join(documents.path, name, 'incoming.bin')).exists(),
          isFalse,
        );
      }
      expect(
        await Directory(p.join(documents.path, 'diary_videos')).exists(),
        isFalse,
      );
    },
  );

  test(
    'rollback failures leave original files in the staging area for recovery',
    () async {
      var rejectRollback = false;
      final transaction = BackupMediaTransaction.withDirectoryMover(
        documents: documents,
        staging: staging,
        renameDirectory: (source, target) {
          if (rejectRollback &&
              target == p.join(documents.path, 'diary_covers')) {
            throw const FileSystemException('simulated rollback failure');
          }
          return source.rename(target);
        },
      );
      await transaction.install();
      rejectRollback = true;
      await expectLater(
        transaction.rollback(),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(
          p.join(documents.path, 'diary_images', 'original.bin'),
        ).readAsBytes(),
        [1, 2, 3],
      );
      final originals = await staging
          .list(recursive: true)
          .where(
            (file) => file is File && p.basename(file.path) == 'original.bin',
          )
          .toList();
      expect(originals, hasLength(1));
      expect(await File(originals.single.path).readAsBytes(), [1, 2, 3]);
    },
  );
}
