import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/robolectric_cache_key.dart';

void main() {
  const sampleGradle = '''
dependencies {
    // testImplementation("org.robolectric:robolectric:4.14.0")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}
''';

  test('extracts Robolectric version and deduplicated sorted SDKs', () {
    final spec = computeRobolectricCacheSpec(
      gradleContent: sampleGradle,
      testSources: const <String, String>{
        'kotlin/A.kt': '''
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [33, 29])
class ATest {
  @Test @Config(sdk = [33]) fun one() {}
}
''',
        'kotlin/B.kt': '''
@RunWith(RobolectricTestRunner::class)
@Config(
  sdk = [34, 30],
  qualifiers = "xxhdpi",
)
class BTest
''',
      },
    );

    expect(spec.version, '4.16.1');
    expect(spec.sdks, <int>[29, 30, 33, 34]);
    expect(spec.keySuffix, 'sdk-29-30-33-34');
    expect(
      spec.toGitHubOutput(),
      'version=4.16.1\n'
      'sdks=29 30 33 34\n'
      'key_suffix=sdk-29-30-33-34\n',
    );
  });

  test(
    'editing test assertions, comments or unrelated Gradle deps keeps key',
    () {
      final before = computeRobolectricCacheSpec(
        gradleContent: sampleGradle,
        testSources: const <String, String>{
          'kotlin/TodoReminderManagerTest.kt': '''
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 33])
class TodoReminderManagerTest {
  @Test fun original() {}
}
''',
        },
      );
      final after = computeRobolectricCacheSpec(
        gradleContent: sampleGradle.replaceFirst('2.11.2', '2.12.0'),
        testSources: const <String, String>{
          'kotlin/TodoReminderManagerTest.kt': '''
// @Config(sdk = [35]) mentioned in comment should not invalidate cache.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 33])
class TodoReminderManagerTest {
  @Test fun original() {}
  @Test fun addedDailyDigestTest() {
    val sample = "@Config(sdk = [36])"
  }
}
''',
        },
      );

      expect(after.version, before.version);
      expect(after.sdks, before.sdks);
      expect(after.keySuffix, before.keySuffix);
    },
  );

  test(
    'supports Java array syntax, minSdk/maxSdk, symbolic SDKs and properties',
    () {
      final javaAndRange = computeRobolectricCacheSpec(
        gradleContent: sampleGradle,
        testSources: const <String, String>{
          'java/SampleTest.java': '''
@RunWith(RobolectricTestRunner.class)
@Config(sdk = {29, 31})
public class SampleTest {}
''',
          'kotlin/RangeTest.kt': '''
@RunWith(RobolectricTestRunner::class)
@Config(minSdk = 33, maxSdk = 35)
class RangeTest
''',
        },
      );
      expect(javaAndRange.sdks, <int>[29, 31, 33, 34, 35]);
      expect(javaAndRange.keySuffix, startsWith('sdk-29-31-33-34-35-extra-'));

      final symbolic = computeRobolectricCacheSpec(
        gradleContent: sampleGradle,
        testSources: const <String, String>{
          'kotlin/SymbolicTest.kt': '''
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.TIRAMISU])
class SymbolicTest
''',
        },
      );
      expect(symbolic.sdks, isEmpty);
      expect(symbolic.keySuffix, startsWith('extra-'));

      final withProps = computeRobolectricCacheSpec(
        gradleContent: sampleGradle,
        testSources: const <String, String>{
          'kotlin/DefaultTest.kt': '''
@RunWith(RobolectricTestRunner::class)
class DefaultTest
''',
        },
        propertiesFiles: const <String, String>{
          'resources/robolectric.properties': '# comment\nsdk=33\n',
        },
      );
      final withDifferentProps = computeRobolectricCacheSpec(
        gradleContent: sampleGradle,
        testSources: const <String, String>{
          'kotlin/DefaultTest.kt': '''
@RunWith(RobolectricTestRunner::class)
class DefaultTest
''',
        },
        propertiesFiles: const <String, String>{
          'resources/robolectric.properties': 'sdk=34\n',
        },
      );
      expect(withProps.keySuffix, isNot(withDifferentProps.keySuffix));
    },
  );

  test(
    'fails clearly when Robolectric dependency is missing or duplicated',
    () {
      expect(
        () => parseRobolectricVersion(
          'dependencies { testImplementation("junit:junit:4.13.2") }',
        ),
        throwsFormatException,
      );
      expect(
        () => parseRobolectricVersion('''
dependencies {
  testImplementation("org.robolectric:robolectric:4.15.0")
  testImplementation("org.robolectric:robolectric:4.16.1")
}
'''),
        throwsFormatException,
      );
    },
  );

  test('resolves the repository Android test configuration cleanly', () {
    final spec = resolveRobolectricCacheSpec(
      gradleFile: File('android/app/build.gradle.kts'),
      testDir: Directory('android/app/src/test'),
    );
    expect(spec.version, isNotEmpty);
    expect(spec.sdks, containsAll(<int>[29, 30, 33, 34]));
    expect(spec.keySuffix, startsWith('sdk-'));
  });
}
