import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/diary_blocks/diary_blocks_codec.dart';
import '../database/diary_blocks/diary_blocks_media.dart';
import 'backup_constants.dart';
import 'diary_media_references.dart';
import 'diary_media_storage_service.dart';
import 'lan_sync/sync/sync_media_refs.dart';
import 'settings_service.dart';

/// 重绑一个本机路径字符串到 [newRoot] 下的对应托管位置；非托管路径保持不变。
///
/// 当目标文件在新根目录中确实存在，或者原路径确实落在 [oldRoot] 内时执行改写，
/// 避免把外部用户引用误改。
String? rebindManagedMediaPathString(
  String? raw, {
  required String newRoot,
  String? oldRoot,
  List<String> allowedDirectories = backupMediaDirectories,
}) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  final key = syncMediaKeyOfLocalPath(trimmed);
  if (key == null) return raw;
  final topDir = key.split('/').first;
  if (!allowedDirectories.contains(topDir)) return raw;

  final candidate = p.normalize(
    p.joinAll(<String>[newRoot, ...key.split('/')]),
  );
  if (File(candidate).existsSync()) return candidate;
  if (oldRoot != null && _isWithinRoot(trimmed, oldRoot)) {
    return candidate;
  }
  return raw;
}

bool _isWithinRoot(String rawPath, String rootPath) {
  var localPath = rawPath;
  if (rawPath.startsWith('file:')) {
    try {
      localPath = File.fromUri(Uri.parse(rawPath)).path;
    } catch (_) {
      return false;
    }
  }
  final normRoot = p.normalize(rootPath).replaceAll('\\', '/');
  final normPath = p.normalize(localPath).replaceAll('\\', '/');
  if (normPath.toLowerCase().startsWith('${normRoot.toLowerCase()}/')) {
    return true;
  }
  return p.isWithin(p.normalize(rootPath), p.normalize(localPath));
}

/// 在单个事务里把库内全部托管媒体的本机绝对路径重绑到 [newRoot]。
///
/// 不改动 `updatedAt` / `editedAt`：内容语义在同步规范里完全不变，避免迁移存储
/// 目录触发无意义的同步冲突或修改时间变化。返回实际更新的行数。
Future<int> rebindDatabaseManagedMediaRoot({
  required AppDatabase database,
  required String newRoot,
  String? oldRoot,
  SettingsService? settings,
}) async {
  final normalizedNewRoot = p.normalize(newRoot);
  final normalizedOldRoot = oldRoot == null ? null : p.normalize(oldRoot);

  String? rebind(String? raw, List<String> allowed) =>
      rebindManagedMediaPathString(
        raw,
        newRoot: normalizedNewRoot,
        oldRoot: normalizedOldRoot,
        allowedDirectories: allowed,
      );

  var updatedRows = 0;
  await database.transaction(() async {
    final diaries = await database.select(database.diaries).get();
    for (final diary in diaries) {
      var content = diary.content;
      var contentChanged = false;
      if (backupMediaDirectories.any(content.contains)) {
        final doc = decodeStoredDiaryBlocks(content);
        var blockTouched = false;
        await rewriteDiaryBlocksMediaPaths(doc, (kind, path) async {
          final allowed = switch (kind) {
            DiaryBlockMediaKind.image => const <String>[
              DiaryMediaStorageService.imagesDirectoryName,
            ],
            DiaryBlockMediaKind.audio => const <String>['diary_recordings'],
            DiaryBlockMediaKind.video ||
            DiaryBlockMediaKind.attachment => const <String>[
              DiaryMediaStorageService.videosDirectoryName,
              DiaryMediaStorageService.attachmentsDirectoryName,
            ],
          };
          final next = rebind(path, allowed) ?? path;
          if (next != path) blockTouched = true;
          return next;
        });
        if (blockTouched) {
          content = encodeDiaryBlocks(doc);
          contentChanged = content != diary.content;
        }
      }
      final nextCover = rebind(diary.cover, const <String>[
        'diary_covers',
        DiaryMediaStorageService.imagesDirectoryName,
      ]);
      final coverChanged = nextCover != diary.cover;
      if (!contentChanged && !coverChanged) continue;
      await (database.update(
        database.diaries,
      )..where((t) => t.id.equals(diary.id))).write(
        DiariesCompanion(
          content: contentChanged ? Value(content) : const Value.absent(),
          cover: coverChanged ? Value(nextCover) : const Value.absent(),
        ),
      );
      updatedRows++;
    }

    final notebooks = await database.select(database.notebooks).get();
    for (final notebook in notebooks) {
      final json = _decodeJsonMap(notebook.payload);
      final cover = json?['cover'];
      if (json == null || cover is! String) continue;
      final nextCover = rebind(cover, const <String>[
        'diary_covers',
        DiaryMediaStorageService.imagesDirectoryName,
      ]);
      if (nextCover == cover) continue;
      json['cover'] = nextCover;
      await (database.update(database.notebooks)
            ..where((t) => t.id.equals(notebook.id)))
          .write(NotebooksCompanion(payload: Value(jsonEncode(json))));
      updatedRows++;
    }

    final comments = await (database.select(
      database.diaryComments,
    )..where((t) => t.images.isNotNull())).get();
    for (final comment in comments) {
      final decoded = decodeDiaryCommentImages(comment.images);
      if (decoded.isEmpty) continue;
      var changed = false;
      final rebound = <String>[
        for (final image in decoded)
          () {
            final next =
                rebind(image, const <String>[
                  DiaryMediaStorageService.imagesDirectoryName,
                ]) ??
                image;
            if (next != image) changed = true;
            return next;
          }(),
      ];
      if (!changed) continue;
      await (database.update(
        database.diaryComments,
      )..where((t) => t.id.equals(comment.id))).write(
        DiaryCommentsCompanion(
          images: Value(encodeDiaryCommentImages(rebound)),
        ),
      );
      updatedRows++;
    }

    final aiMessages = await (database.select(
      database.aiMessages,
    )..where((t) => t.images.isNotNull())).get();
    for (final message in aiMessages) {
      final decoded = decodeAiMessageImages(message.images);
      if (decoded.isEmpty) continue;
      var changed = false;
      final rebound = <String>[
        for (final image in decoded)
          if (image == kAiMessageImageRemoved)
            image
          else
            () {
              final next =
                  rebind(image, const <String>[
                    DiaryMediaStorageService.imagesDirectoryName,
                  ]) ??
                  image;
              if (next != image) changed = true;
              return next;
            }(),
      ];
      if (!changed) continue;
      await (database.update(
        database.aiMessages,
      )..where((t) => t.id.equals(message.id))).write(
        AiMessagesCompanion(images: Value(encodeAiMessageImages(rebound))),
      );
      updatedRows++;
    }

    final drafts = await database.select(database.diaryDrafts).get();
    for (final draft in drafts) {
      final nextPayload = await _rebindDraftJson(
        draft.payload,
        newRoot: normalizedNewRoot,
        oldRoot: normalizedOldRoot,
      );
      if (nextPayload == null) continue;
      await (database.update(database.diaryDrafts)
            ..where((t) => t.id.equals(draft.id)))
          .write(DiaryDraftsCompanion(payload: Value(nextPayload)));
      updatedRows++;
    }
  });

  if (settings != null && settings.createDiaryDraftRaw != null) {
    final nextDraft = await _rebindDraftJson(
      settings.createDiaryDraftRaw!,
      newRoot: normalizedNewRoot,
      oldRoot: normalizedOldRoot,
    );
    if (nextDraft != null) {
      await settings.setCreateDiaryDraftRaw(nextDraft);
    }
  }

  return updatedRows;
}

