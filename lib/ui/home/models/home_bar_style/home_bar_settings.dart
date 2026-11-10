import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../diaries/models/style_library/saved_style.dart';
import 'home_bar_behavior.dart';
import 'home_bar_style.dart';

/// 用户保存的一套首页栏样式（“我的样式”）。
typedef HomeBarSavedStyle = SavedStyle<HomeBarStyle>;

/// 首页栏设置的整体：当前样式、已保存的样式与栏的行为。
///
/// 持久化为单个 JSON 键（`homeBarStyleRaw`）：
/// `{"v":1,"current":{…},"saved":[…],"behavior":{…}}`。放在一个键里，备份
/// 恢复与失败回滚都是原子的，也只需一个通知源。全为默认时编码为 null，由
/// 设置服务删除该键。保存项的增删改与上限见 [SavedStyles]；所有修改都原样
/// 保留 [behavior]。
@immutable
class HomeBarSettings implements StyleLibrary<HomeBarStyle, HomeBarSettings> {
  const HomeBarSettings({
    this.current = HomeBarStyle.defaults,
    this.saved = const <HomeBarSavedStyle>[],
    this.behavior = HomeBarBehavior.defaults,
  });

  static const HomeBarSettings defaults = HomeBarSettings();
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。各部分逐项容错。
  factory HomeBarSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // 损坏的配置按默认样式展示，不能让首页栏的外观偏好阻断启动。
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    return HomeBarSettings(
      current: HomeBarStyle.fromJson(decoded['current']),
      saved: SavedStyles.decode(decoded['saved'], HomeBarStyle.fromJson),
      behavior: HomeBarBehavior.fromJson(decoded['behavior']),
    );
  }

  @override
  final HomeBarStyle current;
  @override
  final List<HomeBarSavedStyle> saved;
  final HomeBarBehavior behavior;

  bool get isDefault =>
      current.isDefault && saved.isEmpty && behavior.isDefault;

  @override
  bool get canSaveMore => saved.length < SavedStyles.maxItems;

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) {
      return null;
    }
    final behaviorJson = behavior.toJson();
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'current': current.toJson(),
      if (saved.isNotEmpty)
        'saved': SavedStyles.encode(saved, (style) => style.toJson()),
      if (behaviorJson.isNotEmpty) 'behavior': behaviorJson,
    });
  }

  HomeBarSettings withBehavior(HomeBarBehavior value) =>
      HomeBarSettings(current: current, saved: saved, behavior: value);

  @override
  HomeBarSettings withCurrent(HomeBarStyle style) =>
      HomeBarSettings(current: style, saved: saved, behavior: behavior);

  @override
  HomeBarSettings addSaved(String name, HomeBarStyle style, {DateTime? now}) =>
      _withSaved(SavedStyles.add(saved, name, style, now: now));

  @override
  HomeBarSettings renameSaved(String id, String name) =>
      _withSaved(SavedStyles.rename(saved, id, name));

  @override
  HomeBarSettings removeSaved(String id) =>
      _withSaved(SavedStyles.remove(saved, id));

  @override
  HomeBarSettings restoreSaved(HomeBarSavedStyle item, int index) =>
      _withSaved(SavedStyles.restore(saved, item, index));

  HomeBarSettings _withSaved(List<HomeBarSavedStyle>? next) => next == null
      ? this
      : HomeBarSettings(current: current, saved: next, behavior: behavior);

  @override
  bool operator ==(Object other) {
    return other is HomeBarSettings &&
        other.current == current &&
        listEquals(other.saved, saved) &&
        other.behavior == behavior;
  }

  @override
  int get hashCode => Object.hash(current, Object.hashAll(saved), behavior);
}
