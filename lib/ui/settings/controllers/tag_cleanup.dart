import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/tag_order_codec.dart';
import '../../diaries/providers/diary_filters.dart';

/// 标签删掉（或合并进别的标签）之后，清理还记着它的地方：自定义排序、
/// 记住的标签筛选，以及日记列表当前选中的筛选；最后让标签列表重新读。
///
/// 标签管理页删除标签与 AI 助手的删除 / 合并标签共用。写库由调用方负责，
/// 先清理后删、先删后清理都可以（记着不存在的 id 只是多余，不会出错）。
Future<void> forgetDeletedTags(
  ProviderContainer container,
  Set<int> tagIds,
) async {
  if (tagIds.isEmpty) return;
  final settings = await container.read(settingsServiceProvider.future);
  final order = decodeTagOrder(settings.tagOrderRaw)
    ..removeWhere(tagIds.contains);
  await settings.setTagOrderRaw(encodeTagOrder(order));
  final remembered = decodeTagOrder(settings.rememberedTagFilterIdsRaw)
    ..removeWhere(tagIds.contains);
  await settings.setRememberedTagFilterIdsRaw(encodeTagOrder(remembered));
  final active = container.read(diaryFilterProvider).selectedTagIds;
  if (active.any(tagIds.contains)) {
    container
        .read(diaryFilterProvider.notifier)
        .setTags(active.where((id) => !tagIds.contains(id)));
  }
  container.invalidate(tagListProvider);
}
