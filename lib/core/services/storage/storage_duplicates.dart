import '../diary_audio_storage_service.dart';
import '../diary_media_storage_service.dart';
import 'storage_usage_models.dart';

/// 重复文件（内容逐字节相同的托管媒体）的纯规则，导入时复用与存储管理的
/// 合并共用（docs/rules/storage.md「重复文件」）：
/// - 一处引用可以改指向哪些托管目录（[managedMediaShareableDirectories]）；
/// - 哪些文件值得算哈希（[storageDuplicateCandidates]）；
/// - 一组同内容的文件保留哪份、哪些副本能并过去（[planStorageDuplicateGroup]）。
///
/// 不读写文件与数据库，可在后台 isolate 里调用。

const String _images = DiaryMediaStorageService.imagesDirectoryName;
const String _covers = 'diary_covers';
const String _videos = DiaryMediaStorageService.videosDirectoryName;
const String _attachments = DiaryMediaStorageService.attachmentsDirectoryName;
const String _recordings = DiaryAudioStorageService.directoryName;

/// 定位键（`diary_images/media_x/a.jpg`）所在的托管目录，即键的第一段。
String managedMediaDirectoryOf(String key) {
  final slash = key.indexOf('/');
  return slash < 0 ? key : key.substring(0, slash);
}

/// 一处引用（文件在 [directory] 里，[cover] 为日记 / 日记本封面）可以改指向
/// 的托管目录。
///
/// 必须与备份恢复重绑路径（`BackupMediaPaths.rewriteContent`、
/// `BackupPayload.rebindMedia` 等）找文件的范围一致：正文图片、留言与 AI
/// 图片只在 `diary_images/` 里找，封面在 `diary_covers/` 与 `diary_images/`
/// 里找，视频与附件两个目录互通，录音只在 `diary_recordings/`。改指到范围
/// 外，本机照常显示，换机恢复后却找不到文件。
///
/// `diary_covers/` 里的非封面引用只会是草稿的封面（草稿正文与封面记成同一
/// 处引用），同样按封面的范围。
Set<String> managedMediaShareableDirectories(
  String directory, {
  required bool cover,
}) => switch (directory) {
  _covers => const {_covers, _images},
  _images => cover ? const {_covers, _images} : const {_images},
  _videos || _attachments => const {_videos, _attachments},
  _ => {directory},
};

/// 可能存在同内容文件的目录范围（[managedMediaShareableDirectories] 两种
/// 引用的并集）；同一范围里的文件才互相比较。
Set<String> managedMediaPoolOf(String directory) => switch (directory) {
  _covers || _images => const {_covers, _images},
  _videos || _attachments => const {_videos, _attachments},
  _recordings => const {_recordings},
  _ => {directory},
};

/// 导入一份新文件（放在 [directory]，[cover] 为封面）时，可以改用哪些目录
/// 里的同内容文件，按优先顺序：封面优先用 `diary_images/` 里的（正文、
/// 封面都能指向它，是共用的那份），其余先找自己的目录。
List<String> managedMediaAdoptableDirectories(
  String directory, {
  required bool cover,
}) {
  final allowed = managedMediaShareableDirectories(directory, cover: cover);
  // 集合字面量保持插入顺序，同时去掉重复（封面本身就在 diary_images 时）。
  return <String>{
    if (cover && allowed.contains(_images)) _images,
    if (allowed.contains(directory)) directory,
    ...allowed,
  }.toList(growable: false);
}

bool _isCoverRef(StorageMediaRef ref) => switch (ref) {
  StorageDiaryRef(:final isCover) => isCover,
  StorageNotebookCoverRef() => true,
  _ => false,
};

/// [copy] 的每处引用都能改指到 [directory] 里的文件时为 true。没有引用、
/// 或有不知道怎么改写的引用（[StorageOtherRef]）时为 false。
bool canRepointStorageMedia(StorageMediaEntry copy, String directory) {
  if (copy.refs.isEmpty || !copy.isEditable) return false;
  final from = managedMediaDirectoryOf(copy.key);
  return copy.refs.every(
    (ref) => managedMediaShareableDirectories(
      from,
      cover: _isCoverRef(ref),
    ).contains(directory),
  );
}

/// 可能重复的文件：同一目录范围（[managedMediaPoolOf]）里大小相同、至少两个
/// 的被引用文件。内容相同必然大小相同，只有它们需要算哈希，大多数文件一次
/// 都不用读。空文件不算。
List<List<StorageMediaEntry>> storageDuplicateCandidates(
  Iterable<StorageMediaEntry> media,
) {
  final buckets = <String, List<StorageMediaEntry>>{};
  for (final entry in media) {
    if (entry.bytes <= 0 || entry.refs.isEmpty) continue;
    final pool = managedMediaPoolOf(managedMediaDirectoryOf(entry.key)).toList()
      ..sort();
    (buckets['${pool.join(',')}|${entry.bytes}'] ??= <StorageMediaEntry>[]).add(
      entry,
    );
  }
  return [
    for (final bucket in buckets.values)
      if (bucket.length > 1) bucket,
  ];
}

/// 一组内容相同的文件与合并方式。
class StorageDuplicateGroup {
  const StorageDuplicateGroup({
    required this.sha256,
    required this.keeper,
    required this.copies,
    this.retained = const <StorageMediaEntry>[],
  });

