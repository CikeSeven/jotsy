import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';

void main() {
  testWidgets('time capsule picker stays inside publish panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: PublishDiaryPanel(
                  saving: false,
                  bottomInset: 0,
                  hasCover: false,
                  coverLabel: null,
                  locating: false,
                  weatherLoading: false,
                  locationController: TextEditingController(),
                  weatherController: TextEditingController(),
                  weatherIconCode: null,
                  moodEmoji: null,
                  energyLevel: 4,
                  tags: const <Tag>[],
                  tagsLoading: false,
                  tagsError: null,
                  selectedTagIds: const <int>{},
                  onPickCover: () {},
                  onResolveLocation: () {},
                  onResolveWeather: () {},
                  onLocationChanged: (_) {},
                  onWeatherChanged: (_) {},
                  onCreateTag: () {},
                  onToggleTag: (_, _) {},
                  onMoodChanged: (_) {},
                  onEnergyChanged: (_) {},
                  onPublish: () {},
                  showTimeCapsuleOption: true,
                  timeCapsuleLabel: 'Not sealed',
                  onTimeCapsuleChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Swipe up to expand'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time lock'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Choose unlock time'), findsOneWidget);
  });
}
