import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_lock/models/app_lock_options.dart';

void main() {
  group('AppLockOptions.decode', () {
    test('missing, broken or non-object values fall back to the defaults', () {
      for (final raw in <String?>[null, '', '{', '[]', '"x"']) {
        expect(AppLockOptions.decode(raw), AppLockOptions.defaults);
      }
      // 默认与改版前一致：只在打开应用时上锁、自动弹出验证、不防截屏。
      expect(AppLockOptions.defaults.afterLeaving, AppLockAfterLeaving.never);
      expect(AppLockOptions.defaults.autoPrompt, isTrue);
      expect(AppLockOptions.defaults.secureScreen, isFalse);
    });

    test('round-trips every field', () {
      const options = AppLockOptions(
        afterLeaving: AppLockAfterLeaving.minutes5,
        onScreenOff: true,
        whenIdle: AppLockWhenIdle.minutes15,
        autoPrompt: false,
        secureScreen: true,
      );
      expect(AppLockOptions.decode(options.encode()), options);
    });

    test('a bad field only resets that field', () {
      final options = AppLockOptions.decode(
        '{"afterLeaving":"weekly","onScreenOff":"yes","whenIdle":"minutes1",'
        '"autoPrompt":false,"secureScreen":1,"future":true}',
      );
      expect(options.afterLeaving, AppLockAfterLeaving.never);
      expect(options.onScreenOff, isFalse);
      expect(options.whenIdle, AppLockWhenIdle.minutes1);
      expect(options.autoPrompt, isFalse);
      expect(options.secureScreen, isFalse);
    });
  });

  group('AppLockOptions.loosenedBy', () {
    const base = AppLockOptions(
      afterLeaving: AppLockAfterLeaving.minutes5,
      onScreenOff: true,
      whenIdle: AppLockWhenIdle.minutes5,
      secureScreen: true,
    );

    test('locking later or turning protections off loosens', () {
      expect(
        base.loosenedBy(
          base.copyWith(afterLeaving: AppLockAfterLeaving.minutes15),
        ),
        isTrue,
      );
      expect(
        base.loosenedBy(base.copyWith(afterLeaving: AppLockAfterLeaving.never)),
        isTrue,
      );
      expect(base.loosenedBy(base.copyWith(onScreenOff: false)), isTrue);
      expect(
        base.loosenedBy(base.copyWith(whenIdle: AppLockWhenIdle.off)),
        isTrue,
      );
      expect(base.loosenedBy(base.copyWith(secureScreen: false)), isTrue);
    });

    test('locking sooner and the auto prompt switch do not', () {
      expect(
        base.loosenedBy(
          base.copyWith(afterLeaving: AppLockAfterLeaving.immediately),
        ),
        isFalse,
      );
      expect(
        base.loosenedBy(base.copyWith(whenIdle: AppLockWhenIdle.minutes1)),
        isFalse,
      );
      expect(base.loosenedBy(base.copyWith(autoPrompt: false)), isFalse);
      expect(base.loosenedBy(base), isFalse);
    });
  });
}
