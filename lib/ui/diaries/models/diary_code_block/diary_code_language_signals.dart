// 语言识别的加权语法特征表，不运行语法高亮器。
//
// 输入为有界样本及去掉字符串、注释后的代码；每项只计分一次，避免反复出现的
// 通用词压过语言独有语法。正则只在首次使用时构造，均不使用嵌套无界量词。
// 强特征足以识别一行代码，普通单词（class / return / for）本身不计分。
Map<String, int> diaryCodeLanguageScores(String source, String code) {
  final scores = <String, int>{};
  for (final signal in _signals) {
    final matches = signal.raw
        ? signal.pattern.allMatches(source).any((match) {
            // 原文特征（import 的路径等）必须同时在代码中有可见的语法，
            // 不能从多行字串或注释里捞出一条 import/语言指令。
            for (var i = match.start; i < match.end; i++) {
              final c = code.codeUnitAt(i);
              if (c != 32 && c != 10 && c != 13 && c != 9) return true;
            }
            return false;
          })
        : signal.pattern.hasMatch(code);
    if (matches) {
      scores.update(
        signal.language,
        (score) => score + signal.weight,
        ifAbsent: () => signal.weight,
      );
    }
  }
  return scores;
}

class _Signal {
  _Signal(
    this.language,
    this.weight,
    String pattern, {
    this.raw = false,
    bool caseSensitive = true,
  }) : pattern = RegExp(pattern, multiLine: true, caseSensitive: caseSensitive);

  final String language;
  final int weight;
  final RegExp pattern;
  final bool raw;
}

