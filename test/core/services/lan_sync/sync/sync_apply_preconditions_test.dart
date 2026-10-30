import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_apply.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_apply_test_support.dart';
import 'sync_test_devices.dart';

/// 写入层的前置条件、原地改名、跳过、历史时间继承与撤销窗口（规格 §6、
/// §4.6 写入层须知第 1、6 条）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice device;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    device = await SyncTestDevice.create('apply_pre');
    await seedEveryEntity(device);
  });

  tearDown(() async {
    EditingSessionRegistry.instance.debugReset();
    await device.dispose();
  });

  const rich = SyncKey(SyncEntity.diary, 'diary-rich');
  const delta = SyncKey(SyncEntity.diary, 'diary-delta');

  Future<String> titleOf(String id) async => (await (device.db.select(
    device.db.diaries,
  )..where((t) => t.diaryId.equals(id))).getSingle()).title;

  test('expected 已不符的写入被跳过，其余照常写入', () async {
    final rig = SyncApplyRig(device);
    final records = await rig.records();
    final current = await rig.manifest();
    final plan = sidePlan([
      SyncWrite(
        key: rich,
        expected: {...current[rich]!, SyncFacet.pin: 'stale'},
        record: withFacet(records[rich]!, SyncFacet.content, {'title': 'X'}),
      ),
      SyncWrite(
        key: delta,
        expected: current[delta],
        record: withFacet(records[delta]!, SyncFacet.content, {'title': 'Y'}),
      ),
      // 规划时不存在、现在却已存在：同样跳过。
      SyncWrite(
        key: const SyncKey(SyncEntity.dayMood, '2026-01-01'),
        expected: null,
        record: records[const SyncKey(SyncEntity.dayMood, '2026-01-01')],
      ),
    ]);
    final result = await rig.applier.apply(plan);

    expect(result.skipped, [
      const SyncApplySkip(rich, SyncSkipReason.precondition),
      const SyncApplySkip(
        SyncKey(SyncEntity.dayMood, '2026-01-01'),
        SyncSkipReason.precondition,
      ),
    ]);
    expect(await titleOf('diary-rich'), 'Rich');
    expect(await titleOf('diary-delta'), 'Y');
    expect(result.diaries, const SyncEntityCounts(updated: 1));
  });

  test('结构不对的记录与缺了依赖的成员关系各自跳过，不让整批回滚', () async {
    final rig = SyncApplyRig(device);
    final records = await rig.records();
    final broken = SyncRecord(rich, {SyncFacet.content: 'not an object'});
    const ghost = SyncKey(SyncEntity.membership, 'nb-parent|ghost');
    final current = await rig.manifest();
    final result = await rig.applier.apply(
      sidePlan([
        SyncWrite(key: rich, expected: current[rich], record: broken),
        SyncWrite(
          key: ghost,
          expected: null,
          record: SyncRecord(ghost, {
            SyncFacet.main: {'chapterId': null, 'addedAt': 1000},
          }),
        ),
        SyncWrite(
          key: delta,
          expected: current[delta],
          record: withFacet(records[delta]!, SyncFacet.pin, {'pinned': true}),
        ),
      ]),
    );

    expect(result.skipped, [
      const SyncApplySkip(rich, SyncSkipReason.invalidRecord),
      const SyncApplySkip(ghost, SyncSkipReason.missingDependency),
    ]);
    expect((await rig.records())[delta]!.facets[SyncFacet.pin], {
      'pinned': true,
    });
  });

  test('原地改名保持本地 id 与日记关联，颜色取改名记录；引用旧名的日记写入照常', () async {
    final rig = SyncApplyRig(device);
    final before = await device.db.select(device.db.tags).get();
    final travelId = before.singleWhere((tag) => tag.name == 'travel').id;
    final links = await device.db.select(device.db.diaryTags).get();
    final records = await rig.records();
    final current = await rig.manifest();
    final result = await rig.applier.apply(
      sidePlan(
        [
          // tags 已是新名，expected 是改名前的哈希（规格 §4.6 第 1 条）。
          SyncWrite(
            key: rich,
            expected: current[rich],
            record: withFacet(records[rich]!, SyncFacet.tags, {
              'names': ['trip', 'work'],
            }),
          ),
        ],
        renames: [
          SyncTagRenameOp(
            from: 'travel',
            to: 'trip',
            expected: current[const SyncKey(SyncEntity.tag, 'travel')]!,
            record: SyncRecord(const SyncKey(SyncEntity.tag, 'trip'), {
              SyncFacet.color: {'color': 0xFF000001},
            }),
          ),
          // 新名已存在：前置条件不符，跳过。
          SyncTagRenameOp(
            from: 'work',
            to: 'unused',
            expected: current[const SyncKey(SyncEntity.tag, 'work')]!,
            record: SyncRecord(const SyncKey(SyncEntity.tag, 'unused'), {
              SyncFacet.color: {'color': 1},
            }),
          ),
        ],
      ),
    );

    expect(result.skipped, [
      const SyncApplySkip(
        SyncKey(SyncEntity.tag, 'work'),
        SyncSkipReason.precondition,
      ),
    ]);
    final trip = (await device.db.select(device.db.tags).get()).singleWhere(
      (tag) => tag.name == 'trip',
    );
    expect(trip.id, travelId);
    expect(trip.color, 0xFF000001);
    expect(
      await device.db.select(device.db.diaryTags).get(),
      unorderedEquals(links),
    );
    expect(result.counts[SyncEntity.tag], const SyncEntityCounts(updated: 1));
    final manifest = result.manifest!;
    expect(
      manifest.containsKey(const SyncKey(SyncEntity.tag, 'travel')),
      false,
    );
    expect(manifest.containsKey(const SyncKey(SyncEntity.tag, 'work')), true);
  });

  test('写入后折叠传入 historySeenAt：只对写成了的键继承来源的确立时间', () async {
    final rig = SyncApplyRig(device);
    await rig.state.refreshCheckpoint();
    final records = await rig.records();
    final current = await rig.manifest();
    final result = await rig.applier.apply(
      sidePlan(
        [
          SyncWrite(
            key: rich,
            expected: current[rich],
            record: withFacet(records[rich]!, SyncFacet.pin, {'pinned': false}),
          ),
          SyncWrite(
            key: delta,
            expected: {...current[delta]!, SyncFacet.pin: 'stale'},
            record: withFacet(records[delta]!, SyncFacet.pin, {'pinned': true}),
          ),
        ],
        historySeenAt: {
          rich: {SyncFacet.pin: 12345},
          delta: {SyncFacet.pin: 678},
        },
      ),
    );
    expect(result.skipped, hasLength(1));

    final snapshot = await rig.state.snapshot();
    final history = snapshot.history(rich, SyncFacet.pin);
    expect(history.first.hash, current[rich]![SyncFacet.pin]);
    expect(history.first.seenAt, 12345);
    expect(snapshot.history(delta, SyncFacet.pin), isEmpty);
    expect(snapshot.manifest[rich], result.manifest![rich]);
  });

  test('撤销窗口未关：等它关闭后再写', () async {
    final rig = SyncApplyRig(device);
    final records = await rig.records();
    final lease = EditingSessionRegistry.instance.beginUndoWindow();
    final pending = rig.applier.apply(
      await rig.planFor([
        withFacet(records[rich]!, SyncFacet.content, {'title': 'after undo'}),
      ]),
    );
    var done = false;
    unawaited(pending.then((_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(done, isFalse);
    expect(await titleOf('diary-rich'), 'Rich');

    lease.end();
    final result = await pending;
    expect(result.isDeferred, isFalse);
    expect(await titleOf('diary-rich'), 'after undo');
  });

  test('撤销窗口超时：推迟，什么都不写', () async {
    final rig = SyncApplyRig(
      device,
      undoWait: const Duration(milliseconds: 30),
    );
    final records = await rig.records();
    final lease = EditingSessionRegistry.instance.beginUndoWindow();
    addTearDown(lease.end);
    final result = await rig.applier.apply(
      await rig.planFor([
        withFacet(records[rich]!, SyncFacet.content, {'title': 'never'}),
      ]),
    );

    expect(result.isDeferred, isTrue);
    expect(result.manifest, isNull);
    expect(await titleOf('diary-rich'), 'Rich');
  });
}
