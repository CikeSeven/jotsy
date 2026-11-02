import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

/// 正文里包含 [text] 的那一行实际绘制的文字颜色（读画出来的 RichText，
/// 编辑器缓存了过期的 EditorStyle 时也能发现）。
Color _renderedColor(WidgetTester tester, String text) {
  final line = tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byType(DiaryEditor),
          matching: find.byType(RichText),
        ),
      )
      .firstWhere((rich) => rich.text.toPlainText().contains(text));
  Color? color;
  line.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.contains(text) ?? false)) {
      color = span.style?.color;
      return false;
    }
    return true;
  });
  return color ?? line.text.style!.color!;
}

void main() {
  // 应用切换明暗时 MaterialApp 按 themeAnimationDuration 补间主题（减少动画时
  // 为 0，直接换），而 Scaffold 的 Material 另用 AnimatedDefaultTextStyle 把
  // 正文的 DefaultTextStyle 补间约 200ms、不受减少动画影响。两种时长下打开着
  // 的编辑器都必须停在新主题的正文色上。
  for (final (label, duration) in <(String, Duration)>[
    ('with the theme animation', ExpressiveMotion.fast),
    ('when motion is reduced', Duration.zero),
  ]) {
    testWidgets('an open editor repaints its text in the new theme $label', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent(
        '晚霞把整片海都染成了橘色\n带上相机',
        readOnly: true,
      );
      addTearDown(controller.dispose);
      Future<void> pump(Brightness brightness) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
            ],
            child: MaterialApp(
              themeAnimationDuration: duration,
              theme: expressiveTestTheme(brightness),
              locale: const Locale('zh'),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                af.AppFlowyEditorLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DiaryEditor(
                  controller: controller,
                  appearance: const DiaryTextAppearance(
                    typography: DiaryTypography(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(Brightness.light);
      final light = expressiveTestTheme(Brightness.light).colorScheme;
      expect(_renderedColor(tester, '晚霞'), light.onSurface);

      await pump(Brightness.dark);
      final dark = expressiveTestTheme(Brightness.dark).colorScheme;
      expect(_renderedColor(tester, '晚霞'), dark.onSurface);
      expect(_renderedColor(tester, '带上相机'), dark.onSurface);

      await pump(Brightness.light);
      expect(_renderedColor(tester, '晚霞'), light.onSurface);
      expect(tester.takeException(), isNull);
    });
  }
}
