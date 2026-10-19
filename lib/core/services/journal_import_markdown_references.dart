import 'package:markdown/markdown.dart' as md;

/// 预读引用式链接定义（`![图][id]` / `[id]: path`），随后仍逐行转换正文。
/// 交给 Markdown 自身的块解析器判断定义，避免把代码围栏中的字面定义当成
/// 附件、也不以正则丢掉多行标题。返回真正消费的定义行，正文转换时跳过。
Set<int> collectJournalMarkdownReferences(
  List<String> lines,
  md.Document inline,
) {
  final parsedLines = lines.map(md.Line.new).toList();
  final positions = {
    for (final (index, line) in parsedLines.indexed) line: index,
  };
  final definitions = <int>{};
  final document = md.Document(
    encodeHtml: false,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: [_ReferenceSyntax(positions, definitions)],
  );
  final parser = md.BlockParser(parsedLines, document);
  // 默认语法里也有同一种定义解析器。保留两份时，普通的 [链接](地址)
  // 会在两者之间反复失败并停滞；替换默认实例，而不是叠加一个。
  parser.blockSyntaxes.removeWhere(
    (syntax) =>
        syntax is md.LinkReferenceDefinitionSyntax &&
        syntax is! _ReferenceSyntax,
  );
  parser.parseLines();
  inline.linkReferences
    ..clear()
    ..addAll(document.linkReferences);
  return definitions;
}

class _ReferenceSyntax extends md.LinkReferenceDefinitionSyntax {
  _ReferenceSyntax(this.positions, this.definitions);
  final Map<md.Line, int> positions;
  final Set<int> definitions;

  @override
  bool canParse(md.BlockParser parser) =>
      positions.containsKey(parser.current) && super.canParse(parser);

  @override
  md.Node? parse(md.BlockParser parser) {
    final start = positions[parser.current]!;
    final result = super.parse(parser);
    final end = parser.isDone ? positions.length : positions[parser.current]!;
    for (var index = start; index < end; index++) {
      definitions.add(index);
    }
    return result;
  }
}
