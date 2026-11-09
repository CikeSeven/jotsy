// 流式 Markdown 的增量解析：AI 回答一边生成一边显示，文字每帧都在变长。
//
// 输入：不断变长的同一段 Markdown（每次给全文）。
// 输出：与 `parseReleaseNotes(全文)` 同样的扁平块列表，但前面已经“定稿”的
//       块保持同一个对象，只有末尾还在变的那一段每次重新解析。
// 副作用：无（纯内存状态）。
//
// 为什么需要：以前每次更新都把全文重新解析一遍、所有块重新排版，回答越长
// 每帧越慢（总开销随长度平方增长），匀速逐字显示后更新更密，长回答会掉帧。
// 定稿的块对象不变，界面就能原样复用它们已经建好的组件，一帧只重排末尾那
// 一块。
//
// 在哪里切开（“定稿”的边界）：只在顶格的新块开头切，并且要同时满足——
// - 上一行是空行（块与块之间）；
// - 不在围栏代码块里（围栏里的空行是代码的一部分）；
// - 这一行不缩进（缩进的行可能是上一个列表项的续行或缩进代码）；
// - 这一行不像列表项的开头（松散列表各项之间也有空行：切开后有序列表会
//   各自从头编号，所以整个列表留在同一段里）。
// 拿不准时一律不切（只是晚一点定稿，结果不会错）。
//
// 已知的差异：引用式链接的定义如果写在很后面，定稿的块里解析不到它（当作
// 普通文字）。回答落库后界面换成整段解析，最终显示以整段解析为准。

import 'release_notes_document.dart';

class ReleaseNotesIncrementalParser {
  String _source = '';

  /// 已定稿的前缀在 [_source] 里的结束位置（也是末尾那一段的开头）。
  int _stableEnd = 0;

  /// 逐行扫描到了哪里（下一行的开头）；只扫完整的行。
  int _scanned = 0;

  /// 扫描状态：上一行是不是空行，是否在围栏里（及围栏用的字符与长度）。
  bool _previousBlank = true;
  int _fenceChar = 0;
  int _fenceLength = 0;

  final List<ReleaseNoteBlock> _stable = <ReleaseNoteBlock>[];
  List<ReleaseNoteBlock> _blocks = const <ReleaseNoteBlock>[];

  /// 最近一次 [update] 的结果。
  List<ReleaseNoteBlock> get blocks => _blocks;

  /// [blocks] 里前多少块已经定稿（对象不会再变）。
  int get stableCount => _stable.length;

  /// 换成新的全文并返回块列表。[markdown] 不是上一次的延长（重新生成、
  /// 换了一条消息）时从头再来。
  List<ReleaseNoteBlock> update(String markdown) {
    if (markdown == _source && (_blocks.isNotEmpty || markdown.isEmpty)) {
      return _blocks;
    }
    if (!markdown.startsWith(_source)) _reset();
    _source = markdown;
    final cut = _scan();
    if (cut > _stableEnd) {
      _stable.addAll(parseReleaseNotes(markdown.substring(_stableEnd, cut)));
      _stableEnd = cut;
    }
    return _blocks = <ReleaseNoteBlock>[
      ..._stable,
      ...parseReleaseNotes(markdown.substring(_stableEnd)),
    ];
  }

  void _reset() {
    _source = '';
    _stableEnd = 0;
    _scanned = 0;
    _previousBlank = true;
    _fenceChar = 0;
    _fenceLength = 0;
    _stable.clear();
    _blocks = const <ReleaseNoteBlock>[];
  }

  /// 从上次停下的地方接着逐行扫描，返回最靠后的可切位置（没有新的就是
  /// 原来的 [_stableEnd]）。只有完整的行才更新扫描状态；末尾没写完的那一行
  /// 只判断能不能在它前面切，下次从它的开头重新看。
  int _scan() {
    final text = _source;
    var cut = _stableEnd;
    while (true) {
      final lineEnd = text.indexOf('\n', _scanned);
      if (lineEnd < 0) break;
      final line = text.substring(_scanned, lineEnd);
      if (_canCutBefore(line)) cut = _scanned;
      _consume(line);
      _scanned = lineEnd + 1;
    }
    if (_scanned < text.length && _canCutBefore(text.substring(_scanned))) {
      cut = _scanned;
    }
    return cut;
  }

  bool _canCutBefore(String line) {
    if (_fenceLength > 0 || !_previousBlank || _scanned == 0) return false;
    if (line.trim().isEmpty) return false;
    final first = line.codeUnitAt(0);
    if (first == 0x20 || first == 0x09) return false;
    return !_maybeListItem.hasMatch(line);
  }

  /// 列表项的开头，或还没写完、有可能是列表项开头的（只有数字、只有一个
  /// 符号）：`- `、`* `、`+ `、`12. `、`3) `，以及单独的 `-`、`12`、`12.`。
  static final RegExp _maybeListItem = RegExp(
    r'^(?:[-*+](?:[ \t]|$)|\d{1,9}(?:[.)](?:[ \t]|$)|$))',
  );

  /// 记下一整行：围栏的开合与是不是空行。
  void _consume(String raw) {
    final line = raw.trimLeft();
    if (_fenceLength > 0) {
      // 收尾的围栏：同一种字符、不比开头短、后面只有空白。
      final run = _runLength(line, _fenceChar);
      if (run >= _fenceLength && line.substring(run).trim().isEmpty) {
        _fenceLength = 0;
      }
      _previousBlank = false;
      return;
    }
    if (line.trim().isEmpty) {
      _previousBlank = true;
      return;
    }
    _previousBlank = false;
    if (line.isEmpty) return;
    final char = line.codeUnitAt(0);
    if (char != 0x60 && char != 0x7E) return;
    final run = _runLength(line, char);
    // 反引号围栏的说明里不能再有反引号（那是行内代码）。
    if (run >= 3 && !(char == 0x60 && line.indexOf('`', run) >= 0)) {
      _fenceChar = char;
      _fenceLength = run;
    }
  }

  static int _runLength(String line, int char) {
    var length = 0;
    while (length < line.length && line.codeUnitAt(length) == char) {
      length++;
    }
    return length;
  }
}