  final String sha256;

  /// 保留的那份：[copies] 的引用都改指向它。
  final StorageMediaEntry keeper;

  /// 合并后不再被引用、会删掉的副本（至少一个）。
  final List<StorageMediaEntry> copies;

  /// 内容相同、但引用不能改指到 [keeper] 的（目录范围不允许，或有不知道
  /// 怎么改写的引用）：原样保留。
  final List<StorageMediaEntry> retained;

  /// 保留的在前，其次是要并掉的副本，最后是原样保留的。
  List<StorageMediaEntry> get members => <StorageMediaEntry>[
    keeper,
    ...copies,
    ...retained,
  ];

  int get savedBytes => copies.fold<int>(0, (sum, entry) => sum + entry.bytes);

  /// 合并时要改写的引用处数（确认对话框的文案用）。
  int get rewrittenRefs =>
      copies.fold<int>(0, (sum, entry) => sum + entry.refs.length);

  /// 同一份内容取全部引用里最公开的一档：任一处公开过，就没有必要再藏。
  StorageRefVisibility get visibility {
    var result = StorageRefVisibility.capsule;
    for (final entry in members) {
      if (entry.visibility.index < result.index) result = entry.visibility;
    }
    return result;
  }
}

/// [same]（已确认内容相同）怎么合并；没有能并过去的副本时为 null。
///
/// 逐个试每份作保留：能并掉的字节越多越好，再依次取 `diary_images/` 或
/// `diary_videos/` 里的（[_preferredHomes]）、被引用多的（要改写的行少，
/// 同步带出的改动也少）、修改时间早的、定位键小的。结果只由输入决定，两台
/// 设备、重复调用得到同样的合并方式。
StorageDuplicateGroup? planStorageDuplicateGroup(
  String sha256,
  List<StorageMediaEntry> same,
) {
  if (same.length < 2) return null;
  StorageDuplicateGroup? best;
  for (final keeper in same) {
    final directory = managedMediaDirectoryOf(keeper.key);
    final copies = <StorageMediaEntry>[];
    final retained = <StorageMediaEntry>[];
    for (final other in same) {
      if (identical(other, keeper)) continue;
      (canRepointStorageMedia(other, directory) ? copies : retained).add(other);
    }
    if (copies.isEmpty) continue;
    copies.sort(_byKey);
    retained.sort(_byKey);
    final candidate = StorageDuplicateGroup(
      sha256: sha256,
      keeper: keeper,
      copies: copies,
      retained: retained,
    );
    if (best == null || _betterKeeper(candidate, best)) best = candidate;
  }
  return best;
}

/// 合并时优先留在这里的目录：`diary_images/` 正文与封面都能指向，
/// `diary_videos/` 是视频本来的家（附件目录里的同一份只是碰巧相同）。
const Set<String> _preferredHomes = {_images, _videos};

bool _betterKeeper(StorageDuplicateGroup a, StorageDuplicateGroup b) {
  if (a.savedBytes != b.savedBytes) return a.savedBytes > b.savedBytes;
  final aHome = _preferredHomes.contains(managedMediaDirectoryOf(a.keeper.key));
  final bHome = _preferredHomes.contains(managedMediaDirectoryOf(b.keeper.key));
  if (aHome != bHome) return aHome;
  if (a.keeper.refs.length != b.keeper.refs.length) {
    return a.keeper.refs.length > b.keeper.refs.length;
  }
  final age = a.keeper.modifiedAt.compareTo(b.keeper.modifiedAt);
  if (age != 0) return age < 0;
  return a.keeper.key.compareTo(b.keeper.key) < 0;
}

int _byKey(StorageMediaEntry a, StorageMediaEntry b) => a.key.compareTo(b.key);

/// 按哈希（定位键 → sha256，算不出的键不在表里）把候选分成重复组，按能
/// 释放的字节从多到少排列。
List<StorageDuplicateGroup> buildStorageDuplicateGroups(
  List<List<StorageMediaEntry>> candidates,
  Map<String, String> hashes,
) {
  final groups = <StorageDuplicateGroup>[];
  for (final bucket in candidates) {
    final byHash = <String, List<StorageMediaEntry>>{};
    for (final entry in bucket) {
      final hash = hashes[entry.key];
      if (hash != null) (byHash[hash] ??= <StorageMediaEntry>[]).add(entry);
    }
    for (final MapEntry(key: hash, value: same) in byHash.entries) {
      if (planStorageDuplicateGroup(hash, same) case final group?) {
        groups.add(group);
      }
    }
  }
  groups.sort((a, b) {
    final saved = b.savedBytes.compareTo(a.savedBytes);
    return saved != 0 ? saved : a.keeper.key.compareTo(b.keeper.key);
  });
  return groups;
}

/// 存储管理找到的全部重复组。
class StorageDuplicates {
  const StorageDuplicates(this.groups);

  static const StorageDuplicates none = StorageDuplicates(
    <StorageDuplicateGroup>[],
  );

  final List<StorageDuplicateGroup> groups;

  bool get isEmpty => groups.isEmpty;

  int get savedBytes =>
      groups.fold<int>(0, (sum, group) => sum + group.savedBytes);

  /// 合并全部后会删掉的副本个数。
  int get copyCount =>
      groups.fold<int>(0, (sum, group) => sum + group.copies.length);
}
