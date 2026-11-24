import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/storage_duplicates.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';

import '../../../support/storage_test_fixtures.dart';

StorageDiaryRef _diaryRef(int id, {bool cover = false}) => StorageDiaryRef(
  diaryLocalId: id,
  diaryId: 'diary-$id',
  title: '日记 $id',
  createdAt: DateTime(2026, 5, id),
  isCover: cover,
  isDeleted: false,
  visibility: StorageRefVisibility.visible,
);

StorageMediaEntry _entry(
  String key, {
  int bytes = 100,
  List<StorageMediaRef>? refs,
  DateTime? modified,
}) {
  final base = storageEntry(key, bytes: bytes, refs: refs);
  return StorageMediaEntry(
    key: base.key,
    path: base.path,
    kind: base.kind,
    category: base.category,
    bytes: base.bytes,
    modifiedAt: modified ?? base.modifiedAt,
    refs: base.refs,
    image: base.image,
  );
}

void main() {
  group('shareable directories (must match backup restore rebinding)', () {
    test('body images, comments and AI images stay in diary_images', () {
      expect(managedMediaShareableDirectories('diary_images', cover: false), {
        'diary_images',
      });
    });

    test('covers may use diary_covers or diary_images', () {
      expect(managedMediaShareableDirectories('diary_images', cover: true), {
        'diary_covers',
        'diary_images',
      });
      expect(managedMediaShareableDirectories('diary_covers', cover: true), {
        'diary_covers',
        'diary_images',
      });
    });

    test('videos and attachments share; recordings stay alone', () {
      expect(managedMediaShareableDirectories('diary_videos', cover: false), {
        'diary_videos',
        'diary_attachments',
      });
      expect(
        managedMediaShareableDirectories('diary_recordings', cover: false),
        {'diary_recordings'},
      );
    });

    test('imports look in the shared home first', () {
      expect(managedMediaAdoptableDirectories('diary_covers', cover: true), [
        'diary_images',
        'diary_covers',
      ]);
      expect(managedMediaAdoptableDirectories('diary_images', cover: false), [
        'diary_images',
      ]);
      expect(
        managedMediaAdoptableDirectories('diary_attachments', cover: false),
        ['diary_attachments', 'diary_videos'],
      );
    });
  });

  group('candidates', () {
    test('only same-size referenced files in one pool are hashed', () {
      final candidates = storageDuplicateCandidates([
        _entry('diary_images/a/1.jpg', bytes: 10),
        _entry('diary_covers/c.jpg', bytes: 10),
        _entry('diary_images/b/2.jpg', bytes: 11),
        _entry('diary_videos/v/1.mp4', bytes: 10),
        _entry('diary_recordings/r.m4a', bytes: 10),
        _entry('diary_images/e/empty.jpg', bytes: 0),
        _entry('diary_images/f/empty.jpg', bytes: 0),
        _entry('diary_images/u/unused.jpg', bytes: 10, refs: const []),
      ]);
      expect(candidates, hasLength(1));
      expect(candidates.single.map((entry) => entry.key), [
        'diary_images/a/1.jpg',
        'diary_covers/c.jpg',
      ]);
    });
  });

  group('planning a group', () {
    test('a cover copy merges into the body image, never the reverse', () {
      final body = _entry('diary_images/a/photo.jpg', refs: [_diaryRef(1)]);
      final cover = _entry(
        'diary_covers/cover_1.jpg',
        refs: [_diaryRef(2, cover: true)],
      );
      final group = planStorageDuplicateGroup('h', [cover, body])!;
      expect(group.keeper.key, body.key);
      expect(group.copies.map((entry) => entry.key), [cover.key]);
      expect(group.retained, isEmpty);
      expect(group.savedBytes, 100);
    });

    test('body references never move into diary_covers', () {
      // 草稿封面在 diary_covers 里，正文图片在 diary_images 里：正文不能指向
      // diary_covers，只能由封面目录那份并进 diary_images。
      final inImages = _entry('diary_images/a/1.jpg', refs: [_diaryRef(1)]);
      final coverDraft = _entry(
        'diary_covers/cover_2.jpg',
        refs: const [StorageDraftRef(draftLocalId: 1, title: '草稿')],
      );
      final group = planStorageDuplicateGroup('h', [coverDraft, inImages])!;
      expect(group.keeper.key, inImages.key);
    });

    test('keeps the copy with more references, then the older one', () {
      final popular = _entry(
        'diary_images/b/2.jpg',
        refs: [_diaryRef(1), _diaryRef(2)],
        modified: DateTime(2026, 6, 1),
      );
      final older = _entry(
        'diary_images/a/1.jpg',
        refs: [_diaryRef(3)],
        modified: DateTime(2026, 1, 1),
      );
      expect(planStorageDuplicateGroup('h', [older, popular])!.keeper, popular);

      final newer = _entry(
        'diary_images/c/3.jpg',
        refs: [_diaryRef(4)],
        modified: DateTime(2026, 9, 1),
      );
      expect(planStorageDuplicateGroup('h', [newer, older])!.keeper, older);
    });

    test('a copy with unknown references is kept and the rest join it', () {
      final unknown = _entry(
        'diary_images/z/9.jpg',
        refs: const [StorageOtherRef()],
      );
      final normal = _entry('diary_images/a/1.jpg', refs: [_diaryRef(1)]);
      final group = planStorageDuplicateGroup('h', [normal, unknown])!;
      expect(group.keeper, unknown);
      expect(group.copies, [normal]);
    });

    test('nothing to merge when no copy can point at another', () {
      final first = _entry(
        'diary_images/a/1.jpg',
        refs: const [StorageOtherRef()],
      );
      final second = _entry(
        'diary_images/b/2.jpg',
        refs: const [StorageOtherRef()],
      );
      expect(planStorageDuplicateGroup('h', [first, second]), isNull);
    });

    test('videos and attachments merge across their two directories', () {
      final video = _entry(
        'diary_videos/v/clip.mp4',
        refs: [_diaryRef(1), _diaryRef(2)],
      );
      final attachment = _entry(
        'diary_attachments/a/clip.mp4',
        refs: [_diaryRef(3)],
      );
      final group = planStorageDuplicateGroup('h', [attachment, video])!;
      expect(group.keeper, video);
      expect(group.copies, [attachment]);
    });

    test('on a tie the video folder wins over the attachments folder', () {
      final video = _entry('diary_videos/v/clip.mp4', refs: [_diaryRef(1)]);
      final attachment = _entry(
        'diary_attachments/a/clip.mp4',
        refs: [_diaryRef(2)],
      );
      // 定位键 diary_attachments 更小，但视频目录是视频本来的家。
      expect(
        planStorageDuplicateGroup('h', [attachment, video])!.keeper,
        video,
      );
    });

    test('the group takes the most public visibility of its copies', () {
      final private = storageEntry(
        'diary_images/a/1.jpg',
        bytes: 100,
        visibility: StorageRefVisibility.private,
      );
      final visible = storageEntry('diary_images/b/2.jpg', bytes: 100);
      final group = planStorageDuplicateGroup('h', [private, visible])!;
      expect(group.visibility, StorageRefVisibility.visible);
    });
  });

  test('groups split by content and sort by what they free', () {
    final small = [
      _entry('diary_images/a/1.jpg', bytes: 10, refs: [_diaryRef(1)]),
      _entry('diary_images/b/2.jpg', bytes: 10, refs: [_diaryRef(2)]),
      _entry('diary_images/c/3.jpg', bytes: 10, refs: [_diaryRef(3)]),
    ];
    final large = [
      _entry('diary_videos/v/1.mp4', bytes: 500, refs: [_diaryRef(4)]),
      _entry('diary_videos/w/2.mp4', bytes: 500, refs: [_diaryRef(5)]),
    ];
    final duplicates = StorageDuplicates(
      buildStorageDuplicateGroups(
        [small, large],
        {
          'diary_images/a/1.jpg': 'same',
          'diary_images/b/2.jpg': 'same',
          // 大小相同、内容不同：不算重复。
          'diary_images/c/3.jpg': 'other',
          'diary_videos/v/1.mp4': 'video',
          'diary_videos/w/2.mp4': 'video',
        },
      ),
    );
    expect(duplicates.groups.map((group) => group.sha256), ['video', 'same']);
    expect(duplicates.savedBytes, 510);
    expect(duplicates.copyCount, 2);
    expect(
      duplicates.groups.last.members.map((entry) => entry.key),
      isNot(contains('diary_images/c/3.jpg')),
    );
  });
}
