import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// 逐块读取 ENEX，只在内存中组装当前一篇笔记。XML 事件解析器识别 CDATA、
/// 注释、属性与跨块标签，正文里字面的 `</note>` 不会提前结束笔记。截断或
/// 结构损坏的导出整次拒绝，不能把已读前半包当作完整导入。
void readEnexNotes(File file, void Function(XmlElement note) onNote) {
  final handle = file.openSync();
  final notes = _EnexNoteSink(onNote);
  final xml = XmlEventDecoder(
    validateDocument: true,
    validateNesting: true,
  ).startChunkedConversion(notes);
  final text = const Utf8Decoder().startChunkedConversion(xml);
  try {
    while (true) {
      final chunk = handle.readSync(1 << 20);
      if (chunk.isEmpty) break;
      text.add(chunk);
    }
    text.close();
  } finally {
    handle.closeSync();
  }
}

class _EnexNoteSink implements Sink<List<XmlEvent>> {
  _EnexNoteSink(this.onNote);

  final void Function(XmlElement note) onNote;
  int _depth = 0;
  bool _recognized = false;
  List<XmlEvent>? _note;

  @override
  void add(List<XmlEvent> events) {
    for (final event in events) {
      if (event is XmlStartElementEvent) {
        if (_depth == 0) {
          if (event.name != 'en-export') {
            throw const FormatException('ENEX root');
          }
          _recognized = true;
        } else if (_depth == 1 && event.name == 'note') {
          _note = [];
        }
        _note?.add(event);
        if (!event.isSelfClosing) {
          _depth++;
        } else if (_depth == 1 && event.name == 'note') {
          _emit();
        }
      } else if (event is XmlEndElementEvent) {
        _depth--;
        _note?.add(event);
        if (_depth == 1 && event.name == 'note') _emit();
      } else {
        _note?.add(event);
      }
    }
  }

  void _emit() {
    final note = const XmlNodeDecoder()
        .convert(_note!)
        .whereType<XmlElement>()
        .single;
    _note = null;
    onNote(note);
  }

  @override
  void close() {
    if (!_recognized || _depth != 0 || _note != null) {
      throw const FormatException('Incomplete ENEX');
    }
  }
}
