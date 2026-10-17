import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 输入法编辑面板上的导航键（Android keyCode）。
enum SoftKeyboardKey {
  arrowUp(19, LogicalKeyboardKey.arrowUp),
  arrowDown(20, LogicalKeyboardKey.arrowDown),
  arrowLeft(21, LogicalKeyboardKey.arrowLeft),
  arrowRight(22, LogicalKeyboardKey.arrowRight),
  home(122, LogicalKeyboardKey.home),
  end(123, LogicalKeyboardKey.end);

  const SoftKeyboardKey(this.keyCode, this.logical);

  final int keyCode;
  final LogicalKeyboardKey logical;
}

/// 按 Flutter 3.47 Android 引擎的实际顺序，模拟输入法发出的一次按键（按下 +
/// 抬起）：先是 KeyData，再是带原始数据的按键消息。
///
/// [selecting] 对应编辑面板开着“选择”：按键带 `META_SHIFT_ON`，但输入法不另发
/// Shift 事件，而引擎对 deviceId 为 VIRTUAL_KEYBOARD 的按键不再按 meta 合成
/// Shift（flutter/flutter#185849），所以 KeyData 里看不到 Shift，只有原始消息的
/// metaState 带着它。scanCode 为 0，引擎把物理键放在 Android 平面。
Future<void> sendSoftKeyboardKey(
  WidgetTester tester,
  SoftKeyboardKey key, {
  bool selecting = false,
}) async {
  const androidPlane = 0x01100000000;
  const metaShiftOn = 0x1;
  const virtualKeyboardDeviceId = -1;
  const sourceKeyboard = 0x101;
  for (final down in <bool>[true, false]) {
    // 与引擎送 KeyData 的入口相同（绑定把它接到 KeyEventManager）。
    tester.binding.platformDispatcher.onKeyData!(
      ui.KeyData(
        type: down ? ui.KeyEventType.down : ui.KeyEventType.up,
        physical: androidPlane | key.keyCode,
        logical: key.logical.keyId,
        timeStamp: Duration.zero,
        character: null,
        synthesized: false,
      ),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.keyEvent.name,
      SystemChannels.keyEvent.codec.encodeMessage(<String, Object>{
        'type': down ? 'keydown' : 'keyup',
        'keymap': 'android',
        'keyCode': key.keyCode,
        'scanCode': 0,
        'metaState': selecting ? metaShiftOn : 0,
        'deviceId': virtualKeyboardDeviceId,
        'source': sourceKeyboard,
      }),
      (_) {},
    );
  }
  await tester.pump();
}
