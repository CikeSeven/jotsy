package com.jotsy.diary

import android.app.Activity
import android.app.usage.StorageStatsManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.StatFs
import android.os.storage.StorageManager
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Video helpers for the storage manager (`lib/core/services/storage/media_compressor.dart`).
 *
 * - `probe`: size (rotation applied), duration and bitrate through [MediaMetadataRetriever];
 * - `thumbnail`: one frame scaled to a small JPEG, cached by Dart in the app's cache directory;
 * - `transcode` / `cancel`: re-encodes a stored video as H.264 + AAC in an MP4 with Media3
 *   [Transformer], scaling the short side down (never up) and capping the bitrates. HDR input is
 *   tone-mapped to SDR so the result plays everywhere, including the desktop builds. Output goes
 *   to a temporary sibling that is renamed into place only on success; the source is never
 *   touched — Dart rewrites the diary references and deletes the original itself;
 * - `deviceSpace`: total and available bytes of the internal storage, plus this app's own code,
 *   data and cache bytes. On Android 8+ these come from [StorageStatsManager], the numbers the
 *   system Settings shows (total rounded to the marketed size, app stats as in App info →
 *   Storage); an app may always query its own package without extra permissions. Older systems
 *   fall back to [StatFs] of the data partition and report no app stats.
 *
 * Probing and thumbnails run on one background thread. Transformer must be driven from a thread
 * with a Looper, so transcodes start on the main thread; progress is polled and sent back as
 * `progress` calls.
 */
