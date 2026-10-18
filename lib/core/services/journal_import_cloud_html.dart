import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'journal_import_cloud.dart';
import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';

/// 把云端笔记的 HTML 正文写入 [writer]（华为、荣耀、OPPO、vivo 等）。
///
/// 正文里的图片先经 [imageId] 换算成附件 ID，再由 [resolve] 换成已下载的
/// 媒体；对应不上附件的图片直接移除——它们的地址多是带时效的签名链接，
/// 留作远程图片过后就会失效。[prepare] 可在转换前改写平台专有标记（附件
/// 卡片一律改写成以附件 ID 为 `src` 的 `<img>` 占位，媒体类型由附件文件名
/// 决定）。其余格式交给 [JournalHtmlConverter]（粗斜体、下划线、删除线、
/// 颜色与背景色、字号、标题、列表与待办 `data-checked`、引用、代码块、对齐、
/// 分隔线）。
void writeCloudHtml(
  JournalDeltaWriter writer,
  String html,
  CloudEmbedResolver resolve, {
  String? Function(dom.Element image)? imageId,
  void Function(dom.Element root)? prepare,
}) {
  final root = dom.Element.tag('div');
  html_parser.parseFragment(html).reparentChildren(root);
  prepare?.call(root);
  for (final image in root.querySelectorAll('img')) {
    final id = imageId == null ? image.attributes['src'] : imageId(image);
    if (id == null || id.isEmpty) {
      image.remove();
    } else {
      image.attributes['src'] = '$_scheme$id';
    }
  }
  JournalHtmlConverter(
    writer,
    resolveEmbed: (source) => source.startsWith(_scheme)
        ? resolve(source.substring(_scheme.length))
        : null,
  ).appendNodes(root.nodes.toList());
}

const String _scheme = 'cloud-attachment:';
