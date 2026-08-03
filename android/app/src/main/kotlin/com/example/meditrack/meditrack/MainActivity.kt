package com.example.meditrack

import android.content.ContentValues
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val galleryChannel = "meditrack/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePngToGallery") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name") ?: "meditrack_qr"
                if (bytes == null) {
                    result.error("invalid_image", "The QR image is missing.", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val values = ContentValues().apply {
                            put(MediaStore.Images.Media.DISPLAY_NAME, "$name.png")
                            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/MediTrack")
                            put(MediaStore.Images.Media.IS_PENDING, 1)
                        }
                        val uri = contentResolver.insert(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            values,
                        ) ?: throw IllegalStateException("Could not create a gallery image.")
                        contentResolver.openOutputStream(uri)?.use { stream ->
                            stream.write(bytes)
                        } ?: throw IllegalStateException("Could not write the gallery image.")
                        values.clear()
                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                        uri.toString()
                    } else {
                        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: throw IllegalStateException("Could not decode the QR image.")
                        MediaStore.Images.Media.insertImage(contentResolver, bitmap, name, null)
                            ?: throw IllegalStateException("Could not save the gallery image.")
                    }
                    result.success(savedUri)
                } catch (error: Exception) {
                    result.error("gallery_save_failed", error.message, null)
                }
            }
    }
}
