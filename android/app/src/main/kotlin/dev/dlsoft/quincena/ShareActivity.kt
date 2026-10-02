package dev.dlsoft.quincena

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import org.json.JSONObject

/**
 * What another app shares with Quincena: a screenshot, a photo, a PDF or a
 * text. It is read here, without starting the app, and left in the inbox's
 * file like a notification; a small dialog says so and the person stays in
 * the app they shared from, unless they choose to open Quincena.
 *
 * Reading a payment is left to `parseCapture` in Dart. This only keeps what
 * has an amount next to a currency, as the notification listener does.
 */
class ShareActivity : Activity() {
    private var dialog: AlertDialog? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val night = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
        val shown = AlertDialog.Builder(
            this,
            if (night) {
                android.R.style.Theme_DeviceDefault_Dialog_Alert
            } else {
                android.R.style.Theme_DeviceDefault_Light_Dialog_Alert
            },
        )
            .setTitle("Quincena")
            .setMessage(R.string.share_reading)
            .setPositiveButton(R.string.share_open) { _, _ -> openInbox() }
            .setNegativeButton(R.string.share_done, null)
            .setOnDismissListener { finish() }
            .create()
        shown.show()
        shown.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = false
        dialog = shown

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val streams = streams(intent)
        Thread {
            val read = mutableListOf<Pair<String, String>>()
            if (streams.isEmpty() && text != null) read.add("paste" to text)
            for (uri in streams) {
                val found = try {
                    contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?.let { TextReader.read(this, it) }
                } catch (e: Exception) {
                    Log.w("Quincena", "Could not read what was shared: $uri", e)
                    null
                }
                if (!found.isNullOrBlank()) read.add("screenshot" to found)
            }
            val kept = read.filter { (_, body) ->
                val reading = Reading(null, body)
                reading.looksLikeMoney() && !reading.isSecurityCode()
            }
            for ((source, body) in kept) {
                CaptureStore.append(
                    this,
                    JSONObject()
                        .put("source", source)
                        .put("at", CaptureStore.iso(System.currentTimeMillis()))
                        .put("text", body.trim()),
                )
            }
            runOnUiThread { done(kept.size) }
        }.start()
    }

    private fun done(kept: Int) {
        val shown = dialog ?: return
        if (kept == 0) {
            shown.setMessage(getString(R.string.share_nothing))
            return
        }
        shown.setMessage(resources.getQuantityString(R.plurals.share_kept, kept, kept))
        shown.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = true
        CaptureListener.onCaptured?.invoke()
    }

    /** Quincena, on the inbox: the app asks for it when it comes up. */
    private fun openInbox() {
        CaptureStore.askToOpenInbox(this)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** The files shared, in EXTRA_STREAM as Android asks, or as the
     *  intent's data, as some apps send them. */
    private fun streams(intent: Intent): List<Uri> =
        sent(intent).ifEmpty { listOfNotNull(intent.data) }

    @Suppress("DEPRECATION")
    private fun sent(intent: Intent): List<Uri> = when (intent.action) {
        Intent.ACTION_SEND -> listOfNotNull(
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            },
        )
        Intent.ACTION_SEND_MULTIPLE -> (
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
            ).orEmpty()
        else -> emptyList()
    }

    override fun onDestroy() {
        dialog?.setOnDismissListener(null)
        dialog?.dismiss()
        dialog = null
        super.onDestroy()
    }
}
