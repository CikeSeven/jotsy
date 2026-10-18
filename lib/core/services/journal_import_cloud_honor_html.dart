import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 荣耀笔记正文（`html_content`）的私有标记。类名与属性取自荣耀云网页版
/// 编辑器（`portal/note/main.2b996175.js` 的类名枚举与 `J0` 解析函数），
/// 每个内容块都带 `h_n` 类：
///
/// | 类名 | 含义 | 处理 |
/// | --- | --- | --- |
/// | `Nb` | 段落，`hlevel` 为标题级别，`Ai`/`Aj`/`Ak`/`Am` 左/中/右/两端对齐 | `p`/`h1`~`h6` + `text-align` |
/// | `Na` | 待办，`Sc` 为已完成 | `li[data-checked]` |
/// | `Nd`/`Nh`/`Nc` | 有序/无序列表与列表项 | `ol`/`ul`/`li` |
/// | `Nm` > `Nr` | 分隔线 | `hr` |
/// | `Nk` > `Ni[hid]` | 图片（外层带对齐类） | `div[text-align]` > `img` |
/// | `Nx[hid]` | 上传的文件（文档/音频/视频），文件名在 `.first-title` + `.last-title` + `.upload-type` 里，视频带封面 `hposterid` | 附件占位 |
/// | `N0[hid]` | 录音 | 附件占位 |
/// | `Nv` > `Nu` | 视频（`video[src]` 与 `.video-url`，文件名前缀是附件 ID） | 附件占位 |
///
/// 行内文字是 `h-text > font`：`La`~`Ld` 粗体/斜体/下划线/删除线，`Le` 高亮，
/// `hcolor` 文字色（`#191919`/`#000000` 是默认墨色），`hbgcolor` 背景色（CSS
/// 的 `#RRGGBBAA`），`hsize` 字号（工具栏档位 14/16/18/20/24，16 为正文），
/// `hlink` 链接。表格、网页收藏等其余块保留可读文字。
///
/// 附件占位一律写成 `img[src=附件 ID]`，由 writeCloudHtml 换成已下载的媒体，
/// 媒体类型按附件文件名判断，所以文档、录音、视频都能落在原来的位置。

/// 正文里与附件有关的信息：上传文件的显示名称，以及只作为视频封面、不应
/// 单独导入的图片附件。
class HonorHtmlIndex {
  const HonorHtmlIndex({required this.names, required this.posters});

  /// 附件 ID → 原文件名（上传文件卡片上显示的名称）。
  final Map<String, String> names;

  /// 视频封面图片的附件 ID。
  final Set<String> posters;
}

HonorHtmlIndex indexHonorHtml(String html) {
  final root = dom.Element.tag('div');
  html_parser.parseFragment(html).reparentChildren(root);
  final names = <String, String>{};
  final posters = <String>{};
  for (final file in root.querySelectorAll('.Nx')) {
    final id = file.attributes['hid'];
    final title = [
      '.first-title',
      '.last-title',
      '.upload-type',
    ].map((selector) => file.querySelector(selector)?.text ?? '').join().trim();
    if (id != null && id.isNotEmpty && title.isNotEmpty) names[id] = title;
    posters.addAll(
      [
        file.attributes['hposterid'],
        file.querySelector('.video-poster-card')?.attributes['poster-cid'],
      ].nonNulls.where((id) => id.isNotEmpty),
    );
  }
  for (final video in root.querySelectorAll('.Nu')) {
    posters.addAll(
      [
        video.querySelector('video')?.attributes['poster'],
        ...video.querySelectorAll('.video-poster').map((node) => node.text),
      ].map(_idFromUrl).nonNulls,
    );
  }
  return HonorHtmlIndex(names: names, posters: posters);
}

