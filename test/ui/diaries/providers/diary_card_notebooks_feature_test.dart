import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/providers/diary_card_style_provider.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';

void main() {
  final withNotebooks = DiaryCardStyle.defaults.copyWith(
    content: DiaryCardStyle.defaults.content.copyWith(showNotebooks: true),
  );

  ProviderContainer container(AppFeatures features) {
    final container = ProviderContainer(
      overrides: [
        appFeaturesProvider.overrideWith(() => _FixedFeatures(features)),
        diaryCardStyleSettingsProvider.overrideWith(
          () => _FixedCardStyle(DiaryCardStyleSettings(current: withNotebooks)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('cards show notebooks when the style asks for it', () {
    final style = container(AppFeatures.defaults).read(diaryCardStyleProvider);
    expect(style.content.showNotebooks, isTrue);
  });

  test('turning the notebooks feature off hides them but keeps the saved '
      'style untouched', () {
    final c = container(const AppFeatures(notebooks: false));
    expect(c.read(diaryCardStyleProvider).content.showNotebooks, isFalse);
    expect(
      c.read(diaryCardStyleSettingsProvider).current.content.showNotebooks,
      isTrue,
    );
  });
}

class _FixedFeatures extends AppFeaturesNotifier {
  _FixedFeatures(this.features);

  final AppFeatures features;

  @override
  AppFeatures build() => features;
}

class _FixedCardStyle extends DiaryCardStyleSettingsNotifier {
  _FixedCardStyle(this.settings);

  final DiaryCardStyleSettings settings;

  @override
  DiaryCardStyleSettings build() => settings;
}
