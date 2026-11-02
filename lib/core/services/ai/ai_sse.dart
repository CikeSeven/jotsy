import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

/// 一个 Server-Sent Event。
@immutable
class AiSseEvent {
  const AiSseEvent({this.event, required this.data});

  /// `event:` 字段；没有时为 null（OpenAI 兼容与 Gemini 都不写）。
  final String? event;

  /// 多行 `data:` 以换行拼接后的内容。
  final String data;

  bool get isDone => data.trim() == '[DONE]';

  @override
  String toString() => 'AiSseEvent($event, $data)';
}

/// 把字节流解码成 SSE 事件流（WHATWG EventSource 的子集）：
/// - UTF-8 跨块边界由 [utf8.decoder] 处理，换行（`\n` / `\r\n` / `\r`）由
///   [LineSplitter] 处理；
/// - 空行结束一个事件；同一事件里的多行 `data:` 以 `\n` 拼接；
/// - 以 `:` 开头的注释行（心跳）忽略；冒号后的第一个空格去掉；
/// - 没有 data 的事件不发出；流结束时若还有未以空行结束的事件也照样发出
///   （部分服务商最后一块后面不跟空行）。
///
/// 不处理 `id:` / `retry:`：AI 接口不支持断线续传，断了就按失败处理。
Stream<AiSseEvent> decodeAiSse(Stream<List<int>> bytes) async* {
  String? event;
  final data = <String>[];

  AiSseEvent? flush() {
    if (data.isEmpty) {
      event = null;
      return null;
    }
    final result = AiSseEvent(event: event, data: data.join('\n'));
    event = null;
    data.clear();
    return result;
  }

  final lines = bytes
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      final dispatched = flush();
      if (dispatched != null) yield dispatched;
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        data.add(value);
      case 'event':
        event = value;
    }
  }
  final tail = flush();
  if (tail != null) yield tail;
}
