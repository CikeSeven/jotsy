// 本地模拟 AI 服务：手动验证 AI 助手用，不需要任何真实密钥。
//
// 用法：
//   dart run tool/ai_mock_server.dart [--port 8787] [--delay 40]
//       [--think] [--fail 401|403|404|429|500|context|filtered]
//
// 同时实现四种协议（流式与一次性请求、模型列表）：
//   OpenAI 兼容：POST /v1/chat/completions、GET /v1/models
//                 （Jotsy 里地址填 http://127.0.0.1:8787/v1）
//   OpenAI Responses：POST /v1/responses（地址同上）
//   Anthropic：   POST /v1/messages、GET /v1/models
//                 （地址填 http://127.0.0.1:8787）
//   Gemini：      POST /v1beta/models/<模型>:streamGenerateContent?alt=sse
//                 与 :generateContent、GET /v1beta/models
//                 （地址填 http://127.0.0.1:8787/v1beta）
// 密钥随便填。桌面上直接用 127.0.0.1；Android 模拟器里用 10.0.2.2，真机用
// 电脑的局域网地址（需要同一网络，并允许 http 明文请求的调试构建）。
//
// 回答的内容：
// - 请求里出现检索计划的格式（"keywords"）时返回一个检索计划 JSON；
// - 出现智能填写的格式（"newTags"）时返回标题 / 标签 / 心情的 JSON；
// - 其他请求回显收到了什么（消息数、最后一条的开头、带不带图片），提示词
//   里有 [D1] 这样的编号时在回答里引用第一个，方便检查引用胶囊。
// --think 时先吐一段“思考过程”；--delay 为每块之间的毫秒数（模拟慢网络、
// 方便试“停止”）；--fail 让每个请求都按该协议的格式返回对应错误。
//
// 只监听本机回环地址；这是开发工具，不进应用、不在 CI 中运行。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    options.port,
  );
  stdout.writeln(
    'AI mock server on http://127.0.0.1:${server.port} '
    '(delay ${options.delayMs}ms${options.think ? ', thinking' : ''}'
    '${options.fail != null ? ', failing with ${options.fail}' : ''})',
  );
  await for (final request in server) {
    unawaited(_handle(request, options));
  }
}

class _Options {
  const _Options({
    required this.port,
    required this.delayMs,
    required this.think,
    this.fail,
  });

  factory _Options.parse(List<String> args) {
    var port = 8787;
    var delay = 40;
    var think = false;
    String? fail;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      String next() => i + 1 < args.length ? args[++i] : '';
      switch (arg) {
        case '--port':
          port = int.tryParse(next()) ?? port;
        case '--delay':
          delay = int.tryParse(next()) ?? delay;
        case '--think':
          think = true;
        case '--fail':
          fail = next();
        case '-h' || '--help':
          stdout.writeln(
            'dart run tool/ai_mock_server.dart [--port 8787] [--delay 40] '
            '[--think] [--fail 401|403|404|429|500|context|filtered]',
          );
          exit(0);
      }
    }
    return _Options(port: port, delayMs: delay, think: think, fail: fail);
  }

  final int port;
  final int delayMs;
  final bool think;
  final String? fail;
}

enum _Protocol { openAi, responses, anthropic, gemini }

Future<void> _handle(HttpRequest request, _Options options) async {
  final path = request.uri.path;
  final method = request.method;
  stdout.writeln('$method ${request.uri}');
  try {
    if (method == 'GET' && (path == '/v1/models' || path == '/models')) {
      final anthropic = request.headers.value('anthropic-version') != null;
      return await _json(
        request.response,
        anthropic
            ? <String, Object?>{
                'data': <Object?>[
                  <String, Object?>{
                    'id': 'mock-claude',
                    'display_name': 'Mock Claude',
                  },
                ],
                'has_more': false,
              }
            : <String, Object?>{
                'data': <Object?>[
                  <String, Object?>{'id': 'mock-chat'},
                  <String, Object?>{'id': 'mock-vision'},
                  <String, Object?>{'id': 'mock-reasoner'},
                ],
              },
      );
    }
    if (method == 'GET' && path == '/v1beta/models') {
      return await _json(request.response, <String, Object?>{
        'models': <Object?>[
          <String, Object?>{
            'name': 'models/mock-gemini',
            'displayName': 'Mock Gemini',
            'supportedGenerationMethods': <String>['generateContent'],
          },
        ],
      });
    }
    if (method != 'POST') return await _notFound(request.response);

    final _Protocol protocol;
    final bool stream;
    if (path.endsWith('/chat/completions')) {
      protocol = _Protocol.openAi;
      stream = false;
    } else if (path.endsWith('/responses')) {
      protocol = _Protocol.responses;
      stream = false;
    } else if (path == '/v1/messages') {
      protocol = _Protocol.anthropic;
      stream = false;
    } else if (path.startsWith('/v1beta/models/') &&
        (path.endsWith(':streamGenerateContent') ||
            path.endsWith(':generateContent'))) {
      protocol = _Protocol.gemini;
      stream = path.endsWith(':streamGenerateContent');
    } else {
      return await _notFound(request.response);
    }
    final body = jsonDecode(await utf8.decodeStream(request)) as Object?;
    final json = body is Map<String, Object?>
        ? body
        : const <String, Object?>{};
    final wantsStream = protocol == _Protocol.gemini
        ? stream
        : json['stream'] == true;

    final fail = options.fail;
    if (fail != null) return await _fail(request.response, protocol, fail);

    final prompt = _promptText(protocol, json);
    final reply = _reply(prompt);
    final thinking = options.think ? '先看看用户写了什么……再想想该怎么回答。' : '';
    if (!wantsStream) {
      return await _json(
        request.response,
        _whole(protocol, reply, thinking, model: _model(protocol, json, path)),
      );
    }
    await _stream(
      request.response,
      protocol,
      reply,
      thinking,
      delay: Duration(milliseconds: options.delayMs),
      model: _model(protocol, json, path),
    );
  } catch (error) {
    stderr.writeln('error: $error');
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    } catch (_) {
      // 连接已断开（客户端停止了生成）。
    }
  }
}

