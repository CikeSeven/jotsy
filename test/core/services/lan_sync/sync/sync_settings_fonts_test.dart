import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_settings_fonts.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// settings 记录里的导入字体（#288）：两台设备导入同一个字体文件时本机 id
/// 不同，同步按文件内容的引用对上，不再把对方改回内置字体。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hashWenKai = 'a' * 64;
  final hashOther = 'b' * 64;
  final refWenKai = '$kSyncFontRefPrefix$hashWenKai';

  Future<SettingsService> freshSettings() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SettingsService.create();
  }

  Future<void> useFont(SettingsService settings, String fontId) async {
    await settings.setDiaryTypography(
      const DiaryTypography(fontSize: 18).copyWith(fontId: fontId),
    );
    await settings.setDiaryCodeBlockStyleRaw(
      jsonEncode(const DiaryCodeBlockStyle().copyWith(fontId: fontId).toJson()),
    );
  }

  SyncRecord recordOf(SettingsService settings, Map<String, String> refs) =>
      syncSettingsRecord(
        syncCaptureSettings(settings, includeSettings: true).values,
        fontRefs: refs,
      );

  Object? valueOf(SyncRecord record, String key) =>
      (record.facets[key]! as Map)['value'];

  String? codeBlockFontId(Object? raw) =>
      (jsonDecode(raw! as String) as Map)['fontId'] as String?;

  test('两台设备导入同一个字体：对方的选择写进本机后换回本机那份的 id，'
      '写入后的规范值与对方逐字节相同', () async {
    // 设备 A：字体 id 是 A 自己导入时生成的。
    final settingsA = await freshSettings();
    await useFont(settingsA, 'fA');
    final recordA = recordOf(
      settingsA,
      syncFontRefsOf(<String, String>{'fA': hashWenKai}),
    );
    expect((valueOf(recordA, 'diaryTypography')! as Map)['fontId'], refWenKai);
    expect(
      codeBlockFontId(valueOf(recordA, 'diaryCodeBlockStyleRaw')),
      refWenKai,
    );
    expect(syncCanonicalJson(recordA.facets), isNot(contains('"fA"')));

    // 设备 B：导入的是同一个文件（指纹相同、id 不同），另有一款别的字体；
    // 本机此刻还停在修复前同步过来的、本机没有的 A 的 id 上。
    final settingsB = await freshSettings();
    await useFont(settingsB, 'fA');
    final refsB = syncFontRefsOf(<String, String>{
      'fB': hashWenKai,
      'fOther': hashOther,
    });
    final node = syncSettingsRestoreNode(
      recordA,
      dataRoot: '/data',
      localAppFeaturesRaw: settingsB.appFeaturesRaw,
      fontIdsByRef: syncFontIdsByRef(refsB),
    );
    await BackupSettings.restore(settingsB, node, clearLegacyDraft: false);

    expect(settingsB.diaryTypography.fontId, 'fB');
    expect(settingsB.diaryTypography.fontSize, 18);
    expect(codeBlockFontId(settingsB.diaryCodeBlockStyleRaw), 'fB');
    // 再取值时与 A 的记录逐字节相同：下次同步不会再判成差异、来回改。
    expect(
      syncCanonicalJson(recordOf(settingsB, refsB).facets),
      syncCanonicalJson(recordA.facets),
    );
  });

  test('本机没有这款字体时原样存下引用，再取值仍与对方相同', () async {
    final settingsA = await freshSettings();
    await useFont(settingsA, 'fA');
    final recordA = recordOf(
      settingsA,
      syncFontRefsOf(<String, String>{'fA': hashWenKai}),
    );

    final settingsB = await freshSettings();
    final refsB = syncFontRefsOf(<String, String>{'fOther': hashOther});
    final node = syncSettingsRestoreNode(
      recordA,
      dataRoot: '/data',
      localAppFeaturesRaw: settingsB.appFeaturesRaw,
      fontIdsByRef: syncFontIdsByRef(refsB),
    );
    await BackupSettings.restore(settingsB, node, clearLegacyDraft: false);

    expect(settingsB.diaryTypography.fontId, refWenKai);
    expect(settingsB.diaryTypography.usesImportedFont, isTrue);
    expect(codeBlockFontId(settingsB.diaryCodeBlockStyleRaw), refWenKai);
    expect(
      syncCanonicalJson(recordOf(settingsB, refsB).facets),
      syncCanonicalJson(recordA.facets),
    );
  });

  test('内置 / 系统 / 等宽字体与表里没有的 id 原样同步，原文不重新编码', () {
    final refs = syncFontRefsOf(<String, String>{'fA': hashWenKai});
    for (final id in <String>['bundled', 'system', 'fGone']) {
      final typography = const DiaryTypography().copyWith(fontId: id).toJson();
      expect(
        syncFontIdsToRefs('diaryTypography', typography, refs),
        same(typography),
      );
    }
    // 不是规范 JSON 的原文（多余空格）在没换 id 时逐字节保留。
    const mono = '{ "fontId": "mono", "fontScale": 1.0 }';
    const broken = 'not json {';
    expect(syncFontIdsToRefs('diaryCodeBlockStyleRaw', mono, refs), mono);
    expect(syncFontIdsToRefs('diaryCodeBlockStyleRaw', broken, refs), broken);
    expect(syncFontIdsToRefs('diaryCodeBlockStyleRaw', null, refs), isNull);
    // 别的设置键里碰巧叫 fontId 的字段不动。
    final other = <String, Object?>{'fontId': 'fA'};
    expect(syncFontIdsToRefs('diaryCardStyleRaw', other, refs), same(other));
    // 没有引用表（旧版本的对方、读不了字体目录）时一律原样。
    expect(
      syncFontRefsToIds('diaryTypography', <String, Object?>{
        'fontId': refWenKai,
      }, const <String, String>{}),
      <String, Object?>{'fontId': refWenKai},
    );
  });

  test('同一个文件导入了两份时固定换回 id 较小的一份', () {
    final byRef = syncFontIdsByRef(
      syncFontRefsOf(<String, String>{
        'fz': hashWenKai,
        'fa': hashWenKai,
        'fm': hashOther,
      }),
    );
    expect(byRef, <String, String>{
      refWenKai: 'fa',
      '$kSyncFontRefPrefix$hashOther': 'fm',
    });
  });
}
