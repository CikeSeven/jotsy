import '../database/diary_blocks/diary_blocks_codec.dart';
import 'journal_import_blocks.dart';

/// 根据正文中的媒体引用（图片 src、Day One 的 `dayone-moment://` 等）返回
/// 本应用的嵌入数据，如 `{'image': 路径}`；无法解析或文件缺失时返回 null，
/// 该引用被丢弃。
typedef JournalEmbedResolver = Map<String, Object?>? Function(String source);

/// 把导入正文组装成块文档 JSON 与纯文本镜像。
///
/// 以“行”为单位积累：行内片段先缓存，行结束时才连同块级属性（标题、列表、
/// 缩进、引用、代码块）一起写出。这样可以：
/// - 去掉每行首尾因 HTML 排版产生的空白（代码块除外）；
/// - 让图片、视频、录音、附件始终独占一行，与编辑器插入媒体的结构一致
///   （见 insertDiaryImages / insertDiaryMediaBlocks）；
/// - 最后去掉文档首尾的空行。
///
/// 块级属性沿用 Quill 的写法（`header`、`list`、`indent`、`blockquote`、
/// `code-block`、`align`），另有两种本应用的结构：
/// - 折叠列表：标题行带 `toggle: true` 与 `collapsed`（bool，是否收起），
///   折叠的内容是后面 `indent` 比它多一级的行（与列表嵌套同一规则，见
///   DiaryBlocksBuilder）；
/// - 调用方整个建好的结构块（如表格，含格子与格内段落）经 [node] 写入，
///   独占一行，不再拆分。
///
/// 纯文本镜像与 Document.toPlainText 的规则一致：嵌入物不计文本，只留换行。
/// 只是内存中的组装，不做 IO，可在后台 isolate 中使用。
class JournalBlockWriter {
  JournalBlockWriter({this.preserveWhitespace = false});

  /// 纯文本导出中的缩进、空行和尾随空格也是正文，不按 HTML 排版清理。
  final bool preserveWhitespace;
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
    final segments =
        preserveWhitespace || blockAttributes.containsKey('code-block')
        ? List<_Segment>.of(_pending)
        : _trimmed(_pending);
    _lines.add(_Line.text(segments, blockAttributes));
    _pending.clear();
  }

  /// 当前行有文本时结束它，否则丢弃只含空白的片段，不产生空行。
  void closeLine([Map<String, Object?> blockAttributes = const {}]) {
    if (lineHasContent || (preserveWhitespace && _pending.isNotEmpty)) {
      endLine(blockAttributes);
    } else {
      _pending.clear();
    }
  }

  /// 插入独占一行的媒体；当前行的文本先以 [blockAttributes] 结束。
  ///
  /// [embedAttributes] 写在媒体行的换行符上，目前只用于图片的对齐
  /// （`align`），编辑器据此决定比列宽窄的图片靠哪一侧。
  void embed(
    Map<String, Object?> data, [
    Map<String, Object?> blockAttributes = const {},
    Map<String, Object?> embedAttributes = const {},
  ]) {
    closeLine(blockAttributes);
    _lines.add(_Line.embed(data, embedAttributes));
  }

  /// 插入调用方建好的结构块 [node]（如整个表格：格子与格内段落都已建好），
  /// 独占一行、原样进入文档；当前行的文本先以 [blockAttributes] 结束。节点
  /// 与当前块同级：层级取 [blockAttributes] 的 `indent`，其余块属性不作用
  /// 于它。节点自身的结构由调用方保证（表格应能通过 DiaryTableGrid 校验），
  /// 这里不做检查。
  void node(
    Map<String, Object?> node, [
    Map<String, Object?> blockAttributes = const {},
  ]) {
    closeLine(blockAttributes);
    final indent = blockAttributes['indent'];
    _lines.add(
      _Line.node(node, {if (indent is int && indent > 0) 'indent': indent}),
    );
  }

  ({String contentJson, String contentText}) build() {
    final document = buildDocument();
    return (
      contentJson: encodeDiaryBlocks(document),
      contentText: diaryBlocksPlainText(document),
    );
  }

  /// 与 [build] 相同，但直接返回块文档（未编码），供需要再加工节点的调用方
  /// （如把一格表格内容写成格内段落）使用。
  Map<String, Object?> buildDocument() {
    closeLine();
    var start = 0;
    var end = _lines.length;
    while (!preserveWhitespace && start < end && _lines[start].isBlank) {
      start++;
    }
    while (!preserveWhitespace && end > start && _lines[end - 1].isBlank) {
      end--;
    }
    return buildJournalImportBlocks([
      for (final line in _lines.sublist(start, end))
        (
          delta: [
            for (final segment in line.segments)
              {
                'insert': segment.text,
                if (segment.attributes.isNotEmpty)
                  'attributes': segment.attributes,
              },
          ],
          attributes: line.blockAttributes,
          embed: line.embed,
          node: line.node,
        ),
    ]);
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
void appendJournalPlainText(JournalBlockWriter writer, String text) {
  var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // Delta 已要求最后一个换行。纯文本保留模式只补必要的终止符，不能把
  // 原有的终止换行当作额外空段落再写一次。
  if (writer.preserveWhitespace && normalized.endsWith('\n')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final lines = normalized.split('\n');
  for (final line in lines) {
    writer.text(line);
    writer.endLine();
  }
}

class _Segment {
  const _Segment(this.text, this.attributes);

  final String text;
  final Map<String, Object?> attributes;
}

class _Line {
  const _Line.text(this.segments, this.blockAttributes)
    : embed = null,
      node = null;

  const _Line.embed(Map<String, Object?> this.embed, this.blockAttributes)
    : segments = const <_Segment>[],
      node = null;

  const _Line.node(Map<String, Object?> this.node, this.blockAttributes)
    : segments = const <_Segment>[],
      embed = null;

  final List<_Segment> segments;
  final Map<String, Object?> blockAttributes;
  final Map<String, Object?>? embed;

  /// 调用方建好的结构块（见 JournalBlockWriter.node）。
  final Map<String, Object?>? node;

  /// 没有文本、没有媒体、也没有块级格式的空行，文档首尾的这种行会被去掉。
  bool get isBlank =>
      embed == null &&
      node == null &&
      segments.isEmpty &&
      blockAttributes.isEmpty;
}
