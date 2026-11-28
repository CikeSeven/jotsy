import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 编译并运行 Linux 与 Windows 原生 runner 的纯 C++ 窗口状态模块
/// （`linux/runner/window_state.cc` 与 `windows/runner/window_state.cpp`），
/// 在不依赖图形会话的情况下覆盖 JSON 容错解析、Wayland 无位置序列化、
/// Per-Monitor DPI 缩放、最小尺寸约束以及拔掉外接屏/标题栏越界时的可见区裁剪。
void main() {
  final compiler = _findCppCompiler();

  test(
    'Linux window_state.cc parses, serializes, and clamps multi-monitor bounds',
    () {
      _compileAndRunNativeTest(
        compiler: compiler!,
        standardFlag: '-std=c++14',
        extraFlags: const <String>['-Wall', '-Wextra', '-Werror'],
        sourceFile: 'linux/runner/window_state.cc',
        includeDir: 'linux/runner',
        driverSource: _linuxDriverSource,
      );
    },
    skip: compiler == null ? 'No C++ compiler found on PATH' : false,
  );

  test(
    'Windows window_state.cpp parses, rescales DPI, and clamps multi-monitor bounds without exceptions',
    () {
      _compileAndRunNativeTest(
        compiler: compiler!,
        standardFlag: '-std=c++17',
        extraFlags: const <String>[
          '-Wall',
          '-Wextra',
          '-Werror',
          '-fno-exceptions',
        ],
        sourceFile: 'windows/runner/window_state.cpp',
        includeDir: 'windows/runner',
        driverSource: _windowsDriverSource,
      );
    },
    skip: compiler == null ? 'No C++ compiler found on PATH' : false,
  );
}

String? _findCppCompiler() {
  if (!Platform.isLinux && !Platform.isMacOS) {
    return null;
  }
  for (final candidate in const <String>['clang++', 'g++']) {
    final result = Process.runSync('which', <String>[candidate]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        return path;
      }
    }
  }
  return null;
}

