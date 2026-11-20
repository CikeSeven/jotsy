import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';
import 'home_bar_style_enums.dart';

/// 首页栏的行为：不属于外观，不随内置预设、样式码与“我的样式”改变（套用
/// 一个预设不该顺手改掉滚动时隐藏底栏之类的习惯）。与外观一起存在单键
/// `homeBarStyleRaw` 的 `behavior` 里，逐字段容错、稀疏编码。
@immutable
class HomeBarBehavior {
  const HomeBarBehavior({
    this.hideOnScroll = false,
    this.indicatorFollowsSwipe = false,
    this.settingsPlacement = HomeBarSettingsPlacement.bar,
  });

  static const HomeBarBehavior defaults = HomeBarBehavior();

  factory HomeBarBehavior.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return defaults;
    }
    return HomeBarBehavior(
      hideOnScroll: StyleJson.boolean(
        json['hideOnScroll'],
        defaults.hideOnScroll,
      ),
      indicatorFollowsSwipe: StyleJson.boolean(
        json['indicatorFollowsSwipe'],
        defaults.indicatorFollowsSwipe,
      ),
      settingsPlacement: StyleJson.enumByName(
        HomeBarSettingsPlacement.values,
        json['settingsPlacement'],
        defaults.settingsPlacement,
      ),
    );
  }

  /// 往下滚动内容时收起底栏，往回滚即出现。
  final bool hideOnScroll;

  /// 左右滑动切换 Tab 时，选中指示器跟着手指在两项之间移动（而不是松手后
  /// 才跳到新的一项）。
  final bool indicatorFollowsSwipe;

  /// 设置的入口：默认是导航栏末尾的“设置”Tab；改放到日记页顶栏的“更多”
  /// 菜单时不占导航栏（#310）。两处不会同时出现。
  final HomeBarSettingsPlacement settingsPlacement;

  /// 设置是不是导航栏里的一个 Tab。
  bool get settingsInBar => settingsPlacement == HomeBarSettingsPlacement.bar;

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.put(json, 'hideOnScroll', hideOnScroll, defaults.hideOnScroll);
    StyleJson.put(
      json,
      'indicatorFollowsSwipe',
      indicatorFollowsSwipe,
      defaults.indicatorFollowsSwipe,
    );
    StyleJson.putEnum(
      json,
      'settingsPlacement',
      settingsPlacement,
      defaults.settingsPlacement,
    );
    return json;
  }

  HomeBarBehavior copyWith({
    bool? hideOnScroll,
    bool? indicatorFollowsSwipe,
    HomeBarSettingsPlacement? settingsPlacement,
  }) {
    return HomeBarBehavior(
      hideOnScroll: hideOnScroll ?? this.hideOnScroll,
      indicatorFollowsSwipe:
          indicatorFollowsSwipe ?? this.indicatorFollowsSwipe,
      settingsPlacement: settingsPlacement ?? this.settingsPlacement,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarBehavior &&
        other.hideOnScroll == hideOnScroll &&
        other.indicatorFollowsSwipe == indicatorFollowsSwipe &&
        other.settingsPlacement == settingsPlacement;
  }

  @override
  int get hashCode =>
      Object.hash(hideOnScroll, indicatorFollowsSwipe, settingsPlacement);
}
