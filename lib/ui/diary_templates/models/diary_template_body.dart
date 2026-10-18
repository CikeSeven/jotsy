import '../../../core/database/divider_embed_codec.dart';

/// 模板正文（Quill Delta）的白名单清洗、内置模板的块描述与编译。
///
/// 模板会被分享（模板码）、随备份到另一台设备，也会从日记“另存为模板”，
/// 正文里绝不能带图片、录音、视频、附件这类指向本机私有文件的嵌入。所以
/// 一律按**白名单**清洗：只留文字和分隔线，其余嵌入（含将来新增、这里还
/// 不认识的种类）全部丢弃。保存、导入模板码、读出数据库行、另存为模板四处
/// 都经过 [sanitizeDiaryTemplateOps]。

/// 清洗后的空正文。
const List<Map<String, Object?>> emptyDiaryTemplateOps = <Map<String, Object?>>[
  <String, Object?>{'insert': '\n'},
];

/// 只保留文字与分隔线的 insert 操作，并保证以换行结尾（Quill 文档的要求）。
///
/// 被丢弃的嵌入独占一行时（图片、录音通常如此），连同它那一行的换行一起
/// 去掉，不在正文里留下一串空行。[raw] 不是列表时返回空正文。
List<Map<String, Object?>> sanitizeDiaryTemplateOps(Object? raw) {
  if (raw is! List) return emptyDiaryTemplateOps;
  final result = <Map<String, Object?>>[];
  // 输出是否停在行首：用来判断被丢弃的嵌入是否独占一行。
  var atLineStart = true;
  var dropNextNewline = false;
  for (final op in raw) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final attributes = _attributes(op['attributes']);
    if (insert is String) {
      var text = insert;
      if (dropNextNewline && text.startsWith('\n')) {
        text = text.substring(1);
      }
      dropNextNewline = false;
      if (text.isEmpty) continue;
      result.add(<String, Object?>{
        'insert': text,
        if (attributes != null) 'attributes': attributes,
      });
      atLineStart = text.endsWith('\n');
    } else if (insert is Map && insert.containsKey(diaryDividerEmbedType)) {
      dropNextNewline = false;
      result.add(<String, Object?>{
        'insert': Map<String, Object?>.of(diaryDividerEmbed),
        if (attributes != null) 'attributes': attributes,
      });
      atLineStart = false;
    } else {
      dropNextNewline = atLineStart;
    }
  }
  if (result.isEmpty) return emptyDiaryTemplateOps;
  final last = result.last['insert'];
  if (last is! String || !last.endsWith('\n')) {
    result.add(<String, Object?>{'insert': '\n'});
  }
  return result;
}

/// 文字属性原样保留（粗体、颜色、标题级别、列表、引用、链接等都只是格式），
/// 只要求是字符串键的 Map。
Map<String, Object?>? _attributes(Object? raw) {
  if (raw is! Map || raw.isEmpty) return null;
  return <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

/// 套用后光标该停的位置：第一个空行的行首；没有空行时停在正文末尾。
///
/// 按纯文本计算（嵌入在纯文本里占一个字符，与 Quill 的偏移一致）。模板里的
/// 小标题下面通常跟着一个空段落，光标落在那里就能直接开始写。
int firstEmptyLineOffset(String plainText) {
  for (var i = 0; i < plainText.length; i++) {
    if (plainText.codeUnitAt(i) == 0x0A &&
        (i == 0 || plainText.codeUnitAt(i - 1) == 0x0A)) {
      return i;
    }
  }
  return plainText.isEmpty ? 0 : plainText.length - 1;
}

/// 内置模板正文的块描述，由 [compileDiaryTemplateBlocks] 编译为 Delta。
///
/// 内置模板的文字来自 ARB，按界面语言生成；块描述让每个模板的结构一目
/// 了然，也保证中英文两版的结构完全一致。块里的文字都是单行，换行会被
/// 折成空格。
sealed class DiaryTemplateBlock {
  const DiaryTemplateBlock();
}

/// 小标题（默认二级）。
final class TplHeading extends DiaryTemplateBlock {
  const TplHeading(this.text, {this.level = 2});

  final String text;
  final int level;
}

/// 普通段落；不给文字就是一个空行，留给用户书写。
final class TplParagraph extends DiaryTemplateBlock {
  const TplParagraph([this.text = '']);

  final String text;
}

/// 无序列表，每项一行；空字符串是待填写的空项。
final class TplBullets extends DiaryTemplateBlock {
  const TplBullets(this.items);

  final List<String> items;
}

/// 有序列表。
final class TplNumbered extends DiaryTemplateBlock {
  const TplNumbered(this.items);

  final List<String> items;
}

/// 待办（未勾选）。
final class TplChecklist extends DiaryTemplateBlock {
  const TplChecklist(this.items);

  final List<String> items;
}

/// 引用。
final class TplQuote extends DiaryTemplateBlock {
  const TplQuote([this.text = '']);

  final String text;
}

/// 分隔线。
final class TplDivider extends DiaryTemplateBlock {
  const TplDivider();
}

/// 把块描述编译为 Delta 操作列表（已是白名单内的内容）。
///
/// 不复用导入用的 `JournalDeltaWriter`：它会裁掉首尾空行，而模板正是靠这些
/// 空行给用户留出书写的位置。
List<Map<String, Object?>> compileDiaryTemplateBlocks(
  List<DiaryTemplateBlock> blocks,
) {
  final ops = <Map<String, Object?>>[];
  void line(String text, [Map<String, Object?>? attributes]) {
    final single = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (single.isNotEmpty) ops.add(<String, Object?>{'insert': single});
    ops.add(<String, Object?>{
      'insert': '\n',
      if (attributes != null) 'attributes': attributes,
    });
  }

  for (final block in blocks) {
    switch (block) {
      case TplHeading(:final text, :final level):
        line(text, <String, Object?>{'header': level});
      case TplParagraph(:final text):
        line(text);
      case TplBullets(:final items):
        for (final item in items) {
          line(item, <String, Object?>{'list': 'bullet'});
        }
      case TplNumbered(:final items):
        for (final item in items) {
          line(item, <String, Object?>{'list': 'ordered'});
        }
      case TplChecklist(:final items):
        for (final item in items) {
          line(item, <String, Object?>{'list': 'unchecked'});
        }
      case TplQuote(:final text):
        line(text, <String, Object?>{'blockquote': true});
      case TplDivider():
        ops.add(<String, Object?>{
          'insert': Map<String, Object?>.of(diaryDividerEmbed),
        });
        ops.add(<String, Object?>{'insert': '\n'});
    }
  }
  return ops.isEmpty ? emptyDiaryTemplateOps : ops;
}
