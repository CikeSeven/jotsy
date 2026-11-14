import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_paged_background.dart';

import '../app_surface_test_images.dart';

class _Surface extends AppSurfaceSettingsNotifier {
  _Surface(this.settings);
  final AppSurfaceSettings settings;

  @override
  AppSurfaceSettings build() => settings;
}

void main() {
  const areas = <AppBackgroundArea>[
    AppBackgroundArea.diaries,
    AppBackgroundArea.calendar,
  ];
  const image = AppBackground(kind: AppBackgroundKind.image, image: 'bg.png');

  for (final identicalBackgrounds in <bool>[true, false]) {
    testWidgets(
      'paged sample is ${identicalBackgrounds ? 'shared' : 'disabled'} '
      'when area backgrounds ${identicalBackgrounds ? 'match' : 'differ'}',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cache = AppBackgroundImageCache(
          loader: FakeBackgroundLoader().call,
        );
        addTearDown(cache.dispose);
        final position = ValueNotifier<double>(0);
        addTearDown(position.dispose);
        await tester.runAsync(() async {
          (await cache.load(
            AppBackgroundImageKey.forDisplay(
              fileName: 'bg.png',
              blur: 0,
              logicalSize: const Size(400, 800),
              devicePixelRatio: 1,
            ),
          ))?.dispose();
        });
        final settings = AppSurfaceSettings(global: image).withArea(
          AppBackgroundArea.calendar,
          AppAreaBackground(
            mode: identicalBackgrounds
                ? AppAreaBackgroundMode.follow
                : AppAreaBackgroundMode.off,
          ),
        );
        final backdrops = <AppBackgroundArea, AppPageBackdrop>{};
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSurfaceSettingsProvider.overrideWith(() => _Surface(settings)),
              appBackgroundImageCacheProvider.overrideWithValue(cache),
            ],
            child: MaterialApp(
              home: AppPagedBackground(
                areas: areas,
                current: 0,
                position: position,
                child: Column(
                  children: <Widget>[
                    for (final area in areas)
                      AppAreaBackdrop(
                        area: area,
                        child: Builder(
                          builder: (context) {
                            backdrops[area] = AppPageBackdrop.of(context);
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final diary = backdrops[AppBackgroundArea.diaries]!;
        expect(diary.contentGlass != null, identicalBackgrounds);
        position.value = 0.5;
        await tester.pump();
        expect(
          backdrops[AppBackgroundArea.diaries]!.contentGlass != null,
          identicalBackgrounds,
        );
        if (identicalBackgrounds) {
          expect(
            backdrops[AppBackgroundArea.calendar]!.contentGlass!.link,
            same(diary.contentGlass!.link),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
