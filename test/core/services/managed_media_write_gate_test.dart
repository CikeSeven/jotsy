import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/managed_media_write_gate.dart';

void main() {
  const timeout = Duration(seconds: 2);

  test('exclusive waits for writers already in progress', () async {
    final events = <String>[];
    final release = Completer<void>();
    final writer = ManagedMediaWriteGate.write(() async {
      events.add('write start');
      await release.future;
      events.add('write end');
    });
    await Future<void>.delayed(Duration.zero);

    final cleaning = ManagedMediaWriteGate.exclusive(() async {
      events.add('exclusive');
    }, timeout: timeout);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['write start']);

    release.complete();
    await writer;
    await cleaning;
    expect(events, ['write start', 'write end', 'exclusive']);
    expect(ManagedMediaWriteGate.hasWriters, isFalse);
  });

  test('new writers wait until the exclusive action is done', () async {
    final events = <String>[];
    final release = Completer<void>();
    final cleaning = ManagedMediaWriteGate.exclusive(() async {
      events.add('exclusive start');
      await release.future;
      events.add('exclusive end');
    }, timeout: timeout);
    await Future<void>.delayed(Duration.zero);

    final writer = ManagedMediaWriteGate.write(() async {
      events.add('write');
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['exclusive start']);

    release.complete();
    await cleaning;
    await writer;
    expect(events, ['exclusive start', 'exclusive end', 'write']);
  });

  test('a nested write runs at once even while an exclusive waits', () async {
    final inner = Completer<void>();
    final outer = ManagedMediaWriteGate.write(() async {
      await inner.future;
      // 同步换键经 apply 嵌套进入：不能等排在后面的独占者，否则互相等待。
      return ManagedMediaWriteGate.write(() async => 'nested');
    });
    await Future<void>.delayed(Duration.zero);
    final cleaning = ManagedMediaWriteGate.exclusive(
      () async => 'cleaned',
      timeout: timeout,
    );
    await Future<void>.delayed(Duration.zero);

    inner.complete();
    expect(await outer, 'nested');
    expect(await cleaning, 'cleaned');
  });

  test('exclusive gives up after the timeout and lets writers go on', () async {
    final release = Completer<void>();
    final writer = ManagedMediaWriteGate.write(() => release.future);
    await Future<void>.delayed(Duration.zero);

    var ran = false;
    await expectLater(
      ManagedMediaWriteGate.exclusive(
        () async => ran = true,
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<ManagedMediaWritesPending>()),
    );
    expect(ran, isFalse);

    // 放弃后不再挡新的写入者。
    expect(await ManagedMediaWriteGate.write(() async => 1), 1);
    release.complete();
    await writer;
    expect(ManagedMediaWriteGate.hasWriters, isFalse);
  });
}
