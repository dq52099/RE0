package com.dq52099.re0

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "re0/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> saveImageToGallery(
                    path = call.argument<String>("path"),
                    fileName = call.argument<String>("fileName") ?: "re0-image.png",
                    albumName = call.argument<String>("albumName") ?: "从零开始生图",
                    result = result,
                )
                "openApk" -> openApk(
                    path = call.argument<String>("path"),
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun saveImageToGallery(
        path: String?,
        fileName: String,
        albumName: String,
        result: MethodChannel.Result,
    ) {
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "Image path is empty.", null)
            return
        }

        try {
            val source = File(path)
            if (!source.exists()) {
                result.error("MISSING_FILE", "Image file does not exist.", null)
                return
            }

            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeTypeFor(fileName))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$albumName")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create MediaStore item.")

            resolver.openOutputStream(uri)?.use { output ->
                source.inputStream().use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Unable to open MediaStore output stream.")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message, null)
        }
    }

    private fun openApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "APK path is empty.", null)
            return
        }

        try {
            val apk = File(path)
            if (!apk.exists()) {
                result.error("MISSING_FILE", "APK file does not exist.", null)
                return
            }

            val uri = FileProvider.getUriForFile(
                applicationContext,
                "${applicationContext.packageName}.fileprovider",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            applicationContext.startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("OPEN_APK_FAILED", error.message, null)
        }
    }

    private fun mimeTypeFor(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/png"
        }
    }
}
