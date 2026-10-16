import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// 用户保存的一套样式（“我的样式”）。[S] 为样式类型（卡片样式、预览页
/// 样式……），需实现值相等。
@immutable
class SavedStyle<S> {
  const SavedStyle({required this.id, required this.name, required this.style});

  final String id;
  final String name;
  final S style;

  SavedStyle<S> copyWith({String? name, S? style}) {
    return SavedStyle<S>(
      id: id,
      name: name ?? this.name,
      style: style ?? this.style,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedStyle<S> &&
        other.id == id &&
        other.name == name &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(id, name, style);
}

/// 一类样式设置的整体：当前样式 + 已保存的样式。样式编辑器
/// （`StyleEditorController`）只经这个接口读写，具体的设置类可以另带与
/// 样式无关的字段（如预览页的阅读行为），由各自的方法原样保留。
///
/// 所有修改都返回新实例；修改无效（已达上限、名字为空、条目不存在）时返回
/// 自身，调用方可以用 `==` 判断是否真的变了。
abstract interface class StyleLibrary<S, L extends StyleLibrary<S, L>> {
  S get current;
  List<SavedStyle<S>> get saved;
  bool get canSaveMore;
  L withCurrent(S style);
  L addSaved(String name, S style, {DateTime? now});
  L renameSaved(String id, String name);
  L removeSaved(String id);

  /// 撤销删除：把条目放回原位置（超出当前长度时放到末尾）。
  L restoreSaved(SavedStyle<S> item, int index);
}

/// “我的样式”列表的纯函数操作与 JSON 编解码，供各样式设置类共用。
///
/// 列表最多 [maxItems] 份：每份约数百字节，12 份足够常用，又不让设置键
/// 膨胀。名字去首尾空白、折叠连续空白，并按字符（不拆 emoji）截到
/// [maxNameLength]。
abstract final class SavedStyles {
  static const int maxItems = 12;
  static const int maxNameLength = 24;

  static String normalizeName(String raw) {
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final characters = collapsed.characters;
    if (characters.length <= maxNameLength) {
      return collapsed;
    }
    return characters.take(maxNameLength).toString().trimRight();
  }

  /// 追加一份；已达上限或名字为空时返回 null。id 由时间戳生成并避开已有 id。
  static List<SavedStyle<S>>? add<S>(
    List<SavedStyle<S>> saved,
    String name,
    S style, {
    DateTime? now,
  }) {
    final normalizedName = normalizeName(name);
    if (saved.length >= maxItems || normalizedName.isEmpty) {
      return null;
    }
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch.toRadixString(
      36,
    );
    var id = 'u$stamp';
    var suffix = 1;
    while (saved.any((item) => item.id == id)) {
      id = 'u${stamp}_${suffix++}';
    }
    return List<SavedStyle<S>>.unmodifiable(<SavedStyle<S>>[
      ...saved,
      SavedStyle<S>(id: id, name: normalizedName, style: style),
    ]);
  }

  /// 改名；名字为空时返回 null。
  static List<SavedStyle<S>>? rename<S>(
    List<SavedStyle<S>> saved,
    String id,
    String name,
  ) {
    final normalizedName = normalizeName(name);
    if (normalizedName.isEmpty) {
      return null;
    }
    return List<SavedStyle<S>>.unmodifiable(
      saved.map(
        (item) => item.id == id ? item.copyWith(name: normalizedName) : item,
      ),
    );
  }

  static List<SavedStyle<S>> remove<S>(List<SavedStyle<S>> saved, String id) =>
      List<SavedStyle<S>>.unmodifiable(saved.where((item) => item.id != id));

  /// 放回原位置；id 已存在或已达上限时返回 null。
  static List<SavedStyle<S>>? restore<S>(
    List<SavedStyle<S>> saved,
    SavedStyle<S> item,
    int index,
  ) {
    if (saved.any((existing) => existing.id == item.id) ||
        saved.length >= maxItems) {
      return null;
    }
    return List<SavedStyle<S>>.unmodifiable(
      List<SavedStyle<S>>.of(saved)
        ..insert(index.clamp(0, saved.length).toInt(), item),
    );
  }

  static SavedStyle<S>? byId<S>(List<SavedStyle<S>> saved, String id) {
    for (final item in saved) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// 与 [style] 相同的第一份保存项；没有时为 null。
  static SavedStyle<S>? matching<S>(List<SavedStyle<S>> saved, S style) {
    for (final item in saved) {
      if (item.style == style) {
        return item;
      }
    }
    return null;
  }

  /// 解析持久化的保存项列表；逐条容错：结构不对、名字为空或 id 重复的条目
  /// 被跳过，超出上限的丢弃。
  static List<SavedStyle<S>> decode<S>(
    Object? raw,
    S Function(Object? json) styleFromJson,
  ) {
    if (raw is! List) {
      return List<SavedStyle<S>>.unmodifiable(const <Never>[]);
    }
    final saved = <SavedStyle<S>>[];
    final ids = <String>{};
    for (final item in raw) {
      if (saved.length >= maxItems) {
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
        SavedStyle<S>(
          id: id,
          name: normalizedName,
          style: styleFromJson(item['style']),
        ),
      );
    }
    return List<SavedStyle<S>>.unmodifiable(saved);
  }

  static List<Object> encode<S>(
    List<SavedStyle<S>> saved,
    Object Function(S style) styleToJson,
  ) {
    return <Object>[
      for (final item in saved)
        <String, Object>{
          'id': item.id,
          'name': item.name,
          'style': styleToJson(item.style),
        },
    ];
  }
}
