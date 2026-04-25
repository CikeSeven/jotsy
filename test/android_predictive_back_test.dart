import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';

void main() {
  test('FlutterFragmentActivity bridges Android predictive back progress', () {
    final mainActivity =
        File(
          'android/app/src/main/kotlin/com/jotsy/diary/MainActivity.kt',
        ).readAsStringSync();

    expect(mainActivity, contains('OnBackAnimationCallback'));
    expect(mainActivity, contains('onBackStarted'));
    expect(mainActivity, contains('onBackProgressed'));
    expect(mainActivity, contains('startBackGesture'));
    expect(mainActivity, contains('updateBackGestureProgress'));
  });

  test('predictive back bridge restores registration after recreation', () {
    final mainActivity =
        File(
          'android/app/src/main/kotlin/com/jotsy/diary/MainActivity.kt',
        ).readAsStringSync();

    expect(mainActivity, contains('override fun onCreate'));
    expect(mainActivity, contains('backCallbackState'));
  });

  test('Android activity opts in to predictive back callbacks', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
  });

  test('Android routes use predictive back page transitions', () {
    final theme = MaterialTheme(
      Typography.material2021().black,
    ).theme(ColorScheme.fromSeed(seedColor: Colors.blue));

    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });
}