String _model(_Protocol protocol, Map<String, Object?> json, String path) {
  if (protocol == _Protocol.gemini) {
    final name = path.substring('/v1beta/models/'.length);
    return name.split(':').first;
  }
  final model = json['model'];
  return model is String ? model : 'mock';
}

/// 把请求里所有文字拼起来（判断要回什么），并数图片。
String _promptText(_Protocol protocol, Map<String, Object?> json) {
  final buffer = StringBuffer();
  var images = 0;
  void collect(Object? value) {
    if (value is String) {
      buffer.writeln(value);
    } else if (value is List) {
      value.forEach(collect);
    } else if (value is Map) {
      final type = value['type'];
      if (type == 'image_url' ||
          type == 'input_image' ||
          type == 'image' ||
          value['inline_data'] != null) {
        images++;
        return;
      }
      for (final key in <String>['text', 'content', 'parts', 'system']) {
        if (value.containsKey(key)) collect(value[key]);
      }
    }
  }

  switch (protocol) {
    case _Protocol.openAi:
      collect(json['messages']);
    case _Protocol.responses:
      collect(json['instructions']);
      collect(json['input']);
    case _Protocol.anthropic:
      collect(json['system']);
      collect(json['messages']);
    case _Protocol.gemini:
      collect(json['systemInstruction']);
      collect(json['contents']);
  }
  final messages = switch (protocol) {
    _Protocol.openAi => json['messages'],
    _Protocol.responses => json['input'],
    _Protocol.anthropic => json['messages'],
    _Protocol.gemini => json['contents'],
  };
  final count = messages is List ? messages.length : 0;
  return '[$count messages, $images images]\n$buffer';
}

String _reply(String prompt) {
  if (prompt.contains('"keywords"')) {
    return '{"keywords": ["海边", "散步"], "from": null, "to": null}';
  }
  if (prompt.contains('"newTags"')) {
    return '{"title": "海边的傍晚", "tags": [], "newTags": ["散步"], '
        '"mood": ""}';
  }
  final header = RegExp(
    r'^\[(\d+) messages, (\d+) images\]',
  ).firstMatch(prompt);
  final cite = RegExp(r'\[D\d+\]').firstMatch(prompt)?.group(0);
  final words = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
  final excerpt = words.length > 60
      ? words.substring(words.length - 60)
      : words;
  return [
    '## 模拟回答',
    '',
    '- 收到 ${header?.group(1) ?? '?'} 条消息、${header?.group(2) ?? '0'} 张图片。',
    '- 最后的内容：…$excerpt',
    if (cite != null) '- 这里引用了一篇日记 $cite。',
    '',
    '这是 **ai_mock_server** 的回答，用来检查流式、Markdown 与引用的显示。',
  ].join('\n');
}

/// 把回答切成小块（按字，几个字一块）。
List<String> _pieces(String text) {
  final runes = text.runes.toList();
  return <String>[
    for (var i = 0; i < runes.length; i += 4)
      String.fromCharCodes(
        runes.sublist(i, i + 4 > runes.length ? runes.length : i + 4),
      ),
  ];
}

