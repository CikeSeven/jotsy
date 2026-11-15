// 工作室「预设」页的“我的样式”：保存、改名、删除与撤销删除。
//
// 读写的都是小组件设置（`app.settings.home_widgets`）里的 `saved` 字段，每次整份读出
// 最新的设置再写回，不持有副本：工作室同时在改实例的外观，两边各自读写最新值，不会
// 互相覆盖。列表规则（上限、名字规范化、id 生成）全部复用 `SavedStyles`。

import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/style_library/saved_style.dart';
import '../models/home_widget_style_library.dart';
import '../providers/home_widget_providers.dart';

class HomeWidgetStyleLibraryController {
  HomeWidgetStyleLibraryController({
    required this.settingsService,
    required this.readSettings,
  });

  final SettingsService settingsService;
  final HomeWidgetSettings Function() readSettings;

  List<SavedStyle<HomeWidgetStyle>> get saved =>
      homeWidgetSavedStyles(readSettings());

  bool get canSaveMore => saved.length < SavedStyles.maxItems;

  /// 把 [style] 存为一份“我的样式”；已达上限或名字为空时返回 false。
  Future<bool> save(String name, HomeWidgetStyle style) async {
    final next = SavedStyles.add(saved, name, style);
    if (next == null) return false;
    await _write(next);
    return true;
  }

  Future<void> rename(String id, String name) async {
    final next = SavedStyles.rename(saved, id, name);
    if (next != null) await _write(next);
  }

  /// 删除一份；返回被删的条目与原位置供撤销，不存在时为 null。
  Future<(SavedStyle<HomeWidgetStyle>, int)?> delete(String id) async {
    final current = saved;
    final index = current.indexWhere((item) => item.id == id);
    if (index < 0) return null;
    await _write(SavedStyles.remove(current, id));
    return (current[index], index);
  }

  Future<void> restore(SavedStyle<HomeWidgetStyle> item, int index) async {
    final next = SavedStyles.restore(saved, item, index);
    if (next != null) await _write(next);
  }

  Future<void> _write(List<SavedStyle<HomeWidgetStyle>> next) =>
      saveHomeWidgetSettings(
        settingsService,
        homeWidgetSettingsWithSaved(readSettings(), next),
      );
}
