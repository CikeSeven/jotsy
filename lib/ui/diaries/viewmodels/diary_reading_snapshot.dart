import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../utils/optional_text.dart';
import '../models/diary_meta_draft.dart';
import '../models/publish_metadata_composer.dart';
import 'diary_preview_view_data.dart';

/// 阅读式编辑页里“这一篇此刻的样子”：预览组件（信息栏、头图、配色基调、
/// 页尾）要的 [DiaryWithTags] 与派生数据。
class DiaryReadingSnapshot {
  const DiaryReadingSnapshot({required this.detail, required this.viewData});

  final DiaryWithTags detail;
  final DiaryPreviewViewData viewData;
}

/// 把编辑页手里的草稿拼成 [DiaryReadingSnapshot]，并记住上一次的结果。
///
/// 输入：库里读出的原日记（id、归档 / 回收站 / 胶囊等列）、标题、正文、
/// 信息面板草稿、发表时间与最后编辑时间，以及全部标签。输出：内存里的一份
/// 日记行，与预览页从库里读出的那份同构——信息栏与配色基调读到的心情、
/// 精力、地点、天气、标签与封面都是面板里的当前值，改了立刻看得到。
///
/// 为什么记忆化：页面每次重建都会调用；metadata 只在面板草稿变化时重新
/// 组装，派生数据（解析 metadata、扫描正文图片、字数）只在来源变化时重算
/// （[DiaryPreviewViewData.resolve] 按来源比较）。正文由调用方按自动保存
/// 的节拍传入（保存下来的那一份），不在每次按键时重新扫描。无副作用。
class DiaryReadingSnapshotBuilder {
  DiaryMetaDraft? _composedFor;
  String _metadata = '{}';
  DiaryPreviewViewData? _viewData;

  DiaryReadingSnapshot build({
    required Diary base,
    required String title,
    required String contentJson,
    required String contentText,
    required DiaryMetaDraft meta,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<Tag> allTags,
  }) {
    if (_composedFor != meta) {
      _composedFor = meta;
      // 只有 metadata.context（心情、精力、地点、天气）会被读到：生成时间
      // 取固定值、不带设备信息，草稿没变时组装结果逐字相同，派生数据得以
      // 复用。
      _metadata = PublishMetadataComposer.composeDraft(
        draft: meta,
        contentText: '',
        generatedAt: base.createdAt,
        deviceInfo: const <String, Object?>{},
      );
    }
    final diary = base.copyWith(
      title: title,
      content: contentJson,
      contentText: contentText,
      cover: Value<String?>(normalizeOptionalText(meta.cover)),
      metadata: _metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    final viewData = DiaryPreviewViewData.resolve(diary, previous: _viewData);
    _viewData = viewData;
    return DiaryReadingSnapshot(
      detail: DiaryWithTags(diary: diary, tags: tagsOf(meta.tagIds, allTags)),
      viewData: viewData,
    );
  }

  /// 草稿选中的标签行，按名称排序——与库里读出的日记标签同一顺序
  /// （`getDiaryWithTagsByDiaryId` 按名称升序），“首个标签”配色基调取到的
  /// 颜色与预览页一致。标签列表里已经没有的 id（刚被删除）跳过。
  static List<Tag> tagsOf(Set<int> ids, List<Tag> allTags) {
    if (ids.isEmpty) return const <Tag>[];
    return allTags.where((Tag tag) => ids.contains(tag.id)).toList()
      ..sort((Tag a, Tag b) => a.name.compareTo(b.name));
  }
}
