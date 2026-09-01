package com.example.sk360

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "sk360/file_viewer"
    private val pickPdfRequestCode = 361
    private var pendingPdfPickResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val permissions = arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO,
            )
            val missing = permissions.filter {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            }
            if (missing.isNotEmpty()) {
                requestPermissions(missing.toTypedArray(), 360)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> openUrl(call.argument("url"), result)
                "pickPdf" -> pickPdf(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun openUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_url", "No submitted file URL was provided.", null)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        } catch (exception: Exception) {
            result.error("open_failed", exception.message ?: "Unable to open submitted file.", null)
        }
    }

    private fun pickPdf(result: MethodChannel.Result) {
        if (pendingPdfPickResult != null) {
            result.error("picker_busy", "PDF picker is already open.", null)
            return
        }

        pendingPdfPickResult = result
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/pdf"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf"))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(Intent.createChooser(intent, "Choose PDF file"), pickPdfRequestCode)
        } catch (_: ActivityNotFoundException) {
            try {
                val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivityForResult(Intent.createChooser(fallback, "Choose PDF file"), pickPdfRequestCode)
            } catch (exception: Exception) {
                pendingPdfPickResult = null
                result.error("picker_failed", exception.message ?: "No file picker app was found.", null)
            }
        } catch (exception: Exception) {
            pendingPdfPickResult = null
            result.error("picker_failed", exception.message ?: "Unable to open PDF picker.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickPdfRequestCode) return

        val result = pendingPdfPickResult ?: return
        pendingPdfPickResult = null

        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("read_failed", "Unable to read selected PDF.", null)
                return
            }

            result.success(
                mapOf(
                    "name" to displayName(uri),
                    "base64" to Base64.encodeToString(bytes, Base64.NO_WRAP)
                )
            )
        } catch (exception: Exception) {
            result.error("read_failed", exception.message ?: "Unable to read selected PDF.", null)
        }
    }

    private fun displayName(uri: Uri): String {
        var name = "selected.pdf"
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && it.moveToFirst()) {
                name = it.getString(index) ?: name
            }
        }
        return if (name.lowercase().endsWith(".pdf")) name else "$name.pdf"
    }
}
