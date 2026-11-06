import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_passcode/app_passcode_config.dart';
import 'passcode_dots.dart';
import 'passcode_feedback.dart';
import 'passcode_keypad.dart';
import 'pattern_pad.dart';

/// 密码输入区（解锁视图与设置页共用），按形式切换两种布局：
///
/// - 数字：圆点（输错时抖动）→ 提示行 → 数字键盘（左下为可选的指纹键）。
///   桌面可直接用实体键盘：数字键、小键盘数字、Backspace；Esc 不处理，留给
///   外层（验证页返回）；
/// - 图案：提示行 → 图案板（输错时抖动）→ 可选的“使用指纹或面容”。
///
/// 尺寸：键与图案板按“可见高度 − [reservedHeight]”挑选，高度放不下时取最小
/// 尺寸（56dp 键 / 220dp 图案板）、由外层滚动；可用宽度始终是上限。
/// [viewportHeight] 为无穷大时取默认尺寸。
///
/// 纯展示：状态都由调用方的控制器给出，本组件不持有输入内容（图案板自己
/// 保存正在画的连线）。
class PasscodeInput extends StatelessWidget {
  const PasscodeInput({
    super.key,
    required this.kind,
    required this.pinLength,
    required this.filled,
    required this.rejected,
    required this.enabled,
    required this.shakeCount,
    required this.patternClears,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onPatternStarted,
    required this.onPatternCompleted,
    this.status,
    this.statusIsError = true,
    this.onBiometric,
    this.dotsKey = 0,
    this.viewportHeight = double.infinity,
    this.reservedHeight = 0,
  });

  final AppPasscodeKind kind;
  final int pinLength;
  final int filled;

  /// 刚被拒：圆点全红 / 连线变红。
  final bool rejected;
  final bool enabled;
  final int shakeCount;
  final int patternClears;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onPatternStarted;
  final ValueChanged<List<int>> onPatternCompleted;
  final String? status;
  final bool statusIsError;

  /// 非 null 时提供指纹 / 面容快捷解锁。
  final VoidCallback? onBiometric;

  /// 变化时（设置页换步）圆点行交叉淡入：输满的一行淡出，新的空行淡入。
  final Object dotsKey;

  final double viewportHeight;
  final double reservedHeight;

  static final Map<LogicalKeyboardKey, int> _digitKeys =
      <LogicalKeyboardKey, int>{
        LogicalKeyboardKey.digit0: 0,
        LogicalKeyboardKey.digit1: 1,
        LogicalKeyboardKey.digit2: 2,
        LogicalKeyboardKey.digit3: 3,
        LogicalKeyboardKey.digit4: 4,
        LogicalKeyboardKey.digit5: 5,
        LogicalKeyboardKey.digit6: 6,
        LogicalKeyboardKey.digit7: 7,
        LogicalKeyboardKey.digit8: 8,
        LogicalKeyboardKey.digit9: 9,
        LogicalKeyboardKey.numpad0: 0,
        LogicalKeyboardKey.numpad1: 1,
        LogicalKeyboardKey.numpad2: 2,
        LogicalKeyboardKey.numpad3: 3,
        LogicalKeyboardKey.numpad4: 4,
        LogicalKeyboardKey.numpad5: 5,
        LogicalKeyboardKey.numpad6: 6,
        LogicalKeyboardKey.numpad7: 7,
        LogicalKeyboardKey.numpad8: 8,
        LogicalKeyboardKey.numpad9: 9,
      };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final digit = _digitKeys[event.logicalKey];
    if (digit != null) {
      onDigit(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      onBackspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final room = viewportHeight - reservedHeight;
        return kind == AppPasscodeKind.pin
            ? _buildPin(context, width, room)
            : _buildPattern(context, width, room);
      },
    );
  }

  Widget _buildPin(BuildContext context, double width, double room) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // 键盘宽 3 键 + 2 间距 = 3.74 键宽，高 4 键 + 3 间距 = 4.63 键宽；
    // 圆点 + 提示行 + 间距约 65。
    // 高度不够时最小缩到 56 再交给外层滚动；宽度始终优先（极窄的窗口里
    // 宁可键再小一点，也不横向溢出）。
    final byHeight = ((room - 65) / 4.63)
        .clamp(PasscodeKeypad.minKeySize, PasscodeKeypad.defaultKeySize)
        .toDouble();
    final keySize = math.min(width / 3.74, byHeight);
    final biometric = onBiometric;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PasscodeShake(
            trigger: shakeCount,
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              child: PasscodeDots(
                key: ValueKey<Object>(dotsKey),
                length: pinLength,
                filled: filled,
                error: rejected,
              ),
            ),
          ),
          const SizedBox(height: 8),
          PasscodeStatusLine(text: status, error: statusIsError),
          const SizedBox(height: 12),
          PasscodeKeypad(
            keySize: keySize,
            enabled: enabled,
            showBackspace: filled > 0 && !rejected,
            onDigit: onDigit,
            onBackspace: onBackspace,
            onClear: onClear,
            leading: biometric == null
                ? null
                : PasscodeIconKey(
                    icon: FontAwesomeIcons.fingerprint,
                    size: keySize,
                    color: scheme.primary,
                    semanticLabel: l10n.passcodeUseBiometric,
                    onTap: biometric,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPattern(BuildContext context, double width, double room) {
    final l10n = context.l10n;
    final biometric = onBiometric;
    // 提示行 32 + 指纹按钮行约 48。
    final byHeight = (room - 32 - (biometric == null ? 0 : 48))
        .clamp(PatternPad.minSize, PatternPad.defaultSize)
        .toDouble();
    final size = math.min(width, byHeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PasscodeStatusLine(text: status, error: statusIsError),
        PasscodeShake(
          trigger: shakeCount,
          child: PatternPad(
            size: size,
            enabled: enabled,
            error: rejected,
            clearSignal: patternClears,
            onStarted: onPatternStarted,
            onCompleted: onPatternCompleted,
          ),
        ),
        if (biometric != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: biometric,
            icon: const FaIcon(FontAwesomeIcons.fingerprint, size: 16),
            label: Text(l10n.passcodeUseBiometric),
          ),
        ],
      ],
    );
  }
}
