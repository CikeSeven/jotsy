import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_media_summary.dart';

void main() {
  group('DiaryCardColors', () {
    test('contrast ratio follows WCAG and is symmetric', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      expect(DiaryCardColors.contrastRatio(black, white), closeTo(21, 0.01));
      expect(DiaryCardColors.contrastRatio(white, black), closeTo(21, 0.01));
      expect(DiaryCardColors.contrastRatio(white, white), closeTo(1, 0.001));
    });

    test('contrastOver blends translucent foregrounds first', () {
      const background = Color(0xFFFFFFFF);
      final faint = const Color(0xFF000000).withValues(alpha: 0.05);
      expect(DiaryCardColors.contrastOver(faint, background), lessThan(1.2));
    });

    test('bestContrast picks the most readable candidate', () {
      const dark = Color(0xFF111111);
      const light = Color(0xFFF5F5F5);
      expect(
        DiaryCardColors.bestContrast(<Color>[
          dark,
          light,
        ], const Color(0xFF202020)),
        light,
      );
      expect(
        DiaryCardColors.bestContrast(<Color>[
          dark,
          light,
        ], const Color(0xFFFFF4B8)),
        dark,
      );
    });

    test('deriveDark keeps the hue and maps lightness by role', () {
      const sticky = Color(0xFFFFF4B8);
      final hue = HSLColor.fromColor(sticky).hue;
      final surface = HSLColor.fromColor(
        DiaryCardColors.deriveDark(sticky, DiaryCardColorRole.surface),
      );
      expect(surface.hue, closeTo(hue, 1));
      expect(surface.lightness, inInclusiveRange(0.12, 0.22));

      final accent = HSLColor.fromColor(
        DiaryCardColors.deriveDark(
          const Color(0xFF0D2B66),
          DiaryCardColorRole.accent,
        ),
      );
      // 经 RGB 往返后明度有约 0.005 的取整误差。
      expect(accent.lightness, inInclusiveRange(0.54, 0.81));

      final text = HSLColor.fromColor(
        DiaryCardColors.deriveDark(
          const Color(0xFF202020),
          DiaryCardColorRole.text,
        ),
      );
      expect(text.lightness, inInclusiveRange(0.69, 0.96));
    });
  });

  group('DiaryCardMediaSummary', () {
    test('counts Quill embeds and keeps the first images in order', () {
      final summary = DiaryCardMediaSummary.scan(
        '[{"insert":{"image":"/a.jpg"}},{"insert":"text\\n"},'
        '{"insert":{"image":"/b.jpg"}},{"insert":{"image":"/a.jpg"}},'
        '{"insert":{"audio":"{}"}},{"insert":{"video":"/v.mp4"}},'
        '{"insert":{"attachment":"{}"}},{"insert":{"file":"{}"}}]',
      );
      expect(summary.images, <String>['/a.jpg', '/b.jpg']);
      expect(summary.imageCount, 3);
      expect(summary.audioCount, 1);
      expect(summary.videoCount, 1);
      expect(summary.attachmentCount, 2);
      expect(summary.isEmpty, isFalse);
    });

    test('reads legacy AppFlowy image nodes like the cover lookup does', () {
      final nested = DiaryCardMediaSummary.scan(
        '{"root":{"children":[{"type":"image","attributes":{"url":"/x.png"}},'
        '{"type":"video","attributes":{"path":"/v.mp4"}}]}}',
      );
      expect(nested.images, <String>['/x.png']);
      expect(nested.videoCount, 1);
    });

    test('treats empty or corrupt content as no media', () {
      for (final raw in <String>['', '   ', '{oops', '[1,2,3]']) {
        expect(DiaryCardMediaSummary.scan(raw), DiaryCardMediaSummary.empty);
      }
    });
  });
}
