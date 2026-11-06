import '../../../core/services/app_passcode/app_passcode_config.dart';

/// 设置应用密码时可选的形式：6 位数字、4 位数字、图案（设置页的单选按钮组）。
enum PasscodeForm {
  pin6(AppPasscodeKind.pin, 6),
  pin4(AppPasscodeKind.pin, 4),
  pattern(AppPasscodeKind.pattern, 0);

  const PasscodeForm(this.kind, this.pinLength);

  final AppPasscodeKind kind;

  /// 数字位数；图案为 0。
  final int pinLength;

  /// 已设密码的形式（修改密码时默认选中原来的形式）。
  static PasscodeForm of(AppPasscodeConfig config) {
    if (config.kind == AppPasscodeKind.pattern) return PasscodeForm.pattern;
    return config.pinLength == 4 ? PasscodeForm.pin4 : PasscodeForm.pin6;
  }
}
