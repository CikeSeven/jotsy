// 工具参数的 schema：既生成发给模型的 JSON Schema，也在执行前**集中一次**
// 校验并转换模型给的参数，工具内部拿到的就是干净的值。
//
// - 只生成四家协议都认的子集：type / properties / required / enum / items /
//   description / minimum / maximum（Gemini 不认 additionalProperties、
//   oneOf、format 等，日期的格式写在 description 里）；
// - 转换（模型常见的小偏差，照单收下而不是报错）：数字写成字符串、布尔写成
//   "true"、数组只给了一个值、整数写成 3.0；
// - 报错（回传给模型让它改正）：缺必填、未知参数、类型不对、超出范围、
//   不在枚举里、日期格式不对。错误信息用英文，指明参数路径。

/// 参数不合法：[message] 原样回传模型。
class AiToolArgumentError implements Exception {
  const AiToolArgumentError(this.message);

  final String message;

  @override
  String toString() => message;
}

sealed class AiSchema {
  const AiSchema({this.description});

  final String? description;

  /// 发给模型的 JSON Schema。
  Map<String, Object?> toJson();

  /// 校验并转换 [value]；[path] 用于错误信息。
  Object? coerce(Object? value, String path);

  Map<String, Object?> _base(String type) => <String, Object?>{
    'type': type,
    if (description != null) 'description': description,
  };

  static AiToolArgumentError _error(String path, String expected) =>
      AiToolArgumentError('`$path` must be $expected.');
}

/// 对象（工具参数的顶层总是对象）。
class AiObjectSchema extends AiSchema {
  const AiObjectSchema({
    required this.properties,
    this.required = const <String>[],
    super.description,
  });

  final Map<String, AiSchema> properties;
  final List<String> required;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._base('object'),
    'properties': <String, Object?>{
      for (final entry in properties.entries) entry.key: entry.value.toJson(),
    },
    if (required.isNotEmpty) 'required': required,
  };

  /// 校验顶层参数（工具执行前调用）。
  Map<String, Object?> validate(Map<String, Object?> arguments) =>
      coerce(arguments, 'arguments')! as Map<String, Object?>;

  @override
  Object? coerce(Object? value, String path) {
    if (value is! Map) throw AiSchema._error(path, 'an object');
    final unknown = [
      for (final key in value.keys)
        if (!properties.containsKey(key)) '$key',
    ];
    if (unknown.isNotEmpty) {
      throw AiToolArgumentError(
        'Unknown parameter(s) ${unknown.map((k) => '`$k`').join(', ')} in '
        '`$path`. Allowed: ${properties.keys.join(', ')}.',
      );
    }
    final result = <String, Object?>{};
    for (final entry in properties.entries) {
      final raw = value[entry.key];
      // 显式的 null 与没给一样（不少模型会把可选参数写成 null）。
      if (raw == null) {
        if (required.contains(entry.key)) {
          throw AiToolArgumentError(
            'Missing required parameter `$path.${entry.key}`.',
          );
        }
        continue;
      }
      result[entry.key] = entry.value.coerce(raw, '$path.${entry.key}');
    }
    return result;
  }
}

class AiStringSchema extends AiSchema {
  const AiStringSchema({
    super.description,
    this.enumValues,
    this.maxLength,
    this.allowEmpty = false,
  });

  final List<String>? enumValues;
  final int? maxLength;

  /// 空字符串是否算有效值（默认不算，当成没给）。
  final bool allowEmpty;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._base('string'),
    if (enumValues != null) 'enum': enumValues,
  };

  @override
  Object? coerce(Object? value, String path) {
    final text = switch (value) {
      final String text => text,
      final num number => '$number',
      final bool flag => '$flag',
      _ => throw AiSchema._error(path, 'a string'),
    };
    if (text.trim().isEmpty && !allowEmpty) {
      throw AiSchema._error(path, 'a non-empty string');
    }
    final allowed = enumValues;
    if (allowed != null && !allowed.contains(text)) {
      throw AiSchema._error(path, 'one of ${allowed.join(', ')}');
    }
    final limit = maxLength;
    if (limit != null && text.length > limit) {
      throw AiSchema._error(path, 'at most $limit characters');
    }
    return text;
  }
}

