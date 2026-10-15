/// 自动地址的展示层级，与设备定位精度无关。
/// 使用稳定名称保存选择；旧草稿和未知值沿用原来的街道／乡镇层级。
enum DiaryLocationPrecision {
  city,
  district,
  township,
  street,
  address;

  static DiaryLocationPrecision parse(Object? value) => values.firstWhere(
    (precision) => precision.name == value,
    orElse: () => township,
  );
}

/// 将高德地址组件映射为日记地址文案，无网络请求和状态副作用。
/// 不使用完整地址兜底，避免用户选城市时意外展示门牌；更细字段缺失时逐级
/// 回退。高德的空字段可能是空数组，须与普通字符串一起归一化。
class DiaryLocationLabel {
  const DiaryLocationLabel._();

  static String? format(
    Map<String, Object?>? components,
    DiaryLocationPrecision precision,
  ) {
    if (components == null) return null;
    final city = _text(components['city']) ?? _text(components['province']);
    final district = _text(components['district']);
    final township = _text(components['township']);
    final streetNumber = components['streetNumber'];
    final street = streetNumber is Map ? _text(streetNumber['street']) : null;
    final number = streetNumber is Map ? _text(streetNumber['number']) : null;

    final parts = switch (precision) {
      DiaryLocationPrecision.city => [city],
      DiaryLocationPrecision.district => [city, district],
      DiaryLocationPrecision.township => [city, township ?? district],
      DiaryLocationPrecision.street || DiaryLocationPrecision.address =>
        street == null
            ? [city, township ?? district]
            : [
                city,
                district,
                precision == DiaryLocationPrecision.address && number != null
                    ? '$street$number'
                    : street,
              ],
    };
    final label = parts.whereType<String>().toSet().join(' · ');
    return label.isEmpty ? null : label;
  }

  /// 地点文案是否仍是按 [precision] 自动生成的，切换层级时只重组这种文案。
  ///
  /// 不单独保存“文案来自自动定位”的标记，而是与自动文案比对：手动改过的
  /// 地点（包括旧版本“自动定位后再手改”、但 metadata 仍带 geo 的日记）
  /// 自然不相等，不会被覆盖；改回与自动文案一致时又能继续跟随层级。
  static bool isAutoLabel(
    String? text,
    Map<String, Object?>? components,
    DiaryLocationPrecision precision,
  ) => components != null && _text(text) == format(components, precision);

  static String? _text(Object? value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is List) {
      for (final item in value) {
        final text = _text(item);
        if (text != null) return text;
      }
    }
    return null;
  }
}
