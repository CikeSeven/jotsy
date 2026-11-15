import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 读出一个本机音频文件的时长；读不出（格式不支持、文件损坏、超时）时为
/// null。
typedef AudioDurationProbe = Future<Duration?> Function(String path);

/// 用正文录音卡片播放时的同一套播放器（audioplayers）读时长：读得出就说明
/// 这台设备能在正文里直接播放它（#251 导入的音频据此做成录音块），读不出的
/// 照旧当附件交给其他应用打开。
///
/// 只准备数据源、不播放，不申请音频焦点；[timeout] 兜住个别平台后端
/// （如缺插件的 GStreamer）准备时一直不回应的情况。
Future<Duration?> probeAudioDuration(
  String path, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final player = AudioPlayer();
  try {
    await player.setSource(DeviceFileSource(path)).timeout(timeout);
    return await player.getDuration().timeout(timeout);
  } catch (error) {
    debugPrint('probeAudioDuration failed for $path: $error');
    return null;
  } finally {
    unawaited(player.dispose().catchError((Object _) {}));
  }
}
