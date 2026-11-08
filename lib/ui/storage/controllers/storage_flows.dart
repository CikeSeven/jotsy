import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/storage/storage_media_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../app_lock/controllers/identity_verifier.dart';
import '../providers/storage_providers.dart';
import '../sections/storage_compress_sheet.dart';
import '../sections/storage_delete_dialog.dart';
import '../sections/storage_progress_sheet.dart';
import 'storage_busy_messages.dart';

/// 页面给流程的出口：忙碌遮罩与提示条（与数据管理页同一做法）。
abstract interface class StorageFlowHost {
  void setBusy(bool busy, [String label]);

  void showSnack(String message);
}

/// 存储管理的操作流程：确认 → 忙碌 → 调服务 → 提示 → 刷新（docs/rules/storage.md）。
///
/// 页面只负责装配与选择状态；所有写入经 [StorageMediaService]，结束后经
/// [refreshStorageViews] 让总览、媒体页与设置首页的“已用”重新读取。守卫
/// 拒绝（有编辑页开着、撤销提示没消失）时只提示原因，什么都不改。
class StorageFlows {
  const StorageFlows(this._ref, this._host);

  final WidgetRef _ref;
  final StorageFlowHost _host;

  StorageMediaService get _service => _ref.read(storageMediaServiceProvider);

  /// 清理缓存 / 未使用的文件 / 数据库空闲页（默认三样一起，“一键清理”）。
  /// 只清安全的东西，不需要确认。
  Future<void> cleanUp(
    BuildContext context, {
    bool cache = true,
    bool orphans = true,
    bool database = true,
  }) async {
    final l10n = context.l10n;
    _host.setBusy(true, l10n.storageMgmtCleaning);
    try {
      final freed = await _service.cleanUp(
        cache: cache,
        orphans: orphans,
        database: database,
      );
      _host.showSnack(
        freed > 0
            ? l10n.storageMgmtFreed(l10n.formatByteSize(freed))
            : l10n.storageMgmtNothingFreed,
      );
    } on StorageBusyException catch (error) {
      _host.showSnack(storageBusyMessage(l10n, error.reason));
    } finally {
      _host.setBusy(false);
      refreshStorageViews(_ref);
    }
  }

  /// 确认后删除 [entries]（只处理引用都能改写的）；删除了返回 true。
  Future<bool> delete(
    BuildContext context,
    List<StorageMediaEntry> entries,
  ) async {
    final l10n = context.l10n;
    final editable = [
      for (final entry in entries)
        if (entry.isEditable) entry,
    ];
    if (editable.isEmpty) {
      _host.showSnack(l10n.storageMgmtCannotDelete);
      return false;
    }
    if (!await confirmStorageDelete(context, editable) || !context.mounted) {
      return false;
    }
    _host.setBusy(true, l10n.storageMgmtDeleting);
    try {
      final result = await _service.deleteMedia({
        for (final entry in editable) entry.key,
      });
      _host.showSnack(
        [
          l10n.storageMgmtDeleted(
            result.deletedFiles,
            l10n.formatByteSize(result.freedBytes),
          ),
          if (result.skippedRows > 0)
            l10n.storageMgmtSkippedRows(result.skippedRows),
        ].join(' '),
      );
      return true;
    } on StorageBusyException catch (error) {
      _host.showSnack(storageBusyMessage(l10n, error.reason));
      return false;
    } finally {
      _host.setBusy(false);
      refreshStorageViews(_ref);
    }
  }

  /// 选档位 → 压缩进度 → 结果；压缩过（哪怕只成功一项）返回 true。
  Future<bool> compress(
    BuildContext context,
    List<StorageMediaEntry> entries,
    StorageUsageReport report,
  ) async {
    final l10n = context.l10n;
    final initial = _ref.read(storageCompressContextProvider);
    if (!initial.supported) return false;
    final editable = [
      for (final entry in entries)
        if (entry.isEditable &&
            (entry.kind == DiaryBlockMediaKind.image ||
                entry.kind == DiaryBlockMediaKind.video))
          entry,
    ];
    if (editable.isEmpty) {
      _host.showSnack(l10n.storageMgmtCompressNothing);
      return false;
    }
    final choice = await showStorageCompressSheet(
      context,
      entries: editable,
      report: report,
      initial: initial,
    );
    if (choice == null || !context.mounted) return false;
    await _ref
        .read(storagePreferencesProvider.notifier)
        .save(
          _ref
              .read(storagePreferencesProvider)
              .copyWith(
                imagePreset: choice.imagePreset,
                videoPreset: choice.videoPreset,
              ),
        );
    final targets = [
      for (final entry in editable)
        if (choice.estimate(entry, report) != null) entry,
    ];
    if (!context.mounted) return false;
    final result = await showStorageCompressProgress(
      context,
      service: _service,
      entries: targets,
      choice: choice,
    );
    refreshStorageViews(_ref);
    return (result?.compressed ?? 0) > 0;
  }

  /// 揭示私密日记里的媒体：有在上锁日记本里的先验证身份（与进入上锁日记
  /// 本同一验证方式，不能验证时不放行）。通过返回 true。
  Future<bool> revealPrivate(
    BuildContext context, {
    required bool needsVerification,
  }) async {
    if (!needsVerification) return true;
    final l10n = context.l10n;
    final verifier = _ref.read(identityVerifierProvider);
    if (!await verifier.isAvailable()) {
      _host.showSnack(l10n.storageMgmtRevealUnavailable);
      return false;
    }
    if (!context.mounted) return false;
    return verifier.verify(context, reason: l10n.storageMgmtRevealReason);
  }
}
