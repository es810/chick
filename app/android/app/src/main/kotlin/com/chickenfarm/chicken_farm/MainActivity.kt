package com.chickenfarm.chicken_farm

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.chickenfarm.chicken_farm/whatsapp"
    private val mainHandler = Handler(Looper.getMainLooper())

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
                        val inviteUrl = call.argument<String>("inviteUrl")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Missing file path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareFileToWhatsApp(path, text, mime, jid, inviteUrl)
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
     * - Real JID (`…@g.us`): opens that chat with the file attached.
     * - Invite link (`chat.whatsapp.com/…`): warms the group, then opens the
     *   share composer with the PDF attached (user taps the group once + Send).
     */
    private fun shareFileToWhatsApp(
        path: String,
        text: String,
        mime: String,
        jid: String?,
        inviteUrl: String?,
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
        val normalizedInvite = normalizeInviteUrl(inviteUrl)

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

        if (!normalizedInvite.isNullOrBlank()) {
            shareViaInviteLink(target, uri, mime, normalizedInvite)
            return
        }

        startActivity(buildShareIntent(target, uri, mime))
    }

    /**
     * Invite links cannot carry EXTRA_STREAM. Strategy:
     * 1) Open the group (so it sits at the top of WhatsApp recents)
     * 2) Immediately open ACTION_SEND with the PDF on top
     * User taps that same group once, then Send.
     */
    private fun shareViaInviteLink(
        packageName: String,
        uri: Uri,
        mime: String,
        inviteUrl: String,
    ) {
        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(inviteUrl)).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val shareIntent = buildShareIntent(packageName, uri, mime)

        // Prefer startActivities so the share composer (with PDF) ends on top.
        try {
            startActivities(arrayOf(viewIntent, shareIntent))
            return
        } catch (_: Exception) {
            // fall through
        }

        // Fallback: open group, then force the share composer after WhatsApp settles.
        try {
            startActivity(viewIntent)
        } catch (_: Exception) {
            // ignore — still share below
        }

        mainHandler.postDelayed({
            grantUriPermission(
                packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            try {
                startActivity(shareIntent)
            } catch (_: Exception) {
                startActivity(Intent.createChooser(shareIntent, "WhatsApp"))
            }
        }, 1200)
    }

    private fun buildShareIntent(packageName: String, uri: Uri, mime: String): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = mime
            clipData = ClipData.newUri(contentResolver, "invoice.pdf", uri)
            putExtra(Intent.EXTRA_STREAM, uri)
            // Do not set EXTRA_TEXT — it often drops the attachment composer.
            setPackage(packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    private fun tryDirectShare(
        packageName: String,
        uri: Uri,
        mime: String,
        jid: String,
    ): Boolean {
        val classNames = listOf(
            "$packageName.ContactPicker",
            "com.whatsapp.ContactPicker",
            "com.whatsapp.contact.ContactPicker",
            "com.whatsapp.contact.ui.ContactPicker",
        )

        for (className in classNames) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                clipData = ClipData.newUri(contentResolver, "invoice.pdf", uri)
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

        val plain = buildShareIntent(packageName, uri, mime).apply {
            putExtra("jid", jid)
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

        val embedded = Regex(
            """(\d+(?:-\d+)?)@(g\.us|s\.whatsapp\.net)""",
            RegexOption.IGNORE_CASE,
        ).find(value)
        if (embedded != null) {
            val local = embedded.groupValues[1]
            val host = embedded.groupValues[2].lowercase()
            return "$local@$host"
        }

        if (value.matches(Regex("""^\d{10,}(-\d+)?$"""))) {
            return "$value@g.us"
        }

        return null
    }

    private fun normalizeInviteUrl(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        if (value.isEmpty()) return null

        val match = Regex(
            """(?:https?://)?(?:www\.)?chat\.whatsapp\.com/([A-Za-z0-9_-]+)""",
            RegexOption.IGNORE_CASE,
        ).find(value)
        if (match != null) {
            return "https://chat.whatsapp.com/${match.groupValues[1]}"
        }

        if (value.matches(Regex("""^[A-Za-z0-9_-]{16,}$"""))) {
            return "https://chat.whatsapp.com/$value"
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
