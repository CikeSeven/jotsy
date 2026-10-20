import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/code_block_codec.dart';

void main() {
  group('normalizeCodeLanguageTag', () {
    test('every language id has a display name', () {
      expect(
        kDiaryCodeLanguageIds.toSet(),
        kDiaryCodeLanguageNames.keys.toSet(),
      );
      for (final id in kDiaryCodeLanguageIds) {
        expect(normalizeCodeLanguageTag(id), id);
      }
    });

    test('maps aliases to highlight.js ids, ignoring case and spaces', () {
      const expected = <String, String>{
        'c': 'cpp',
        'C++': 'cpp',
        ' hpp ': 'cpp',
        'cxx': 'cpp',
        'csharp': 'cs',
        'C#': 'cs',
        'cs': 'cs',
        'JS': 'javascript',
        'jsx': 'javascript',
        'node': 'javascript',
        'tsx': 'typescript',
        'py': 'python',
        'python3': 'python',
        'kts': 'kotlin',
        'rs': 'rust',
        'rb': 'ruby',
        'zsh': 'bash',
        'console': 'bash',
        'yml': 'yaml',
        'HTML': 'xml',
        'vue': 'xml',
        'svg': 'xml',
        'md': 'markdown',
        'golang': 'go',
        'patch': 'diff',
      };
      expected.forEach((raw, id) {
        expect(normalizeCodeLanguageTag(raw), id, reason: raw);
      });
    });

    test('maps plain-text synonyms to plain', () {
      for (final raw in ['text', 'TXT', 'plain', 'plaintext', ' none ']) {
        expect(normalizeCodeLanguageTag(raw), kCodeBlockPlain, reason: raw);
      }
    });

    test('returns null for empty or unknown tags', () {
      for (final raw in [null, '', '   ', 'brainfuck', 'objective-c', '1c']) {
        expect(normalizeCodeLanguageTag(raw), isNull, reason: '$raw');
      }
    });
  });

  group('codeBlockExplicitLanguage', () {
    test('treats true, null, false and unknown strings as auto', () {
      expect(codeBlockExplicitLanguage(true), isNull);
      expect(codeBlockExplicitLanguage(null), isNull);
      expect(codeBlockExplicitLanguage(false), isNull);
      expect(codeBlockExplicitLanguage('weird'), isNull);
      expect(codeBlockExplicitLanguage(3), isNull);
    });

    test('reads explicit languages and plain text', () {
      expect(codeBlockExplicitLanguage('PYTHON'), 'python');
      expect(codeBlockExplicitLanguage('js'), 'javascript');
      expect(codeBlockExplicitLanguage('plain'), kCodeBlockPlain);
    });
  });
}
