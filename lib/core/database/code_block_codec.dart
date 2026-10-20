/// 正文代码块的语言标记（Quill `code-block` 属性值）编解码。
///
/// 值约定与 quill.js 兼容：
/// - `true`：未指定语言（自动识别或按默认样式显示）；
/// - [kCodeBlockPlain]（`'plain'`）：明确按纯文本显示、不高亮；
/// - [kDiaryCodeLanguageIds] 中的 highlight.js 语言 id（如 `'python'`）。
///
/// 导入器（Markdown 围栏、其他应用的富文本）与编辑器写入语言时，一律先经
/// [normalizeCodeLanguageTag] 规整：别名收敛到同一 id，认不出的标记返回
/// null（按“未指定”写 `true`），保证库里只出现上面三种值。读取时经
/// [codeBlockExplicitLanguage] 容错：旧数据、手改备份里的怪值都当作未指定。
library;

/// 明确指定为纯文本的代码块属性值。
const String kCodeBlockPlain = 'plain';

/// 可选的代码语言（highlight.js 语言 id），按界面展示顺序排列。
const List<String> kDiaryCodeLanguageIds = <String>[
  'dart',
  'python',
  'javascript',
  'typescript',
  'java',
  'kotlin',
  'swift',
  'cpp',
  'cs',
  'go',
  'rust',
  'php',
  'ruby',
  'lua',
  'bash',
  'sql',
  'json',
  'yaml',
  'xml',
  'css',
  'markdown',
  'diff',
];

/// 语言 id → 展示名（专有名词，不做本地化）。
const Map<String, String> kDiaryCodeLanguageNames = <String, String>{
  'dart': 'Dart',
  'python': 'Python',
  'javascript': 'JavaScript',
  'typescript': 'TypeScript',
  'java': 'Java',
  'kotlin': 'Kotlin',
  'swift': 'Swift',
  'cpp': 'C/C++',
  'cs': 'C#',
  'go': 'Go',
  'rust': 'Rust',
  'php': 'PHP',
  'ruby': 'Ruby',
  'lua': 'Lua',
  'bash': 'Shell',
  'sql': 'SQL',
  'json': 'JSON',
  'yaml': 'YAML',
  'xml': 'HTML/XML',
  'css': 'CSS',
  'markdown': 'Markdown',
  'diff': 'Diff',
};

const Set<String> _plainSynonyms = <String>{
  'text',
  'txt',
  'plain',
  'plaintext',
  'none',
};

// 常见围栏标记 / 文件扩展名到 highlight.js id 的别名；只收录能落到
// [kDiaryCodeLanguageIds] 的写法，其余一律视为未指定。
const Map<String, String> _languageAliases = <String, String>{
  'c': 'cpp',
  'c++': 'cpp',
  'cc': 'cpp',
  'h': 'cpp',
  'hpp': 'cpp',
  'cxx': 'cpp',
  'csharp': 'cs',
  'c#': 'cs',
  'js': 'javascript',
  'jsx': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'node': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'py': 'python',
  'python3': 'python',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'rs': 'rust',
  'rb': 'ruby',
  'sh': 'bash',
  'shell': 'bash',
  'zsh': 'bash',
  'console': 'bash',
  'yml': 'yaml',
  'html': 'xml',
  'htm': 'xml',
  'xhtml': 'xml',
  'svg': 'xml',
  'vue': 'xml',
  'md': 'markdown',
  'golang': 'go',
  'patch': 'diff',
};

/// 把任意来源的语言标记规整为 [kCodeBlockPlain] 或已知语言 id；
/// 空白或认不出时返回 null（调用方按“未指定”处理）。
String? normalizeCodeLanguageTag(String? raw) {
  if (raw == null) {
    return null;
  }
  final tag = raw.trim().toLowerCase();
  if (tag.isEmpty) {
    return null;
  }
  if (_plainSynonyms.contains(tag)) {
    return kCodeBlockPlain;
  }
  if (kDiaryCodeLanguageNames.containsKey(tag)) {
    return tag;
  }
  return _languageAliases[tag];
}

/// 从 `code-block` 属性值读出明确指定的语言：[kCodeBlockPlain] 或已知 id；
/// `true`、null、false 与认不出的字符串都返回 null（= 未指定 / 自动）。
String? codeBlockExplicitLanguage(Object? value) {
  if (value is! String) {
    return null;
  }
  return normalizeCodeLanguageTag(value);
}
