package com.jotsy.diary

import android.app.Activity
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.robolectric.shadows.ShadowContentResolver
import java.io.File
import java.nio.ByteBuffer

/** In-memory channel/provider fixtures; no application database or real media is opened. */
class VideoPickerTestActivity : Activity() {
  val launched = mutableListOf<Intent>()
  var startFailure: (Intent) -> RuntimeException? = { null }

  override fun startActivityForResult(intent: Intent, requestCode: Int) {
    launched.add(intent)
    startFailure(intent)?.let { throw it }
  }
}

class VideoPickerTestReply {
  var completed = false
  var errorCode: String? = null
  var value: Any? = null
}

class VideoPickerTestMessenger : BinaryMessenger {
  private var handler: BinaryMessenger.BinaryMessageHandler? = null

  override fun send(channel: String, message: ByteBuffer?) = Unit
  override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
  override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
    this.handler = handler
  }

  fun pick(): VideoPickerTestReply {
    val result = VideoPickerTestReply()
    val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall("pickVideos", null))
    message.flip()
    handler!!.onMessage(message) { envelope ->
      envelope!!.flip()
      try {
        result.value = StandardMethodCodec.INSTANCE.decodeEnvelope(envelope)
      } catch (error: FlutterException) {
        result.errorCode = error.code
      }
      result.completed = true
    }
    return result
  }
}

class VideoPickerTestProvider : ContentProvider() {
  var deniedVideo: String? = null
  var denyMetadata = false

  override fun onCreate() = true
  override fun getType(uri: Uri) = "video/mp4"
  override fun insert(uri: Uri, values: ContentValues?): Uri? = null
  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
  override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0

  override fun query(
    uri: Uri, projection: Array<out String>?, selection: String?,
    selectionArgs: Array<out String>?, sortOrder: String?,
  ): Cursor {
    if (denyMetadata) throw SecurityException("metadata query denied")
    return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME)).apply {
      addRow(arrayOf("${uri.lastPathSegment}.mp4"))
    }
  }

  override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
    if (uri.lastPathSegment == deniedVideo) throw SecurityException("selected URI read denied")
    val source = File(context!!.cacheDir, "provider_fixture.mp4")
    source.writeBytes(byteArrayOf(1, 2, 3))
    return ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY)
  }

  companion object {
    fun uri(name: String): Uri = Uri.parse("content://video-picker.test/$name")
    fun install(context: Context): VideoPickerTestProvider {
      val provider = VideoPickerTestProvider()
      provider.attachInfo(context, ProviderInfo().apply { authority = "video-picker.test" })
      ShadowContentResolver.registerProviderInternal("video-picker.test", provider)
      return provider
    }
  }
}
