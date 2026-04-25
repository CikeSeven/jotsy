package com.jotsy.diary

import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  private val configChannelName = "com.jotsy.diary/config"
  private var predictiveBackCallback: OnBackInvokedCallback? = null
  private var predictiveBackCallbackRegistered = false

  override fun createFlutterFragment(): FlutterFragment {
    val backgroundMode = backgroundMode
    val renderMode = renderMode
    val transparencyMode =
      if (backgroundMode == BackgroundMode.opaque) {
        TransparencyMode.opaque
      } else {
        TransparencyMode.transparent
      }
    val shouldDelayFirstAndroidViewDraw = renderMode == RenderMode.surface
    val shouldAutomaticallyHandleOnBackPressed = true

    cachedEngineId?.let { engineId ->
      return FlutterFragment.CachedEngineFragmentBuilder(
          PredictiveBackFlutterFragment::class.java,
          engineId,
        )
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .handleDeeplinking(shouldHandleDeeplinking())
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .destroyEngineWithFragment(shouldDestroyEngineWithHost())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)
        .build<PredictiveBackFlutterFragment>()
    }

    cachedEngineGroupId?.let { engineGroupId ->
      return FlutterFragment.NewEngineInGroupFragmentBuilder(
          PredictiveBackFlutterFragment::class.java,
          engineGroupId,
        )
        .dartEntrypoint(dartEntrypointFunctionName)
        .initialRoute(initialRoute)
        .handleDeeplinking(shouldHandleDeeplinking())
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)
        .build<PredictiveBackFlutterFragment>()
    }

    val builder =
      FlutterFragment.NewEngineFragmentBuilder(PredictiveBackFlutterFragment::class.java)
        .dartEntrypoint(dartEntrypointFunctionName)
        .initialRoute(initialRoute)
        .flutterShellArgs(FlutterShellArgs.fromIntent(intent))
        .handleDeeplinking(shouldHandleDeeplinking())
        .renderMode(renderMode)
        .transparencyMode(transparencyMode)
        .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
        .shouldDelayFirstAndroidViewDraw(shouldDelayFirstAndroidViewDraw)
        .shouldAutomaticallyHandleOnBackPressed(shouldAutomaticallyHandleOnBackPressed)

    dartEntrypointLibraryUri?.let { builder.dartLibraryUri(it) }
    dartEntrypointArgs?.let { builder.dartEntrypointArgs(it) }
    appBundlePath?.let { builder.appBundlePath(it) }

    return builder.build<PredictiveBackFlutterFragment>()
  }

  @SuppressLint("NewApi")
  internal fun setPredictiveBackProgressEnabled(enabled: Boolean) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      return
    }
    if (enabled && !predictiveBackCallbackRegistered) {
      val callback = predictiveBackCallback ?: createPredictiveBackCallback().also {
        predictiveBackCallback = it
      }
      onBackInvokedDispatcher.registerOnBackInvokedCallback(
        OnBackInvokedDispatcher.PRIORITY_DEFAULT,
        callback,
      )
      predictiveBackCallbackRegistered = true
      return
    }
    if (!enabled && predictiveBackCallbackRegistered) {
      predictiveBackCallback?.let(onBackInvokedDispatcher::unregisterOnBackInvokedCallback)
      predictiveBackCallbackRegistered = false
    }
  }

  @SuppressLint("NewApi")
  private fun createPredictiveBackCallback(): OnBackInvokedCallback {
    return object : OnBackAnimationCallback {
      override fun onBackStarted(backEvent: BackEvent) {
        flutterEngine?.backGestureChannel?.startBackGesture(backEvent)
      }

      override fun onBackProgressed(backEvent: BackEvent) {
        flutterEngine?.backGestureChannel?.updateBackGestureProgress(backEvent)
      }

      override fun onBackCancelled() {
        flutterEngine?.backGestureChannel?.cancelBackGesture()
      }

      override fun onBackInvoked() {
        flutterEngine?.backGestureChannel?.commitBackGesture()
      }
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, configChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getAmapWebApiKey" -> {
            val key = BuildConfig.AMAP_WEB_API_KEY.trim()
            result.success(if (key.isEmpty()) null else key)
          }
          "getQWeatherCredentialId" -> {
            val value = BuildConfig.QWEATHER_CREDENTIAL_ID.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          "getQWeatherApiKey" -> {
            val value = BuildConfig.QWEATHER_API_KEY.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          "getQWeatherApiHost" -> {
            val value = BuildConfig.QWEATHER_API_HOST.trim()
            result.success(if (value.isEmpty()) null else value)
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun onDestroy() {
    setPredictiveBackProgressEnabled(false)
    super.onDestroy()
  }

  class PredictiveBackFlutterFragment : FlutterFragment() {
    override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(backCallbackState)
    }

    override fun setFrameworkHandlesBack(frameworkHandlesBack: Boolean) {
      super.setFrameworkHandlesBack(frameworkHandlesBack)
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(frameworkHandlesBack)
    }

    override fun onDetach() {
      (activity as? MainActivity)?.setPredictiveBackProgressEnabled(false)
      super.onDetach()
    }
  }
}
