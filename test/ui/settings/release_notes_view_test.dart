import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/release_notes_view.dart';
import 'package:node_diary/ui/widgets/markdown/markdown_code_block.dart';
import 'package:node_diary/ui/widgets/markdown/markdown_table.dart';

/// Markdown 视图：表格画成表、代码块带语言名与复制；内容没变时块的组件
/// 原样复用（不重建），流式时只有末尾那一块跟着变。
void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('tables render as a table and code blocks can be copied', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        const ReleaseNotesView(
          markdown:
              '| 月份 | 篇数 |\n|---|---:|\n| 十月 | 12 |\n\n'
              '```py\nprint("hi")\n```\n',
        ),
      ),
    );

    expect(find.byType(MarkdownTable), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('十月', findRichText: true), findsOneWidget);
    // 别名 py 认成 Python，标题写语言名。
    expect(markdownCodeLanguageId('py'), 'python');
    expect(find.text('Python'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.markdownCopyCode));
    await tester.pump();
    expect(copied, 'print("hi")');
    expect(find.byTooltip(l10n.markdownCodeCopied), findsOneWidget);
    // 两秒后换回“复制”。
    await tester.pump(const Duration(seconds: 3));
    expect(find.byTooltip(l10n.markdownCopyCode), findsOneWidget);
  });

  testWidgets('while streaming only the last block is rebuilt', (tester) async {
    Future<void> pump(String markdown) => tester.pumpWidget(
      host(ReleaseNotesView(markdown: markdown, streaming: true)),
    );

    await pump('第一段写完了。\n\n第二段');
    await tester.pumpAndSettle();
    final first = tester.renderObject(find.text('第一段写完了。', findRichText: true));
    final firstWidget = tester.widget(find.text('第一段写完了。', findRichText: true));

    await pump('第一段写完了。\n\n第二段还在写');
    await tester.pumpAndSettle();
    // 定稿的块交回同一个组件实例，渲染对象也没换。
    expect(
      identical(
        tester.widget(find.text('第一段写完了。', findRichText: true)),
        firstWidget,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.renderObject(find.text('第一段写完了。', findRichText: true)),
        first,
      ),
      isTrue,
    );
    expect(find.text('第二段还在写', findRichText: true), findsOneWidget);
  });

  testWidgets('an unchanged document keeps its block widgets', (tester) async {
    const markdown = '## 标题\n\n正文一段。\n\n---\n\n又一段。\n\n---\n';
    await tester.pumpWidget(host(const ReleaseNotesView(markdown: markdown)));
    final before = tester.widget(find.text('正文一段。', findRichText: true));
    // 外层重建（回调对象换了）但内容没变。
    await tester.pumpWidget(
      host(ReleaseNotesView(markdown: markdown, onOpenLink: (_) {})),
    );
    // 链接能不能点变了：记住的组件作废、重新建。
    expect(
      identical(tester.widget(find.text('正文一段。', findRichText: true)), before),
      isFalse,
    );
    final rebuilt = tester.widget(find.text('正文一段。', findRichText: true));
    await tester.pumpWidget(
      host(ReleaseNotesView(markdown: markdown, onOpenLink: (_) {})),
    );
    expect(
      identical(tester.widget(find.text('正文一段。', findRichText: true)), rebuilt),
      isTrue,
    );
    // 两条分隔线各在各的位置。
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
