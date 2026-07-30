package com.example.autoterra

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Сохранение выгрузок в системную папку «Загрузки».
 *
 * Начиная с Android 10 писать туда напрямую нельзя — только через MediaStore,
 * зато и разрешений не требуется. На более старых версиях пишем обычным файлом.
 * Наружу отдаём человекочитаемый путь, чтобы показать его пользователю.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "autoterra/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> saveToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

        if (fileName.isNullOrEmpty() || bytes == null) {
            result.error("bad_args", "Нужны fileName и bytes", null)
            return
        }

        try {
            val savedPath =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveViaMediaStore(fileName, bytes, mimeType)
                } else {
                    saveLegacy(fileName, bytes)
                }
            result.success(savedPath)
        } catch (error: Exception) {
            result.error("save_failed", error.message ?: "Не удалось сохранить файл", null)
        }
    }

    private fun saveViaMediaStore(fileName: String, bytes: ByteArray, mimeType: String): String {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Система не выдала место для файла")

        resolver.openOutputStream(uri).use { stream ->
            if (stream == null) throw IllegalStateException("Не удалось открыть файл для записи")
            stream.write(bytes)
            stream.flush()
        }
        return "Загрузки/$fileName"
    }

    private fun saveLegacy(fileName: String, bytes: ByteArray): String {
        val directory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!directory.exists()) directory.mkdirs()

        val file = File(directory, fileName)
        FileOutputStream(file).use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        return "Загрузки/$fileName"
    }
}
