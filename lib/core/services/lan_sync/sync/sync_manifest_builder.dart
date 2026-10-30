import '../../../database/sync_rows.dart';
import 'sync_canonical_diary.dart';
import 'sync_canonical_misc.dart';
import 'sync_canonical_notebook.dart';
import 'sync_canonical_settings.dart';
import 'sync_hash_cache.dart';
import 'sync_model.dart';
import 'sync_state_model.dart';

/// 由原始行算出清单（带哈希缓存）或完整规范记录。
///
/// - 输入：一致快照 [SyncRawSnapshot]、可选的设置原值（[syncCaptureSettings]
///   的结果：有就生成 prefs 记录，`includeSettings` 时再生成 settings 记录；
///   null 表示两者都不含——没有设置服务的测试）、上一份哈希缓存；
/// - 输出：[SyncObserveResult]（观测 + 新缓存）或记录列表；
/// - 纯同步计算、无 I/O，参数与结果都是可以跨 isolate 传递的普通对象，由
///   `SyncLocalState` 放进 `Isolate.run` 执行。
///
/// 每条记录拆成“缓存部分”（按行指纹缓存哈希：日记的行分面、日记本、模板、
/// 纪念日，这些要解码正文或 JSON 列）与“现算部分”（每次都算：日记的 tags、
/// 标签、成员关系、顺序列表、留言、心情、设置，都很便宜）。需要记录值的分面
/// （diary.tags、orderList.items、prefs.tagOrderNames）一律在现算部分，值随手
/// 可得，不必进缓存。

class SyncObserveResult {
  const SyncObserveResult({
    required this.observation,
    required this.cache,
    required this.cacheHits,
    required this.cacheMisses,
  });

  final SyncObservation observation;

  /// 只含本次存在的记录。
  final Map<String, SyncHashCacheEntry> cache;
  final int cacheHits;
  final int cacheMisses;
}

/// 算出本次观测。没生成的记录（[settings] 为 null 时的 prefs 与 settings、
/// 不 `includeSettings` 时的 settings）的实体也不算“观测过”（折叠时不会把
/// 它当成被删除）。
SyncObserveResult syncObserveRows(
  SyncRawSnapshot rows, {
  SyncSettingsCapture? settings,
  Map<String, SyncHashCacheEntry> cache = const <String, SyncHashCacheEntry>{},
}) {
  final index = _SyncRowIndex(rows);
  final entries = <SyncKey, Map<String, String>>{};
  final tracked = <SyncKey, Map<String, Object?>>{};
  final nextCache = <String, SyncHashCacheEntry>{};
  var hits = 0;
  var misses = 0;

  for (final source in index.sources(settings)) {
    final hashes = <String, String>{};
    final fingerprint = source.fingerprint;
    if (fingerprint != null) {
      final cacheKey = source.key.toString();
      final fp = fingerprint();
      final hit = cache[cacheKey];
      if (hit != null && hit.fingerprint == fp) {
        hits++;
        hashes.addAll(hit.hashes);
        nextCache[cacheKey] = hit;
      } else {
        misses++;
        final computed = <String, String>{
          for (final facet in source.cached!().entries)
            facet.key: syncHashValue(facet.value),
        };
        hashes.addAll(computed);
        nextCache[cacheKey] = SyncHashCacheEntry(fp, computed);
      }
    }
    final fresh = source.fresh();
    for (final facet in fresh.entries) {
      hashes[facet.key] = syncHashValue(facet.value);
      if (SyncFacet.tracksValue(source.key.entity, facet.key)) {
        (tracked[source.key] ??= <String, Object?>{})[facet.key] = facet.value;
      }
    }
    entries[source.key] = hashes;
  }

  return SyncObserveResult(
    observation: SyncObservation(
      manifest: SyncManifest(entries),
      trackedValues: tracked,
      tagLocalIds: index.tagLocalIds,
      observed: <SyncEntity>{
        for (final entity in SyncEntity.values)
          if (switch (entity) {
            SyncEntity.settings => settings?.includeSettings ?? false,
            SyncEntity.prefs => settings != null,
            _ => true,
          })
            entity,
      },
    ),
    cache: nextCache,
    cacheHits: hits,
    cacheMisses: misses,
  );
}

/// 完整规范记录。[only] 非 null 时只构建这些键（其余记录连规范化都不做）；
/// 查不到的键直接不出现在结果里。[settings] 的口径同 [syncObserveRows]。
List<SyncRecord> syncBuildRecords(
  SyncRawSnapshot rows, {
  SyncSettingsCapture? settings,
  Set<SyncKey>? only,
}) {
  final index = _SyncRowIndex(rows);
  return <SyncRecord>[
    for (final source in index.sources(settings))
      if (only == null || only.contains(source.key))
        SyncRecord(source.key, <String, Object?>{
          ...?source.cached?.call(),
          ...source.fresh(),
        }),
  ];
}

/// 一条记录的来源：键、（可选的）原始列指纹与缓存部分、现算部分。
class _SyncSource {
  const _SyncSource(
    this.key, {
    this.fingerprint,
    this.cached,
    required this.fresh,
  });

  final SyncKey key;
  final String Function()? fingerprint;
  final Map<String, Object?> Function()? cached;
  final Map<String, Object?> Function() fresh;
}

Map<String, Object?> _none() => const <String, Object?>{};

