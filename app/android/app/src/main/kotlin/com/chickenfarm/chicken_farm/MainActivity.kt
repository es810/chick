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
     * - Invite link (`chat.whatsapp.com/…`): opens the group, then presents the
     *   file share so the same group is at the top of recent chats.
     * WhatsApp still requires one Send tap — silent send is not allowed.
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

        // Caption + EXTRA_STREAM together often make WhatsApp ignore `jid`.
        // Keep caption on the clipboard when targeting a specific chat/group.
        if (text.isNotBlank() && (!normalizedJid.isNullOrBlank() || !normalizedInvite.isNullOrBlank())) {
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
            shareViaInviteLink(target, uri, mime, normalizedInvite, text)
            return
        }

        // Fallback: open WhatsApp with the file (user picks the chat).
        val fallback = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text.isNotBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            setPackage(target)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(fallback)
    }

    /**
     * Opens the group via invite link (lands on the chat if already a member),
     * then starts a file share so that group appears first in WhatsApp recents.
     */
    private fun shareViaInviteLink(
        packageName: String,
        uri: Uri,
        mime: String,
        inviteUrl: String,
        text: String,
    ) {
        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(inviteUrl)).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(viewIntent)
        } catch (_: Exception) {
            // If VIEW fails, still try SEND below.
        }

        mainHandler.postDelayed({
            val share = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                // Don't put EXTRA_TEXT here — it often forces the chat picker
                // away from the conversation we just opened.
                setPackage(packageName)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(share)
            } catch (_: Exception) {
                // Last resort without package restriction.
                startActivity(
                    Intent.createChooser(
                        Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (text.isNotBlank()) putExtra(Intent.EXTRA_TEXT, text)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        },
                        "WhatsApp",
                    ),
                )
            }
        }, 700)
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
            "com.whatsapp.conversation.conversationrow.message.MessageReplyActivity",
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

        val embedded = Regex(
            """(\d+(?:-\d+)?)@(g\.us|s\.whatsapp\.net)""",
            RegexOption.IGNORE_CASE,
        ).find(value)
        if (embedded != null) {
            val local = embedded.groupValues[1]
            val host = embedded.groupValues[2].lowercase()
            return "$local@$host"
        }

        if (value.matches(Regex("""^\d+(-\d+)?$"""))) {
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

        // Bare invite code pasted without the domain.
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
