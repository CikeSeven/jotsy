import 'package:flutter/foundation.dart';

/// 新建页带进来的初始内容（AI 的“另存为日记”）：像套用模板一样填进标题
/// 与正文，原样未动时不算草稿——直接返回不在草稿箱里留下一份，开着“返回
/// 时直接发表”也不会发表；改过一个字就照常自动保存。
///
/// 与续写草稿（`createDraftId`）不同，打开时不写草稿表。
@immutable
class EditDiaryCreateSeed {
  const EditDiaryCreateSeed({
    required this.title,
    required this.contentDocJson,
  });

  final String title;

  /// 正文的块文档 JSON（`Document.toJson()` 同构）。
  final String contentDocJson;
}
