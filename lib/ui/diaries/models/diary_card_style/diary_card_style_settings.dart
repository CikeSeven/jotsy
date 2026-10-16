import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'diary_card_style.dart';

/// 用户保存的一套卡片样式（“我的样式”）。
@immutable
class DiaryCardSavedStyle {
  const DiaryCardSavedStyle({
    required this.id,
    required this.name,
    required this.style,
  });

  final String id;
  final String name;
  final DiaryCardStyle style;

  DiaryCardSavedStyle copyWith({String? name, DiaryCardStyle? style}) {
    return DiaryCardSavedStyle(
      id: id,
      name: name ?? this.name,
      style: style ?? this.style,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardSavedStyle &&
        other.id == id &&
        other.name == name &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(id, name, style);
}

/// 卡片样式设置的整体：当前样式 + 已保存的样式。
///
/// 持久化为单个 JSON 键（`diaryCardStyleRaw`）：
/// `{"v":1,"current":{…},"saved":[{"id":…,"name":…,"style":{…}}]}`。
/// 放在一个键里，备份恢复与失败回滚都是原子的，也只需一个通知源。
/// 与默认完全相同（默认样式且没有保存项）时编码为 null，由设置服务删除
/// 该键，备份里不留冗余配置。
@immutable
class DiaryCardStyleSettings {
  const DiaryCardStyleSettings({
    this.current = DiaryCardStyle.defaults,
    this.saved = const <DiaryCardSavedStyle>[],
  });

  static const DiaryCardStyleSettings defaults = DiaryCardStyleSettings();

  /// “我的样式”上限：每份约数百字节，12 份足够常用又不让设置键膨胀。
  static const int maxSaved = 12;
  static const int maxNameLength = 24;
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。保存项逐条容错：
  /// 结构不对、名字为空或 id 重复的条目被跳过，超出上限的丢弃。
  factory DiaryCardStyleSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    final saved = <DiaryCardSavedStyle>[];
    final ids = <String>{};
    final rawSaved = decoded['saved'];
    if (rawSaved is List) {
      for (final item in rawSaved) {
        if (saved.length >= maxSaved) {
          break;
        }
        if (item is! Map) {
          continue;
        }
        final id = item['id'];
        final name = item['name'];
        if (id is! String || id.isEmpty || !ids.add(id) || name is! String) {
          continue;
        }
        final normalizedName = normalizeName(name);
        if (normalizedName.isEmpty) {
          continue;
        }
        saved.add(
          DiaryCardSavedStyle(
            id: id,
            name: normalizedName,
            style: DiaryCardStyle.fromJson(item['style']),
          ),
        );
      }
    }
    return DiaryCardStyleSettings(
      current: DiaryCardStyle.fromJson(decoded['current']),
      saved: List<DiaryCardSavedStyle>.unmodifiable(saved),
    );
  }

  final DiaryCardStyle current;
  final List<DiaryCardSavedStyle> saved;

  bool get isDefault => current.isDefault && saved.isEmpty;

  bool get canSaveMore => saved.length < maxSaved;

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) {
      return null;
    }
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'current': current.toJson(),
      if (saved.isNotEmpty)
        'saved': <Object>[
          for (final item in saved)
            <String, Object>{
              'id': item.id,
              'name': item.name,
              'style': item.style.toJson(),
            },
        ],
    });
  }

  /// 名字去首尾空白、折叠连续空白并按字符（不拆 emoji）截到上限。
  static String normalizeName(String raw) {
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final characters = collapsed.characters;
    if (characters.length <= maxNameLength) {
      return collapsed;
    }
    return characters.take(maxNameLength).toString().trimRight();
  }

  DiaryCardStyleSettings withCurrent(DiaryCardStyle style) =>
      DiaryCardStyleSettings(current: style, saved: saved);

  /// 追加一份保存项；已达上限或名字为空时原样返回。
  DiaryCardStyleSettings addSaved(
    String name,
    DiaryCardStyle style, {
    DateTime? now,
  }) {
    final normalizedName = normalizeName(name);
    if (!canSaveMore || normalizedName.isEmpty) {
      return this;
    }
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch.toRadixString(
      36,
    );
    var id = 'u$stamp';
    var suffix = 1;
    while (saved.any((item) => item.id == id)) {
      id = 'u${stamp}_${suffix++}';
    }
    return DiaryCardStyleSettings(
      current: current,
      saved: List<DiaryCardSavedStyle>.unmodifiable(<DiaryCardSavedStyle>[
        ...saved,
        DiaryCardSavedStyle(id: id, name: normalizedName, style: style),
      ]),
    );
  }

  DiaryCardStyleSettings renameSaved(String id, String name) {
    final normalizedName = normalizeName(name);
    if (normalizedName.isEmpty) {
      return this;
    }
    return _replaceSaved(
      saved.map(
        (item) => item.id == id ? item.copyWith(name: normalizedName) : item,
      ),
    );
  }

  DiaryCardStyleSettings removeSaved(String id) =>
      _replaceSaved(saved.where((item) => item.id != id));

  /// 撤销删除：把条目放回原来的位置（超出当前长度时放到末尾）。
  DiaryCardStyleSettings restoreSaved(DiaryCardSavedStyle item, int index) {
    if (saved.any((existing) => existing.id == item.id) || !canSaveMore) {
      return this;
    }
    final next = List<DiaryCardSavedStyle>.of(saved)
      ..insert(index.clamp(0, saved.length).toInt(), item);
    return _replaceSaved(next);
  }

  DiaryCardSavedStyle? savedById(String id) {
    for (final item in saved) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  DiaryCardStyleSettings _replaceSaved(Iterable<DiaryCardSavedStyle> items) =>
      DiaryCardStyleSettings(
        current: current,
        saved: List<DiaryCardSavedStyle>.unmodifiable(items),
      );

  @override
  bool operator ==(Object other) {
    return other is DiaryCardStyleSettings &&
        other.current == current &&
        listEquals(other.saved, saved);
  }

  @override
  int get hashCode => Object.hash(current, Object.hashAll(saved));
}
