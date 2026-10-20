import 'package:flutter/foundation.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/diff.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

import '../../../../core/database/code_block_codec.dart';

// 代码块可选语言与“语言选择”值类型。
//
// 语言表与 `code_block_codec.dart` 的 [kDiaryCodeLanguageIds] 一一对应、顺序
// 一致（界面按此顺序展示）；这里额外挂上 highlight 的语法定义 [Mode]。
// 只导入这 22 个语言文件：`package:highlight/highlight.dart` 会把全部
// 约 190 种语言编进安装包，自动识别也会逐个试一遍，既慢又容易误判。

/// 一种可选的代码语言：highlight.js id、展示名与语法定义。
@immutable
class DiaryCodeLanguage {
  const DiaryCodeLanguage({
    required this.id,
    required this.name,
    required this.mode,
  });

  /// highlight.js 语言 id，即 `code-block` 属性里存的值。
  final String id;

  /// 展示名（专有名词，不做本地化）。
  final String name;

  /// highlight 的语法定义。
  final Mode mode;
}

final Map<String, Mode> _languageModes = <String, Mode>{
  'dart': dart,
  'python': python,
  'javascript': javascript,
  'typescript': typescript,
  'java': java,
  'kotlin': kotlin,
  'swift': swift,
  'cpp': cpp,
  'cs': cs,
  'go': go,
  'rust': rust,
  'php': php,
  'ruby': ruby,
  'lua': lua,
  'bash': bash,
  'sql': sql,
  'json': json,
  'yaml': yaml,
  'xml': xml,
  'css': css,
  'markdown': markdown,
  'diff': diff,
};

/// 全部可选语言，顺序同 [kDiaryCodeLanguageIds]。
final List<DiaryCodeLanguage> kDiaryCodeLanguages = List.unmodifiable(
  kDiaryCodeLanguageIds.map(
    (id) => DiaryCodeLanguage(
      id: id,
      name: kDiaryCodeLanguageNames[id]!,
      mode: _languageModes[id]!,
    ),
  ),
);

final Map<String, DiaryCodeLanguage> _languagesById = {
  for (final language in kDiaryCodeLanguages) language.id: language,
};

/// 按 id 取语言；不在可选列表里时返回 null。
DiaryCodeLanguage? diaryCodeLanguageById(String id) => _languagesById[id];

enum _ChoiceKind { auto, plain, explicit }

/// 代码块的语言选择：自动识别、纯文本，或明确指定的语言。
///
/// 与 `code-block` 属性值一一对应：`true` ↔ [auto]，`'plain'` ↔ [plain]，
/// 语言 id ↔ [DiaryCodeLanguageChoice.explicit]。
@immutable
class DiaryCodeLanguageChoice {
  const DiaryCodeLanguageChoice._(this._kind, this._languageId);

  /// 由调用方保证 [id] 在 [kDiaryCodeLanguageIds] 里；认不出的值请经
  /// [fromAttributeValue] 规整。
  const DiaryCodeLanguageChoice.explicit(String id)
    : this._(_ChoiceKind.explicit, id);

  /// 未指定语言：按自动识别结果高亮（关闭自动识别时不高亮）。
  static const DiaryCodeLanguageChoice auto = DiaryCodeLanguageChoice._(
    _ChoiceKind.auto,
    null,
  );

  /// 明确按纯文本显示、不高亮。
  static const DiaryCodeLanguageChoice plain = DiaryCodeLanguageChoice._(
    _ChoiceKind.plain,
    null,
  );

  final _ChoiceKind _kind;
  final String? _languageId;

  /// 从 `code-block` 属性值读出选择；`true`、null 与认不出的值都是 [auto]。
  static DiaryCodeLanguageChoice fromAttributeValue(Object? value) {
    final explicit = codeBlockExplicitLanguage(value);
    if (explicit == null) {
      return auto;
    }
    if (explicit == kCodeBlockPlain) {
      return plain;
    }
    return DiaryCodeLanguageChoice.explicit(explicit);
  }

  bool get isAuto => _kind == _ChoiceKind.auto;

  bool get isPlain => _kind == _ChoiceKind.plain;

  /// 写回 `code-block` 属性的值：`true`、`'plain'` 或语言 id。
  Object get attributeValue => switch (_kind) {
    _ChoiceKind.auto => true,
    _ChoiceKind.plain => kCodeBlockPlain,
    _ChoiceKind.explicit => _languageId!,
  };

  /// 明确指定的语言 id；[auto] 与 [plain] 为 null。
  String? get languageId => _languageId;

  @override
  bool operator ==(Object other) =>
      other is DiaryCodeLanguageChoice &&
      other._kind == _kind &&
      other._languageId == _languageId;

  @override
  int get hashCode => Object.hash(_kind, _languageId);

  @override
  String toString() => 'DiaryCodeLanguageChoice($attributeValue)';
}
