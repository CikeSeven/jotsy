import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/text_process_actions_service.dart';

class _FakeProcessTextService implements ProcessTextService {
  List<ProcessTextAction> actions = const <ProcessTextAction>[];
  bool fail = false;
  int queries = 0;
  final List<(String, String, bool)> processed = <(String, String, bool)>[];

  @override
  Future<List<ProcessTextAction>> queryTextActions() async {
    queries++;
    if (fail) throw PlatformException(code: 'boom');
    return actions;
  }

  @override
  Future<String?> processTextAction(
    String id,
    String text,
    bool readOnly,
  ) async {
    processed.add((id, text, readOnly));
    if (fail) throw PlatformException(code: 'boom');
    return readOnly ? null : '$text!';
  }
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('caches queried actions and notifies listeners on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final fake = _FakeProcessTextService()
      ..actions = const <ProcessTextAction>[
        ProcessTextAction('translate', 'Google 翻译'),
      ];
    final service = TextProcessActionsService(service: fake);
    var notified = 0;
    service.actions.addListener(() => notified++);
    expect(service.current, isEmpty);

    await service.refresh();
    expect(service.current.single.label, 'Google 翻译');
    expect(notified, 1);

    // 结果没变时不再通知。
    await service.refresh();
    expect(notified, 1);
  });

  test('keeps the previous actions when a refresh fails', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final fake = _FakeProcessTextService()
      ..actions = const <ProcessTextAction>[ProcessTextAction('keep', 'Keep')];
    final service = TextProcessActionsService(service: fake);
    await service.refresh();
    fake.fail = true;
    await service.refresh();
    expect(service.current.single.id, 'keep');
    expect(await service.process('keep', 'hi', readOnly: false), isNull);
  });

  test('shares one query between overlapping refreshes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final fake = _FakeProcessTextService();
    final service = TextProcessActionsService(service: fake);
    await Future.wait(<Future<void>>[service.refresh(), service.refresh()]);
    expect(fake.queries, 1);
  });

  test('passes text and read-only flag through process', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final fake = _FakeProcessTextService();
    final service = TextProcessActionsService(service: fake);
    expect(await service.process('t', 'hi', readOnly: false), 'hi!');
    expect(fake.processed.single, ('t', 'hi', false));
  });

  test('never queries on platforms without process text', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final fake = _FakeProcessTextService()
      ..actions = const <ProcessTextAction>[ProcessTextAction('a', 'A')];
    final service = TextProcessActionsService(service: fake);
    await service.refresh();
    expect(fake.queries, 0);
    expect(service.current, isEmpty);
    expect(await service.process('a', 'hi', readOnly: true), isNull);
  });

  test('instance can be replaced in tests', () {
    final fake = TextProcessActionsService(service: _FakeProcessTextService());
    TextProcessActionsService.debugOverride(fake);
    expect(TextProcessActionsService.instance, same(fake));
    TextProcessActionsService.debugOverride(null);
    expect(TextProcessActionsService.instance, isNot(same(fake)));
  });
}
