package dev.dlsoft.quincena

import android.content.Context
import android.content.SharedPreferences
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

/**
 * Where the notification listener leaves what it read, and what it knows
 * of the person's choices.
 */
object CaptureStore {
    /**
     * The same file as `captureFileName` in lib/capture/native_inbox_io.dart,
     * in the folder `getApplicationSupportDirectory` returns.
     */
    const val FILE = "capture-inbox.jsonl"

    class Choices(val useLocation: Boolean, val mutedApps: Set<String>)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("capture", Context.MODE_PRIVATE)

    fun choices(context: Context): Choices {
        val prefs = prefs(context)
        return Choices(
            prefs.getBoolean("useLocation", false),
            prefs.getStringSet("mutedApps", null).orEmpty(),
        )
    }

    /** What the person chose in the app, sent each time it changes. */
    fun configure(context: Context, useLocation: Boolean, mutedApps: Collection<String>) {
        prefs(context).edit()
            .putBoolean("useLocation", useLocation)
            .putStringSet("mutedApps", mutedApps.toSet())
            .apply()
    }

    /**
     * Appends one event to the file. One write on a file opened for
     * appending: the app renames the file before reading it, and an event
     * that arrives meanwhile starts a new one.
     */
    @Synchronized
    fun append(context: Context, event: JSONObject) {
        val line = (event.toString() + "\n").toByteArray(Charsets.UTF_8)
        FileOutputStream(File(context.filesDir, FILE), true).use { it.write(line) }
    }

    /** The person shared something and chose to see it: the app opens on
     *  the inbox when it comes up. */
    fun askToOpenInbox(context: Context) {
        prefs(context).edit().putBoolean("openInbox", true).apply()
    }

    /** Whether the app should open on the inbox, once. */
    fun takeOpenInbox(context: Context): Boolean {
        val prefs = prefs(context)
        val asked = prefs.getBoolean("openInbox", false)
        if (asked) prefs.edit().remove("openInbox").apply()
        return asked
    }

    /** A moment as Dart's `DateTime.parse` reads it, in UTC. */
    fun iso(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(Date(millis))
}
