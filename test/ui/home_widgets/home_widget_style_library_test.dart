import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_settings.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_style.dart';
import 'package:node_diary/ui/diaries/models/style_library/saved_style.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';
import 'package:node_diary/ui/home_widgets/models/home_widget_style_library.dart';

void main() {
  test('presets are distinct and the classic one is the default look', () {
    final styles = HomeWidgetStylePreset.values.map((p) => p.style).toSet();
    expect(styles.length, HomeWidgetStylePreset.values.length);
    expect(
      HomeWidgetStylePreset.matching(HomeWidgetStyle.defaults),
      HomeWidgetStylePreset.classic,
    );
    expect(
      HomeWidgetStylePreset.matching(
        const HomeWidgetStyle(background: HomeWidgetBackground.tonal),
      ),
      isNull,
    );
  });

  test('my styles survive other settings changes and a round trip', () {
    const style = HomeWidgetStyle(
      palette: HomeWidgetPalette.seed,
      seed: 0xFFD98BA0,
      background: HomeWidgetBackground.vivid,
    );
    final saved = SavedStyles.add(<SavedStyle<HomeWidgetStyle>>[], '粉', style)!;
    var settings = homeWidgetSettingsWithSaved(HomeWidgetSettings.empty, saved);
    settings = settings
        .withInstance(3, HomeWidgetInstance.defaultsFor(HomeWidgetKind.today))
        .withPending(
          HomeWidgetInstance.defaultsFor(HomeWidgetKind.todos),
          DateTime(2026, 11, 15),
        );
    settings = settings.reconcile(
      <int, HomeWidgetKind>{},
      DateTime(2026, 11, 15),
    )!;
    final decoded = HomeWidgetSettings.decode(settings.encode());
    final restored = homeWidgetSavedStyles(decoded);
    expect(restored.single.name, '粉');
    expect(restored.single.style, style);
  });

  test('a broken saved entry is skipped, the rest stay', () {
    final settings = HomeWidgetSettings.decode(
      '{"v":1,"instances":{},"saved":['
      '{"id":"a","name":"好","style":{"background":"vivid"}},'
      '{"id":"","name":"坏"},'
      '"nope"]}',
    );
    final saved = homeWidgetSavedStyles(settings);
    expect(saved.single.name, '好');
    expect(saved.single.style.background, HomeWidgetBackground.vivid);
  });

  test('style codes round-trip and reject other kinds of codes', () {
    final style = HomeWidgetStylePreset.night.style;
    final code = homeWidgetStyleCode.encode(style, name: '夜读');
    expect(code, startsWith('jotsy-widget:v1:'));
    final decoded = homeWidgetStyleCode.decode('看看这个：$code 好看吗');
    expect(decoded.status, StyleCodeStatus.ok);
    expect(decoded.style, style);
    expect(decoded.name, '夜读');
    // 别的样式编辑页的样式码（前缀不同）不认。
    final other = code.replaceFirst('jotsy-widget', 'jotsy-card');
    expect(homeWidgetStyleCode.decode(other).status, StyleCodeStatus.invalid);
  });
}
