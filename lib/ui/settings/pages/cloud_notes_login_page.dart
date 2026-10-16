import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/journal_import_cloud.dart';
import '../../../core/services/journal_import_cloud_cookies.dart';
import '../../../core/services/journal_import_cloud_http.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../controllers/journal_import_cloud_failure.dart';

/// 登录成功后交给导入流程的客户端；导入结束时须调用 [close]。
class CloudLoginResult {
  const CloudLoginResult(this.provider, this._http);

  final CloudNoteProvider provider;
  final CloudNoteHttp _http;

  /// 丢弃本次读取用的 Cookie 罐与连接，并清除网页视图里的登录状态。
  Future<void> close() async {
    _http.close();
    await CloudLoginCookies.clear();
  }
}

/// 在官方网页中登录手机厂商或 WPS 的云服务，确认登录后返回可读取笔记的
/// 客户端（[CloudLoginResult]）；返回或关闭页面得到 null。
///
/// - 打开前清空网页视图的 Cookie，每次都是全新的登录，不带入其他账号；
/// - 网页用桌面浏览器 UA：各平台网页版在手机 UA 下会跳到应用下载页；
/// - 点“读取笔记”时读取该平台接口源的 Cookie，做一次真实的账号核验
///   （[CloudNoteProvider.probe]），未登录时留在页面提示，不进入导入；
/// - 没有成功登录就离开页面时清除 Cookie；成功时由导入流程在结束后清除。
/// 返回键先在网页内后退，网页无法再后退时才离开页面。
class CloudNotesLoginPage extends StatefulWidget {
  const CloudNotesLoginPage({
    super.key,
    required this.platform,
    required this.platformName,
  });

  final CloudNotePlatform platform;
  final String platformName;

  @override
  State<CloudNotesLoginPage> createState() => _CloudNotesLoginPageState();
}

class _CloudNotesLoginPageState extends State<CloudNotesLoginPage> {
  late final WebViewController _controller;
  bool _firstPageLoaded = false;
  bool _checking = false;
  bool _succeeded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(cloudNoteUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && !_firstPageLoaded) {
              setState(() => _firstPageLoaded = true);
            }
          },
          // 只放行 https；应用商店、电话等外部协议不在网页视图里打开。
          onNavigationRequest: (request) =>
              request.url.startsWith('https://') ||
                  request.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    unawaited(_start());
  }

  Future<void> _start() async {
    await CloudLoginCookies.clear();
    await _controller.loadRequest(Uri.parse(widget.platform.loginUrl));
  }

  @override
  void dispose() {
    if (!_succeeded) unawaited(CloudLoginCookies.clear());
    super.dispose();
  }

  Future<void> _read() async {
    if (_checking) return;
    final l10n = context.l10n;
    setState(() => _checking = true);
    CloudNoteHttp? http;
    try {
      final jar = await CloudLoginCookies.read(widget.platform.cookieOrigins);
      http = IoCloudNoteHttp(jar);
      final provider = widget.platform.create(http);
      await provider.probe();
      if (!mounted) {
        http.close();
        return;
      }
      _succeeded = true;
      Navigator.of(context).pop(CloudLoginResult(provider, http));
    } on CloudNoteException catch (error) {
      http?.close();
      if (mounted) {
        _showSnack(
          error.failure == CloudNoteFailure.sessionExpired
              ? l10n.cloudLoginNotSignedIn
              : describeCloudNoteFailure(l10n, error, widget.platformName),
        );
      }
    } finally {
      if (mounted && !_succeeded) setState(() => _checking = false);
    }
  }

  void _showSnack(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      ),
    );
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_checking) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: Text(l10n.cloudLoginTitle(widget.platformName)),
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: _checking ? null : () => Navigator.of(context).pop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.cloudLoginReload,
              onPressed: _checking ? null : _controller.reload,
              icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  WebViewWidget(controller: _controller),
                  if (!_firstPageLoaded)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colorScheme.surface,
                        child: const DelayedLoadingIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            Material(
              color: colorScheme.surfaceContainerLow,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.m,
                    AppSpacing.l,
                    AppSpacing.m,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l10n.cloudLoginHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      FilledButton(
                        onPressed: _checking ? null : _read,
                        child: _checking
                            ? ExpressiveLoadingIndicator(
                                size: 24,
                                semanticLabel: l10n.cloudLoginChecking,
                              )
                            : Text(l10n.cloudLoginRead),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
