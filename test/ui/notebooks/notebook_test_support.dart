import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';

/// 日记本界面测试的小工具：写库都经 `tester.runAsync`（drift 在假时钟下
/// 不会推进），读库同理。
extension NotebookHarnessX on DiaryDraftsHarness {
  Future<String> notebook(
    String name, {
    NotebookKind kind = NotebookKind.manual,
    NotebookVisibility visibility = NotebookVisibility.normal,
    NotebookPayload payload = NotebookPayload.defaults,
    bool pinned = false,
    bool closed = false,
    String? parentId,
  }) async {
    final id = (await tester.runAsync(
      () => database.createNotebook(
        name: name,
        kind: kind,
        visibility: visibility,
        payload: payload,
        parentId: parentId,
      ),
    ))!;
    if (pinned || closed) {
      await tester.runAsync(
        () => database.updateNotebook(id, isPinned: pinned, isClosed: closed),
      );
    }
    return id;
  }

  Future<String> diary(String title, {List<String>? notebookIds}) async {
    return (await tester.runAsync(
      () => database.createDiary(
        title: title,
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
        notebookIds: notebookIds,
      ),
    ))!;
  }

  Future<List<NotebookRow>> shelf() async =>
      (await tester.runAsync(database.getNotebooks))!;

  Future<NotebookRow?> notebookRow(String id) =>
      tester.runAsync<NotebookRow?>(() => database.getNotebook(id));

  /// 等 drift 写入与数据流推送，再把动画跑完。
  Future<void> settleAll() async {
    await settle();
    await tester.pumpAndSettle();
    await settle();
    await tester.pumpAndSettle();
  }
}

/// 不需要数据库的组件：套上中文本地化与测试主题。
Widget notebookTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(brightness),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// 设备验证的假实现：记录每次验证的说明文字，按预设结果返回。
class FakeDeviceAuth extends DeviceAuthService {
  FakeDeviceAuth({this.supported = true, this.results = const <bool>[]});

  bool supported;
  List<bool> results;
  final List<String> reasons = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    reasons.add(reason);
    if (results.isEmpty) return false;
    final next = results.first;
    results = results.sublist(1);
    return next;
  }
}
