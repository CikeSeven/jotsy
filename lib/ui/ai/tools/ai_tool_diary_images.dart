// 新建 / 追加日记时把对话里用户发的图片放进正文（纯函数，除了抛错不碰外部）。
//
// - 图片只能按编号（P1、P2…，`ai_chat_images.dart`）引用：编号换成那张图在
//   托管目录里的路径，写成正文的图片块，与对话消息共用同一个文件（与复制
//   粘贴共用文件同理，删了对话日记照常）。模型拿不到也写不出任意的本机
//   路径：Markdown 转换本来就不认本地图片（`escapeLocalMarkdownImages`）；
// - 正文里写 `![说明](P2)` 的图片放在那个位置：按引用把 Markdown 切成几段，
//   各段照常转换，图片块插在中间；与文字同一行时放在那一行之后。代码块与
//   行内代码里的不算；
// - `images` 里列了、正文里没放的，按顺序接在最后；同一张只放一次；
// - **写之前全部校验**：有一个编号不存在或图片已被删掉，就整次不写，并在
//   错误里列出可用的编号。

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../viewmodels/ai_chat_images.dart';
import 'ai_tool.dart';

/// 转好的正文块与其中的图片张数。
typedef AiDiaryBody = ({List<Object?> children, int images});

final RegExp _inlineImage = RegExp(
  r'!\[[^\]\n]*\]\(\s*<?\s*\[?\s*([Pp]\d{1,6})\s*\]?\s*>?\s*\)',
);
final RegExp _fence = RegExp(r'^\s*(```|~~~)');
final RegExp _codeSpan = RegExp(r'(`+)[^`\n]*?\1');

/// 把 [markdown] 与 [images]（编号）转成正文块。编号按 [chatImages] 解析。
AiDiaryBody aiDiaryBodyWithImages(
  String markdown, {
  required List<String> images,
  required List<AiChatImage> chatImages,
}) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  // 先找出正文里放图片的地方（代码块与行内代码里的不算）。
  final inline = <int, List<RegExpMatch>>{};
  var fenced = false;
  for (final (index, line) in lines.indexed) {
    if (_fence.hasMatch(line)) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final spans = [
      for (final m in _codeSpan.allMatches(line)) (m.start, m.end),
    ];
    final matches = [
      for (final match in _inlineImage.allMatches(line))
        if (!spans.any(
          (span) => match.start >= span.$1 && match.end <= span.$2,
        ))
          match,
    ];
    if (matches.isNotEmpty) inline[index] = matches;
  }

  // 全部编号先校验，不留半截改动。
  final wanted = <String>[
    for (final matches in inline.values)
      for (final match in matches) match.group(1)!,
    ...images,
  ];
  final resolved = <String, String>{};
  final problems = <String>[];
  for (final raw in wanted) {
    final ref = aiNormalizeImageRef(raw);
    final image = ref == null ? null : aiChatImageByRef(chatImages, ref);
    if (image == null) {
      problems.add('$raw is not a photo in this chat');
    } else if (image.removed) {
      problems.add('${image.ref} was deleted by the user');
    } else {
      resolved[raw] = image.path;
    }
  }
  if (problems.isNotEmpty) {
    final available = [
      for (final image in chatImages)
        if (!image.removed) image.ref,
    ];
    throw AiToolFailure(
      '${problems.join('; ')}. Nothing was written. '
      '${available.isEmpty ? 'This chat has no photos.' : 'Photos in this chat: ${available.join(', ')}.'}',
    );
  }

  final children = <Object?>[];
  final placed = <String>{};
  final pending = StringBuffer();
  void flush() {
    final text = pending.toString();
    pending.clear();
    if (text.trim().isEmpty) return;
    final document = aiMarkdownDiaryDocument(text)['document']! as Map;
    children.addAll(document['children']! as List);
  }

  void addImage(String raw) {
    final path = resolved[raw]!;
    if (!placed.add(path)) return;
    children.add(<String, Object?>{
      kDiaryBlockTypeKey: kDiaryBlockImage,
      kDiaryBlockDataKey: <String, Object?>{kDiaryBlockUrlKey: path},
    });
  }

  for (final (index, line) in lines.indexed) {
    final matches = inline[index];
    if (matches == null) {
      pending.writeln(line);
      continue;
    }
    final rest = _withoutMatches(line, matches).trimRight();
    if (rest.trim().isNotEmpty) pending.writeln(rest);
    flush();
    for (final match in matches) {
      addImage(match.group(1)!);
    }
  }
  flush();
  for (final raw in images) {
    addImage(raw);
  }
  return (children: children, images: placed.length);
}

/// 去掉一行里放图片的语法；两侧都是空格时只留一个，不留双空格。
String _withoutMatches(String line, List<RegExpMatch> matches) {
  final out = StringBuffer();
  var from = 0;
  for (final match in matches) {
    out.write(line.substring(from, match.start));
    from = match.end;
    if (out.toString().endsWith(' ') &&
        from < line.length &&
        line[from] == ' ') {
      from++;
    }
  }
  out.write(line.substring(from));
  return out.toString();
}
