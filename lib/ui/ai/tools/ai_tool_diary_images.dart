// 智能体把对话里用户发的图片写进日记正文（新建与修改共用；纯函数，除了
// 抛错不碰外部）。
//
// - 图片只能按编号（P1、P2…，`ai_chat_images.dart`）引用：编号换成那张图在
//   托管目录里的路径，写成正文的图片块，与对话消息共用同一个文件（与复制
//   粘贴共用文件同理，删了对话日记照常）。模型拿不到也写不出任意的本机
//   路径：正文写法里别的 `![](…)` 一律不成图片；
// - 一行里写 `![说明](P2)` 的图片放在那一行之后（单独一行时就在那个位置），
//   行内代码里的不算（代码块里的行根本不经过这里）；
// - 同一次写入里同一张只放一次；
// - **写之前全部校验**：有一个编号不存在或图片已被删掉，就整次不写，并在
//   错误里列出全部问题与可用的编号（[AiChatPhotoRefs.check]）。

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../viewmodels/ai_chat_images.dart';
import 'ai_tool.dart';

final RegExp _inlineImage = RegExp(
  r'!\[[^\]\n]*\]\(\s*<?\s*\[?\s*([Pp]\d{1,6})\s*\]?\s*>?\s*\)',
);
final RegExp _codeSpan = RegExp(r'(`+)[^`\n]*?\1');

/// 一行里引用的对话图片：去掉图片写法后的文字与按顺序的编号（原样，如
/// `p1`、`[P2]`）。没有引用时 [refs] 为空、[rest] 为原文。
({String rest, List<String> refs}) aiChatPhotoRefsInLine(String line) {
  final spans = [for (final m in _codeSpan.allMatches(line)) (m.start, m.end)];
  final matches = [
    for (final match in _inlineImage.allMatches(line))
      if (!spans.any((span) => match.start >= span.$1 && match.end <= span.$2))
        match,
  ];
  if (matches.isEmpty) return (rest: line, refs: const <String>[]);
  return (
    rest: _withoutMatches(line, matches),
    refs: [for (final match in matches) match.group(1)!],
  );
}

final RegExp _anyImage = RegExp(r'!\[[^\]\n]*\]\([^)\n]*\)');

/// 一行（已去掉对话图片）里还有没有别的图片写法 `![…](…)`（行内代码里的
/// 不算）：本机路径与网址都不能成图片，整次不写并告诉模型，免得悄悄丢字。
bool aiHasOtherImageSyntax(String line) {
  final spans = [for (final m in _codeSpan.allMatches(line)) (m.start, m.end)];
  return _anyImage
      .allMatches(line)
      .any(
        (match) => !spans.any(
          (span) => match.start >= span.$1 && match.end <= span.$2,
        ),
      );
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

/// 一次写入里对话图片的解析：按编号换成图片块，记下问题，同一张只放一次。
class AiChatPhotoRefs {
  AiChatPhotoRefs(this.chatImages);

  final List<AiChatImage> chatImages;
  final List<String> _problems = <String>[];
  final Set<String> _placed = <String>{};

  /// 这次放进正文的图片张数。
  int get placed => _placed.length;

  /// 编号 [raw] 对应的图片块；编号不对、图片已删或这次已经放过时为 null
  /// （前两种记进问题，由 [check] 统一报错）。
  Map<String, Object?>? imageBlock(String raw) {
    final ref = aiNormalizeImageRef(raw);
    final image = ref == null ? null : aiChatImageByRef(chatImages, ref);
    if (image == null) {
      _problems.add('$raw is not a photo in this chat');
      return null;
    }
    if (image.removed) {
      _problems.add('${image.ref} was deleted by the user');
      return null;
    }
    if (!_placed.add(image.path)) return null;
    return <String, Object?>{
      kDiaryBlockTypeKey: kDiaryBlockImage,
      kDiaryBlockDataKey: <String, Object?>{kDiaryBlockUrlKey: image.path},
    };
  }

  /// 有问题时抛 [AiToolFailure]（列出全部问题与可用的编号）；写库之前调用。
  void check() {
    if (_problems.isEmpty) return;
    final available = [
      for (final image in chatImages)
        if (!image.removed) image.ref,
    ];
    throw AiToolFailure(
      '${_problems.toSet().join('; ')}. Nothing was written. '
      '${available.isEmpty ? 'This chat has no photos.' : 'Photos in this chat: ${available.join(', ')}.'}',
    );
  }
}