final _signals = <_Signal>[
  _Signal(
    'dart',
    12,
    r'''^\s*(?:import|export|part)\s+['"](?:dart:|package:|[^'"\r\n]+\.dart['"])''',
    raw: true,
  ),
  _Signal('dart', 8, r'\bvoid\s+main\s*\('),
  _Signal('dart', 7, r'\b(?:final|late)\s+(?:[\w<>?]+\s+)?\w+\s*='),
  _Signal(
    'dart',
    12,
    r'\b(?:Widget\s+build|BuildContext\s+\w+|extends\s+(?:StatefulWidget|StatelessWidget)|mixin\s+\w+)\b',
  ),
  _Signal('dart', 6, r'\b(?:Future|Stream)\s*<[^>\n]+>\s+\w+\s*\('),
  _Signal(
    'python',
    10,
    r'^\s*(?:async\s+)?def\s+\w+\s*\([^\n]*\)\s*(?:->[^:\n]+)?\s*:',
  ),
  _Signal('python', 7, r'^\s*from\s+[\w.]+\s+import\s+\w+'),
  _Signal('python', 5, r'^\s*import\s+[\w.]+\s*(?:$|#)'),
  _Signal('python', 5, r'\b(?:print|range|len|enumerate)\s*\('),
  _Signal(
    'python',
    6,
    r'^\s*(?:if|elif|for|while|with|except|class)\b[^\n]*:\s*$',
  ),
  _Signal('python', 4, r'\b(?:self\.|None\b|True\b|False\b)'),
  _Signal(
    'javascript',
    6,
    r'\b(?:const|let|var)\s+(?:\w+|\{[^}\n]+\}|\[[^\]\n]+\])\s*=',
  ),
  _Signal(
    'javascript',
    6,
    r'\b(?:console\.(?:log|error|warn)|document\.\w+|require)\s*\(',
  ),
  _Signal('javascript', 6, r'\b(?:async\s+)?function\s*[\w$]*\s*\('),
  _Signal('javascript', 3, r'=>'),
  _Signal('javascript', 7, r'\b(?:module\.exports|exports\.\w+)\s*='),
  _Signal(
    'javascript',
    12,
    r'\bclass\s+[\w$]+\s*\{[^}]*#[A-Za-z_$][\w$]*\s*=',
    raw: true,
  ),
  _Signal('javascript', 5, r'''^\s*(?:import|export)\b[^\n]*\bfrom\s*['"]'''),
  _Signal('typescript', 18, r'\b(?:const|let|var)\s+\w+\s*:\s*[\w{\[]'),
  _Signal(
    'typescript',
    18,
    r'[(,]\s*\w+\s*\??:\s*(?:string|number|boolean|unknown|never|any|readonly)\b',
  ),
  _Signal('typescript', 18, r'\)\s*:\s*(?:void|Promise|[A-Z]\w*)\b'),
  _Signal(
    'typescript',
    18,
    r'^\s*(?:export\s+)?(?:interface\s+\w+|type\s+\w+(?:<[^>\n]+>)?\s*=|import\s+type\b)',
  ),
  _Signal(
    'java',
    9,
    r'\bpublic\s+(?:(?:static|final|abstract)\s+)*(?:class|interface|enum|void)\b',
  ),
  _Signal('java', 14, r'\bSystem\.out\.print(?:ln)?\s*\('),
  _Signal('java', 10, r'^\s*import\s+(?:java|javax|android)\.'),
  _Signal('java', 8, r'\bString\s*\[\s*\]\s+\w+'),
  _Signal('kotlin', 20, r'\bfun\s+(?:<[^>\n]+>\s*)?\w+\s*\('),
  _Signal('kotlin', 6, r'\bval\s+\w+\s*(?::[^=\n]+)?='),
  _Signal(
    'kotlin',
    10,
    r'\b(?:data\s+class|sealed\s+class|object\s+\w+\s*[:{]|companion\s+object)\b',
  ),
  _Signal('swift', 5, r'\bfunc\s+\w+\s*\('),
  _Signal('swift', 12, r'\bfunc\s+\w+\s*\([^\n]*\w\s*:\s*[A-Za-z]|\)\s*->'),
  _Signal(
    'swift',
    22,
    r'\b(?:let|var)\s+\w+\s*:\s*(?:String|Int|Double|Bool)\b',
  ),
  _Signal(
    'swift',
    10,
    r'\b(?:guard\s+let|if\s+let|import\s+(?:SwiftUI|UIKit|Foundation))\b',
  ),
  _Signal('cpp', 16, r'^\s*#\s*(?:include|define|pragma)\b'),
  _Signal('cpp', 12, r'\b(?:std::|using\s+namespace\s+std\b)'),
  _Signal('cpp', 6, r'\b(?:int|auto)\s+main\s*\('),
  _Signal('cpp', 7, r'\b(?:printf|scanf|malloc|free)\s*\('),
  _Signal(
    'cs',
    15,
    r'\b(?:Console\.(?:WriteLine|Write)|using\s+System\b|namespace\s+\w+\s*[;{])',
  ),
  _Signal(
    'cs',
    9,
    r'\b(?:public|private|internal)\s+(?:static\s+)?(?:async\s+)?Task\b',
  ),
  _Signal('go', 16, r'^\s*package\s+\w+\s*$'),
  _Signal('go', 10, r'\bfunc\s+(?:\([^\n]*\)\s*)?\w+\s*\('),
  _Signal('go', 9, r'\b\w+\s*:=|\bfmt\.\w+\s*\('),
  _Signal('rust', 20, r'\b(?:pub\s+)?(?:async\s+)?fn\s+\w+\s*[<(]'),
  _Signal('rust', 16, r'^\s*use\s+\w+::'),
  _Signal('rust', 8, r'\b(?:let\s+mut|impl\s+\w+|use\s+\w+::|println!|vec!)'),
  _Signal('php', 24, r'^\s*<\?php\b'),
  _Signal('php', 8, r'\$\w+\s*->\s*\w+|\b(?:echo|require_once)\s+[^;\n]+;'),
  _Signal('ruby', 7, r'^\s*def\s+\w+[!?]?(?:\([^\n]*\))?\s*$'),
  _Signal(
    'ruby',
    8,
    r'^\s*(?:puts|require_relative|attr_accessor|attr_reader)\b',
  ),
  _Signal('ruby', 4, r'^\s*end\s*$'),
  _Signal('lua', 13, r'\blocal\s+(?:function\s+\w+|\w+\s*=)'),
  _Signal('lua', 8, r'\bfunction\s+\w+\s*\([^\n]*\)\s*$'),
  _Signal('lua', 7, r'\b(?:then|do)\s*$|\b(?:ipairs|pairs)\s*\('),
  _Signal('bash', 24, r'^#![^\n]*\b(?:ba|z|fi|da|k)?sh\b', raw: true),
  _Signal(
    'bash',
    12,
    r'^\s*(?:if|elif|for|while)\b[^\n]*;\s*(?:then|do)\b|^\s*(?:fi|done|esac)\s*$',
  ),
  _Signal(
    'bash',
    6,
    r'^\s*(?:echo|export|source|sudo|curl|chmod|mkdir|grep|ls|cd)\s+[^\n]+',
  ),
  _Signal('bash', 6, r'\$\([^)\n]+\)|\$\{\w+(?::[-=?+][^}\n]*)?\}'),
  _Signal('sql', 14, r'\bselect\b[^;]*\bfrom\s+[\w"`\[]', caseSensitive: false),
  _Signal(
    'sql',
    10,
    r'\b(?:insert\s+into|delete\s+from|create\s+table|alter\s+table|drop\s+table|update\s+\w+\s+set)\b',
    caseSensitive: false,
  ),
  _Signal('sql', 5, r'\b(?:select|with)\b[^;\n]+;', caseSensitive: false),
];
