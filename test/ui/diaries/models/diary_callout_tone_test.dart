import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/models/diary_callout_tone.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('tone ids match the stored tone values one to one', () {
    expect(
      DiaryCalloutTone.values.map((tone) => tone.id).toList(),
      kDiaryCalloutTones,
    );
  });

  test('unknown or missing tone falls back to neutral', () {
    expect(DiaryCalloutTone.fromId(null), DiaryCalloutTone.neutral);
    expect(DiaryCalloutTone.fromId('teal'), DiaryCalloutTone.neutral);
    expect(DiaryCalloutTone.fromId(3), DiaryCalloutTone.neutral);
    expect(DiaryCalloutTone.fromId('red'), DiaryCalloutTone.red);
  });

  test('body text stays readable on every tone in both themes', () {
    for (final seed in const [
      Color(0xFF6750A4),
      Color(0xFF006A60),
      Color(0xFFB3261E),
      Color(0xFF8C7000),
    ]) {
      for (final brightness in Brightness.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        );
        for (final tone in DiaryCalloutTone.values) {
          expect(
            _contrast(scheme.onSurface, tone.background(scheme)),
            greaterThanOrEqualTo(4.5),
            reason: '${tone.id} on $brightness seed $seed',
          );
        }
      }
    }
  });

  test('paper colors keep dark ink readable for exports', () {
    for (final tone in DiaryCalloutTone.values) {
      expect(
        _contrast(const Color(0xFF1F1F1F), tone.paperBackground),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
