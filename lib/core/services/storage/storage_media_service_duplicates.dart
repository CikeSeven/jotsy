part of 'storage_media_service.dart';

/// 存储管理的重复文件：找出内容逐字节相同的托管媒体，合并成一份
/// （docs/rules/storage.md「重复文件」；规则见 `storage_duplicates.dart`）。
///
/// 合并与压缩同一条链路，只是“新文件”换成同组里保留的那份：守卫 → 独占
/// 托管媒体写入闸门（要删的副本可能正被同步当作“已有同样内容”复用）→ 按
/// 内容直接核对哈希 → 串行队列里重新读取全部引用、重新规划 → 一次事务
/// 改写引用 → 只删已经没有引用的副本 → 通知打开着的界面重新读取。
///
/// 对外的入口是 [StorageMediaService.findDuplicates] /
/// [StorageMediaService.mergeDuplicates]（实例方法，测试的假服务可以覆盖）。
extension _StorageMediaDuplicates on StorageMediaService {
  Future<StorageDuplicates> _findDuplicates(StorageUsageReport report) async {
    final candidates = storageDuplicateCandidates(report.media);
    final index = ManagedMediaContentIndex.forRoot(await _dataRoot());
    final hashes = candidates.isEmpty
        ? const <String, SyncMediaInfo>{}
        : await index.describeAll(<String>[
            for (final bucket in candidates)
              for (final entry in bucket) entry.key,
          ]);
    await index.retainOnly(<String>{
      for (final entry in report.media) entry.key,
      for (final entry in report.unused) entry.key,
    });
    if (hashes.isEmpty) return StorageDuplicates.none;
    return StorageDuplicates(
      buildStorageDuplicateGroups(candidates, <String, String>{
        for (final info in hashes.values) info.key: info.sha256,
      }),
    );
  }

  Future<StorageMergeResult> _mergeDuplicates(
    List<StorageDuplicateGroup> groups,
  ) async {
    await _guard();
    return _exclusive(() async {
      final root = (await _dataRoot()).path;
      // 先按内容核对（视频可能很大，放在串行队列之外，不拖住同步与导入）：
      // 每组只留内容仍是这组哈希的成员。
      final verified = <(String, List<String>)>[];
      for (final group in groups) {
        final same = <String>[
          for (final entry in group.members)
            if (await _hashOf(_pathOf(root, entry.key)) == group.sha256)
              entry.key,
        ];
        if (same.length > 1) verified.add((group.sha256, same));
      }
      if (verified.isEmpty) return StorageMergeResult.none;
      return DataArchiveService.runSerialized(() async {
        final sources = await _database.getStorageReferenceSources();
        final refs = await _refsInBackground(
          sources,
          (await _settings()).createDiaryDraftRaw,
          _clock(),
          {for (final (_, same) in verified) ...same},
        );
        final replacements = <String, String>{};
        for (final (hash, same) in verified) {
          final entries = <StorageMediaEntry>[
            for (final key in same)
              if (await _currentEntry(root, key, refs[key]) case final entry?)
                entry,
          ];
          final plan = planStorageDuplicateGroup(hash, entries);
          if (plan == null) continue;
          for (final copy in plan.copies) {
            replacements[copy.key] = plan.keeper.path;
          }
        }
        if (replacements.isEmpty) return StorageMergeResult.none;
        final plan = await planStorageMediaReplacement(sources, replacements);
        final written = await _database.applyStorageMediaEdits(plan.edits);
        final freed = await _deleteUnreferenced(replacements.keys.toSet());
        if (written.applied > 0) _registry.notifyDataReplaced();
        return StorageMergeResult(
          mergedFiles: freed.files,
          freedBytes: freed.bytes,
          skippedRows: written.skipped,
        );
      });
    });
  }

  /// 定位键在本机的绝对路径（按平台分隔符拼，写进引用的也是这个路径）。
  static String _pathOf(String root, String key) =>
      p.joinAll(<String>[root, ...key.split('/')]);

  /// 文件内容的 sha256；读不到时为 null。
  static Future<String?> _hashOf(String path) async {
    try {
      return await syncSha256OfFile(File(path));
    } on FileSystemException {
      return null;
    }
  }

  /// 按现状重建一个文件的条目（大小、修改时间、引用）；文件已不在时为 null。
  /// 合并的规则只看定位键、大小、修改时间与引用，其余字段不需要。
  static Future<StorageMediaEntry?> _currentEntry(
    String root,
    String key,
    List<StorageMediaRef>? refs,
  ) async {
    final path = _pathOf(root, key);
    final FileStat stat;
    try {
      stat = await File(path).stat();
    } on FileSystemException {
      return null;
    }
    if (stat.type != FileSystemEntityType.file) return null;
    return StorageMediaEntry(
      key: key,
      path: path,
      kind: DiaryBlockMediaKind.image,
      category: StorageCategory.images,
      bytes: stat.size,
      modifiedAt: stat.modified,
      refs: refs ?? const <StorageMediaRef>[],
    );
  }

  /// [keys] 各自现在的引用（口径同扫描，见 [StorageReferenceIndex]）。
  static Future<Map<String, List<StorageMediaRef>>> _refsInBackground(
    StorageReferenceSources sources,
    String? legacyDraftRaw,
    DateTime now,
    Set<String> keys,
  ) => Isolate.run(() {
    final index = buildStorageReferenceIndex(
      sources,
      now: now,
      legacyDraftRaw: legacyDraftRaw,
    );
    return <String, List<StorageMediaRef>>{
      for (final key in keys) key: index.refsOf(key),
    };
  });
}

class StorageMergeResult {
  const StorageMergeResult({
    required this.mergedFiles,
    required this.freedBytes,
    required this.skippedRows,
  });

  static const StorageMergeResult none = StorageMergeResult(
    mergedFiles: 0,
    freedBytes: 0,
    skippedRows: 0,
  );

  /// 合并后删掉的副本数。
  final int mergedFiles;
  final int freedBytes;

  /// 读取之后被改过、这次没有改写的行（它们引用的副本保留）。
  final int skippedRows;
}
