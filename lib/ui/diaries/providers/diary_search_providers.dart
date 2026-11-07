import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../models/diary_search_preferences.dart';

/// 搜索页的本机偏好（最近搜索、结果排序），见 [DiarySearchPreferences]。
///
/// autoDispose：离开搜索页即释放，下次打开从设置重新读取。设置服务在启动
/// 门控里已加载；未就绪时按默认值显示，改动只记在内存里。
final diarySearchPreferencesProvider =
    NotifierProvider.autoDispose<
      DiarySearchPreferencesNotifier,
      DiarySearchPreferences
    >(DiarySearchPreferencesNotifier.new);

class DiarySearchPreferencesNotifier extends Notifier<DiarySearchPreferences> {
  @override
  DiarySearchPreferences build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    return DiarySearchPreferences.decode(settings?.diarySearchPreferencesRaw);
  }

  /// 记下一次搜索（键盘“搜索”或从结果打开一篇时，见搜索页控制器）。
  void remember(String keyword) => _update(state.remember(keyword));

  void forget(String keyword) => _update(state.forget(keyword));

  void clearRecent() => _update(state.clearRecent());

  void setSort(DiarySearchSort sort) => _update(state.withSort(sort));

  /// 先改内存状态让界面立即更新，写盘在后台进行。
  void _update(DiarySearchPreferences next) {
    if (next == state) return;
    state = next;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings != null) {
      unawaited(settings.setDiarySearchPreferencesRaw(next.encode()));
    }
  }
}

/// 搜索页空状态最多列出的常用标签数。
const int searchTagSuggestionLimit = 12;

/// 范围内各标签的篇数（降序），口径见 `watchTagUsageCounts`。
final tagUsageCountsProvider = StreamProvider.autoDispose
    .family<List<TagUsageCount>, DiaryListScope>((
      Ref ref,
      DiaryListScope scope,
    ) {
      return ref.watch(appDatabaseProvider).watchTagUsageCounts(scope: scope);
    });

/// 搜索页空状态的“常用标签”：范围内用得最多的前 [searchTagSuggestionLimit]
/// 个标签（标签列表或篇数还没到时为空表）。已选为条件的标签由界面排除。
final searchTagSuggestionsProvider = Provider.autoDispose
    .family<List<Tag>, DiaryListScope>((Ref ref, DiaryListScope scope) {
      final usages = ref.watch(tagUsageCountsProvider(scope)).value;
      final tags = ref.watch(tagListProvider).value;
      if (usages == null || tags == null) {
        return const <Tag>[];
      }
      final byId = <int, Tag>{for (final tag in tags) tag.id: tag};
      return <Tag>[
        for (final usage in usages)
          if (byId[usage.tagId] case final tag?) tag,
      ].take(searchTagSuggestionLimit).toList(growable: false);
    });
