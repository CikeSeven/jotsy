import 'package:flutter/material.dart';

/// 按基础主题与派生参数记住派生出的主题：输入不变时交回同一个
/// [ThemeData] 实例。
///
/// 为什么：`MaterialApp.builder` 读了整份 MediaQuery，软键盘升降时逐帧重建；
/// 挂在里面的主题覆盖（玻璃控件与提示条、减少动画）若每次都 `copyWith` 出
/// 新的 ThemeData，其中的 `WidgetStateProperty.resolveWith` 等闭包比较起来
/// 永远不相等，[Theme] 就会逐帧通知全应用所有读主题的组件重建——真机上
/// 打开玻璃材质时，键盘动画的每一帧都把编辑页、预览页、首页整个重建一遍。
///
/// 基础主题按值比较而不是按实例：`Theme.of` 返回的是按文字几何本地化后的
/// 副本，存在框架里只有 5 项的缓存中；应用里主题层级一多（玻璃、首页、预览
/// 与阅读式编辑页的样式主题……）就会被挤出，每次调用都得到内容相同的新
/// 实例。先比实例、不同再比 `==`。最多记 [_capacity] 份（明暗、设置页预览
/// 等），按最近使用淘汰。
class DerivedThemeCache<K> {
  static const int _capacity = 4;

  final List<(ThemeData, K, ThemeData)> _entries =
      <(ThemeData, K, ThemeData)>[];

  ThemeData resolve(ThemeData base, K key, ThemeData Function() derive) {
    for (var i = 0; i < _entries.length; i++) {
      final (cachedBase, cachedKey, derived) = _entries[i];
      if (cachedKey == key &&
          (identical(cachedBase, base) || cachedBase == base)) {
        // 记下最新的基础实例：下次同一实例走 identical 的快路。
        _entries
          ..removeAt(i)
          ..add((base, key, derived));
        return derived;
      }
    }
    final derived = derive();
    _entries.add((base, key, derived));
    if (_entries.length > _capacity) _entries.removeAt(0);
    return derived;
  }
}