void _compileAndRunNativeTest({
  required String compiler,
  required String standardFlag,
  required List<String> extraFlags,
  required String sourceFile,
  required String includeDir,
  required String driverSource,
}) {
  final tempDir = Directory.systemTemp.createTempSync('jotsy_win_state_test_');
  try {
    final driverPath = p.join(tempDir.path, 'driver.cc');
    final binaryPath = p.join(tempDir.path, 'driver_bin');
    File(driverPath).writeAsStringSync(driverSource);

    final compile = Process.runSync(compiler, <String>[
      standardFlag,
      ...extraFlags,
      '-I',
      includeDir,
      sourceFile,
      driverPath,
      '-o',
      binaryPath,
    ]);
    expect(
      compile.exitCode,
      0,
      reason:
          'Compilation failed for $sourceFile:\n'
          'stdout: ${compile.stdout}\nstderr: ${compile.stderr}',
    );

    final run = Process.runSync(binaryPath, const <String>[]);
    expect(
      run.exitCode,
      0,
      reason:
          'Native assertions failed for $sourceFile:\n'
          'stdout: ${run.stdout}\nstderr: ${run.stderr}',
    );
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

const String _linuxDriverSource = r'''
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "window_state.h"

#define CHECK(expr)                                                          \
  do {                                                                       \
    if (!(expr)) {                                                           \
      std::cerr << "CHECK FAILED at line " << __LINE__ << ": " #expr "\n";   \
      std::exit(1);                                                          \
    }                                                                        \
  } while (0)

int main() {
  // 1. Round-trip with negative secondary monitor coordinates + maximized.
  {
    WindowState orig;
    orig.has_position = true;
    orig.x = -1200;
    orig.y = 64;
    orig.width = 1100;
    orig.height = 760;
    orig.maximized = true;
    const std::string json = SerializeWindowStateJson(orig);
    WindowState parsed;
    CHECK(ParseWindowStateJson(json, &parsed));
    CHECK(parsed.has_position);
    CHECK(parsed.x == -1200);
    CHECK(parsed.y == 64);
    CHECK(parsed.width == 1100);
    CHECK(parsed.height == 760);
    CHECK(parsed.maximized);
  }

  // 2. Wayland serialization omits x/y and parses cleanly without position.
  {
    WindowState wayland;
    wayland.has_position = false;
    wayland.width = 1024;
    wayland.height = 700;
    wayland.maximized = false;
    const std::string json = SerializeWindowStateJson(wayland);
    CHECK(json.find("\"x\"") == std::string::npos);
    CHECK(json.find("\"y\"") == std::string::npos);
    WindowState parsed;
    CHECK(ParseWindowStateJson(json, &parsed));
    CHECK(!parsed.has_position);
    CHECK(parsed.width == 1024);
    CHECK(parsed.height == 700);
    CHECK(!parsed.maximized);
  }

  // 3. BOM, whitespace, unknown nested fields, null x/y tolerance.
  {
    const std::string json =
        "\xEF\xBB\xBF { \"extra\": {\"nested\": [1, \"\\\"width\\\":99\", true]}, "
        "\"height\": 720, \"width\": 960, \"x\": null, \"y\": 50, "
        "\"version\": 1, \"maximized\": false } ";
    WindowState parsed;
    CHECK(ParseWindowStateJson(json, &parsed));
    CHECK(!parsed.has_position);
    CHECK(parsed.width == 960);
    CHECK(parsed.height == 720);
  }

  // 4. Reject malformed, unsupported version, fractional, zero/oversized, trailing junk.
  {
    WindowState out;
    CHECK(!ParseWindowStateJson("", &out));
    CHECK(!ParseWindowStateJson("[]", &out));
    CHECK(!ParseWindowStateJson("{\"version\":2,\"width\":800,\"height\":600}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":0,\"height\":600}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":800,\"height\":-10}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":40000,\"height\":600}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":800.5,\"height\":600}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":800,\"height\":600} trailing", &out));
    CHECK(!ParseWindowStateJson("{\"width\":800}", &out));
  }

  // 5. Minimum size clamping and exact preservation when title bar is accessible.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 28, 1920, 1052}, true},
    };
    WindowState tiny;
    tiny.has_position = true;
    tiny.x = 120;
    tiny.y = 80;
    tiny.width = 200;
    tiny.height = 300;
    const WindowState resolved =
        ResolveWindowStateForMonitors(tiny, monitors, 400, 600, true);
    CHECK(resolved.width == 400);
    CHECK(resolved.height == 600);
    CHECK(resolved.x == 120);
    CHECK(resolved.y == 80);
  }

  // 6. Disconnected external monitor centers cleanly on primary monitor.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 28, 1920, 1052}, true},
    };
    WindowState unplugged;
    unplugged.has_position = true;
    unplugged.x = 2200;
    unplugged.y = 120;
    unplugged.width = 1200;
    unplugged.height = 800;
    unplugged.maximized = true;
    const WindowState resolved =
        ResolveWindowStateForMonitors(unplugged, monitors, 400, 600, true);
    CHECK(resolved.has_position);
    CHECK(resolved.x == (1920 - 1200) / 2);
    CHECK(resolved.y == 28 + (1052 - 800) / 2);
    CHECK(resolved.maximized);
  }

  // 7. Partially overlapping window with unreachable top bar clamps back in.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 32, 1920, 1048}, true},
    };
    WindowState off_top;
    off_top.has_position = true;
    off_top.x = 200;
    off_top.y = -200;
    off_top.width = 1000;
    off_top.height = 700;
    const WindowState resolved =
        ResolveWindowStateForMonitors(off_top, monitors, 400, 600, true);
    CHECK(resolved.x == 200);
    CHECK(resolved.y == 32);
  }

  // 8. Left secondary monitor (negative coordinates) stays intact when connected.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{-1920, 0, 1920, 1040}, false},
        {WindowRect{0, 0, 2560, 1400}, true},
    };
    WindowState on_left;
    on_left.has_position = true;
    on_left.x = -1600;
    on_left.y = 100;
    on_left.width = 1280;
    on_left.height = 800;
    const WindowState resolved =
        ResolveWindowStateForMonitors(on_left, monitors, 400, 600, true);
    CHECK(resolved.x == -1600);
    CHECK(resolved.y == 100);
    CHECK(resolved.width == 1280);
    CHECK(resolved.height == 800);
  }

  // 9. Wayland strips saved position while capping dimensions to work area.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 1366, 728}, true},
    };
    WindowState saved;
    saved.has_position = true;
    saved.x = 300;
    saved.y = 200;
    saved.width = 1600;
    saved.height = 900;
    const WindowState resolved =
        ResolveWindowStateForMonitors(saved, monitors, 400, 600, false);
    CHECK(!resolved.has_position);
    CHECK(resolved.width == 1366);
    CHECK(resolved.height == 728);
  }

  return 0;
}
''';

const String _windowsDriverSource = r'''
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "window_state.h"

#define CHECK(expr)                                                          \
  do {                                                                       \
    if (!(expr)) {                                                           \
      std::cerr << "CHECK FAILED at line " << __LINE__ << ": " #expr "\n";   \
      std::exit(1);                                                          \
    }                                                                        \
  } while (0)

int main() {
  // 1. Round-trip with DPI, negative coordinates, and maximized flag.
  {
    WindowState orig;
    orig.has_position = true;
    orig.x = -1500;
    orig.y = 40;
    orig.width = 1920;
    orig.height = 1200;
    orig.maximized = true;
    orig.dpi = 144;
    const std::string json = SerializeWindowStateJson(orig);
    WindowState parsed;
    CHECK(ParseWindowStateJson(json, &parsed));
    CHECK(parsed.has_position);
    CHECK(parsed.x == -1500);
    CHECK(parsed.y == 40);
    CHECK(parsed.width == 1920);
    CHECK(parsed.height == 1200);
    CHECK(parsed.maximized);
    CHECK(parsed.dpi == 144);
  }

  // 2. Reject invalid inputs and sanitize out-of-range DPI.
  {
    WindowState out;
    CHECK(!ParseWindowStateJson("{corrupt", &out));
    CHECK(!ParseWindowStateJson("{\"version\":99,\"width\":800,\"height\":600}", &out));
    CHECK(!ParseWindowStateJson("{\"width\":999999999999,\"height\":600}", &out));
    CHECK(ParseWindowStateJson(
        "{\"version\":1,\"width\":1000,\"height\":700,\"dpi\":9999}", &out));
    CHECK(out.dpi == 0);
    CHECK(!out.has_position);
  }

  // 3. DWM edge-snapped window with -7px invisible border stays pixel-exact.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 1920, 1040}, 96, true},
    };
    WindowState snapped;
    snapped.has_position = true;
    snapped.x = -7;
    snapped.y = 0;
    snapped.width = 974;
    snapped.height = 1047;
    snapped.dpi = 96;
    const WindowState resolved =
        ResolveWindowStateForMonitors(snapped, monitors, 400, 600);
    CHECK(resolved.x == -7);
    CHECK(resolved.y == 0);
    CHECK(resolved.width == 974);
    CHECK(resolved.height == 1047);
  }

  // 4. DPI change rescales physical dimensions to preserve logical size.
  {
    // Saved at 150% DPI (144) as 1920x1200 (= 1280x800 logical).
    // Restored on 100% DPI (96) primary monitor -> should become 1280x800.
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 1920, 1040}, 96, true},
    };
    WindowState saved_hidpi;
    saved_hidpi.has_position = true;
    saved_hidpi.x = 100;
    saved_hidpi.y = 80;
    saved_hidpi.width = 1920;
    saved_hidpi.height = 1200;
    saved_hidpi.dpi = 144;
    const WindowState resolved =
        ResolveWindowStateForMonitors(saved_hidpi, monitors, 400, 600);
    CHECK(resolved.dpi == 96);
    CHECK(resolved.width == 1280);
    CHECK(resolved.height == 800);
    CHECK(resolved.x == 100);
    CHECK(resolved.y == 80);
  }

  // 5. Unplugged high-DPI external monitor rescales and centers on primary.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 1920, 1040}, 96, true},
    };
    WindowState external;
    external.has_position = true;
    external.x = 3000;
    external.y = 100;
    external.width = 1800;
    external.height = 1200;
    external.dpi = 144;
    const WindowState resolved =
        ResolveWindowStateForMonitors(external, monitors, 400, 600);
    CHECK(resolved.width == 1200);
    CHECK(resolved.height == 800);
    CHECK(resolved.x == (1920 - 1200) / 2);
    CHECK(resolved.y == (1040 - 800) / 2);
  }

  // 6. Minimum logical size respects target monitor DPI (150% -> 600x900 px).
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 2880, 1720}, 144, true},
    };
    WindowState tiny;
    tiny.has_position = true;
    tiny.x = 100;
    tiny.y = 100;
    tiny.width = 300;
    tiny.height = 400;
    tiny.dpi = 144;
    const WindowState resolved =
        ResolveWindowStateForMonitors(tiny, monitors, 400, 600);
    CHECK(resolved.width == 600);
    CHECK(resolved.height == 900);
  }

  // 7. First launch on 150% 1080p laptop (1920x1020 work area) clamps height.
  {
    const std::vector<MonitorWorkArea> monitors = {
        {WindowRect{0, 0, 1920, 1020}, 144, true},
    };
    const WindowState initial = BuildDefaultWindowStateForMonitors(
        10, 10, 1280, 800, 400, 600, monitors);
    CHECK(initial.dpi == 144);
    CHECK(initial.width == 1920);
    CHECK(initial.height == 1020);
    CHECK(initial.x == 0);
    CHECK(initial.y == 0);
    CHECK(!initial.maximized);
  }

  return 0;
}
''';
