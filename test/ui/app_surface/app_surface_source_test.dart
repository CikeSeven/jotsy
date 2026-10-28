/// “背景与材质”的页面接入源码约束。
///
/// 1. 页面（`lib/ui/**/pages/*.dart` 与几个页面壳组件）里凡是建了 Scaffold
///    的文件，都必须接入页面背景：出现 `AppPageBackground`（自己画所在区域
///    的背景）、`AppPagedBackground`（首页外壳统一画四个 Tab 的背景），或
///    `AppPageBackdrop.`（由外层提供背景：首页各 Tab、预览页嵌在双栏右栏等）。否则用户设了背景，这一页仍是一整块不透明的 surface。
/// 2. `lib/ui` 下 Scaffold 的 `backgroundColor:` 不得直接写主题 surface：
///    页面底色一律经 `AppPageBackdrop.pageColorOf`（无背景时就是 surface）。
///
/// 两条规则共用一份豁免名单，每项写明原因。只看代码，忽略 `//` 注释行。
///
/// 3. 色调按钮（`FilledButton.tonal` / `.tonalIcon` / `IconButton.filledTonal`）
///    须经 `AppGlassField.tonalButtonStyle` 跟随“小控件”材质：主题无法单独
///    给 tonal 变体取色，漏掉一处就是玻璃界面里的一块实色补丁。自己指定了
///    语义底色（`backgroundColor:`，如危险操作的 errorContainer）的不算，
///    另有 [_tonalExempt] 名单。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 不接入页面背景的文件与原因。
const Map<String, String> _exempt = <String, String>{
  'lib/ui/settings/pages/cloud_notes_login_page.dart':
      '云端笔记登录：整页是官方网页视图，背景透不出来，也不该改网页的底',
  'lib/ui/diaries/pages/diary_video_fullscreen_page.dart':
      '全屏视频播放：内容铺满整页，不是阅读或设置页面',
  'lib/ui/widgets/image_viewer_page.dart': '看图页：图片铺满整页，底色随下拉关闭渐隐',
};

/// 不经 `AppGlassField.tonalButtonStyle` 的色调按钮所在文件与原因。
const Map<String, String> _tonalExempt = <String, String>{
  'lib/ui/widgets/expressive_button_group.dart':
      '按钮组的各段自己按 AppGlassField 取色（选中段为主色）',
  'lib/ui/diaries/widgets/diary_video_surface.dart': '叠在视频画面上的播放控件，不是玻璃界面的一部分',
  'lib/ui/diaries/widgets/diary_video_poster_card.dart':
      '视频封面卡的播放按钮叠在封面图上，与视频播放器的控件一致',
  'lib/ui/diaries/widgets/diary_audio_player_controls.dart':
      '播放键随播放状态在 secondaryContainer 与 primary 之间补间，是强调色',
};

/// `lib/ui/**/pages/` 之外、同样是页面壳（自己建页面 Scaffold）的组件。
const List<String> _pageShells = <String>[
  'lib/ui/settings/widgets/style_editor/style_editor_scaffold.dart',
  'lib/ui/diaries/widgets/diary_preview/diary_preview_surface.dart',
  'lib/ui/diaries/widgets/diary_preview/diary_preview_view.dart',
];

final RegExp _scaffoldCall = RegExp(r'(?<![A-Za-z0-9_])Scaffold\(');
final RegExp _tonalCall = RegExp(
  r'(FilledButton\.tonal(Icon)?|IconButton\.filledTonal)\(',
);
final RegExp _surfaceColor = RegExp(
  r'^(Theme\.of\(context\)\.)?(theme\.)?(colorScheme|scheme)\.surface$',
);

