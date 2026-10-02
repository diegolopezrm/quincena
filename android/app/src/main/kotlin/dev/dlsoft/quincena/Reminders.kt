package dev.dlsoft.quincena

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The reminder that the close of the fortnight is ready, on each payday.
 *
 * It says only that: no amount ever shows on the lock screen. The days are
 * kept so a restart of the phone can set them again.
 */
object Reminders {
    private const val PREFS = "quincena.reminders"
    private const val CHANNEL = "close"
    private const val MAX = 12

    fun schedule(context: Context, days: List<Long>, title: String, body: String) {
        cancel(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("days", days.joinToString(","))
            .putString("title", title)
            .putString("body", body)
            .apply()
        setAlarms(context)
    }

    fun cancel(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until MAX) alarms.cancel(pending(context, i))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** Sets an alarm for each kept day still ahead. */
    fun setAlarms(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val days = prefs.getString("days", null).orEmpty()
            .split(",").mapNotNull { it.toLongOrNull() }.filter { it > now }
        val alarms = context.getSystemService(AlarmManager::class.java)
        // Inexact is enough: the reminder belongs to the day, not the minute.
        days.take(MAX).forEachIndexed { i, at ->
            alarms.set(AlarmManager.RTC_WAKEUP, at, pending(context, i))
        }
    }

    private fun pending(context: Context, i: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        i,
        Intent(context, ReminderReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun show(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString("title", null) ?: return
        val body = prefs.getString("body", null).orEmpty()
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_DEFAULT),
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
            REMINDER_ID,
            builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
                // Nothing in it is private, so the lock screen may show it.
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .build(),
        )
    }

    private const val REMINDER_ID = 7041
}

/** Shows the reminder when its day comes. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Reminders.show(context)
}

/** A restart forgets alarms: this sets the reminders again. */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.setAlarms(context)
    }
}
