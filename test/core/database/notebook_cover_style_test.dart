import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  test('default cover style is not written into the payload', () {
    expect(NotebookPayload.defaults.encode(), '{}');
    final payload = NotebookPayload(coverPath: '/c.jpg');
    expect(payload.encode(), '{"cover":"/c.jpg"}');
  });

  test('cover style round-trips sparsely through the payload', () {
    final style = NotebookCoverStyle(
      layout: NotebookCoverLayout.spine,
      texture: NotebookCoverTexture.dots,
      focusX: 0.25,
      focusY: -0.5,
      zoom: 1.5,
    );
    final payload = NotebookPayload(coverStyle: style);
    expect(
      payload.encode(),
      '{"coverStyle":{"layout":"spine","texture":"dots","x":0.25,'
      '"y":-0.5,"zoom":1.5}}',
    );
    expect(NotebookPayload.decode(payload.encode()), payload);
    final layoutOnly = NotebookPayload(
      coverStyle: NotebookCoverStyle(layout: NotebookCoverLayout.label),
    );
    expect(layoutOnly.encode(), '{"coverStyle":{"layout":"label"}}');
  });

  test('bad cover style fields fall back one by one', () {
    final decoded = NotebookPayload.decode(
      '{"desc":"简介","coverStyle":{"layout":"hologram","texture":"grid",'
      '"x":"left","y":9,"zoom":0.1}}',
    );
    expect(decoded.description, '简介');
    expect(decoded.coverStyle.layout, NotebookCoverLayout.classic);
    expect(decoded.coverStyle.texture, NotebookCoverTexture.grid);
    expect(decoded.coverStyle.focusX, 0);
    expect(decoded.coverStyle.focusY, 1);
    expect(decoded.coverStyle.zoom, NotebookCoverStyle.minZoom);
    expect(
      NotebookPayload.decode('{"coverStyle":"spine"}').coverStyle,
      NotebookCoverStyle.defaults,
    );
  });

  test('crop values are rounded so encode and decode agree', () {
    final style = NotebookCoverStyle(focusX: 0.123456, zoom: double.nan);
    expect(style.focusX, 0.123);
    expect(style.zoom, 1);
    final payload = NotebookPayload(coverStyle: style);
    expect(NotebookPayload.decode(payload.encode()), payload);
    expect(style.withoutCrop(), NotebookCoverStyle.defaults);
  });
}
