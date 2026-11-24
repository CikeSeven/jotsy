import '../../../core/services/storage/storage_duplicates.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import 'storage_media_view.dart';

/// 重复文件页的一组：组的预览按整组最公开的一档打码（内容相同，任一处公开
/// 过就没有必要再藏），每份副本的标题与日期按它自己的引用打码（不能借
/// 公开的那份把私密日记的标题带出来）。
class StorageDuplicateGroupView {
  const StorageDuplicateGroupView({
    required this.group,
    required this.preview,
    required this.members,
  });

  final StorageDuplicateGroup group;

  /// 组头的缩略图（保留的那份）。
  final StorageMediaItemView preview;

  /// 与 [StorageDuplicateGroup.members] 同序：保留的、要并掉的、原样保留的。
  final List<StorageMediaItemView> members;

  bool isKept(StorageMediaItemView item) => identical(item.entry, group.keeper);

  bool isRetained(StorageMediaItemView item) =>
      group.retained.any((entry) => identical(entry, item.entry));
}

/// 重复文件页：各组与打码汇总。
class StorageDuplicatesView {
  const StorageDuplicatesView({
    required this.groups,
    required this.savedBytes,
    required this.maskedPrivateCount,
    required this.maskedNeedsVerification,
  });

  final List<StorageDuplicateGroupView> groups;
  final int savedBytes;

  /// 因私密而打码、揭示后能看到的副本数（胶囊不算：永不预览）。
  final int maskedPrivateCount;

  /// 打码的副本里有在上锁日记本里的：揭示前要验证身份。
  final bool maskedNeedsVerification;

  static StorageDuplicatesView of(
    StorageDuplicates duplicates,
    StorageUsageReport? report, {
    required bool revealPrivate,
  }) {
    StorageMediaItemView item(StorageMediaEntry entry, bool masked) =>
        StorageMediaItemView(
          entry: entry,
          masked: masked,
          estimatedBytes: null,
          video: report?.videoInfo[entry.key],
        );
    final groups = <StorageDuplicateGroupView>[];
    var maskedPrivate = 0;
    var needsVerification = false;
    for (final group in duplicates.groups) {
      final members = <StorageMediaItemView>[];
      for (final entry in group.members) {
        final visibility = entry.visibility;
        if (storageVisibilityIsPrivate(visibility) && !revealPrivate) {
          maskedPrivate++;
          if (visibility == StorageRefVisibility.locked) {
            needsVerification = true;
          }
        }
        members.add(
          item(
            entry,
            storageMediaMasked(visibility, revealPrivate: revealPrivate),
          ),
        );
      }
      groups.add(
        StorageDuplicateGroupView(
          group: group,
          preview: item(
            group.keeper,
            storageMediaMasked(group.visibility, revealPrivate: revealPrivate),
          ),
          members: members,
        ),
      );
    }
    return StorageDuplicatesView(
      groups: groups,
      savedBytes: duplicates.savedBytes,
      maskedPrivateCount: maskedPrivate,
      maskedNeedsVerification: needsVerification,
    );
  }
}
