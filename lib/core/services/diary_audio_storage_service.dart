import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns pending microphone files and recordings committed to diary documents.
/// Only this service's directories are eligible for cleanup.
class DiaryAudioStorageService {
  const DiaryAudioStorageService();

  static const String directoryName = 'diary_recordings';
  static const String _pendingDirectoryName = 'pending_recordings';

  Future<String> createPendingPath() async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, _pendingDirectoryName),
    );
    await directory.create(recursive: true);
    return p.join(
      directory.path,
      'recording_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
  }

  Future<String> persistRecording(String pendingPath) async {
    final source = File(pendingPath);
    if (!await source.exists() || await source.length() == 0) {
      throw const FileSystemException('Recorded audio file is empty');
    }
    final directory = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, directoryName),
    );
    await directory.create(recursive: true);
    final target = p.join(directory.path, p.basename(pendingPath));
    await source.copy(target);
    await source.delete();
    return target;
  }

  Future<void> deletePendingRecording(String? path) async {
    if (path == null) return;
    final root = p.join(
      (await getTemporaryDirectory()).path,
      _pendingDirectoryName,
    );
    await _deleteWithin(root, path);
  }

  Future<void> deleteManagedRecording(String? path) async {
    if (path == null) return;
    final root = p.join(
      (await getApplicationDocumentsDirectory()).path,
      directoryName,
    );
    await _deleteWithin(root, path);
  }

  Future<void> _deleteWithin(String root, String path) async {
    if (!p.isWithin(p.normalize(root), p.normalize(path))) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
