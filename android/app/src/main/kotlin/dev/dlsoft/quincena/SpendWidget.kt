package dev.dlsoft.quincena

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The widget on the home screen: what the app last worked out can be spent
 * until payday. The app leaves the figure here through the widget channel
 * and this only draws it, with the same keys as `widgetFigure` in
 * lib/widget/home_widget.dart.
 *
 * Every view comes from the layout, colors included, so the launcher
 * resolves them for its own light or dark.
 */
class SpendWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = views(context)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    companion object {
        private const val PREFS = "quincena.widget"
        private const val SET = "set"
        private val TEXTS = listOf("label", "amount", "until", "when", "day", "updated", "stale")

        /** Keeps [figure], or forgets it with null, and draws every widget again. */
        fun save(context: Context, figure: Map<*, *>?) {
            val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear()
            if (figure != null) {
                for (key in TEXTS) edit.putString(key, figure[key] as? String ?: "")
                edit.putBoolean("short", figure["short"] == true)
                edit.putBoolean(SET, true)
            }
            edit.apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SpendWidget::class.java))
            if (ids.isNotEmpty()) {
                val views = views(context)
                for (id in ids) manager.updateAppWidget(id, views)
            }
        }

        /** Asks the launcher to add the widget; false where it cannot. */
        fun pin(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < 26) return false
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.isRequestPinAppWidgetSupported) return false
            return manager.requestPinAppWidget(
                ComponentName(context, SpendWidget::class.java), null, null,
            )
        }

        private fun views(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.spend_widget)
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        context, 0, it,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            }
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val set = prefs.getBoolean(SET, false)
            views.setViewVisibility(R.id.widget_figure, if (set) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_empty, if (set) View.GONE else View.VISIBLE)
            if (!set) return views

            fun text(key: String) = prefs.getString(key, "") ?: ""
            // A figure of another day says so instead of when it was worked out.
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val stale = text("day") != today
            val short = prefs.getBoolean("short", false)
            views.setTextViewText(R.id.widget_label, text("label"))
            views.setTextViewText(R.id.widget_amount, text("amount"))
            views.setTextViewText(R.id.widget_amount_short, text("amount"))
            views.setViewVisibility(R.id.widget_amount, if (short) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_amount_short, if (short) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_until, text("until"))
            views.setTextViewText(R.id.widget_updated, text("updated"))
            views.setTextViewText(R.id.widget_stale, text("stale"))
            views.setViewVisibility(R.id.widget_updated, if (stale) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_stale, if (stale) View.VISIBLE else View.GONE)
            return views
        }
    }
}
