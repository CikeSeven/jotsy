import 'package:amap_flutter/amap_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/services/amap_config_channel.dart';

const String _amapIosKey = '5cff747ec582e24205e05f49eb920515';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initAMapSdk();
  runApp(ProviderScope(child: const NodeDiaryApp()));
}

Future<void> _initAMapSdk() async {
  if (kIsWeb) {
    return;
  }

  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (!isAndroid && !isIos) {
    return;
  }

  var androidKey = '';
  if (isAndroid) {
    androidKey = await AMapConfigChannel.getAmapApiKey() ?? '';
  }

  if (androidKey.isEmpty && _amapIosKey.isEmpty) {
    return;
  }

  try {
    await AMapFlutter.init(
      apiKey: ApiKey(
        iosKey: _amapIosKey,
        androidKey: androidKey,
        webKey: '',
      ),
      agreePrivacy: true,
    );
  } catch (error) {
    // 初始化失败不阻断应用启动，避免因地图配置问题影响核心流程。
    debugPrint('AMap init failed: $error');
  }
}
