package dev.dlsoft.quincena

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.location.LocationRequest
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.Normalizer
import org.json.JSONObject

/**
 * Reads the notifications that look like payments and leaves them, one JSON
 * line each, where the app takes them when it opens or comes back.
 *
 * Anything without an amount next to a currency passes by without being
 * kept, and so does a security code. Deciding what a notification says is
 * left to `parseCapture` in lib/capture/parser.dart; this only filters.
 */
class CaptureListener : NotificationListenerService() {
    /** The text last written for each notification, so an update that
     *  changes nothing is not written again. */
    private val written = object : LinkedHashMap<String, Int>(32, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Int>) =
            size > 64
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName || sbn.isOngoing) return
        val notification = sbn.notification ?: return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val choices = CaptureStore.choices(this)
        if (sbn.packageName in choices.mutedApps) return
        val reading = Reading.of(notification.extras) ?: return
        if (!reading.looksLikeMoney() || reading.isSecurityCode()) return
        val hash = reading.all.hashCode()
        if (written[sbn.key] == hash) return
        written[sbn.key] = hash

        val source = sourceOf(sbn.packageName)
        val event = JSONObject()
            .put("source", source)
            .put("at", CaptureStore.iso(sbn.postTime))
            .put("app", sbn.packageName)
        appName(notification.extras, sbn.packageName)?.let { event.put("appName", it) }
        if (source == "notification") {
            reading.title?.let { event.put("title", it) }
            reading.body?.let { event.put("body", it) }
        } else {
            reading.title?.let { event.put("sender", it) }
            event.put("text", reading.body ?: reading.title)
        }

        if (!choices.useLocation || !mayLocate()) return keep(event)
        val recent = lastKnown()
        if (recent != null) return keep(event, recent)
        currentLocation { keep(event, it) }
    }

    private fun keep(event: JSONObject, place: Location? = null) {
        if (place != null) {
            event.put("lat", place.latitude).put("lng", place.longitude)
            if (place.hasAccuracy()) event.put("accuracy", place.accuracy.toDouble())
        }
        CaptureStore.append(this, event)
        onCaptured?.invoke()
    }

    private fun sourceOf(app: String): String = when {
        app in smsApps || app == Telephony.Sms.getDefaultSmsPackage(this) -> "sms"
        app in emailApps -> "email"
        else -> "notification"
    }

    /** The name people know the app by, for the inbox and the muted list. */
    @Suppress("DEPRECATION")
    private fun appName(extras: Bundle, app: String): String? = try {
        val carried: ApplicationInfo? = if (Build.VERSION.SDK_INT >= 33) {
            extras.getParcelable("android.appInfo", ApplicationInfo::class.java)
        } else {
            extras.getParcelable("android.appInfo")
        }
        val info = carried ?: packageManager.getApplicationInfo(app, 0)
        info.loadLabel(packageManager).toString().takeIf { it.isNotBlank() && it != app }
    } catch (e: Exception) {
        null
    }

    private fun mayLocate(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /** A fix from the last couple of minutes, which is where the payment was. */
    @SuppressLint("MissingPermission") // Checked by mayLocate.
    private fun lastKnown(): Location? = try {
        val manager = getSystemService(LocationManager::class.java)
        manager.getProviders(true)
            .mapNotNull { manager.getLastKnownLocation(it) }
            .maxByOrNull { it.elapsedRealtimeNanos }
            ?.takeIf { SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos <= freshNanos }
    } catch (e: SecurityException) {
        null
    }

    /**
     * Asks for the location now. Precise where the system allows choosing:
     * the shops searched are the ones within 80 metres. The system gives up
     * after 30 seconds at most.
     */
    @SuppressLint("MissingPermission") // Checked by mayLocate.
    private fun currentLocation(done: (Location?) -> Unit) {
        if (Build.VERSION.SDK_INT < 30) return done(null)
        try {
            val manager = getSystemService(LocationManager::class.java)
            if (Build.VERSION.SDK_INT >= 31 && manager.hasProvider(LocationManager.FUSED_PROVIDER)) {
                val request = LocationRequest.Builder(0)
                    .setQuality(LocationRequest.QUALITY_HIGH_ACCURACY)
                    .setDurationMillis(20_000)
                    .build()
                manager.getCurrentLocation(
                    LocationManager.FUSED_PROVIDER, request, null, mainExecutor,
                ) { done(it) }
                return
            }
            val provider = when {
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                    LocationManager.NETWORK_PROVIDER
                manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                    LocationManager.GPS_PROVIDER
                else -> return done(null)
            }
            manager.getCurrentLocation(provider, null, mainExecutor) { done(it) }
        } catch (e: Exception) {
            done(null)
        }
    }

    companion object {
        /** Set while the Flutter engine runs, so an open app takes each event
         *  as it arrives instead of on its next return. */
        var onCaptured: (() -> Unit)? = null

        private const val freshNanos = 2L * 60 * 1_000_000_000

        private val smsApps = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms",
            "com.android.messaging",
        )
        private val emailApps = setOf(
            "com.google.android.gm",
            "com.microsoft.office.outlook",
            "com.yahoo.mobile.client.android.mail",
            "ch.protonmail.android",
            "com.samsung.android.email.provider",
        )

        fun hasAccess(context: Context): Boolean {
            val me = ComponentName(context, CaptureListener::class.java)
            if (Build.VERSION.SDK_INT >= 27) {
                return context.getSystemService(NotificationManager::class.java)
                    .isNotificationListenerAccessGranted(me)
            }
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
        }
    }
}

/** What a notification says: its title and the text under it. */
internal class Reading(val title: String?, val body: String?) {
    val all: String = listOfNotNull(title, body).joinToString("\n")

    /** An amount next to a currency, as `findAmounts` in
     *  lib/capture/amounts.dart looks for it. A number alone is a date, a
     *  time or a card. */
    fun looksLikeMoney(): Boolean = amount.containsMatchIn(all)

    /** As `parseCapture` sets them aside: a word for a code and the code. */
    fun isSecurityCode(): Boolean {
        val plain = Normalizer.normalize(all.lowercase(), Normalizer.Form.NFD)
            .replace(marks, "")
        return securityWord.containsMatchIn(plain) && securityDigits.containsMatchIn(plain)
    }

    companion object {
        private val amount = Regex(
            """(US[$]|U[$]S|COL[$]|MX[$]|USD|COP|EUR|MXN|€|[$])\s?\d""" +
                """|\d\s?(USDT|USDC|USD|COP|EUR|MXN|BTC|ETH|BNB|SOL)\b""",
            RegexOption.IGNORE_CASE,
        )
        private val securityWord = Regex(
            """\b(clave|codigo|otp|token|contrasena|password|verification|verificacion)\b""",
        )
        private val securityDigits = Regex("""\b\d{4,8}\b""")
        private val marks = Regex("""\p{Mn}+""")

        fun of(extras: Bundle): Reading? {
            val title = clean(extras.getCharSequence(Notification.EXTRA_TITLE))
            val body = clean(
                lastMessage(extras)
                    ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                    ?: extras.getCharSequence(Notification.EXTRA_TEXT),
            )
            return if (title == null && body == null) null else Reading(title, body)
        }

        /** In a conversation, the newest message: the rest came before. */
        private fun lastMessage(extras: Bundle): CharSequence? {
            @Suppress("DEPRECATION")
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            return (messages?.lastOrNull() as? Bundle)?.getCharSequence("text")
        }

        private fun clean(text: CharSequence?): String? =
            text?.toString()?.trim()?.takeIf { it.isNotEmpty() }
    }
}
