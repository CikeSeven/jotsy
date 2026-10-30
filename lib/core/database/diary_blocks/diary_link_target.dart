/// 正文里指向本应用里另一篇日记或另一本日记本的链接（日记链接）。
///
/// 存储：链接目标写成内部地址 `jotsy://diary/<diaryId>` /
/// `jotsy://notebook/<notebookId>`（两种 id 都是业务 id，跨备份、合并与日记包
/// 保持不变）。行内链接沿用行内属性 `href`（与网址链接同一个键：光标、选区、
/// 输入法与撤销都不受影响，链接后接着打字也不会延长链接）；卡片块
/// `link_card` 把地址放在 `data.target`（见 diary_blocks_schema.dart）。
///
/// 为什么用地址而不另起属性：正文、剪贴板快照与备份里只多一种 `href` 取值，
/// 认不出它的旧版本也只是把它当作普通链接文字保留；导出时由
/// `ExportInline.fromAttributes` 统一去掉（文字保留），不会写出外部无法打开的
/// 地址。解析严格：只认这两种路径、id 非空且只有一段，其余一律不是日记链接。
library;

import 'diary_blocks_schema.dart';

/// 内部地址的 scheme。
const String kDiaryLinkScheme = 'jotsy';

/// 链接目标的种类；名称即地址里的第一段（`jotsy://<name>/<id>`）。
enum DiaryLinkKind {
  diary,
  notebook;

  static DiaryLinkKind? fromName(String value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// 一个日记链接的目标：种类 + 业务 id。
class DiaryLinkTarget {
  const DiaryLinkTarget(this.kind, this.id);

  const DiaryLinkTarget.diary(String diaryId)
    : this(DiaryLinkKind.diary, diaryId);

  const DiaryLinkTarget.notebook(String notebookId)
    : this(DiaryLinkKind.notebook, notebookId);

  final DiaryLinkKind kind;
  final String id;

  /// 解析内部地址；不是日记链接（网址、其他 scheme、路径不对、缺 id）时为 null。
  static DiaryLinkTarget? tryParse(Object? href) {
    if (href is! String) return null;
    final value = href.trim();
    if (!value.toLowerCase().startsWith('$kDiaryLinkScheme://')) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != kDiaryLinkScheme ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return null;
    }
    final kind = DiaryLinkKind.fromName(uri.host.toLowerCase());
    final segments = uri.pathSegments;
    if (kind == null || segments.length != 1) return null;
    final id = segments.single.trim();
    if (id.isEmpty) return null;
    return DiaryLinkTarget(kind, id);
  }

  /// 是否为日记链接的地址（不必关心目标时用）。
  static bool isLink(Object? href) => tryParse(href) != null;

  /// 写进正文的内部地址。
  String toHref() =>
      '$kDiaryLinkScheme://${kind.name}/${Uri.encodeComponent(id)}';

  /// 反向链接查询用的 LIKE 模式：在正文 JSON 里找这个地址。
  ///
  /// 地址在 JSON 里总是一个完整的字符串值（行内 `"href":"…"`、卡片
  /// `"target":"…"`），两侧带引号匹配，id 互为前缀（`abc` 与 `abcd`）时不会
  /// 误配；用户在正文里打出的同样文字会被 JSON 转义成 `\"…\"`，也不会命中。
  /// 正文 JSON 以紧凑写法存储（`encodeDiaryBlocks`），`/` 不转义。调用方须写
  /// `LIKE ? ESCAPE '\'`。
  String backlinkLikePattern() => '%"${_escapeLike(toHref())}"%';

  @override
  bool operator ==(Object other) =>
      other is DiaryLinkTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => toHref();
}

/// 日记链接卡片（[kDiaryBlockLinkCard]）的 `data`：目标地址 + 标题快照
/// （快照为空时不写）。
Map<String, Object?> diaryLinkCardData(DiaryLinkTarget target, String title) {
  final snapshot = _singleLine(title);
  return <String, Object?>{
    kDiaryLinkCardTargetKey: target.toHref(),
    if (snapshot.isNotEmpty) kDiaryLinkCardTitleKey: snapshot,
  };
}

/// 卡片 `data` 里的目标；地址缺失或认不出时为 null（卡片按“不存在”显示）。
DiaryLinkTarget? diaryLinkCardTarget(Map<String, Object?> data) =>
    DiaryLinkTarget.tryParse(data[kDiaryLinkCardTargetKey]);

/// 卡片 `data` 里的标题快照（单行、去掉首尾空白）；没有时为 null。
String? diaryLinkCardTitle(Map<String, Object?> data) {
  final raw = data[kDiaryLinkCardTitleKey];
  if (raw is! String) return null;
  final title = _singleLine(raw);
  return title.isEmpty ? null : title;
}

/// 换行折成空格：快照与插入的链接文字都只占一行。
String _singleLine(String value) =>
    value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// LIKE 的转义：`%`、`_` 与转义符本身按字面匹配。
String _escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
