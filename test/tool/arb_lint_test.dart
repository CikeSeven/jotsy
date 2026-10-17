import 'package:flutter_test/flutter_test.dart';

import '../../tool/arb_lint.dart';

Map<String, Object?> _meta([Map<String, Object?>? placeholders]) =>
    <String, Object?>{
      'description': 'Shown somewhere.',
      'placeholders': ?placeholders,
    };

List<String> _lint(Map<String, Map<String, Object?>> arbs) => lintArbs(
  arbs,
  templateLocale: 'en',
).map((issue) => '${issue.locale} ${issue.key}: ${issue.message}').toList();

void main() {
  group('icuPlaceholderNames', () {
    test('collects simple placeholders', () {
      expect(icuPlaceholderNames('Hi {name}, {count} new'), <String>{
        'name',
        'count',
      });
      expect(icuPlaceholderNames('No placeholders.'), isEmpty);
    });

    test('ignores plural branch text but keeps nested placeholders', () {
      expect(
        icuPlaceholderNames('{count, plural, =1{word} other{words}}'),
        <String>{'count'},
      );
      expect(
        icuPlaceholderNames(
          '{count, plural, =0{No diary in {year}} other{{count} in {year}}}',
        ),
        <String>{'count', 'year'},
      );
      expect(
        icuPlaceholderNames('{mode, select, light {Light} other {Dark}}'),
        <String>{'mode'},
      );
    });

    test('rejects malformed messages', () {
      for (final message in <String>[
        'Unclosed {name',
        'Stray } brace',
        'Empty {} braces',
        '{count, plural, other{x}',
        '{count, plural, }',
        '{count, number}',
      ]) {
        expect(
          () => icuPlaceholderNames(message),
          throwsFormatException,
          reason: message,
        );
      }
    });
  });

  group('lintArbs', () {
    test('accepts matching locales with full metadata', () {
      final placeholders = <String, Object?>{
        'count': <String, Object?>{'type': 'int'},
      };
      expect(
        _lint(<String, Map<String, Object?>>{
          'en': <String, Object?>{
            '@@locale': 'en',
            'unit': '{count, plural, =1{word} other{words}}',
            '@unit': _meta(placeholders),
          },
          'zh': <String, Object?>{
            '@@locale': 'zh',
            'unit': '字',
            '@unit': _meta(placeholders),
          },
        }),
        isEmpty,
      );
    });

    test('reports missing and extra translations', () {
      expect(
        _lint(<String, Map<String, Object?>>{
          'en': <String, Object?>{'a': 'A', '@a': _meta()},
          'zh': <String, Object?>{'b': 'B', '@b': _meta()},
        }),
        unorderedEquals(<String>[
          'zh a: missing translation',
          'zh b: not in the template ARB',
        ]),
      );
    });

    test('requires a description and rejects orphan metadata', () {
      expect(
        _lint(<String, Map<String, Object?>>{
          'en': <String, Object?>{
            'noMeta': 'x',
            'blank': 'y',
            '@blank': <String, Object?>{'description': '  '},
            '@gone': _meta(),
          },
        }),
        unorderedEquals(<String>[
          'en noMeta: missing "@noMeta" metadata',
          'en blank: "@blank" needs a non-empty description',
          'en @gone: metadata without a message',
        ]),
      );
    });

    test('requires declared placeholders with gen-l10n types', () {
      expect(
        _lint(<String, Map<String, Object?>>{
          'en': <String, Object?>{
            'undeclared': 'Hi {name}',
            '@undeclared': _meta(),
            'object': '{value}',
            '@object': _meta(<String, Object?>{
              'value': <String, Object?>{'type': 'Object'},
            }),
            'untyped': '{value}',
            '@untyped': _meta(<String, Object?>{'value': <String, Object?>{}}),
            'broken': 'Oops {',
            '@broken': _meta(),
          },
        }),
        unorderedEquals(<String>[
          'en undeclared: placeholder {name} is not declared',
          'en object: placeholder {value} type must be one of '
              'String/int/double/num/DateTime (got Object)',
          'en untyped: placeholder {value} type must be one of '
              'String/int/double/num/DateTime (got none)',
          'en broken: invalid ICU syntax: expected placeholder name',
        ]),
      );
    });
  });
}
