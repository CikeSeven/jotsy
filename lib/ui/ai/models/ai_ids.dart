import 'dart:math';

final Random _random = Random();

/// 本机生成的 id（服务商、人设、自定义指令）：前缀 + 时间戳 + 随机后缀。
/// 只在偏好与本机配置里引用，不需要全局唯一的业务 id。
String newAiLocalId(String prefix) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 30).toRadixString(36);
  return '$prefix.$time$salt';
}
