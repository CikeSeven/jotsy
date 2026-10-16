import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "JotsyBackupFileSaver") {
      BackupFileSaver.register(with: registrar)
    }
    if let registrar = registrar(forPlugin: "JotsyWebCookies") {
      registerWebCookies(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 云端笔记导入：读取网页视图（默认数据存储）中对某个 https 地址生效的
  /// Cookie，拼成请求头格式返回；webview_flutter 没有读取接口。
  private func registerWebCookies(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.jotsy.diary/web_cookies",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getCookies":
        guard let arguments = call.arguments as? [String: Any],
          let raw = arguments["url"] as? String,
          let url = URL(string: raw),
          url.scheme == "https",
          let host = url.host?.lowercased() else {
          result(FlutterError(code: "invalid_url", message: "Only https URLs are supported.", details: nil))
          return
        }
        let path = url.path.isEmpty ? "/" : url.path
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
          let matched = cookies.filter { cookie in
            let domain = cookie.domain.lowercased()
            let bare = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
            let domainMatches = host == bare || host.hasSuffix("." + bare)
            return domainMatches && path.hasPrefix(cookie.path)
          }
          let header = matched.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
          result(header.isEmpty ? nil : header)
        }
      case "flush":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
