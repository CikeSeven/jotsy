// 把请求里的图片槽位（`ai_agent_image_slots.dart`）加载成图片或占位文字。
//
// 参考 pi 与 deepseek-harness：历史里的图片每轮原样重发（前缀逐字节不变，
// 提示缓存整段命中）；请求里的图片超出上限（[kAiRequestMaxImages] 张或
// [kAiRequestMaxImageBytes] 字节）时，从最旧的开始**一次换掉一批**、降到
// 上限的一半以下（高水位分段）。换掉的判定只取决于对话内容本身——同样的
// 槽位序列每次得到同样的结果，较早的决定不会因为后面多了图片而改变——所以
// 缓存只在越过上限的那一轮断一次，不会每发一张图就改写一次很早的前缀。
//
// 每个槽位按顺序得到：
// - 墓碑（附图被存储管理删掉）→ “图片已删除”；
// - 这一轮不发图（模型不识图、图片理解关着）→ “图片没有发给你”；
// - 来自日记、那篇日记现在不能给 AI 看（变私密、被排除、删除）→
//   “读不出来”；文件不在或解不出 → 同样“读不出来”；
// - 否则为图片本身，计入预算；超出时按上面的规则把较早的换成“为控制请求
//   大小没发，需要时重看”。
//
// 返回的预算是处理完全部槽位后请求里已有的图片，这一轮“查看图片”工具在
// 它之上继续累加（不再换掉较早的图片，超出时由工具拒绝）。

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_vision.dart';
import '../../../l10n/app_localizations.dart';
import '../viewmodels/ai_agent_image_slots.dart';

/// 读一张图片（测试替换用）。
typedef AiImageLoader =
    Future<AiImagePart?> Function(String source, int maxSide);

/// 加载结果：槽位键 → 图片或占位文字，以及请求里已有的图片。
class AiResolvedImages {
  const AiResolvedImages(this.parts, this.budget);

  final Map<String, AiPart> parts;
  final AiImageBudget budget;
}

Future<AiResolvedImages> resolveAiImageSlots(
  List<AiImageSlot> slots, {
  required bool vision,
  required int maxSide,
  required AppLocalizations l10n,
  Future<bool> Function(String diaryId)? diaryAllowed,
  int maxCount = kAiRequestMaxImages,
  int maxBytes = kAiRequestMaxImageBytes,
  AiImageLoader? loader,
}) async {
  final load =
      loader ??
      (String source, int side) => AiVisionImages.load(source, maxSide: side);
  final budget = AiImageBudget(maxCount: maxCount, maxBytes: maxBytes);
  final parts = <String, AiPart>{};
  // 已放进请求的图片，旧 → 新（超出时从前面换掉）。
  final kept = <({AiImageSlot slot, int bytes})>[];
  final allowedCache = <String, bool>{};
  for (final slot in slots) {
    if (slot.removed) {
      parts[slot.key] = AiTextPart(l10n.aiPromptImageRemoved(slot.label));
      continue;
    }
    if (!vision) {
      parts[slot.key] = AiTextPart(l10n.aiPromptImageNotSent(slot.label));
      continue;
    }
    final diaryId = slot.diaryId;
    if (diaryId != null && diaryAllowed != null) {
      final allowed = allowedCache[diaryId] ??= await diaryAllowed(diaryId);
      if (!allowed) {
        parts[slot.key] = AiTextPart(l10n.aiPromptImageUnavailable(slot.label));
        continue;
      }
    }
    final image = await load(slot.source, maxSide);
    if (image == null) {
      parts[slot.key] = AiTextPart(l10n.aiPromptImageUnavailable(slot.label));
      continue;
    }
    final size = image.bytes.lengthInBytes;
    parts[slot.key] = image;
    kept.add((slot: slot, bytes: size));
    budget.add(size);
    if (budget.count > maxCount || budget.bytes > maxBytes) {
      while (kept.isNotEmpty &&
          (budget.count > maxCount ~/ 2 || budget.bytes > maxBytes ~/ 2)) {
        final oldest = kept.removeAt(0);
        parts[oldest.slot.key] = AiTextPart(
          l10n.aiPromptImageOmitted(oldest.slot.label),
        );
        budget
          ..count -= 1
          ..bytes -= oldest.bytes;
      }
    }
  }
  return AiResolvedImages(parts, budget);
}
