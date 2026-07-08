package com.clipback.clipback_share_receiver

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.clipback.share_receiver/intent",
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharePayload" -> result.success(intent.toSharePayload(this))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        methodChannel?.invokeMethod("onSharePayload", intent.toSharePayload(this))
    }
}

private val urlPattern = Pattern.compile("https?://[^\\s<>'\"]+")

private fun Intent.toSharePayload(activity: Activity): Map<String, Any?> {
    val rawText = getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
    val attachments = collectAttachments(activity)

    return mapOf(
        "action" to action,
        "mime_type" to type,
        "raw_text" to rawText,
        "subject" to getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString(),
        "title" to getCharSequenceExtra(Intent.EXTRA_TITLE)?.toString(),
        "url" to extractFirstUrl(rawText),
        "source_app" to detectSourceApp(activity),
        "platform" to "android",
        "attachments" to attachments,
    )
}

private fun Intent.detectSourceApp(activity: Activity): String? {
    activity.referrer?.toString()?.let { referrer ->
        return referrer.removePrefix("android-app://")
    }

    @Suppress("DEPRECATION")
    getParcelableExtra<Uri>(Intent.EXTRA_REFERRER)?.toString()?.let { referrer ->
        return referrer.removePrefix("android-app://")
    }

    return getStringExtra(Intent.EXTRA_REFERRER_NAME)
}

private fun Intent.collectAttachments(activity: Activity): List<Map<String, Any?>> {
    val attachments = linkedMapOf<String, Map<String, Any?>>()

    @Suppress("DEPRECATION")
    val singleStream = getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
    if (singleStream != null) {
        attachments[singleStream.toString()] = singleStream.toAttachment(activity)
    }

    @Suppress("DEPRECATION")
    val multipleStreams = getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
    multipleStreams?.forEach { uri ->
        attachments[uri.toString()] = uri.toAttachment(activity)
    }

    clipData?.let { data: ClipData ->
        for (index in 0 until data.itemCount) {
            val uri = data.getItemAt(index).uri
            if (uri != null) {
                attachments[uri.toString()] = uri.toAttachment(activity)
            }
        }
    }

    return attachments.values.toList()
}

private fun Uri.toAttachment(activity: Activity): Map<String, Any?> {
    return mapOf(
        "filename" to queryOpenableColumn(activity, this, OpenableColumns.DISPLAY_NAME),
        "mime_type" to activity.contentResolver.getType(this),
        "uri" to toString(),
        "size_bytes" to queryOpenableColumn(activity, this, OpenableColumns.SIZE)?.toLongOrNull(),
    )
}

private fun queryOpenableColumn(activity: Activity, uri: Uri, column: String): String? {
    return try {
        activity.contentResolver.query(uri, arrayOf(column), null, null, null).use { cursor ->
            cursor?.readFirstString(column)
        }
    } catch (_: Exception) {
        null
    }
}

private fun Cursor.readFirstString(column: String): String? {
    if (!moveToFirst()) {
        return null
    }
    val columnIndex = getColumnIndex(column)
    if (columnIndex < 0 || isNull(columnIndex)) {
        return null
    }
    return getString(columnIndex)
}

private fun extractFirstUrl(value: String?): String? {
    if (value == null) {
        return null
    }
    val matcher = urlPattern.matcher(value)
    if (!matcher.find()) {
        return null
    }
    return matcher.group(0).trimEnd('.', ',', ';', ':', '!', '?', ')', ']', '}', '>')
}
