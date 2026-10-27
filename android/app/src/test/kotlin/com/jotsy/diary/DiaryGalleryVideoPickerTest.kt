package com.jotsy.diary

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.os.BadParcelableException
import android.os.Build
import android.os.Looper
import android.provider.MediaStore
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.TimeUnit

/** Exercises Android callbacks/provider access without a decoder or video-library permission. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [29, 33])
class DiaryGalleryVideoPickerTest {
  private lateinit var activity: VideoPickerTestActivity
  private lateinit var messenger: VideoPickerTestMessenger
  private lateinit var picker: DiaryGalleryVideoPicker
  private lateinit var provider: VideoPickerTestProvider

  @Before
  fun setUp() {
    activity = Robolectric.buildActivity(VideoPickerTestActivity::class.java).setup().get()
    shadowOf(activity.application).denyPermissions(
      Manifest.permission.READ_EXTERNAL_STORAGE,
      Manifest.permission.READ_MEDIA_VIDEO,
    )
    messenger = VideoPickerTestMessenger()
    picker = DiaryGalleryVideoPicker(activity, messenger)
    provider = VideoPickerTestProvider.install(activity)
  }

  @After
  fun tearDown() {
    picker.dispose()
    File(activity.cacheDir, "diary_video_gallery").deleteRecursively()
    File(activity.cacheDir, "provider_fixture.mp4").delete()
    activity.finish()
  }

  @Test
  fun `picker uses a video-only per-file grant contract`() {
    messenger.pick()
    val intent = activity.launched.single()
    assertEquals("video/*", intent.type)
    assertNull(intent.`package`)
    assertTrue(intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
    if (Build.VERSION.SDK_INT >= 33) {
      assertEquals(MediaStore.ACTION_PICK_IMAGES, intent.action)
      assertTrue(intent.getIntExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, 0) > 1)
    } else {
      assertEquals(Intent.ACTION_OPEN_DOCUMENT, intent.action)
      assertTrue(intent.hasCategory(Intent.CATEGORY_OPENABLE))
      assertTrue(intent.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
    }
  }

  @Test
  @Config(sdk = [33])
  fun `missing photo picker falls back to documents`() {
    activity.startFailure = { intent ->
      if (intent.action == MediaStore.ACTION_PICK_IMAGES) ActivityNotFoundException() else null
    }
    val reply = messenger.pick()
    assertEquals(2, activity.launched.size)
    assertEquals(Intent.ACTION_OPEN_DOCUMENT, activity.launched.last().action)
    picker.onActivityResult(7622, Activity.RESULT_CANCELED, null)
    assertTrue(reply.completed)
    assertNull(reply.errorCode)
  }

  @Test
  fun `denied picker access returns a permission error and can be retried`() {
    activity.startFailure = { SecurityException("picker access denied") }
    assertEquals("permission_denied", messenger.pick().errorCode)
    activity.startFailure = { null }
    val retried = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_CANCELED, null)
    assertTrue(retried.completed)
    assertNull(retried.errorCode)
  }

  @Test
  fun `unavailable system pickers return a recoverable error`() {
    activity.startFailure = { ActivityNotFoundException("no picker") }
    assertEquals("gallery_unavailable", messenger.pick().errorCode)
  }

  @Test
  fun `malformed result is caught before leaving the activity callback`() {
    val reply = messenger.pick()
    val malformed = object : Intent() {
      override fun getClipData(): ClipData? = throw BadParcelableException("invalid result")
    }
    assertTrue(picker.onActivityResult(7622, Activity.RESULT_OK, malformed))
    assertEquals("video_copy_failed", reply.errorCode)
    val retried = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_CANCELED, null)
    assertTrue(retried.completed)
  }

  @Test
  fun `result access denial is reported without escaping the activity callback`() {
    val reply = messenger.pick()
    val denied = object : Intent() {
      override fun getClipData(): ClipData? = throw SecurityException("result access denied")
    }
    assertTrue(picker.onActivityResult(7622, Activity.RESULT_OK, denied))
    assertEquals("permission_denied", reply.errorCode)
  }

  @Test
  fun `selected videos copy in order without reading the whole library`() {
    val reply = messenger.pick()
    val first = VideoPickerTestProvider.uri("first")
    val second = VideoPickerTestProvider.uri("second")
    val clip = ClipData.newRawUri("videos", first).apply { addItem(ClipData.Item(second)) }
    picker.onActivityResult(7622, Activity.RESULT_OK, Intent().apply {
      clipData = clip
      data = first // Some pickers also return the first URI here; do not duplicate it.
    })
    awaitReply(reply)
    assertNull(reply.errorCode)
    val files = reply.value as List<*>
    assertEquals(2, files.size)
    files.forEachIndexed { index, item ->
      val file = item as Map<*, *>
      assertEquals(listOf("first.mp4", "second.mp4")[index], file["name"])
      assertArrayEquals(byteArrayOf(1, 2, 3), File(file["path"] as String).readBytes())
      assertEquals(3L, file["size"])
    }
  }

  @Test
  fun `provider stream access denial removes partial copies and permits retry`() {
    provider.deniedVideo = "second"
    val reply = messenger.pick()
    val clip = ClipData.newRawUri("videos", VideoPickerTestProvider.uri("first")).apply {
      addItem(ClipData.Item(VideoPickerTestProvider.uri("second")))
    }
    picker.onActivityResult(7622, Activity.RESULT_OK, Intent().apply { clipData = clip })
    awaitReply(reply)
    assertEquals("permission_denied", reply.errorCode)
    assertTrue(File(activity.cacheDir, "diary_video_gallery").listFiles().orEmpty().isEmpty())
    provider.deniedVideo = null
    val retried = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_OK, Intent().setData(VideoPickerTestProvider.uri("first")))
    awaitReply(retried)
    assertNull(retried.errorCode)
    assertEquals(1, (retried.value as List<*>).size)
  }

  @Test
  fun `metadata access denial does not reject a readable video`() {
    provider.denyMetadata = true
    val reply = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_OK, Intent().setData(VideoPickerTestProvider.uri("first")))
    awaitReply(reply)
    assertNull(reply.errorCode)
    val file = (reply.value as List<*>).single() as Map<*, *>
    assertEquals("video.mp4", file["name"])
    assertArrayEquals(byteArrayOf(1, 2, 3), File(file["path"] as String).readBytes())
  }

  @Test
  fun `missing result returns an error and cancellation is not a failure`() {
    val missing = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_OK, null)
    assertEquals("video_copy_failed", missing.errorCode)
    val cancelled = messenger.pick()
    picker.onActivityResult(7622, Activity.RESULT_CANCELED, null)
    assertTrue(cancelled.completed)
    assertNull(cancelled.errorCode)
    assertNull(cancelled.value)
  }

  private fun awaitReply(reply: VideoPickerTestReply) {
    val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
    while (!reply.completed && System.nanoTime() < deadline) {
      shadowOf(Looper.getMainLooper()).idle()
      Thread.sleep(5)
    }
    assertTrue("Native picker must always complete its channel reply", reply.completed)
  }
}
