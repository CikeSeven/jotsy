import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/desktop_exit_guard.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('repeated close requests wait for the same save', () async {
    final saved = Completer<bool>();
    var calls = 0;
    final guard = DesktopExitGuard(
      onExit: () {
        calls++;
        return saved.future;
      },
    );
    addTearDown(guard.dispose);
    var finished = false;
    final first = binding.handleRequestAppExit().then((result) {
      finished = true;
      return result;
    });
    final second = binding.handleRequestAppExit();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(finished, isFalse);
    saved.complete(true);
    expect(await first, AppExitResponse.exit);
    expect(await second, AppExitResponse.exit);
  });

  test('a failed or throwing save cancels exit and can be retried', () async {
    var attempt = 0;
    final guard = DesktopExitGuard(
      onExit: () async {
        attempt++;
        if (attempt == 1) return false;
        if (attempt == 2) throw StateError('disk unavailable');
        return true;
      },
    );
    addTearDown(guard.dispose);
    expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
    expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
    expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
  });

  test('every active session must save before exit is allowed', () async {
    var firstSaved = false;
    var secondSaved = false;
    final first = DesktopExitGuard(
      onExit: () async {
        firstSaved = true;
        return false;
      },
    );
    final second = DesktopExitGuard(
      onExit: () async {
        secondSaved = true;
        return true;
      },
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
    expect(firstSaved && secondSaved, isTrue);
    first.dispose();
    expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
  });

  test('mobile sessions do not register desktop exit behavior', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var called = false;
    final guard = DesktopExitGuard(
      onExit: () async {
        called = true;
        return false;
      },
    );
    addTearDown(guard.dispose);
    expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
    expect(called, isFalse);
  });
}