Map<String, Object?> _whole(
  _Protocol protocol,
  String reply,
  String thinking, {
  required String model,
}) {
  switch (protocol) {
    case _Protocol.responses:
      return <String, Object?>{
        'id': 'resp_mock',
        'object': 'response',
        'model': model,
        'status': 'completed',
        'output': <Object?>[
          if (thinking.isNotEmpty)
            <String, Object?>{
              'type': 'reasoning',
              'summary': <Object?>[
                <String, Object?>{'type': 'summary_text', 'text': thinking},
              ],
            },
          <String, Object?>{
            'type': 'message',
            'role': 'assistant',
            'content': <Object?>[
              <String, Object?>{'type': 'output_text', 'text': reply},
            ],
          },
        ],
        'usage': <String, Object?>{
          'input_tokens': 120,
          'output_tokens': reply.length,
        },
      };
    case _Protocol.openAi:
      return <String, Object?>{
        'id': 'mock',
        'object': 'chat.completion',
        'model': model,
        'choices': <Object?>[
          <String, Object?>{
            'index': 0,
            'message': <String, Object?>{
              'role': 'assistant',
              'content': reply,
              if (thinking.isNotEmpty) 'reasoning_content': thinking,
            },
            'finish_reason': 'stop',
          },
        ],
        'usage': <String, Object?>{
          'prompt_tokens': 120,
          'completion_tokens': reply.length,
        },
      };
    case _Protocol.anthropic:
      return <String, Object?>{
        'id': 'msg_mock',
        'type': 'message',
        'role': 'assistant',
        'model': model,
        'content': <Object?>[
          if (thinking.isNotEmpty)
            <String, Object?>{'type': 'thinking', 'thinking': thinking},
          <String, Object?>{'type': 'text', 'text': reply},
        ],
        'stop_reason': 'end_turn',
        'usage': <String, Object?>{
          'input_tokens': 120,
          'output_tokens': reply.length,
        },
      };
    case _Protocol.gemini:
      return <String, Object?>{
        'candidates': <Object?>[
          <String, Object?>{
            'content': <String, Object?>{
              'role': 'model',
              'parts': <Object?>[
                if (thinking.isNotEmpty)
                  <String, Object?>{'text': thinking, 'thought': true},
                <String, Object?>{'text': reply},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
        'usageMetadata': <String, Object?>{
          'promptTokenCount': 120,
          'candidatesTokenCount': reply.length,
        },
      };
  }
}

Future<void> _stream(
  HttpResponse response,
  _Protocol protocol,
  String reply,
  String thinking, {
  required Duration delay,
  required String model,
}) async {
  response
    ..statusCode = HttpStatus.ok
    ..bufferOutput = false
    ..headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    )
    ..headers.set('cache-control', 'no-cache');
  Future<void> send(Object data, {String? event}) async {
    if (event != null) response.write('event: $event\n');
    response.write('data: ${jsonEncode(data)}\n\n');
    await response.flush();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  switch (protocol) {
    case _Protocol.responses:
      Future<void> emit(Map<String, Object?> data) =>
          send(data, event: data['type']! as String);
      await emit(<String, Object?>{
        'type': 'response.created',
        'response': <String, Object?>{'id': 'resp_mock', 'model': model},
      });
      for (final piece in _pieces(thinking)) {
        await emit(<String, Object?>{
          'type': 'response.reasoning_summary_text.delta',
          'delta': piece,
        });
      }
      if (thinking.isNotEmpty) {
        await emit(<String, Object?>{
          'type': 'response.reasoning_summary_part.done',
        });
      }
      for (final piece in _pieces(reply)) {
        await emit(<String, Object?>{
          'type': 'response.output_text.delta',
          'delta': piece,
        });
      }
      await emit(<String, Object?>{
        'type': 'response.completed',
        'response': <String, Object?>{
          'id': 'resp_mock',
          'status': 'completed',
          'usage': <String, Object?>{
            'input_tokens': 120,
            'output_tokens': reply.length,
          },
        },
      });
    case _Protocol.openAi:
      Map<String, Object?> chunk(
        Map<String, Object?> delta, {
        String? finish,
      }) => <String, Object?>{
        'id': 'mock',
        'object': 'chat.completion.chunk',
        'model': model,
        'choices': <Object?>[
          <String, Object?>{
            'index': 0,
            'delta': delta,
            'finish_reason': finish,
          },
        ],
      };
      for (final piece in _pieces(thinking)) {
        await send(chunk(<String, Object?>{'reasoning_content': piece}));
      }
      for (final piece in _pieces(reply)) {
        await send(chunk(<String, Object?>{'content': piece}));
      }
      await send(chunk(const <String, Object?>{}, finish: 'stop'));
      await send(<String, Object?>{
        'id': 'mock',
        'choices': const <Object?>[],
        'usage': <String, Object?>{
          'prompt_tokens': 120,
          'completion_tokens': reply.length,
        },
      });
      response.write('data: [DONE]\n\n');
    case _Protocol.anthropic:
      await send(event: 'message_start', <String, Object?>{
        'type': 'message_start',
        'message': <String, Object?>{
          'id': 'msg_mock',
          'model': model,
          'usage': <String, Object?>{'input_tokens': 120, 'output_tokens': 1},
        },
      });
      var index = 0;
      if (thinking.isNotEmpty) {
        await send(event: 'content_block_start', <String, Object?>{
          'type': 'content_block_start',
          'index': index,
          'content_block': <String, Object?>{
            'type': 'thinking',
            'thinking': '',
          },
        });
        for (final piece in _pieces(thinking)) {
          await send(event: 'content_block_delta', <String, Object?>{
            'type': 'content_block_delta',
            'index': index,
            'delta': <String, Object?>{
              'type': 'thinking_delta',
              'thinking': piece,
            },
          });
        }
        await send(event: 'content_block_stop', <String, Object?>{
          'type': 'content_block_stop',
          'index': index,
        });
        index++;
      }
      await send(event: 'content_block_start', <String, Object?>{
        'type': 'content_block_start',
        'index': index,
        'content_block': <String, Object?>{'type': 'text', 'text': ''},
      });
      for (final piece in _pieces(reply)) {
        await send(event: 'content_block_delta', <String, Object?>{
          'type': 'content_block_delta',
          'index': index,
          'delta': <String, Object?>{'type': 'text_delta', 'text': piece},
        });
      }
      await send(event: 'content_block_stop', <String, Object?>{
        'type': 'content_block_stop',
        'index': index,
      });
      await send(event: 'message_delta', <String, Object?>{
        'type': 'message_delta',
        'delta': <String, Object?>{'stop_reason': 'end_turn'},
        'usage': <String, Object?>{'output_tokens': reply.length},
      });
      await send(event: 'message_stop', <String, Object?>{
        'type': 'message_stop',
      });
    case _Protocol.gemini:
      for (final piece in _pieces(thinking)) {
        await send(<String, Object?>{
          'candidates': <Object?>[
            <String, Object?>{
              'content': <String, Object?>{
                'role': 'model',
                'parts': <Object?>[
                  <String, Object?>{'text': piece, 'thought': true},
                ],
              },
            },
          ],
        });
      }
      final pieces = _pieces(reply);
      for (var i = 0; i < pieces.length; i++) {
        final last = i == pieces.length - 1;
        await send(<String, Object?>{
          'candidates': <Object?>[
            <String, Object?>{
              'content': <String, Object?>{
                'role': 'model',
                'parts': <Object?>[
                  <String, Object?>{'text': pieces[i]},
                ],
              },
              if (last) 'finishReason': 'STOP',
            },
          ],
          if (last)
            'usageMetadata': <String, Object?>{
              'promptTokenCount': 120,
              'candidatesTokenCount': reply.length,
            },
        });
      }
  }
  await response.close();
}

/// 按协议的错误体格式返回 [kind] 对应的错误。
Future<void> _fail(HttpResponse response, _Protocol protocol, String kind) {
  final (status, message) = switch (kind) {
    '401' => (401, 'Incorrect API key provided (mock).'),
    '403' => (403, 'Permission denied (mock).'),
    '404' => (404, 'The model does not exist (mock).'),
    '429' => (429, 'Rate limit reached (mock).'),
    'context' => (
      400,
      "This model's maximum context length is 8192 tokens (mock).",
    ),
    'filtered' => (400, 'Content blocked by safety settings (mock).'),
    _ => (500, 'Internal server error (mock).'),
  };
  final body = switch (protocol) {
    _Protocol.openAi || _Protocol.responses => <String, Object?>{
      'error': <String, Object?>{
        'message': message,
        'type': kind == 'context' ? 'invalid_request_error' : 'mock_error',
        'code': kind == 'context' ? 'context_length_exceeded' : kind,
      },
    },
    _Protocol.anthropic => <String, Object?>{
      'type': 'error',
      'error': <String, Object?>{
        'type': switch (status) {
          401 => 'authentication_error',
          403 => 'permission_error',
          404 => 'not_found_error',
          429 => 'rate_limit_error',
          400 => 'invalid_request_error',
          _ => 'api_error',
        },
        'message': message,
      },
    },
    _Protocol.gemini => <String, Object?>{
      'error': <String, Object?>{
        'code': status,
        'message': message,
        'status': switch (status) {
          401 => 'UNAUTHENTICATED',
          403 => 'PERMISSION_DENIED',
          404 => 'NOT_FOUND',
          429 => 'RESOURCE_EXHAUSTED',
          400 => 'INVALID_ARGUMENT',
          _ => 'INTERNAL',
        },
      },
    },
  };
  return _json(response, body, status: status);
}

Future<void> _json(
  HttpResponse response,
  Object body, {
  int status = HttpStatus.ok,
}) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

Future<void> _notFound(HttpResponse response) =>
    _json(response, <String, Object?>{
      'error': <String, Object?>{'message': 'not found'},
    }, status: HttpStatus.notFound);
