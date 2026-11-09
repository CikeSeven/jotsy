// 智能体请求里的图片位置（纯数据与常量）。
//
// 一次请求里图片出现在两种地方：用户消息的附图（在提问文字之前），以及
// 工具结果之后（“查看图片”看的图，在同一条用户消息里）。历史按原样回放，
// 每一处图片都由一个“槽位”描述——它在消息里的位置（[AiImageSlot.key]）、
// 给模型看的称呼（[AiImageSlot.label]）和来源文件。槽位先由纯函数按对话
// 记录算出，再由 `resolveAiImageSlots` 统一加载成图片或占位文字，最后插回
// 原位：同样的对话记录每次得到同样的槽位、同样的字节，提示缓存按前缀命中。

import 'ai_chat_images.dart';

/// 一张图片在请求里的位置。
class AiImageSlot {
  const AiImageSlot({
    required this.key,
    required this.label,
    required this.source,
    this.diaryId,
  });

  /// 位置键：用户附图为 `q:<消息 id>:<位置>`，工具结果后的图为
  /// `c:<消息 id>:<调用 id>:<序号>`。
  final String key;

  /// 给模型看的称呼（`P3`、`D3#2`），占位文字里用它。
  final String label;

  /// 托管图片的绝对路径；被删掉的附图为空串。
  final String source;

  /// 来自日记的图片：回放时重新检查那篇日记还能不能给 AI 看。
  final String? diaryId;

  bool get removed => source.isEmpty;
}

/// 历史预算里每张图片按多少字计（与模型对图片的计费量级相当）。
const int kAiImageHistoryWeight = 1500;

/// 一次请求最多带多少张图片、多少字节（原始字节，base64 后约多三分之一）。
/// 超出时从最旧的图片开始换成占位，一次降到一半以下（见
/// `resolveAiImageSlots`）。12 MB 编码后约 16 MB，低于各家的请求体上限。
const int kAiRequestMaxImages = 20;
const int kAiRequestMaxImageBytes = 12 * 1024 * 1024;

/// 一次请求里的图片张数与字节（原始字节）。历史与这一轮附图加载后
/// （`resolveAiImageSlots`）是起点，这一轮“查看图片”在它之上累加。
class AiImageBudget {
  AiImageBudget({
    this.maxCount = kAiRequestMaxImages,
    this.maxBytes = kAiRequestMaxImageBytes,
  });

  final int maxCount;
  final int maxBytes;
  int count = 0;
  int bytes = 0;

  /// 再加一张 [size] 字节的图片仍在上限之内。
  bool fits(int size) => count + 1 <= maxCount && bytes + size <= maxBytes;

  void add(int size) {
    count++;
    bytes += size;
  }
}

/// 工具结果之后那张图片的位置键。
String aiCallImageKey(String messageId, String callId, int index) =>
    'c:$messageId:$callId:$index';

/// 用户附图的位置键。
String aiQuestionImageKey(String messageId, int index) => 'q:$messageId:$index';

/// 用户一条消息附图的槽位，按位置。
List<AiImageSlot> aiQuestionImageSlots(Iterable<AiChatImage> images) => [
  for (final image in images)
    AiImageSlot(
      key: aiQuestionImageKey(image.messageId, image.index),
      label: image.ref,
      source: image.path,
    ),
];
