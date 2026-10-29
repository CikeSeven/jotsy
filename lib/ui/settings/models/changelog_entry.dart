import 'package:flutter/foundation.dart';

import '../../../core/services/app_update_version.dart';
import '../../../core/services/release_notes_catalog.dart';

/// 更新日志里的一个版本：开头的要点在卡片上常显，其余章节展开后才显示。
@immutable
class ChangelogEntry {
  const ChangelogEntry({
    required this.tag,
    required this.version,
    required this.highlights,
    required this.details,
  });

  factory ChangelogEntry.fromNotes(BundledReleaseNotes notes) {
    final split = splitReleaseHighlights(notes.markdown);
    return ChangelogEntry(
      tag: notes.tag,
      version: notes.version,
      highlights: split.highlights,
      details: split.details,
    );
  }

  /// 说明文件名里的版本标记，在页面里唯一（展开状态按它记录）。
  final String tag;
  final AppVersion version;

  /// 常显的要点（Markdown）。
  final String highlights;

  /// 展开后接在要点下面的其余章节（Markdown）；为空时不显示“展开全部”。
  final String details;

  /// 卡片标题：只写版本名，不带构建号（早期文件名带构建号，tag 不一定带）。
  String get title => 'v${version.name}';

  bool get hasDetails => details.isNotEmpty;
}

/// 把一篇更新说明拆成常显的要点与其余章节。
///
/// 本项目的说明都以“版本要点 / Highlights”这类二级标题开头，所以：
/// - 第一个一、二级标题之前有正文时，那段正文就是要点，标题起的全部是其余
///   章节；
/// - 否则第一节（不含标题本身，卡片标题已是版本号）是要点，第二个一、二级
///   标题起的全部是其余章节；
/// - 没有一、二级标题（如 v0.5.1 只有一个列表），或第一节没有正文时，整篇
///   都作要点、不再展开。
/// 代码块里以 `#` 开头的行不算标题。
({String highlights, String details}) splitReleaseHighlights(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final headings = <int>[];
  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
    } else if (!inFence && _sectionHeading.hasMatch(lines[i])) {
      headings.add(i);
    }
  }
  String join(int start, [int? end]) =>
      lines.sublist(start, end).join('\n').trim();

  final whole = markdown.trim();
  if (headings.isEmpty) {
    return (highlights: whole, details: '');
  }
  final preamble = join(0, headings.first);
  if (preamble.isNotEmpty) {
    return (highlights: preamble, details: join(headings.first));
  }
  final next = headings.length > 1 ? headings[1] : null;
  final first = join(headings.first + 1, next);
  if (first.isEmpty) {
    return (highlights: whole, details: '');
  }
  return (highlights: first, details: next == null ? '' : join(next));
}

/// 一、二级标题（ATX 写法，`#` 之后至少一个空格）。
final RegExp _sectionHeading = RegExp(r'^#{1,2}\s');
