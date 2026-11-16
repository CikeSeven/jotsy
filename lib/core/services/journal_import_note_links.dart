import 'package:path/path.dart' as p;

import '../database/diary_blocks/diary_link_target.dart';
import 'journal_import_files.dart';

/// Markdown 笔记导出（Obsidian 库、Bear、Notion、Typora…）里笔记之间的链接
/// → 导入后的日记链接（`jotsy://diary/<diaryId>`，见 [DiaryLinkTarget]）。
///
/// 为什么解析阶段就能写出目标：导入日记的 diaryId 由“来源 + 稳定键”确定性
/// 生成（`journalImportDiaryId`），Markdown 笔记的稳定键是文件在导出中的
/// 相对路径、天然唯一（不会被 `JournalKeyRegistry` 加后缀），所以拿到全部
/// 笔记的路径清单就知道每篇导入后的 id。合并导入按 diaryId 匹配、从不改 id：
/// 目标在本机已存在而被“跳过”时，链接同样指向本机那篇；再次导入并覆盖，
/// 旧版导入只留了文字的双链也会变成链接。
///
/// 只认这次导出里的笔记：库里没有的（Obsidian 允许指向尚未创建的笔记）、
/// 指向附件或网址的不算，调用方保留文字。
class JournalNoteLinkIndex {
  /// [notes] 是导出里的全部笔记：文件路径、按来源规整过的名字（Bear 的
  /// TextBundle 取包名、Notion 去掉 ID，见 markdown 文件导入）与导入后的
  /// diaryId；[root] 是导出根目录。
  JournalNoteLinkIndex({
    required String root,
    required Iterable<({String path, String stem, String diaryId})> notes,
  }) {
    final base = p.normalize(p.absolute(root));
    for (final note in notes) {
      final absolute = p.normalize(p.absolute(note.path));
      final relative = p.posix.joinAll(
        p.split(p.relative(absolute, from: base)),
      );
      final entry = _Note(
        target: DiaryLinkTarget.diary(note.diaryId),
        relative: relative,
        key: p.posix.withoutExtension(relative).toLowerCase(),
        name: p.posix.basenameWithoutExtension(relative).toLowerCase(),
        stem: note.stem.toLowerCase(),
      );
      for (final name in {entry.name, entry.stem}) {
        (_byName[name] ??= <_Note>[]).add(entry);
      }
      _byFile[absolute] = entry;
      _targets.add(entry.target);
    }
  }

  /// 文件名与规整后的名字（小写）→ 笔记：每个双链只看同名的几篇，几千篇
  /// 笔记、上万个链接的库也不必逐篇比较。
  final Map<String, List<_Note>> _byName = <String, List<_Note>>{};
  final Map<String, _Note> _byFile = <String, _Note>{};
  final Set<DiaryLinkTarget> _targets = <DiaryLinkTarget>{};

  /// Obsidian 双链 `[[linkPath]]`（已去掉 `#标题` 与 `|别名`）的目标，口径与
  /// Obsidian 的链接解析一致，不区分大小写，`.md` 扩展名可写可不写：
  /// - `./`、`../` 开头：相对 [from] 所在文件夹（“基于当前笔记的相对路径”）；
  /// - 含 `/`：库内路径，按路径结尾匹配（导出外面多包的一层文件夹不影响）；
  /// - 只有名字：按文件名匹配，Bear / Notion 另认规整后的名字。
  ///
  /// 同名的有多篇时取与 [from] 同一文件夹的，再取路径最短的（Obsidian
  /// “尽可能简短”的写法就是在名字不唯一时才带上路径），仍并列按路径排序，
  /// 保证每次导入结果相同。
  DiaryLinkTarget? wikiTarget(String linkPath, {required String from}) {
    var path = linkPath.trim().replaceAll(r'\', '/');
    if (journalNoteExtensions.contains(_extension(path))) {
      path = p.posix.withoutExtension(path);
    }
    path = path.toLowerCase();
    final source = _byFile[p.normalize(p.absolute(from))];
    if (path.isEmpty || path == '/') return null;
    final named = _byName[p.posix.basename(path)] ?? const <_Note>[];
    final Iterable<_Note> candidates;
    if (path.startsWith('./') || path.startsWith('../')) {
      if (source == null) return null;
      final resolved = p.posix.normalize(
        p.posix.join(p.posix.dirname(source.key), path),
      );
      candidates = named.where((note) => note.key == resolved);
    } else if (path.contains('/')) {
      final suffix = path.replaceFirst(RegExp('^/+'), '');
      candidates = named.where(
        (note) => note.key == suffix || note.key.endsWith('/$suffix'),
      );
    } else {
      candidates = named;
    }
    return _closest(candidates.toList(), source)?.target;
  }

  /// 普通 Markdown 链接 `[文字](href)` 的目标：
  /// - 双链改写后写出的日记链接地址（[rewriteJournalWikiLinks]），只认这次
  ///   导入里的笔记；
  /// - 指向导出里另一篇笔记的路径（Obsidian 关闭“使用 Wiki 链接”时的
  ///   `笔记.md`、Notion 的 `标题%20<ID>.md`，可带 `#标题`），按 [files]
  ///   的口径查找（相对路径优先，再按唯一的文件名）。
  DiaryLinkTarget? markdownTarget(
    String href, {
    required String from,
    required JournalImportFiles files,
  }) {
    final internal = DiaryLinkTarget.tryParse(href);
    if (internal != null) return _targets.contains(internal) ? internal : null;
    final path = files.resolve(href, from: p.dirname(from));
    return path == null ? null : _byFile[path]?.target;
  }

  static _Note? _closest(List<_Note> candidates, _Note? source) {
    if (candidates.length <= 1) return candidates.firstOrNull;
    final folder = source == null ? null : p.posix.dirname(source.key);
    final sorted = [...candidates]
      ..sort((a, b) {
        final aNear = p.posix.dirname(a.key) == folder;
        final bNear = p.posix.dirname(b.key) == folder;
        if (aNear != bNear) return aNear ? -1 : 1;
        final depth = a.relative
            .split('/')
            .length
            .compareTo(b.relative.split('/').length);
        return depth != 0 ? depth : a.relative.compareTo(b.relative);
      });
    return sorted.first;
  }
}

class _Note {
  const _Note({
    required this.target,
    required this.relative,
    required this.key,
    required this.name,
    required this.stem,
  });

