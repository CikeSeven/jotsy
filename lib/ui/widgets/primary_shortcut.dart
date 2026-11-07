import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// “主修饰键 + [key]”的快捷键：苹果平台为 ⌘，其余平台为 Ctrl。
///
/// 按 [defaultTargetPlatform] 判断（测试用 `debugDefaultTargetPlatformOverride`
/// 切换），首页与搜索页的 Ctrl / ⌘ + F 等共用这一处口径。
SingleActivator primaryShortcut(LogicalKeyboardKey key) {
  final apple = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => true,
    _ => false,
  };
  return SingleActivator(key, control: !apple, meta: apple);
}
