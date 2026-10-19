import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../models/tag_picker_sort.dart';

/// 发布面板标签子页的排序方式（跨日记记住上次的选择）。
///
/// autoDispose：子页离开即释放，下次打开从设置重新读取，备份恢复改写的
/// 值不会被内存里的旧状态盖住，也就不必监听设置。设置服务在启动门控里
/// 已加载；未就绪时按默认排序显示，选择只记在内存里。
final tagPickerSortProvider =
    NotifierProvider.autoDispose<TagPickerSortNotifier, TagPickerSort>(
      TagPickerSortNotifier.new,
    );

class TagPickerSortNotifier extends Notifier<TagPickerSort> {
  @override
  TagPickerSort build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    return TagPickerSort.fromName(settings?.tagPickerSortRaw);
  }

  /// 先改内存状态让列表立即重排，写盘在后台进行。
  void select(TagPickerSort sort) {
    if (sort == state) return;
    state = sort;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings != null) {
      unawaited(settings.setTagPickerSortRaw(sort.name));
    }
  }
}
