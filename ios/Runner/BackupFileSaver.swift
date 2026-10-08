import Flutter
import UIKit

/// Receives a ZIP path, prepares a named file copy off the main thread, and
/// exports it through Files. No ZIP bytes are loaded into a MethodChannel or
/// NSData; cancellation and picker dismissal each finish the request once.
final class BackupFileSaver: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate {
  private var pendingResult: FlutterResult?
  private var pendingDirectory: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.jotsy.diary/backup_file_saver",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(BackupFileSaver(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "saveBackupFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "already_active", message: "Another backup save is active.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      !sourcePath.isEmpty else {
      result(FlutterError(code: "missing_source", message: "Backup source path is empty.", details: nil))
      return
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory),
      !isDirectory.boolValue else {
      result(FlutterError(code: "missing_source", message: "Backup source file is unavailable.", details: nil))
      return
    }

    let source = URL(fileURLWithPath: sourcePath)
    let requestedName = (arguments["fileName"] as? String) ?? source.lastPathComponent
    let name = (requestedName as NSString).lastPathComponent
    guard !name.isEmpty && name != "." && name != ".." else {
      result(FlutterError(code: "invalid_name", message: "Backup file name is invalid.", details: nil))
      return
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("backup_save_\(UUID().uuidString)", isDirectory: true)
    let destination = directory.appendingPathComponent(name)
    pendingResult = result

    // Files uses the source filename as its suggested export name. A unique
    // working copy avoids renaming or overwriting the caller's source ZIP.
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
        DispatchQueue.main.async { [weak self] in
          guard let self = self else {
            try? FileManager.default.removeItem(at: directory)
            return
          }
          self.pendingDirectory = directory
          self.present(exporting: destination)
        }
      } catch {
        try? FileManager.default.removeItem(at: directory)
        DispatchQueue.main.async { [weak self] in
          self?.finish(FlutterError(code: "copy_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func present(exporting file: URL) {
    let root: UIViewController?
    if #available(iOS 13.0, *) {
      root = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController
    } else {
      root = UIApplication.shared.keyWindow?.rootViewController
    }
    guard var presenter = root else {
      finish(FlutterError(code: "save_unavailable", message: "No active window for backup saving.", details: nil))
      return
    }
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    guard !presenter.isBeingDismissed else {
      finish(FlutterError(code: "save_unavailable", message: "The active window is closing.", details: nil))
      return
    }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: file, in: .exportToService)
    }
    // System document UI owns its colors and controls, including Dark Mode.
    picker.delegate = self
    presenter.present(picker, animated: true)
    picker.presentationController?.delegate = self
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let destination = urls.first else {
      finish(FlutterError(code: "missing_target", message: "Backup save target is missing.", details: nil))
      return
    }
    finish(destination.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }

  @available(iOS 13.0, *)
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish(nil)
  }

  private func finish(_ value: Any?) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    let directory = pendingDirectory
    pendingDirectory = nil
    result(value)
    if let directory = directory {
      DispatchQueue.global(qos: .utility).async {
        try? FileManager.default.removeItem(at: directory)
      }
    }
  }
}
