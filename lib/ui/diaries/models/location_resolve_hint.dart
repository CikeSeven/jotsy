import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 核心服务保留诊断原因，界面只展示当前语言下可操作的提示。
String locationResolveHint(
  AppLocalizations l10n,
  LocationResolveErrorType type,
) => switch (type) {
  LocationResolveErrorType.unsupported => l10n.locationUnsupported,
  LocationResolveErrorType.missingApiKey => l10n.autoT0204,
  LocationResolveErrorType.permissionDenied => l10n.locationPermissionDenied,
  LocationResolveErrorType.permissionDeniedForever =>
    l10n.locationPermissionDeniedForever,
  LocationResolveErrorType.serviceDisabled => l10n.locationServiceDisabled,
  LocationResolveErrorType.networkError => l10n.locationNetworkError,
  LocationResolveErrorType.apiError => l10n.locationApiError,
  LocationResolveErrorType.parseError => l10n.locationAddressInvalid,
  LocationResolveErrorType.unavailable => l10n.locationUnavailable,
};
