import 'package:node_diary/core/services/app_passcode/app_passcode_hasher.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';

/// 测试用的摘要计算：不进 isolate、迭代次数很低。
const AppPasscodeHasher testPasscodeHasher = AppPasscodeHasher(
  iterations: 16,
  useIsolate: false,
);

/// 可拨动的时钟（输错限流与倒数共用）。
class TestClock {
  DateTime now = DateTime(2026, 11, 6, 9);
  DateTime call() => now;
}

/// 预置存储里的数字密码（与界面里设置的效果相同）。
Future<Map<String, Object>> presetPin(
  String digits, {
  bool biometric = false,
  bool appLock = false,
}) async {
  final secret = await testPasscodeHasher.create(
    AppPasscodeRules.material(AppPasscodeKind.pin, digits),
  );
  return <String, Object>{
    AppPasscodeStore.key: AppPasscodeConfig(
      secret: secret,
      pinLength: digits.length,
      biometric: biometric,
    ).encode()!,
    if (appLock) 'app.settings.app_lock_enabled': true,
  };
}

/// 预置存储里的图案密码。
Future<Map<String, Object>> presetPattern(
  List<int> nodes, {
  bool biometric = false,
  bool appLock = false,
}) async {
  final secret = await testPasscodeHasher.create(
    AppPasscodeRules.material(
      AppPasscodeKind.pattern,
      AppPasscodeRules.encodePattern(nodes),
    ),
  );
  return <String, Object>{
    AppPasscodeStore.key: AppPasscodeConfig(
      secret: secret,
      kind: AppPasscodeKind.pattern,
      biometric: biometric,
    ).encode()!,
    if (appLock) 'app.settings.app_lock_enabled': true,
  };
}
