package dev.dlsoft.quincena

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Quincena's reminders: the close of the fortnight on payday, and the
 * renewals the person asked about.
 *
 * None ever carries an amount: the lock screen shows them. They are kept
 * so a restart of the phone can set them again.
 */
object Reminders {
    private const val PREFS = "quincena.reminders"
    private const val CHANNEL = "close"
    private const val MAX = 24
    private const val INDEX = "index"

    fun schedule(context: Context, items: List<Map<String, Any?>>) {
        cancel(context)
        val kept = JSONArray()
        for (item in items.take(MAX)) {
            val at = (item["at"] as? Number)?.toLong() ?: continue
            kept.put(
                JSONObject()
                    .put("at", at)
                    .put("title", item["title"] as? String ?: "")
                    .put("body", item["body"] as? String ?: ""),
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("items", kept.toString())
            .apply()
        setAlarms(context)
    }

    fun cancel(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until MAX) alarms.cancel(pending(context, i))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** Sets an alarm for each kept reminder still ahead. */
    fun setAlarms(context: Context) {
        val now = System.currentTimeMillis()
        val alarms = context.getSystemService(AlarmManager::class.java)
        // Inexact is enough: a reminder belongs to the day, not the minute.
        items(context).forEachIndexed { i, item ->
            val at = item.optLong("at")
            if (at > now) alarms.set(AlarmManager.RTC_WAKEUP, at, pending(context, i))
        }
    }

    private fun items(context: Context): List<JSONObject> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString("items", null) ?: return before9(prefs)
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * What builds before 9 kept, the close's days with one title and body,
     * so a reminder due before the updated app is first opened still shows.
     */
    private fun before9(prefs: SharedPreferences): List<JSONObject> {
        val title = prefs.getString("title", null) ?: return emptyList()
        val body = prefs.getString("body", null).orEmpty()
        return prefs.getString("days", null).orEmpty().split(",")
            .mapNotNull { it.toLongOrNull() }
            .map { JSONObject().put("at", it).put("title", title).put("body", body) }
    }

    private fun pending(context: Context, i: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        i,
        Intent(context, ReminderReceiver::class.java).putExtra(INDEX, i),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun show(context: Context, index: Int) {
        val item = items(context).getOrNull(index) ?: return
        val title = item.optString("title")
        if (title.isEmpty()) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Quincena", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        manager.notify(
            REMINDER_ID + index,
            builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(item.optString("body"))
                .setContentIntent(open)
                .setAutoCancel(true)
                // Nothing in it is private, so the lock screen may show it.
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .build(),
        )
    }

    fun indexOf(intent: Intent): Int = intent.getIntExtra(INDEX, 0)

    private const val REMINDER_ID = 7041
}

/** Shows a reminder when its day comes. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) =
        Reminders.show(context, Reminders.indexOf(intent))
}

/** A restart forgets alarms: this sets the reminders again. */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.setAlarms(context)
    }
}
