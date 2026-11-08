// 写工具共用的检查、刷新与撤销辅助。
//
// - 能写哪篇日记：私密日记、回收站里的、未解封的时间胶囊、AI 隐私里排除的
//   日记本或标签里的，一律不写（AI 本来也查不到它们的 id）；
// - 写库后一次性 provider 手动失效（与 `syncedDataRefreshProvider` 同一份
//   清单里相关的几项），Drift watch 的列表自己会刷新；
// - 撤销前核对数据在那之后有没有被别处改过（按 `updatedAt`），改过就抛
//   `AiUndoConflict`，界面问过用户再强制。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/providers/diary_detail_provider.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../widgets/color_palette_families.dart';
import 'ai_tool.dart';

/// AI 新建标签的颜色：与“新建标签”弹窗的默认色同一格。
final int aiDefaultTagColor = kColorPaletteFamilies[3].colors[2].toARGB32();

/// 取一篇 AI 可以改的日记；不能改时抛 [AiToolFailure]。
Future<DiaryWithTags> aiWritableDiary(
  AiToolContext context,
  String diaryId,
) async {
  final database = context.database;
  final found = await database.getDiaryWithTagsByDiaryId(diaryId);
  if (found == null || found.diary.isDeleted) {
    throw AiToolFailure(
      'No entry with id $diaryId (it may be in the recycle bin).',
    );
  }
  final diary = found.diary;
  final privacy = context.prefs.privacy;
  final sealed = TimeCapsuleState.fromFields(
    lockedAt: diary.capsuleLockedAt,
    unlockAt: diary.capsuleUnlockAt,
    now: context.now,
  ).isLocked;
  final excluded =
      sealed ||
      await database.isDiaryPrivate(diaryId) ||
      found.tags.any((tag) => privacy.excludedTagNames.contains(tag.name)) ||
      (await database.getDiaryNotebookIds(
        diaryId,
      )).any(privacy.excludedNotebookIds.contains);
  if (excluded) {
    throw AiToolFailure(
      'Entry $diaryId is private, sealed or excluded from AI; it cannot be '
      'changed here.',
    );
  }
  return found;
}

/// 一批日记 id 都得能改，否则整批不做（不留半截改动）。
Future<List<DiaryWithTags>> aiWritableDiaries(
  AiToolContext context,
  Iterable<String> diaryIds,
) async => [
  for (final id in diaryIds.toSet()) await aiWritableDiary(context, id),
];

/// 日记写入后让一次性 provider 重新读。
void aiRefreshDiaries(ProviderContainer container, Iterable<String> diaryIds) {
  for (final id in diaryIds) {
    container
      ..invalidate(diaryDetailProvider(id))
      ..invalidate(diaryNotebooksProvider(id));
  }
}

/// 标签表变了：标签列表（自定义排序）重新读。
void aiRefreshTags(ProviderContainer container) =>
    container.invalidate(tagListProvider);

/// 一篇日记当前内容的指纹：标题、正文、元数据、发表与更新时间。库里的
/// 时间只精确到秒，同一秒内的再次修改单靠更新时间发现不了，所以连内容一起
/// 算。用确定性的 FNV-1a（`String.hashCode` 不保证跨版本稳定，而指纹要存进
/// 步骤记录、重开应用后还要用）。
String aiDiaryFingerprint(Diary diary) {
  var hash = 0x811c9dc5;
  for (final part in <String>[
    diary.title,
    diary.content,
    diary.metadata,
    '${diary.createdAt.millisecondsSinceEpoch}',
    '${diary.updatedAt.millisecondsSinceEpoch}',
  ]) {
    for (final unit in part.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    hash = ((hash ^ 0x1f) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}

/// 日记现在的指纹；不存在时为 null。
Future<String?> aiDiaryFingerprintOf(
  AppDatabase database,
  String diaryId,
) async {
  final found = await database.getDiaryWithTagsByDiaryId(diaryId);
  return found == null ? null : aiDiaryFingerprint(found.diary);
}

/// 撤销前核对：[expected] 是写完时记下的指纹。之后又被改过、且不是强制时
/// 抛 [AiUndoConflict]；日记已不存在时不算冲突（撤销照常做能做的）。
Future<void> aiCheckUnchanged(
  AppDatabase database,
  String diaryId,
  Object? expected, {
  required bool force,
}) async {
  if (force || expected is! String) return;
  final current = await aiDiaryFingerprintOf(database, diaryId);
  if (current != null && current != expected) throw const AiUndoConflict();
}

/// 撤销数据里的字符串列表。
List<String> aiUndoStrings(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is String) item,
];

/// 撤销数据里的整数列表。
List<int> aiUndoInts(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is int) item,
];