class AiIntegerSchema extends AiSchema {
  const AiIntegerSchema({super.description, this.minimum, this.maximum});

  final int? minimum;
  final int? maximum;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._base('integer'),
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  @override
  Object? coerce(Object? value, String path) {
    final number = switch (value) {
      final int number => number,
      final double number when number == number.roundToDouble() =>
        number.toInt(),
      final String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (number == null) throw AiSchema._error(path, 'an integer');
    if (minimum case final min? when number < min) {
      throw AiSchema._error(path, '>= $min');
    }
    if (maximum case final max? when number > max) {
      throw AiSchema._error(path, '<= $max');
    }
    return number;
  }
}

class AiNumberSchema extends AiSchema {
  const AiNumberSchema({super.description, this.minimum, this.maximum});

  final num? minimum;
  final num? maximum;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._base('number'),
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  @override
  Object? coerce(Object? value, String path) {
    final number = switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text.trim()),
      _ => null,
    };
    if (number == null || !number.isFinite) {
      throw AiSchema._error(path, 'a number');
    }
    if (minimum case final min? when number < min) {
      throw AiSchema._error(path, '>= $min');
    }
    if (maximum case final max? when number > max) {
      throw AiSchema._error(path, '<= $max');
    }
    return number;
  }
}

class AiBooleanSchema extends AiSchema {
  const AiBooleanSchema({super.description});

  @override
  Map<String, Object?> toJson() => _base('boolean');

  @override
  Object? coerce(Object? value, String path) => switch (value) {
    final bool flag => flag,
    'true' || 'True' || '1' || 1 => true,
    'false' || 'False' || '0' || 0 => false,
    _ => throw AiSchema._error(path, 'true or false'),
  };
}

class AiArraySchema extends AiSchema {
  const AiArraySchema({required this.items, super.description, this.maxItems});

  final AiSchema items;
  final int? maxItems;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._base('array'),
    'items': items.toJson(),
  };

  @override
  Object? coerce(Object? value, String path) {
    // 只给了一个值时当作一项的数组。
    final list = value is List ? value : <Object?>[value];
    final limit = maxItems;
    if (limit != null && list.length > limit) {
      throw AiSchema._error(path, 'at most $limit items');
    }
    return <Object?>[
      for (var i = 0; i < list.length; i++) items.coerce(list[i], '$path[$i]'),
    ];
  }
}

/// 日期：`YYYY-MM-DD`，转换成当天零点的 [DateTime]（本地时间）。
class AiDateSchema extends AiSchema {
  const AiDateSchema({String? description})
    : super(description: description ?? 'Date as YYYY-MM-DD.');

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');

  @override
  Map<String, Object?> toJson() => _base('string');

  @override
  Object? coerce(Object? value, String path) {
    final match = value is String ? _pattern.firstMatch(value.trim()) : null;
    if (match == null) throw AiSchema._error(path, 'a date like 2026-01-31');
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    // DateTime 会把 2 月 30 日滚成 3 月 2 日：滚过了就是日期不存在。
    if (date.month != month || date.day != day) {
      throw AiSchema._error(path, 'a real calendar date');
    }
    return date;
  }
}

/// 时间：`HH:MM`（24 小时），转换成一天中的分钟数。
class AiTimeSchema extends AiSchema {
  const AiTimeSchema({String? description})
    : super(description: description ?? 'Time of day as HH:MM (24-hour).');

  static final RegExp _pattern = RegExp(r'^(\d{1,2}):(\d{2})$');

  @override
  Map<String, Object?> toJson() => _base('string');

  @override
  Object? coerce(Object? value, String path) {
    final match = value is String ? _pattern.firstMatch(value.trim()) : null;
    final hour = match == null ? null : int.parse(match.group(1)!);
    final minute = match == null ? null : int.parse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw AiSchema._error(path, 'a time like 09:30');
    }
    return hour * 60 + minute;
  }
}