Future<String?> _rebindDraftJson(
  String raw, {
  required String newRoot,
  String? oldRoot,
}) async {
  final json = _decodeJsonMap(raw);
  if (json == null) return null;
  var changed = false;
  final rawContent = json['contentDocJson'];
  if (rawContent is String &&
      backupMediaDirectories.any(rawContent.contains) &&
      DiaryMediaReferences(<String?>[rawContent]).keys.isNotEmpty) {
    final doc = decodeStoredDiaryBlocks(rawContent);
    var docTouched = false;
    await rewriteDiaryBlocksMediaPaths(doc, (kind, path) async {
      final allowed = switch (kind) {
        DiaryBlockMediaKind.image => const <String>[
          DiaryMediaStorageService.imagesDirectoryName,
        ],
        DiaryBlockMediaKind.audio => const <String>['diary_recordings'],
        DiaryBlockMediaKind.video ||
        DiaryBlockMediaKind.attachment => const <String>[
          DiaryMediaStorageService.videosDirectoryName,
          DiaryMediaStorageService.attachmentsDirectoryName,
        ],
      };
      final next =
          rebindManagedMediaPathString(
            path,
            newRoot: newRoot,
            oldRoot: oldRoot,
            allowedDirectories: allowed,
          ) ??
          path;
      if (next != path) docTouched = true;
      return next;
    });
    if (docTouched) {
      final encoded = encodeDiaryBlocks(doc);
      if (encoded != rawContent) {
        json['contentDocJson'] = encoded;
        changed = true;
      }
    }
  }
  final cover = json['cover'];
  if (cover is String) {
    final nextCover = rebindManagedMediaPathString(
      cover,
      newRoot: newRoot,
      oldRoot: oldRoot,
      allowedDirectories: const <String>[
        'diary_covers',
        DiaryMediaStorageService.imagesDirectoryName,
      ],
    );
    if (nextCover != cover) {
      json['cover'] = nextCover;
      changed = true;
    }
  }
  return changed ? jsonEncode(json) : null;
}

Map<String, Object?>? _decodeJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, Object?>.of(decoded.cast()) : null;
  } on FormatException {
    return null;
  }
}
