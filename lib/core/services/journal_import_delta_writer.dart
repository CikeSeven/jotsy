import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';

/// 根据正文中的媒体引用（图片 src、Day One 的 `dayone-moment://` 等）返回
/// 本应用的嵌入数据，如 `{'image': 路径}`；无法解析或文件缺失时返回 null，
/// 该引用被丢弃。
typedef JournalEmbedResolver = Map<String, Object?>? Function(String source);

/// 把导入正文组装成本应用的 Delta JSON 与纯文本镜像。
///
/// 以“行”为单位积累：行内片段先缓存，行结束时才连同块级属性（标题、列表、
/// 缩进、引用、代码块）一起写出。这样可以：
/// - 去掉每行首尾因 HTML 排版产生的空白（代码块除外）；
/// - 让图片、视频、录音、附件始终独占一行，与编辑器插入媒体的结构一致
///   （见 insertDiaryImages / insertDiaryMediaBlocks）；
/// - 最后去掉文档首尾的空行。
///
/// 纯文本镜像与 Document.toPlainText 的规则一致：嵌入物不计文本，只留换行。
/// 只是内存中的组装，不做 IO，可在后台 isolate 中使用。
class JournalDeltaWriter {
  final List<_Line> _lines = <_Line>[];
  final List<_Segment> _pending = <_Segment>[];

  /// 当前行是否已有非空白文本。
  bool get lineHasContent =>
      _pending.any((segment) => segment.text.trim().isNotEmpty);

  /// 已写出的行数（含媒体行），调用方据此判断某个块是否产出过内容。
  int get lineCount => _lines.length;

  /// 当前行是否以空白结尾（或尚无内容），供 HTML 合并相邻空白。
  bool get endsWithSpace =>
      _pending.isEmpty || _pending.last.text.endsWith(' ');

  void text(String value, [Map<String, Object?> attributes = const {}]) {
    if (value.isEmpty) return;
    _pending.add(_Segment(value, attributes));
  }

  /// 结束当前行（即使为空，用于 `<br>` 与空段落）。
  void endLine([Map<String, Object?> blockAttributes = const {}]) {
    final segments = blockAttributes.containsKey('code-block')
        ? List<_Segment>.of(_pending)
        : _trimmed(_pending);
    _lines.add(_Line.text(segments, blockAttributes));
    _pending.clear();
  }

  /// 当前行有文本时结束它，否则丢弃只含空白的片段，不产生空行。
  void closeLine([Map<String, Object?> blockAttributes = const {}]) {
    if (lineHasContent) {
      endLine(blockAttributes);
    } else {
      _pending.clear();
    }
  }

  /// 插入独占一行的媒体；当前行的文本先以 [blockAttributes] 结束。
  void embed(
    Map<String, Object?> data, [
    Map<String, Object?> blockAttributes = const {},
  ]) {
    closeLine(blockAttributes);
    _lines.add(_Line.embed(data));
  }

  ({String contentJson, String contentText}) build() {
    closeLine();
    var start = 0;
    var end = _lines.length;
    while (start < end && _lines[start].isBlank) {
      start++;
    }
    while (end > start && _lines[end - 1].isBlank) {
      end--;
    }
    final delta = Delta();
    final plain = StringBuffer();
    for (final line in _lines.sublist(start, end)) {
      final embed = line.embed;
      if (embed != null) {
        delta.insert(embed);
        delta.insert('\n');
        plain.write('\n');
        continue;
      }
      for (final segment in line.segments) {
        delta.insert(
          segment.text,
          segment.attributes.isEmpty ? null : segment.attributes,
        );
        plain.write(segment.text);
      }
      delta.insert(
        '\n',
        line.blockAttributes.isEmpty ? null : line.blockAttributes,
      );
      plain.write('\n');
    }
    if (delta.isEmpty) delta.insert('\n');
    return (
      contentJson: jsonEncode(delta.toJson()),
      contentText: plain.toString().trimRight(),
    );
  }

  /// 去掉行首与行尾的空格/制表符，必要时整段丢弃只含空白的片段。
  static List<_Segment> _trimmed(List<_Segment> segments) {
    final result = List<_Segment>.of(segments);
    while (result.isNotEmpty) {
      final text = result.first.text.trimLeft();
      if (text.isNotEmpty) {
        result[0] = _Segment(text, result.first.attributes);
        break;
      }
      result.removeAt(0);
    }
    while (result.isNotEmpty) {
      final text = result.last.text.trimRight();
      if (text.isNotEmpty) {
        result[result.length - 1] = _Segment(text, result.last.attributes);
        break;
      }
      result.removeLast();
    }
    return result;
  }
}

/// 把纯文本按行写入 [writer]，保留空行。
void appendJournalPlainText(JournalDeltaWriter writer, String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  for (final line in lines) {
    writer.text(line.replaceAll('\u00a0', ' '));
    writer.endLine();
  }
}

class _Segment {
  const _Segment(this.text, this.attributes);

  final String text;
  final Map<String, Object?> attributes;
}

class _Line {
  const _Line.text(this.segments, this.blockAttributes) : embed = null;

  const _Line.embed(Map<String, Object?> this.embed)
    : segments = const <_Segment>[],
      blockAttributes = const <String, Object?>{};

  final List<_Segment> segments;
  final Map<String, Object?> blockAttributes;
  final Map<String, Object?>? embed;

  /// 没有文本、没有媒体、也没有块级格式的空行，文档首尾的这种行会被去掉。
  bool get isBlank =>
      embed == null && segments.isEmpty && blockAttributes.isEmpty;
}