/// 把荣耀私有标记改写成 JournalHtmlConverter 认识的通用 HTML；[posters]
/// （视频封面）不生成附件占位。
void normalizeHonorHtml(
  dom.Element root, {
  Set<String> posters = const <String>{},
}) {
  // 编辑器的占位与装饰节点（`Al` 不保存、`spacer` 光标占位）不是正文。
  for (final node in root.querySelectorAll('.Al, [spacer]')) {
    node.remove();
  }
  for (final node in root.querySelectorAll('.h_n')) {
    // 外层块已被整体替换时，里面的节点不再在树上。
    if (!_attached(node, root)) continue;
    final classes = node.classes;
    final dom.Node replacement;
    if (classes.contains('Nb')) {
      final level = int.tryParse(node.attributes['hlevel'] ?? '');
      replacement = _aligned(
        dom.Element.tag(
          level != null && level >= 1 && level <= 6 ? 'h$level' : 'p',
        ),
        classes,
      );
      node.reparentChildren(replacement as dom.Element);
    } else if (classes.contains('Na')) {
      final checked =
          classes.contains('Sc') || node.querySelector('.Sc') != null;
      final item = dom.Element.tag('li')
        ..attributes['data-checked'] = '$checked';
      // 待办的勾选图标等装饰去掉，只保留文字片段。
      for (final text in node.querySelectorAll('h-text')) {
        item.append(text);
      }
      replacement = item;
    } else if (classes.contains('Nd') || classes.contains('Nh')) {
      replacement = dom.Element.tag(classes.contains('Nd') ? 'ol' : 'ul');
      node.reparentChildren(replacement as dom.Element);
    } else if (classes.contains('Nc')) {
      replacement = dom.Element.tag('li');
      node.reparentChildren(replacement as dom.Element);
    } else if (classes.contains('Nr')) {
      replacement = dom.Element.tag('hr');
    } else if (classes.contains('Ni') ||
        classes.contains('Nx') ||
        classes.contains('N0')) {
      replacement = _placeholder(node.attributes['hid']);
    } else if (classes.contains('Nu')) {
      replacement = dom.DocumentFragment();
      for (final id in _videoIds(node).where((id) => !posters.contains(id))) {
        replacement.append(_placeholder(id));
      }
    } else if (classes.contains('Nk') || classes.contains('Nv')) {
      replacement = _aligned(dom.Element.tag('div'), classes);
      node.reparentChildren(replacement as dom.Element);
    } else {
      continue;
    }
    node.replaceWith(replacement);
  }
  for (final font in root.getElementsByTagName('font').toList()) {
    final classes = font.classes;
    final attributes = font.attributes;
    final size = int.tryParse(attributes['hsize'] ?? '');
    // `Le` 高亮没有具体颜色，用 journalHighlightColor 对应的 CSS 写法。
    final background =
        attributes['hbgcolor'] ??
        (classes.contains('Le') ? 'rgba(255, 193, 7, 0.4)' : null);
    final style = [
      attributes['style'] ?? '',
      if (classes.contains('La')) 'font-weight:bold',
      if (classes.contains('Lb')) 'font-style:italic',
      if (classes.contains('Lc') || classes.contains('Ld'))
        'text-decoration:${[if (classes.contains('Lc')) 'underline', if (classes.contains('Ld')) 'line-through'].join(' ')}',
      if (attributes['hcolor'] case final color?) 'color:$color',
      if (background != null) 'background-color:$background',
      if (size != null) 'font-size:${_sizeKeyword(size)}',
    ].where((part) => part.isNotEmpty).join(';');
    final link = attributes['hlink'];
    final replacement = dom.Element.tag(link == null ? 'span' : 'a');
    if (link != null) replacement.attributes['href'] = link;
    if (style.isNotEmpty) replacement.attributes['style'] = style;
    font.reparentChildren(replacement);
    font.replaceWith(replacement);
  }
}

/// 荣耀的字号档位换成 CSS 关键字：14 偏小、18/20 偏大、24 起特大，正文 16
/// 与介于其间的值写成 medium（去掉外层继承的字号）。
String _sizeKeyword(int size) {
  if (size < 15) return 'small';
  if (size <= 17) return 'medium';
  if (size < 22) return 'large';
  return 'xx-large';
}

dom.Element _aligned(dom.Element element, Iterable<String> classes) {
  final align = classes.contains('Aj')
      ? 'center'
      : classes.contains('Ak')
      ? 'right'
      : classes.contains('Am')
      ? 'justify'
      : null;
  if (align != null) element.attributes['style'] = 'text-align:$align';
  return element;
}

dom.Element _placeholder(String? id) =>
    dom.Element.tag('img')..attributes['src'] = id ?? '';

/// 视频卡片引用的附件：每段视频地址的文件名前缀（`<附件ID>_…`）与卡片
/// 自身的 `hid`（编辑器统计附件时两者都算）。对不上附件的 ID 在换成媒体时
/// 自然丢弃。
List<String> _videoIds(dom.Element node) {
  final urls = [
    ...node.querySelectorAll('.video-url').map((url) => url.text),
    node.querySelector('video')?.attributes['src'],
  ];
  return <String>{
    ...urls.map(_idFromUrl).nonNulls,
    if (node.attributes['hid'] case final id? when id.isNotEmpty) id,
  }.toList();
}

String? _idFromUrl(String? url) {
  final segment = url?.trim().split(RegExp(r'[/\\]+')).last ?? '';
  if (segment.isEmpty) return null;
  final name = segment.split('?').first;
  String decoded;
  try {
    decoded = Uri.decodeComponent(name);
  } on ArgumentError {
    decoded = name;
  }
  final id = decoded.split('_').first;
  return id.isEmpty ? null : id;
}

bool _attached(dom.Node node, dom.Element root) {
  for (dom.Node? current = node; current != null; current = current.parent) {
    if (identical(current, root)) return true;
  }
  return false;
}
