import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_comment_images.dart';
import 'package:node_diary/ui/diaries/controllers/diary_comment_images_controller.dart';

void main() {
  List<PlatformFile> files(int count, {String prefix = 'p'}) => <PlatformFile>[
    for (var i = 0; i < count; i++)
      PlatformFile(
        name: '$prefix$i.jpg',
        size: 1,
        path: '/picked/$prefix$i.jpg',
      ),
  ];

  late List<String> discarded;
  setUp(() => discarded = <String>[]);

  DiaryCommentImagesController controller({
    List<String> initial = const <String>[],
    required Future<List<PlatformFile>?> Function() picker,
    Future<String> Function(PlatformFile file)? importer,
  }) => DiaryCommentImagesController(
    initial: initial,
    picker: picker,
    importer:
        importer ?? (file) async => '/managed/diary_images/m/${file.name}',
    discarder: (path) async => discarded.add(path),
  );

  test('picked photos are copied in, in order', () async {
    final images = controller(
      initial: const <String>['/managed/diary_images/old.jpg'],
      picker: () async => files(2),
    );
    expect(await images.pick(), DiaryCommentImagePickResult.added);
    expect(images.images, <String>[
      '/managed/diary_images/old.jpg',
      '/managed/diary_images/m/p0.jpg',
      '/managed/diary_images/m/p1.jpg',
    ]);
    expect(images.isBusy, isFalse);
    expect(images.pending, 0);
    images.dispose();
    // 没有保存：本次新复制的删掉，原有的不动。
    expect(discarded, <String>[
      '/managed/diary_images/m/p0.jpg',
      '/managed/diary_images/m/p1.jpg',
    ]);
  });

  test('picking more than fits keeps the first ones and says so', () async {
    final images = controller(
      initial: <String>[
        for (var i = 0; i < 7; i++) '/managed/diary_images/o$i.jpg',
      ],
      picker: () async => files(4),
    );
    expect(images.remaining, 2);
    expect(await images.pick(), DiaryCommentImagePickResult.truncated);
    expect(images.images, hasLength(kDiaryCommentMaxImages));
    expect(images.canAdd, isFalse);
    expect(await images.pick(), DiaryCommentImagePickResult.busy);
    images.dispose();
  });

  test('cancelling the picker changes nothing', () async {
    final images = controller(picker: () async => null);
    expect(await images.pick(), DiaryCommentImagePickResult.cancelled);
    expect(images.images, isEmpty);
    images.dispose();
    expect(discarded, isEmpty);
  });

  test(
    'removing a new photo deletes its file, an existing one only leaves the list',
    () async {
      final images = controller(
        initial: const <String>['/managed/diary_images/old.jpg'],
        picker: () async => files(1),
      );
      await images.pick();
      images
        ..remove('/managed/diary_images/old.jpg')
        ..remove('/managed/diary_images/m/p0.jpg');
      await pumpEventQueue();
      expect(images.images, isEmpty);
      expect(discarded, <String>['/managed/diary_images/m/p0.jpg']);
    },
  );

  test(
    'saving hands the new photos over; closing then deletes nothing',
    () async {
      final images = controller(picker: () async => files(2));
      await images.pick();
      images.remove('/managed/diary_images/m/p0.jpg');
      await pumpEventQueue();
      discarded.clear();
      expect(images.handOff(), <String>['/managed/diary_images/m/p1.jpg']);
      images.dispose();
      expect(discarded, isEmpty);
    },
  );

  test('a copy that finishes after the sheet closed is deleted', () async {
    final gate = Completer<void>();
    final images = controller(
      picker: () async => files(1),
      importer: (file) async {
        await gate.future;
        return '/managed/diary_images/m/late.jpg';
      },
    );
    final picking = images.pick();
    await pumpEventQueue();
    expect(images.isBusy, isTrue);
    expect(images.pending, 1);
    images.dispose();
    gate.complete();
    expect(await picking, DiaryCommentImagePickResult.cancelled);
    await pumpEventQueue();
    expect(discarded, <String>['/managed/diary_images/m/late.jpg']);
  });

  test('a failed copy keeps what was already added', () async {
    var calls = 0;
    final images = controller(
      picker: () async => files(3),
      importer: (file) async {
        if (++calls == 2) throw const FileSystemException('disk full');
        return '/managed/diary_images/m/${file.name}';
      },
    );
    expect(await images.pick(), DiaryCommentImagePickResult.failed);
    expect(images.images, <String>['/managed/diary_images/m/p0.jpg']);
    expect(images.isBusy, isFalse);
    images.dispose();
  });

  test('a denied permission is reported as such', () async {
    final images = controller(
      picker: () async => throw PlatformException(code: 'permission_denied'),
    );
    expect(await images.pick(), DiaryCommentImagePickResult.permissionDenied);
    images.dispose();
  });
}
