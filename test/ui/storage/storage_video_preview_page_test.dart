import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/storage/pages/storage_video_preview_page.dart';
import 'package:node_diary/ui/storage/viewmodels/storage_media_view.dart';

import '../../support/fake_video_player.dart';
import '../../support/storage_test_fixtures.dart';
import 'storage_test_app.dart';

void main() {
  final l10n = storageL10n;
  final report = sampleStorageReport();
  final video = report.media.firstWhere(
    (entry) => entry.key == 'diary_videos/m1/trip.mp4',
  );
  final item = StorageMediaItemView(
    entry: video,
    masked: false,
    estimatedBytes: null,
    video: report.videoInfo[video.key],
  );

  testWidgets('starts playing once ready and shows what it is', (tester) async {
    final player = FakeVideoPlayer();
    await pumpStoragePage(
      tester,
      StorageVideoPreviewPage(item: item, player: player),
      service: FakeStorageMediaService(report),
    );

    expect(player.playCount, 1);
    expect(find.text('海边'), findsOneWidget);
    expect(find.text(l10n.formatByteSize(video.bytes)), findsOneWidget);
    expect(find.textContaining('3840×2160'), findsOneWidget);
    expect(find.byTooltip(l10n.storageMgmtOpenExternally), findsOneWidget);
    expect(find.byTooltip(l10n.videoPause), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.videoPause));
    await tester.pumpAndSettle();
    expect(player.pauseCount, greaterThanOrEqualTo(1));
    expect(find.byTooltip(l10n.videoPlay), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(player.wasDisposed, isTrue);
  });

  testWidgets('a video that cannot play says so instead of spinning', (
    tester,
  ) async {
    final player = FakeVideoPlayer()..failInitialization = true;
    await pumpStoragePage(
      tester,
      StorageVideoPreviewPage(item: item, player: player),
      service: FakeStorageMediaService(report),
    );

    expect(player.playCount, 0);
    expect(find.text(l10n.videoPlaybackFailed), findsOneWidget);
  });
}