/// 去掉整行注释后的源码（行号不变，便于报告）。
String _code(File file) => file
    .readAsLinesSync()
    .map((line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');

/// 从 [open]（`(` 的下标）起找到配对的 `)`；跳过字符串字面量。
int _matchParen(String source, int open) {
  var depth = 0;
  var i = open;
  while (i < source.length) {
    final char = source[i];
    if (char == '\'' || char == '"') {
      i++;
      while (i < source.length && source[i] != char) {
        if (source[i] == '\\') i++;
        i++;
      }
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  throw StateError('unbalanced parentheses at $open');
}

/// 一次 Scaffold 调用里顶层 `backgroundColor:` 参数的值（没有则为 null）。
String? _backgroundArgument(String source, int open, int close) {
  var depth = 0;
  var start = open + 1;
  final args = <String>[];
  for (var i = open + 1; i < close; i++) {
    final char = source[i];
    if (char == '\'' || char == '"') {
      i++;
      while (i < close && source[i] != char) {
        if (source[i] == '\\') i++;
        i++;
      }
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      args.add(source.substring(start, i));
      start = i + 1;
    }
  }
  args.add(source.substring(start, close));
  for (final arg in args) {
    final trimmed = arg.trim();
    if (trimmed.startsWith('backgroundColor:')) {
      return trimmed
          .substring('backgroundColor:'.length)
          .replaceAll(RegExp(r'\s+'), '');
    }
  }
  return null;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  final uiFiles = Directory('lib/ui')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('exempt files exist', () {
    final missing = <String>[
      for (final path in <String>[
        ..._exempt.keys,
        ..._pageShells,
        ..._tonalExempt.keys,
      ])
        if (!File(path).existsSync()) path,
    ];
    expect(missing, isEmpty, reason: '豁免名单或页面壳名单里的文件已移动');
  });

  test('pages that build a Scaffold draw the page background', () {
    final pages = <File>[
      for (final file in uiFiles)
        if (RegExp(r'/pages/[^/]+\.dart$').hasMatch(file.path)) file,
      for (final path in _pageShells) File(path),
    ];
    expect(pages, isNotEmpty);
    final violations = <String>[];
    for (final file in pages) {
      if (_exempt.containsKey(file.path)) continue;
      final code = _code(file);
      if (!_scaffoldCall.hasMatch(code)) continue;
      if (!code.contains('AppPageBackground') &&
          !code.contains('AppPagedBackground') &&
          !code.contains('AppPageBackdrop.')) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          '页面 Scaffold 须包 AppPageBackground（或由外层经 AppPageBackdrop 提供背景），'
          '底色改为 AppPageBackdrop.pageColorOf(context)；确实不接入的页面加进豁免名单并写明原因',
    );
  });

  test('Scaffold backgroundColor never hard-codes the theme surface', () {
    final violations = <String>[];
    for (final file in uiFiles) {
      if (_exempt.containsKey(file.path)) continue;
      final code = _code(file);
      for (final match in _scaffoldCall.allMatches(code)) {
        final open = match.end - 1;
        final close = _matchParen(code, open);
        final value = _backgroundArgument(code, open, close);
        if (value != null && _surfaceColor.hasMatch(value)) {
          violations.add('${file.path}:${_lineOf(code, match.start)} $value');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '页面底色经 AppPageBackdrop.pageColorOf(context)：无背景时就是 surface',
    );
  });

  test('tonal buttons follow the glass controls material', () {
    final violations = <String>[];
    for (final file in uiFiles) {
      if (_tonalExempt.containsKey(file.path)) continue;
      final code = _code(file);
      for (final match in _tonalCall.allMatches(code)) {
        final open = match.end - 1;
        final call = code.substring(open, _matchParen(code, open));
        // 合并后的样式常先放进局部变量（如几个按钮共用的紧凑样式），这时
        // 调用里只有 `style:`，按文件里确有 tonalButtonStyle 放行。
        final viaVariable =
            call.contains('style:') && code.contains('tonalButtonStyle');
        if (call.contains('tonalButtonStyle') ||
            call.contains('backgroundColor:') ||
            viaVariable) {
          continue;
        }
        violations.add('${file.path}:${_lineOf(code, match.start)}');
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          '色调按钮须传 style: AppGlassField.tonalButtonStyle(context)'
          '（已有 style 时 merge），否则玻璃材质下是一块实色补丁',
    );
  });
}
