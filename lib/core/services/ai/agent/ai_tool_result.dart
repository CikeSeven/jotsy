import 'dart:convert';

/// 工具结果给模型的默认上限（字符）。日记正文另受“最多发送”字数预算约束，
/// 这里只防止某个结果意外地过大（例如列出几千个标签）。
const int kAiToolResultMaxChars = 16000;

/// 把工具结果编成回传给模型的文字（统一出口）。
///
/// - 结果是 JSON 可编码的值时编成紧凑 JSON；
/// - 超过 [maxChars] 时不硬截半个 JSON，而是换成
///   `{"truncated": true, "preview": "...", "hint": "..."}`，提示模型缩小
///   范围再查（预览是原文开头）。
String aiToolResultText(Object? data, {int maxChars = kAiToolResultMaxChars}) {
  final text = data is String ? data : jsonEncode(data);
  if (text.length <= maxChars) return text;
  final keep = maxChars - 200 > 0 ? maxChars - 200 : maxChars ~/ 2;
  return jsonEncode(<String, Object?>{
    'truncated': true,
    'preview': text.substring(0, keep),
    'hint':
        'The result was too long and was cut. Narrow the query '
        '(dates, keywords, limit) and call the tool again.',
  });
}