/// 原始行之间的关联索引（本地 id → 行、日记 → 标签名、日记本 → 成员）。
class _SyncRowIndex {
  _SyncRowIndex(this.rows) {
    for (final tag in rows.tags) {
      _tagsById[tag.localId] = tag;
    }
    for (final diary in rows.diaries) {
      _diaryIdByLocal[diary.localId] = diary.diaryId;
    }
    for (final link in rows.diaryTags) {
      final tag = _tagsById[link.tagLocalId];
      if (tag == null) continue;
      (_tagNamesByDiary[link.diaryLocalId] ??= <String>[]).add(tag.name);
    }
    for (final notebook in rows.notebooks) {
      _notebooksByLocal[notebook.localId] = notebook;
    }
    for (final entry in rows.memberships) {
      final notebook = _notebooksByLocal[entry.notebookLocalId];
      // 只有手动日记本有成员；悬空的关联（日记或日记本已不在）不算。
      if (notebook == null || !_isManual(notebook)) continue;
      if (!_diaryIdByLocal.containsKey(entry.diaryLocalId)) continue;
      (_entriesByNotebook[entry.notebookLocalId] ??= <SyncRawMembership>[]).add(
        entry,
      );
    }
  }

  final SyncRawSnapshot rows;
  final Map<int, SyncRawTag> _tagsById = <int, SyncRawTag>{};
  final Map<int, String> _diaryIdByLocal = <int, String>{};
  final Map<int, List<String>> _tagNamesByDiary = <int, List<String>>{};
  final Map<int, SyncRawNotebook> _notebooksByLocal = <int, SyncRawNotebook>{};
  final Map<int, List<SyncRawMembership>> _entriesByNotebook =
      <int, List<SyncRawMembership>>{};

  /// 与 `acceptsManualEntries` 同一口径：只认列里的原始值。
  static bool _isManual(SyncRawNotebook row) => row.kind == 'manual';

  Map<String, int> get tagLocalIds => <String, int>{
    for (final tag in rows.tags) syncTagRecordName(tag): tag.localId,
  };

  Iterable<_SyncSource> sources(SyncSettingsCapture? settings) sync* {
    for (final diary in rows.diaries) {
      yield _SyncSource(
        SyncKey(SyncEntity.diary, diary.diaryId),
        fingerprint: () => syncDiaryFingerprint(diary),
        cached: () => syncDiaryRowFacets(diary),
        fresh: () => <String, Object?>{
          SyncFacet.tags: syncDiaryTagsFacet(
            _tagNamesByDiary[diary.localId] ?? const <String>[],
          ),
        },
      );
    }
    for (final tag in rows.tags) {
      final record = syncTagRecord(tag);
      yield _SyncSource(record.key, fresh: () => record.facets);
    }
    for (final notebook in rows.notebooks) {
      yield _SyncSource(
        SyncKey(SyncEntity.notebook, notebook.notebookId),
        fingerprint: () => syncNotebookFingerprint(notebook),
        cached: () => syncNotebookRecord(notebook).facets,
        fresh: _none,
      );
    }
    for (final entry in _entriesByNotebook.entries) {
      final notebookId = _notebooksByLocal[entry.key]!.notebookId;
      for (final row in entry.value) {
        final record = syncMembershipRecord(
          notebookId: notebookId,
          diaryId: _diaryIdByLocal[row.diaryLocalId]!,
          row: row,
        );
        yield _SyncSource(record.key, fresh: () => record.facets);
      }
    }
    yield _orderList(
      SyncOrderListId.shelf,
      () => syncShelfOrder(rows.notebooks),
    );
    yield _orderList(
      SyncOrderListId.templates,
      () => syncTemplateOrder(rows.templates),
    );
    for (final notebook in rows.notebooks) {
      if (!_isManual(notebook)) continue;
      yield _orderList(
        SyncOrderListId.book(notebook.notebookId),
        () => syncBookOrder(
          _entriesByNotebook[notebook.localId] ?? const <SyncRawMembership>[],
          (localId) => _diaryIdByLocal[localId],
        ),
      );
    }
    for (final comment in rows.comments) {
      final record = syncCommentRecord(comment);
      yield _SyncSource(record.key, fresh: () => record.facets);
    }
    for (final template in rows.templates) {
      yield _SyncSource(
        SyncKey(SyncEntity.template, template.templateId),
        fingerprint: () => syncTemplateFingerprint(template),
        cached: () => syncTemplateRecord(template).facets,
        fresh: _none,
      );
    }
    for (final anniversary in rows.anniversaries) {
      yield _SyncSource(
        SyncKey(SyncEntity.anniversary, anniversary.anniversaryId),
        fingerprint: () => syncAnniversaryFingerprint(anniversary),
        cached: () => syncAnniversaryRecord(anniversary).facets,
        fresh: _none,
      );
    }
    for (final mood in rows.dayMoods) {
      final record = syncDayMoodRecord(mood);
      yield _SyncSource(record.key, fresh: () => record.facets);
    }
    if (settings != null) {
      final tagNames = <int, String>{
        for (final tag in rows.tags) tag.localId: syncTagRecordName(tag),
      };
      yield _SyncSource(
        const SyncKey(SyncEntity.prefs, kSyncPrefsId),
        fresh: () => syncPrefsRecord(settings.values, tagNames).facets,
      );
      if (settings.includeSettings) {
        yield _SyncSource(
          const SyncKey(SyncEntity.settings, kSyncSettingsId),
          fresh: () => syncSettingsRecord(settings.values).facets,
        );
      }
    }
  }

  _SyncSource _orderList(String listId, List<String> Function() ids) =>
      _SyncSource(
        SyncKey(SyncEntity.orderList, listId),
        fresh: () => syncOrderListRecord(listId, ids()).facets,
      );
}
