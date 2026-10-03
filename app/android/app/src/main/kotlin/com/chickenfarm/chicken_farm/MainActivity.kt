package com.chickenfarm.chicken_farm

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
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

    /**
     * Shares a PDF into WhatsApp.
     *
     * When [jid] is a real group/chat id (`…@g.us` / `…@s.whatsapp.net`), WhatsApp
     * opens that chat with the file attached (no contact picker). The user still
     * taps Send once — WhatsApp does not allow silent send from other apps.
     */
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

        val normalizedJid = normalizeJid(jid)

        // Caption + EXTRA_STREAM together often make WhatsApp ignore `jid` and show
        // the picker. Keep caption on the clipboard instead when targeting a chat.
        if (text.isNotBlank()) {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("invoice", text))
        }

        grantUriPermission(
            target,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        if (!normalizedJid.isNullOrBlank()) {
            if (tryDirectShare(target, uri, mime, normalizedJid)) {
                return
            }
        }

        // Fallback: open WhatsApp with the file (user picks the chat).
        val fallback = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text.isNotBlank() && normalizedJid.isNullOrBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            setPackage(target)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(fallback)
    }

    private fun tryDirectShare(
        packageName: String,
        uri: Uri,
        mime: String,
        jid: String,
    ): Boolean {
        // Prefer ContactPicker — it honors `jid` more reliably than a bare SEND.
        val classNames = listOf(
            "$packageName.ContactPicker",
            "com.whatsapp.ContactPicker",
            "com.whatsapp.contact.ContactPicker",
            "com.whatsapp.contact.ui.ContactPicker",
        )

        for (className in classNames) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra("jid", jid)
                setPackage(packageName)
                component = ComponentName(packageName, className)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) == null) continue
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // try next component
            }
        }

        // Package-targeted SEND with jid (no component).
        val plain = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra("jid", jid)
            setPackage(packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(plain)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun normalizeJid(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        if (value.isEmpty()) return null

        // Full JID already (possibly embedded in other text).
        val embedded = Regex(
            """(\d+(?:-\d+)?)@(g\.us|s\.whatsapp\.net)""",
            RegexOption.IGNORE_CASE,
        ).find(value)
        if (embedded != null) {
            val local = embedded.groupValues[1]
            val host = embedded.groupValues[2].lowercase()
            return "$local@$host"
        }

        // Bare numeric group id (must already be in WhatsApp chat list).
        if (value.matches(Regex("""^\d+(-\d+)?$"""))) {
            return "$value@g.us"
        }

        // Invite links cannot target ACTION_SEND — caller should store a real JID.
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
