import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/agent/ai_tool_result.dart';
import 'package:node_diary/core/services/ai/agent/ai_tool_schema.dart';

void main() {
  const schema = AiObjectSchema(
    properties: <String, AiSchema>{
      'query': AiStringSchema(),
      'limit': AiIntegerSchema(minimum: 1, maximum: 50),
      'tags': AiArraySchema(items: AiStringSchema(), maxItems: 3),
      'archived': AiBooleanSchema(),
      'sort': AiStringSchema(enumValues: <String>['newest', 'oldest']),
      'from': AiDateSchema(),
      'at': AiTimeSchema(),
      'score': AiNumberSchema(minimum: 0, maximum: 1),
    },
    required: <String>['query'],
  );

  Matcher argumentError(String fragment) => throwsA(
    isA<AiToolArgumentError>().having(
      (e) => e.message,
      'message',
      contains(fragment),
    ),
  );

  test('emits only the portable JSON Schema subset', () {
    final json = schema.toJson();
    expect(json['type'], 'object');
    expect(json['required'], ['query']);
    final properties = json['properties']! as Map;
    expect(properties['limit'], {
      'type': 'integer',
      'minimum': 1,
      'maximum': 50,
    });
    expect(properties['tags'], {
      'type': 'array',
      'items': {'type': 'string'},
    });
    expect((properties['sort'] as Map)['enum'], ['newest', 'oldest']);
    // 日期按字符串发，格式写在说明里。
    expect((properties['from'] as Map)['type'], 'string');
    expect(json.toString(), isNot(contains('additionalProperties')));
  });

  test('coerces the small slips models make', () {
    final args = schema.validate(<String, Object?>{
      'query': 'sea',
      'limit': '5',
      'tags': 'travel',
      'archived': 'true',
      'from': '2026-02-28',
      'at': '9:30',
      'score': '0.5',
      'sort': null,
    });
    expect(args['limit'], 5);
    expect(args['tags'], ['travel']);
    expect(args['archived'], isTrue);
    expect(args['from'], DateTime(2026, 2, 28));
    expect(args['at'], 9 * 60 + 30);
    expect(args['score'], 0.5);
    // 显式的 null 当作没给。
    expect(args.containsKey('sort'), isFalse);
    expect(schema.validate({'query': 'x', 'limit': 3.0})['limit'], 3);
  });

  test('reports mistakes the model should fix', () {
    expect(() => schema.validate({}), argumentError('Missing required'));
    expect(
      () => schema.validate({'query': 'x', 'color': 'red'}),
      argumentError('Unknown parameter(s) `color`'),
    );
    expect(
      () => schema.validate({'query': 'x', 'limit': 99}),
      argumentError('arguments.limit'),
    );
    expect(
      () => schema.validate({'query': 'x', 'sort': 'random'}),
      argumentError('one of newest, oldest'),
    );
    expect(
      () => schema.validate({'query': 'x', 'from': '2026-02-30'}),
      argumentError('real calendar date'),
    );
    expect(
      () => schema.validate({'query': 'x', 'at': '25:00'}),
      argumentError('09:30'),
    );
    expect(
      () => schema.validate({
        'query': 'x',
        'tags': ['a', 'b', 'c', 'd'],
      }),
      argumentError('at most 3 items'),
    );
    expect(() => schema.validate({'query': '  '}), argumentError('non-empty'));
  });

  test('tool results stay under the limit without breaking JSON', () {
    expect(aiToolResultText({'a': 1}), '{"a":1}');
    final long = aiToolResultText({'text': 'x' * 500}, maxChars: 300);
    expect(long.length, lessThan(400));
    expect(long, contains('"truncated":true'));
    expect(long, contains('Narrow the query'));
  });
}
