import 'dart:async';

import 'package:flutter/material.dart';
import '../controllers/diary_editor_controller.dart';
import '../controllers/diary_editor_insert.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 将当前系统时间插入到编辑器当前选区。
///
/// 如果用户已选中文字，则替换选区；如果编辑器暂时没有有效选区，则插入到文档末尾。
void insertDiaryToolbarCurrentTime(
  BuildContext context,
  DiaryEditorController controller, {
  String? formatPattern,
}) {
  final now = DateTime.now();
  final insertedText = formatDiaryToolbarCurrentTime(
    context.l10n,
    now,
    customPattern: formatPattern,
  );
  unawaited(insertDiaryEditorText(controller, insertedText));
}

const String kDefaultDiaryToolbarCurrentTimeFormat = 'M月d日 HH:mm';

String formatDiaryToolbarCurrentTime(
  AppLocalizations l10n,
  DateTime value, {
  String? customPattern,
}) {
  final local = value.toLocal();
  final normalizedPattern = customPattern?.trim();
  if (normalizedPattern != null && normalizedPattern.isNotEmpty) {
    return DateFormat(normalizedPattern, l10n.localeName).format(local);
  }
  return DateFormat(kDefaultDiaryToolbarCurrentTimeFormat, 'zh').format(local);
}

bool isValidDiaryToolbarCurrentTimeFormat(
  AppLocalizations l10n,
  String formatPattern,
) {
  final normalized = formatPattern.trim();
  if (normalized.isEmpty) {
    return true;
  }
  try {
    formatDiaryToolbarCurrentTime(
      l10n,
      DateTime(2026, 3, 11, 21, 30),
      customPattern: normalized,
    );
    return true;
  } catch (_) {
    return false;
  }
}
