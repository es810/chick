package com.chickenfarm.chicken_farm

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.chickenfarm.chicken_farm/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val text = call.argument<String>("text") ?: ""
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        val jid = call.argument<String>("jid")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Missing file path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareFileToWhatsApp(path, text, mime, jid)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareFileToWhatsApp(
        path: String,
        text: String,
        mime: String,
        jid: String?,
    ) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $path")
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )

        val packages = listOf("com.whatsapp", "com.whatsapp.w4b")
        val target = packages.firstOrNull { isInstalled(it) }
            ?: throw IllegalStateException("WhatsApp is not installed")

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text.isNotBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            val normalizedJid = normalizeJid(jid)
            if (!normalizedJid.isNullOrBlank()) {
                putExtra("jid", normalizedJid)
            }
            setPackage(target)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        // WhatsApp needs explicit grant on the content URI.
        grantUriPermission(
            target,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        startActivity(intent)
    }

    private fun normalizeJid(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        if (value.isEmpty()) return null
        if (value.contains("@g.us") || value.contains("@s.whatsapp.net")) {
            return value
        }
        // Accept bare group ids like 1203630...-123456@g.us without suffix typed wrong.
        if (value.matches(Regex("""^\d+(-\d+)?$"""))) {
            return "$value@g.us"
        }
        return null
    }

    private fun isInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