  final DiaryLinkTarget target;

  /// 相对导出根目录的路径（`/` 分隔，保留大小写与扩展名）。
  final String relative;

  /// [relative] 去掉扩展名、转小写：路径匹配用。
  final String key;

  /// 文件名（不含扩展名，小写）。
  final String name;

  /// 按来源规整过的名字（小写）。
  final String stem;
}

/// 笔记文件的扩展名（Markdown 与纯文本）。
const Set<String> journalNoteExtensions = {'md', 'markdown', 'mdown', 'txt'};

String _extension(String path) =>
    p.posix.extension(path).toLowerCase().replaceFirst('.', '');

/// 把 Obsidian 双链改写成标准 Markdown，交给 `JournalMarkdownConverter`：
///
/// - `[[笔记]]`、`[[笔记|别名]]`、`[[笔记#标题]]`：[resolve] 认出目标时写成
///   指向日记链接地址的 Markdown 链接，否则只留文字。文字取别名，没有时取
///   链接里写的笔记名（带 `#标题` 时只取笔记名；只有 `#标题`、指向本篇的取
///   标题）。表格里转义的 `\|` 同样认作别名分隔；
/// - `![[图片.png|300]]`：改写为图片语法（尺寸丢掉），附件照常查找；
/// - `![[笔记]]`（嵌入整篇笔记）：认出目标时写成图片语法、地址为日记链接，
///   转换器据此写成日记链接卡片；认不出只留笔记名。
///
/// [resolve] 为 null 时一律只留文字（如把标题行里的双链取成纯文本）。代码
/// 围栏与行内代码里不改写。
String rewriteJournalWikiLinks(
  String markdown, {
  DiaryLinkTarget? Function(String linkPath)? resolve,
}) {
  String? fence;
  return markdown
      .split('\n')
      .map((line) {
        final opening = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(line);
        if (fence != null) {
          if (line.trimLeft().startsWith(fence!)) fence = null;
          return line;
        }
        if (opening != null) {
          fence = opening.group(1)!.substring(0, 3);
          return line;
        }
        return line.replaceAllMapped(_codeOrWikiLink, (match) {
          if (match.group(1) != null) return match.group(0)!;
          final inner = match.group(3)!;
          return match.group(2)!.isEmpty
              ? _link(inner, resolve)
              : _embed(inner, resolve);
        });
      })
      .join('\n');
}

/// 行内代码（第 1 组为反引号串，原样保留）或双链（第 2 组为 `!`，第 3 组为
/// 方括号里的内容）。
final RegExp _codeOrWikiLink = RegExp(r'(`+).*?\1|(!?)\[\[([^\[\]\n]+?)\]\]');

String _link(String inner, DiaryLinkTarget? Function(String)? resolve) {
  final bar = inner.indexOf('|');
  var link = bar < 0 ? inner : inner.substring(0, bar);
  if (link.endsWith(r'\')) link = link.substring(0, link.length - 1);
  final hash = link.indexOf('#');
  final path = (hash < 0 ? link : link.substring(0, hash)).trim();
  final alias = bar < 0 ? '' : inner.substring(bar + 1).trim();
  final text = alias.isNotEmpty
      ? alias
      : path.isNotEmpty
      ? path
      : link.substring(hash + 1).replaceFirst(RegExp(r'^\^'), '').trim();
  final target = path.isEmpty ? null : resolve?.call(path);
  if (target == null || text.isEmpty) return text;
  return '[${_escapeLinkText(text)}](${target.toHref()})';
}

String _embed(String inner, DiaryLinkTarget? Function(String)? resolve) {
  final target = inner.split('|').first.split(RegExp('[#^]')).first.trim();
  if (target.isEmpty) return '';
  // 先认笔记：名字里带点的笔记（`v1.2 计划`）也有“扩展名”。
  final note = resolve?.call(target);
  if (note != null) return '![${_escapeLinkText(target)}](${note.toHref()})';
  final extension = _extension(target);
  // 带扩展名、又不是笔记的是附件（图片、PDF、录音…），照常查找。
  if (extension.isNotEmpty && !journalNoteExtensions.contains(extension)) {
    final source = Uri.encodeFull(
      target,
    ).replaceAll('(', '%28').replaceAll(')', '%29');
    return '![]($source)';
  }
  return target;
}

/// Markdown 链接文字里的方括号与反斜杠按字面保留。
String _escapeLinkText(String text) =>
    text.replaceAllMapped(RegExp(r'[\\\[\]]'), (match) => '\\${match[0]}');
