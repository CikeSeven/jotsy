package com.jotsy.diary

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Separate class so it does not clash with the plugins' own FileProvider entries in the merged manifest. */
class AppUpdateFileProvider : FileProvider()

/**
 * In-app update support for APKs downloaded from GitHub Releases. Dart downloads and checksums the
 * APK into cacheDir/app_update/; that is the only directory [AppUpdateFileProvider] exposes, and
 * paths outside it are rejected here as well.
 *
 * - supportedAbis: Build.SUPPORTED_ABIS, preferred first, so Dart picks the matching split APK.
 * - inspectApk: package name, version code and whether the APK shares a signing certificate with
 *   the installed app. Android refuses to replace an app signed by another key with a bare
 *   "App not installed", so Dart checks this first and explains it instead.
 * - canRequestPackageInstalls / openInstallPermissionSettings: Android 8+ per-app "install
 *   unknown apps" permission. Older versions have no per-app permission; the system installer
 *   guides the user through the global setting.
 * - installApk: hands the APK to the system package installer via a content URI.
 */
class AppUpdateInstaller(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/app_update")
  private val authority = "${activity.packageName}.app_update"
  private val stagingDirectoryName = "app_update"

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
        "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
        "openInstallPermissionSettings" -> result.success(openInstallPermissionSettings())
        "inspectApk" -> inspectApk(call.argument<String>("path"), result)
        "installApk" -> installApk(call.argument<String>("path"), result)
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  private fun canRequestPackageInstalls(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return true
    }
    return activity.packageManager.canRequestPackageInstalls()
  }

  private fun openInstallPermissionSettings(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return false
    }
    val intent = Intent(
      Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
      Uri.parse("package:${activity.packageName}"),
    )
    return try {
      activity.startActivity(intent)
      true
    } catch (error: ActivityNotFoundException) {
      false
    }
  }

  /** Parsing an APK reads its whole signing block; keep it off the main thread. */
  private fun inspectApk(path: String?, result: MethodChannel.Result) {
    val file = try {
      stagedFile(path)
    } catch (error: IllegalArgumentException) {
      result.error("invalid_path", error.message, null)
      return
    }
    Thread {
      val info = try {
        val archive = archiveInfo(file)
        if (archive == null) {
          null
        } else {
          val installed = installedInfo()
          val archiveSigners = signerDigests(archive)
          val installedSigners = signerDigests(installed)
          // null when either side could not be read; Dart then relies on the installer.
          val sameSigner: Boolean? =
            if (archiveSigners.isEmpty() || installedSigners.isEmpty()) {
              null
            } else {
              archiveSigners.any { it in installedSigners }
            }
          mapOf(
            "packageName" to archive.packageName,
            "versionName" to archive.versionName,
            "versionCode" to PackageInfoCompat.getLongVersionCode(archive),
            "installedVersionCode" to PackageInfoCompat.getLongVersionCode(installed),
            "sameSigner" to sameSigner,
          )
        }
      } catch (error: Exception) {
        null
      }
      activity.runOnUiThread { result.success(info) }
    }.start()
  }

  private fun installApk(path: String?, result: MethodChannel.Result) {
    val file = try {
      stagedFile(path)
    } catch (error: IllegalArgumentException) {
      result.error("invalid_path", error.message, null)
      return
    }
    if (!canRequestPackageInstalls()) {
      result.error("permission_required", "Install unknown apps is not allowed.", null)
      return
    }
    val uri = FileProvider.getUriForFile(activity, authority, file)
    val intent = Intent(Intent.ACTION_VIEW).apply {
      setDataAndType(uri, "application/vnd.android.package-archive")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    try {
      activity.startActivity(intent)
      result.success(true)
    } catch (error: ActivityNotFoundException) {
      result.success(false)
    } catch (error: SecurityException) {
      result.error("launch_failed", error.message, null)
    }
  }

  private fun stagedFile(path: String?): File {
    require(!path.isNullOrBlank()) { "APK path is empty." }
    val root = File(activity.cacheDir, stagingDirectoryName).canonicalFile
    val file = File(path).canonicalFile
    require(file.isFile && file.path.startsWith(root.path + File.separator)) {
      "APK is not staged for update."
    }
    return file
  }

  private fun signingFlags(): Int =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      PackageManager.GET_SIGNING_CERTIFICATES
    } else {
      @Suppress("DEPRECATION")
      PackageManager.GET_SIGNATURES
    }

  @Suppress("DEPRECATION")
  private fun archiveInfo(file: File): PackageInfo? {
    val manager = activity.packageManager
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      manager.getPackageArchiveInfo(
        file.path,
        PackageManager.PackageInfoFlags.of(signingFlags().toLong()),
      )
    } else {
      manager.getPackageArchiveInfo(file.path, signingFlags())
    }
  }

  @Suppress("DEPRECATION")
  private fun installedInfo(): PackageInfo {
    val manager = activity.packageManager
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      manager.getPackageInfo(
        activity.packageName,
        PackageManager.PackageInfoFlags.of(signingFlags().toLong()),
      )
    } else {
      manager.getPackageInfo(activity.packageName, signingFlags())
    }
  }

  /**
   * SHA-256 of every certificate the package is (or, with key rotation, was) signed with.
   * Comparing the sets lets an APK signed with a rotated key still match when its lineage
   * includes the installed app's certificate.
   */
  @Suppress("DEPRECATION")
  private fun signerDigests(info: PackageInfo): Set<String> {
    val signatures: Array<Signature>? =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val signing = info.signingInfo
        when {
          signing == null -> null
          signing.hasMultipleSigners() -> signing.apkContentsSigners
          else -> signing.signingCertificateHistory
        }
      } else {
        info.signatures
      }
    if (signatures == null) {
      return emptySet()
    }
    val digest = MessageDigest.getInstance("SHA-256")
    return signatures.map { signature ->
      digest.digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
    }.toSet()
  }
}
