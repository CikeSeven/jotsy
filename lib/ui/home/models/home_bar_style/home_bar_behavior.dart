import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/style_json.dart';

/// 首页栏的行为：不属于外观，不随内置预设、样式码与“我的样式”改变（套用
/// 一个预设不该顺手改掉滚动时隐藏底栏之类的习惯）。与外观一起存在单键
/// `homeBarStyleRaw` 的 `behavior` 里，逐字段容错、稀疏编码。
@immutable
class HomeBarBehavior {
  const HomeBarBehavior({
    this.hideOnScroll = false,
    this.indicatorFollowsSwipe = false,
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
    );
  }

  /// 往下滚动内容时收起底栏，往回滚即出现。
  final bool hideOnScroll;

  /// 左右滑动切换 Tab 时，选中指示器跟着手指在两项之间移动（而不是松手后
  /// 才跳到新的一项）。
  final bool indicatorFollowsSwipe;

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
    return json;
  }

  HomeBarBehavior copyWith({bool? hideOnScroll, bool? indicatorFollowsSwipe}) {
    return HomeBarBehavior(
      hideOnScroll: hideOnScroll ?? this.hideOnScroll,
      indicatorFollowsSwipe:
          indicatorFollowsSwipe ?? this.indicatorFollowsSwipe,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBarBehavior &&
        other.hideOnScroll == hideOnScroll &&
        other.indicatorFollowsSwipe == indicatorFollowsSwipe;
  }

  @override
  int get hashCode => Object.hash(hideOnScroll, indicatorFollowsSwipe);
}
