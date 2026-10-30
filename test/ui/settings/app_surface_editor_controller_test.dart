import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_background_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/settings/controllers/app_surface_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景与材质编辑控制器：草稿与提交、区域与全局的背景写入、选图各分支、
/// 重置撤销期间的图片保留，以及清理只按写入后的引用进行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late AppSurfaceEditorController controller;
  late List<Set<String>> cleaned;
  AppBackgroundPickResult nextPick = const AppBackgroundPickCancelled();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    cleaned = <Set<String>>[];
    nextPick = const AppBackgroundPickCancelled();
    controller = AppSurfaceEditorController(
      settingsService: settings,
      pickImage: () async => nextPick,
      deleteUnreferenced: (Set<String> keep) async {
        cleaned.add(keep);
        return 0;
      },
      resolveImage: (_) async => null,
    );
  });

  tearDown(() => controller.dispose());

  AppSurfaceSettings stored() =>
      AppSurfaceSettings.decode(settings.appSurfaceRaw);

  test('starts at defaults: nothing stored, global selected', () {
    expect(controller.style, AppSurfaceSettings.defaults);
    expect(controller.area, isNull);
    expect(controller.previewArea, AppBackgroundArea.diaries);
    expect(settings.appSurfaceRaw, isNull);
  });

  test('previewing a slider only changes the draft, release commits', () async {
    controller.previewBackgroundOf(
      null,
      const AppBackground(kind: AppBackgroundKind.image, image: 'a.jpg'),
    );
    controller.previewBackgroundOf(
      null,
      controller.backgroundOf(null).copyWith(blur: 12),
    );
    expect(controller.style.global.blur, 12);
    expect(settings.appSurfaceRaw, isNull, reason: '拖动中不写盘');

    await controller.commitBackground(
      null,
      controller.backgroundOf(null).copyWith(blur: 14),
    );
    expect(stored().global.blur, 14);
    expect(stored().global.image, 'a.jpg');
    expect(controller.style, stored());
  });

  test('area background edits the custom copy and keeps the mode', () async {
    await controller.commitAreaMode(
      AppBackgroundArea.calendar,
      AppAreaBackgroundMode.custom,
    );
    await controller.commitBackground(
      AppBackgroundArea.calendar,
      const AppBackground(
        kind: AppBackgroundKind.color,
        colorLight: 0xFF336699,
      ),
    );
    final calendar = stored().areaOf(AppBackgroundArea.calendar);
    expect(calendar.mode, AppAreaBackgroundMode.custom);
    expect(calendar.custom.colorLight, 0xFF336699);
    expect(stored().global, AppBackground.defaults);

    // 改回跟随全局：单独设置的那一份原样保留，编码里仍在。
    await controller.commitAreaMode(
      AppBackgroundArea.calendar,
      AppAreaBackgroundMode.follow,
    );
    expect(
      stored().areaOf(AppBackgroundArea.calendar).custom.colorLight,
      0xFF336699,
    );
    expect(settings.appSurfaceRaw, contains('"calendar"'));
  });

  test('follow switches show the source but edits keep the own copy', () async {
    const editor = AppBackgroundArea.editor;
    await controller.commitBackground(
      null,
      const AppBackground(
        kind: AppBackgroundKind.image,
        image: 'global.jpg',
        blur: 9,
      ),
    );
    await controller.commitAreaMode(editor, AppAreaBackgroundMode.custom);
    await controller.commitBackground(
      editor,
      const AppBackground(kind: AppBackgroundKind.image, image: 'own.jpg'),
    );

    await controller.commitFollowImage(editor, true);
    expect(stored().areaOf(editor).followImage, isTrue);
    expect(controller.effectiveBackgroundOf(editor).image, 'global.jpg');
    expect(controller.effectiveBackgroundOf(editor).blur, 0);

    await controller.commitFollowParams(editor, true);
    expect(controller.effectiveBackgroundOf(editor).blur, 9);
    // 编辑仍写自己的那一份：跟随中的值不受影响，关掉跟随后才看得到。
    await controller.commitBackground(
      editor,
      controller.backgroundOf(editor).copyWith(blur: 3),
    );
    expect(controller.effectiveBackgroundOf(editor).blur, 9);
    await controller.commitFollowParams(editor, false);
    expect(controller.effectiveBackgroundOf(editor).blur, 3);
    expect(controller.backgroundOf(editor).image, 'own.jpg');
  });

  test('a source that would loop back is not written', () async {
    await controller.commitFollowSource(
      AppBackgroundArea.editor,
      const AppBackgroundSource.area(AppBackgroundArea.preview),
    );
    expect(
      stored().areaOf(AppBackgroundArea.editor).source,
      const AppBackgroundSource.area(AppBackgroundArea.preview),
    );

    await controller.commitFollowSource(
      AppBackgroundArea.preview,
      const AppBackgroundSource.area(AppBackgroundArea.editor),
    );
    expect(
      stored().areaOf(AppBackgroundArea.preview).source,
      AppBackgroundSource.global,
    );
  });

  test('glass edits encode overrides and texture', () async {
    await controller.commitGlass(
      controller.style.glass
          .withMode(AppGlassMode.glass)
          .withOverride(AppGlassComponent.toolbar, AppGlassOverride.classic),
    );
    controller.previewGlass(controller.style.glass.copyWith(blurSigma: 33));
    expect(stored().glass.blurSigma, AppGlassStyle.defaults.blurSigma);
    await controller.commitGlass(
      controller.style.glass.copyWith(tintOpacity: 0.5),
    );
    final glass = stored().glass;
    expect(glass.mode, AppGlassMode.glass);
    expect(
      glass.overrideFor(AppGlassComponent.toolbar),
      AppGlassOverride.classic,
    );
    expect(glass.isGlass(AppGlassComponent.toolbar), isFalse);
    expect(glass.isGlass(AppGlassComponent.cards), isTrue);
    // 提交基于当前（含草稿）的设置：拖动中的模糊一并写入。
    expect(glass.blurSigma, 33);
    expect(glass.tintOpacity, 0.5);
    expect(settings.appSurfaceRaw, contains('"toolbar":"classic"'));
  });

  test('selecting an area drives the preview background', () async {
    await controller.commitBackground(
      null,
      const AppBackground(
        kind: AppBackgroundKind.color,
        colorLight: 0xFF112233,
      ),
    );
    await controller.commitAreaMode(
      AppBackgroundArea.explore,
      AppAreaBackgroundMode.off,
    );
    expect(controller.previewBackground.colorLight, 0xFF112233);
    controller.area = AppBackgroundArea.explore;
    expect(controller.previewArea, AppBackgroundArea.explore);
    expect(controller.previewBackground, AppBackground.defaults);
    controller.area = null;
    // 回到全局时预览沿用最后选的区域的版式，但画的是全局背景。
    expect(controller.previewBackground.colorLight, 0xFF112233);
  });

  group('pickImage', () {
    test('success switches to the new image and recenters focus', () async {
      await controller.commitBackground(
        AppBackgroundArea.editor,
        const AppBackground(
          kind: AppBackgroundKind.color,
          colorLight: 0xFF445566,
          alignX: 0.6,
          alignY: -0.4,
          blur: 8,
        ),
      );
      nextPick = const AppBackgroundPicked('bg_1.jpg');
      final status = await controller.pickImage(AppBackgroundArea.editor);
      expect(status, AppSurfaceImagePickStatus.picked);
      final custom = stored().areaOf(AppBackgroundArea.editor).custom;
      expect(custom.kind, AppBackgroundKind.image);
      expect(custom.image, 'bg_1.jpg');
      expect(custom.alignX, 0);
      expect(custom.alignY, 0);
      expect(custom.blur, 8, reason: '模糊与遮罩保留');
      expect(custom.colorLight, 0xFF445566, reason: '颜色字段不被清除');
    });

    test('cancel leaves settings untouched', () async {
      nextPick = const AppBackgroundPickCancelled();
      expect(
        await controller.pickImage(null),
        AppSurfaceImagePickStatus.cancelled,
      );
      expect(settings.appSurfaceRaw, isNull);
    });

    test('missing path and import failure are reported', () async {
      nextPick = const AppBackgroundPickMissingPath();
      expect(
        await controller.pickImage(null),
        AppSurfaceImagePickStatus.unavailable,
      );
      nextPick = const AppBackgroundPickFailed();
      expect(
        await controller.pickImage(null),
        AppSurfaceImagePickStatus.failed,
      );
      expect(settings.appSurfaceRaw, isNull);
    });

    test('a throwing picker counts as a failure', () async {
      final throwing = AppSurfaceEditorController(
        settingsService: settings,
        pickImage: () =>
            Future<AppBackgroundPickResult>.error(StateError('platform')),
        deleteUnreferenced: (_) async => 0,
      );
      addTearDown(throwing.dispose);
      expect(await throwing.pickImage(null), AppSurfaceImagePickStatus.failed);
      expect(throwing.picking, isFalse);
    });

    test('a second pick while one is running is ignored', () async {
      final gate = Completer<AppBackgroundPickResult>();
      final gated = AppSurfaceEditorController(
        settingsService: settings,
        pickImage: () => gate.future,
        deleteUnreferenced: (_) async => 0,
      );
      addTearDown(gated.dispose);
      final first = gated.pickImage(null);
      expect(gated.picking, isTrue);
      expect(await gated.pickImage(null), AppSurfaceImagePickStatus.ignored);
      gate.complete(const AppBackgroundPicked('bg_2.png'));
      expect(await first, AppSurfaceImagePickStatus.picked);
      expect(gated.picking, isFalse);
    });

    test('a pick finishing after dispose does not write', () async {
      final gate = Completer<AppBackgroundPickResult>();
      final gated = AppSurfaceEditorController(
        settingsService: settings,
        pickImage: () => gate.future,
        deleteUnreferenced: (_) async => 0,
      );
      final pending = gated.pickImage(null);
      gated.dispose();
      gate.complete(const AppBackgroundPicked('bg_3.png'));
      expect(await pending, AppSurfaceImagePickStatus.ignored);
      expect(settings.appSurfaceRaw, isNull);
    });
  });

  test('removeImage clears the file name but keeps the image type', () async {
    await controller.commitBackground(
      null,
      const AppBackground(kind: AppBackgroundKind.image, image: 'x.jpg'),
    );
    await controller.removeImage(null);
    expect(stored().global.kind, AppBackgroundKind.image);
    expect(stored().global.image, isNull);
  });

  test('reset returns the previous settings and undo restores them', () async {
    await controller.commitGlass(
      controller.style.glass.withMode(AppGlassMode.glass),
    );
    final before = stored();
    final previous = await controller.reset();
    expect(previous, before);
    expect(settings.appSurfaceRaw, isNull, reason: '默认设置删除键');
    await controller.applyStyle(previous);
    expect(stored(), before);
  });

  group('cleanUpImages', () {
    test('keeps the saved references, including inactive areas', () async {
      await controller.commitBackground(
        null,
        const AppBackground(kind: AppBackgroundKind.image, image: 'g.jpg'),
      );
      await controller.commitBackground(
        AppBackgroundArea.other,
        const AppBackground(kind: AppBackgroundKind.image, image: 'o.jpg'),
      );
      // other 仍是跟随全局：单独设置的图只是暂不启用，也要保留。
      await controller.cleanUpImages();
      expect(cleaned.single, <String>{'g.jpg', 'o.jpg'});
    });

    test('runs after the pending save, with the saved set', () async {
      final writes = <Completer<void>>[];
      final slow = _SlowSettings(settings, writes);
      final gated = AppSurfaceEditorController(
        settingsService: settings,
        deleteUnreferenced: (Set<String> keep) async {
          cleaned.add(keep);
          return 0;
        },
        persistOverride: slow.persist,
      );
      addTearDown(gated.dispose);
      unawaited(
        gated.commitBackground(
          null,
          const AppBackground(kind: AppBackgroundKind.image, image: 'new.jpg'),
        ),
      );
      final cleanup = gated.cleanUpImages();
      await Future<void>.delayed(Duration.zero);
      expect(cleaned, isEmpty, reason: '写入未完成前不清理');
      writes.single.complete();
      await cleanup;
      expect(cleaned.single, contains('new.jpg'));
    });

    test('an open undo window keeps the snapshot images', () async {
      await controller.commitBackground(
        null,
        const AppBackground(kind: AppBackgroundKind.image, image: 'old.jpg'),
      );
      final previous = await controller.reset();
      controller.holdUndo(previous);
      await controller.cleanUpImages();
      expect(cleaned.last, <String>{'old.jpg'});

      controller.releaseUndo(previous);
      await controller.cleanUpImages();
      expect(cleaned.last, isEmpty);
    });

    test('cleanup failures are swallowed', () async {
      final failing = AppSurfaceEditorController(
        settingsService: settings,
        deleteUnreferenced: (_) => Future<int>.error(StateError('disk')),
      );
      addTearDown(failing.dispose);
      expect(await failing.cleanUpImages(), 0);
    });
  });
}

/// 把写盘挂起，直到测试放行：验证清理会等进行中的写入。
class _SlowSettings {
  _SlowSettings(this.settings, this.writes);

  final SettingsService settings;
  final List<Completer<void>> writes;

  Future<void> persist(AppSurfaceSettings value) async {
    final gate = Completer<void>();
    writes.add(gate);
    await gate.future;
    await settings.setAppSurfaceRaw(value.encode());
  }
}