class DiaryVideoTools(
  private val activity: Activity,
  messenger: BinaryMessenger,
) {
  private val channel = MethodChannel(messenger, "com.jotsy.diary/video_tools")
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  private val jobs = HashMap<Int, TranscodeJob>()

  init {
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "deviceSpace" -> background(result) { deviceSpace() }
        "probe" -> {
          val paths = call.argument<List<String>>("paths") ?: emptyList()
          background(result) { paths.mapNotNull { path -> probe(path)?.let { path to it.toMap() } }.toMap() }
        }
        "thumbnail" -> {
          val source = call.argument<String>("source")
          val target = call.argument<String>("target")
          val maxSide = call.argument<Int>("maxSide") ?: 320
          if (source.isNullOrBlank() || target.isNullOrBlank()) {
            result.error("invalid_arguments", "source and target are required.", null)
          } else {
            background(result) { thumbnail(File(source), File(target), maxSide) }
          }
        }
        "transcode" -> transcode(call, result)
        "cancel" -> {
          call.argument<Int>("id")?.let { jobs[it]?.cancel() }
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    for (job in jobs.values.toList()) job.cancel()
    jobs.clear()
    executor.shutdown()
  }

  private fun background(result: MethodChannel.Result, work: () -> Any?) {
    executor.execute {
      try {
        val value = work()
        activity.runOnUiThread { result.success(value) }
      } catch (error: Exception) {
        activity.runOnUiThread { result.error("video_tools_failed", error.message, null) }
      } catch (error: OutOfMemoryError) {
        activity.runOnUiThread { result.error("video_tools_failed", "Out of memory.", null) }
      }
    }
  }

  private fun deviceSpace(): Map<String, Long>? {
    val space = HashMap<String, Long>()
    try {
      val stat = StatFs(activity.filesDir.path)
      space["total"] = stat.totalBytes
      space["free"] = stat.availableBytes
    } catch (error: IllegalArgumentException) {
      // Fall through to the system stats below, or report nothing.
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      try {
        val stats = activity.getSystemService(StorageStatsManager::class.java)
        val volume = StorageManager.UUID_DEFAULT
        space["total"] = stats.getTotalBytes(volume)
        space["free"] = stats.getFreeBytes(volume)
        val app = stats.queryStatsForPackage(volume, activity.packageName, Process.myUserHandle())
        space["appBytes"] = app.appBytes
        space["dataBytes"] = app.dataBytes
        space["cacheBytes"] = app.cacheBytes
      } catch (error: Exception) {
        // Keep the StatFs numbers; the app stats are optional.
      }
    }
    return if (space.containsKey("total")) space else null
  }

  private data class VideoInfo(val width: Int, val height: Int, val durationMs: Long, val bitrate: Int) {
    val shortSide get() = min(width, height)

    fun toMap() = mapOf(
      "width" to width,
      "height" to height,
      "durationMs" to durationMs,
      "bitrate" to bitrate,
    )
  }

  private fun probe(path: String): VideoInfo? {
    val retriever = MediaMetadataRetriever()
    return try {
      retriever.setDataSource(path)
      fun read(key: Int) = retriever.extractMetadata(key)?.toLongOrNull() ?: 0L
      val width = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH).toInt()
      val height = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT).toInt()
      val rotation = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION).toInt()
      val rotated = rotation == 90 || rotation == 270
      VideoInfo(
        width = if (rotated) height else width,
        height = if (rotated) width else height,
        durationMs = read(MediaMetadataRetriever.METADATA_KEY_DURATION),
        bitrate = read(MediaMetadataRetriever.METADATA_KEY_BITRATE).toInt(),
      )
    } catch (error: Exception) {
      null
    } finally {
      try {
        retriever.release()
      } catch (error: Exception) {
        // Nothing to release.
      }
    }
  }

  private fun thumbnail(source: File, target: File, maxSide: Int): Boolean {
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(source.path)
      val option = MediaMetadataRetriever.OPTION_CLOSEST_SYNC
      // A frame one second in skips the black fade-in many phone videos start with.
      val frame = frameAt(retriever, 1_000_000L, option, maxSide)
        ?: frameAt(retriever, 0L, option, maxSide)
        ?: return false
      val scale = min(1.0, maxSide.toDouble() / max(frame.width, frame.height))
      val scaled = if (scale < 1.0) {
        Bitmap.createScaledBitmap(
          frame,
          max(1, (frame.width * scale).roundToInt()),
          max(1, (frame.height * scale).roundToInt()),
          true,
        ).also { if (it !== frame) frame.recycle() }
      } else {
        frame
      }
      target.parentFile?.mkdirs()
      val staging = File(target.parentFile, "${target.name}.tmp-${System.nanoTime()}")
      try {
        FileOutputStream(staging).use { scaled.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        if (target.exists()) target.delete()
        if (!staging.renameTo(target)) return false
      } finally {
        scaled.recycle()
        staging.delete()
      }
      return true
    } finally {
      try {
        retriever.release()
      } catch (error: Exception) {
        // Nothing to release.
      }
    }
  }

  private fun frameAt(retriever: MediaMetadataRetriever, timeUs: Long, option: Int, maxSide: Int): Bitmap? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      retriever.getScaledFrameAtTime(timeUs, option, maxSide, maxSide)
    } else {
      retriever.getFrameAtTime(timeUs, option)
    }

  private fun transcode(call: MethodCall, result: MethodChannel.Result) {
    val id = call.argument<Int>("id")
    val source = call.argument<String>("source")
    val target = call.argument<String>("target")
    if (id == null || source.isNullOrBlank() || target.isNullOrBlank()) {
      result.error("invalid_arguments", "id, source and target are required.", null)
      return
    }
    val shortSide = call.argument<Int>("shortSide") ?: 720
    val videoBitrate = call.argument<Int>("videoBitrate") ?: 2_500_000
    val audioBitrate = call.argument<Int>("audioBitrate") ?: 128_000
    val job = TranscodeJob(id, File(source), File(target), result)
    jobs[id] = job
    // Reading the source size touches the file: do it off the main thread, then start there.
    executor.execute {
      val info = probe(source)
      mainHandler.post { job.start(info, shortSide, videoBitrate, audioBitrate) }
    }
  }

  private inner class TranscodeJob(
    private val id: Int,
    private val source: File,
    private val target: File,
    private val result: MethodChannel.Result,
  ) {
    private val staging = File(target.parentFile, "${target.name}.tmp-${System.nanoTime()}.mp4")
    private var transformer: Transformer? = null
    private var finished = false
    private var cancelled = false
    private val progressHolder = ProgressHolder()
    private val poll = object : Runnable {
      override fun run() {
        val current = transformer ?: return
        if (current.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
          channel.invokeMethod("progress", mapOf("id" to id, "value" to progressHolder.progress / 100.0))
        }
        mainHandler.postDelayed(this, 300)
      }
    }

    fun start(info: VideoInfo?, shortSide: Int, videoBitrate: Int, audioBitrate: Int) {
      if (cancelled || finished) return
      if (!source.isFile || info == null) {
        finish { result.error("transcode_failed", "Source is missing or unreadable.", null) }
        return
      }
      try {
        val effects = if (info.shortSide > shortSide) {
          listOf(Presentation.createForShortSide(shortSide))
        } else {
          emptyList()
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(source)))
          .setEffects(Effects(emptyList(), effects))
          .build()
        val composition = Composition.Builder(EditedMediaItemSequence.Builder(item).build())
          .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
          .build()
        // Never ask for more than the source had: re-encoding cannot add detail.
        val bitrate = if (info.bitrate > 0) min(videoBitrate, info.bitrate) else videoBitrate
        val encoders = DefaultEncoderFactory.Builder(activity.applicationContext)
          .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
          .setRequestedAudioEncoderSettings(AudioEncoderSettings.Builder().setBitrate(audioBitrate).build())
          .setEnableFallback(true)
          .build()
        val created = Transformer.Builder(activity.applicationContext)
          .setVideoMimeType(MimeTypes.VIDEO_H264)
          .setAudioMimeType(MimeTypes.AUDIO_AAC)
          .setEncoderFactory(encoders)
          .addListener(object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
              finish {
                if (target.exists()) target.delete()
                if (staging.renameTo(target)) {
                  result.success(true)
                } else {
                  result.error("transcode_failed", "Cannot move the video into place.", null)
                }
              }
            }

            override fun onError(
              composition: Composition,
              exportResult: ExportResult,
              exportException: ExportException,
            ) {
              finish { result.error("transcode_failed", exportException.message, null) }
            }
          })
          .build()
        transformer = created
        created.start(composition, staging.path)
        mainHandler.post(poll)
      } catch (error: Exception) {
        finish { result.error("transcode_failed", error.message, null) }
      }
    }

    fun cancel() {
      if (finished) return
      cancelled = true
      try {
        transformer?.cancel()
      } catch (error: Exception) {
        // Already stopped.
      }
      finish { result.success(false) }
    }

    /** Stops polling, removes the job and answers Dart exactly once. */
    private fun finish(answer: () -> Unit) {
      if (finished) return
      finished = true
      mainHandler.removeCallbacks(poll)
      jobs.remove(id)
      try {
        answer()
      } finally {
        staging.delete()
      }
    }
  }
}
