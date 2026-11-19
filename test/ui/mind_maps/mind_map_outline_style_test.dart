import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_rich_text.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_look.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_outline_view.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';

import '../../support/expressive_test_theme.dart';

/// 大纲的字体与样式（#328）：大纲按正文排版（编辑器设置里的字体、字号、
/// 行距、字间距）排字，再按层级与主题字号放大；画布跟随日记字体；长按一行
/// 弹出与画布相同的主题菜单；编辑时格式条的“字号”改整个主题的字号。
void main() {
  const appearance = DiaryTextAppearance(
    typography: DiaryTypography(fontSize: 20, lineHeight: 2, letterSpacing: 1),
    fontFamily: 'Serif',
  );

  MindMapDocument tree() {
    final document = MindMapOps.replaceRoot(
      MindMapDocument.blank(),
      mindMapNodeFromOutline('Plan\n  Topic\n    Alpha Beta\n    Gamma')!,
    );
    return MindMapOps.setStyle(
      document,
      idOf(document, 'Alpha Beta'),
      kMindMapStyleSizeKey,
      'l',
    );
  }

  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const <Override>[],
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: theme ?? expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  /// 一行主题文字自己那层样式（[Text.rich] 外面还包着一层默认样式）。
  TextStyle rowStyle(WidgetTester tester, String text) {
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text,
      ),
    );
    return ((rich.text as TextSpan).children!.single as TextSpan).style!;
  }

  testWidgets('outline rows use the diary typography, scaled by level and '
      'by the topic size', (tester) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(
      tester,
      MindMapOutlineView(controller: controller, appearance: appearance),
    );

    for (final (text, size, weight) in <(String, double, FontWeight)>[
      ('Plan', 20 * 1.45, FontWeight.w700),
      ('Topic', 20 * 1.1, FontWeight.w600),
      ('Alpha Beta', 20 * 1.2, FontWeight.normal),
      ('Gamma', 20, FontWeight.normal),
    ]) {
      final style = rowStyle(tester, text);
      expect(style.fontFamily, 'Serif', reason: text);
      expect(style.fontSize, closeTo(size, 0.001), reason: text);
      expect(style.fontWeight, weight, reason: text);
      expect(style.height, 2, reason: text);
      expect(style.letterSpacing, 1, reason: text);
    }

    // 编辑框与只读文字同一样式，开始编辑时字不跳。
    await tester.tap(find.text('Alpha Beta'));
    await tester.pump();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontFamily, 'Serif');
    expect(field.style?.fontSize, closeTo(24, 0.001));
  });

  testWidgets('the workspace outline follows the editor typography setting; '
      'the canvas follows the diary font', (tester) async {
    final controller = MindMapEditingController(tree())..outlineView = true;
    addTearDown(controller.dispose);
    late MindMapLook look;
    await pumpHost(
      tester,
      Builder(
        builder: (BuildContext context) {
          look = MindMapLook.of(context, controller.document);
          return MindMapWorkspace(controller: controller);
        },
      ),
      overrides: [diaryTextAppearanceProvider.overrideWithValue(appearance)],
      theme: expressiveTestTheme(
        Brightness.light,
      ).copyWith(extensions: const [AppFonts(diary: 'Serif')]),
    );
    await tester.pump();
    expect(rowStyle(tester, 'Gamma').fontSize, 20);
    expect(rowStyle(tester, 'Gamma').fontFamily, 'Serif');
    // 画布的字号仍由导图主题按层级定，只有字体随日记字体。
    expect(look.baseText.fontFamily, 'Serif');
  });

  testWidgets('long-pressing an outline row opens the topic menu; the size '
      'button in the keyboard bar resizes the whole topic while editing', (
    tester,
  ) async {
    final controller = MindMapEditingController(tree())..outlineView = true;
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    await tester.pump();

    await tester.longPress(find.text('Gamma'));
    await tester.pumpAndSettle();
    final gamma = idOf(controller.document, 'Gamma');
    expect(controller.selectedId, gamma);
    expect(controller.editingId, isNull);
    expect(find.text('Topic style'), findsOneWidget);
    await tester.tap(find.text('Topic style'));
    await tester.pumpAndSettle();
    // 主题样式面板里的字号一组（S / M / L / XL）。
    expect(find.text('XL'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 键盘附件条（手机）里的格式条：字号在按钮行之上展开一排档位。
    await tester.tap(find.text('Gamma'));
    await tester.pump();
    await tester.pump();
    expect(controller.editingId, gamma);
    await tester.tap(find.byTooltip('Size'));
    await tester.pumpAndSettle();
    expect(controller.textSession.panelExtent.value, greaterThan(0));
    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();
    expect(controller.document.index[gamma]!.style[kMindMapStyleSizeKey], 'l');
    expect(controller.editingId, gamma);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontSize, closeTo(16 * 1.2, 0.001));

    // 再点当前档位不留空的撤销步。
    final canUndoBefore = controller.canUndo;
    final revision = controller.revision;
    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();
    expect(controller.revision, revision);
    expect(controller.canUndo, canUndoBefore);

    // 局部样式不受字号影响。
    expect(mindMapHasRichText(controller.document.index[gamma]!), isFalse);
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.document.index[gamma]!.style[kMindMapStyleSizeKey], null);
  });
}

String idOf(MindMapDocument document, String text) => document.index.preorder
    .firstWhere((id) => document.index[id]!.text == text);
