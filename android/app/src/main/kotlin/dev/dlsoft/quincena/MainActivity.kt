package dev.dlsoft.quincena

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var capture: MethodChannel? = null
    private var reminders: MethodChannel? = null
    private var asking: MethodChannel.Result? = null
    private var askingToNotify: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The same channel as `CaptureChannel` in lib/capture/native_channel.dart.
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "notificationAccess" -> result.success(CaptureListener.hasAccess(this))
                "openNotificationAccess" -> {
                    openNotificationAccess()
                    result.success(null)
                }
                "locationAccess" -> result.success(locationAccess())
                "askForLocation" ->
                    if (locationAccess() == "none") {
                        ask(arrayOf(FINE, COARSE), result)
                    } else {
                        result.success(locationAccess())
                    }
                "askForBackgroundLocation" ->
                    if (Build.VERSION.SDK_INT >= 29 && locationAccess() == "foreground") {
                        ask(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), result)
                    } else {
                        result.success(locationAccess())
                    }
                "openAppSettings" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ),
                    )
                    result.success(null)
                }
                "readText", "readStatement" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) {
                        result.success(null)
                    } else {
                        val statement = call.method == "readStatement"
                        Thread {
                            val text = try {
                                if (statement) {
                                    TextReader.readStatement(this, bytes)
                                } else {
                                    TextReader.read(this, bytes)
                                }
                            } catch (e: Exception) {
                                Log.w("Quincena", "Could not read the image", e)
                                null
                            }
                            runOnUiThread { result.success(text) }
                        }.start()
                    }
                }
                "takeOpenInbox" -> result.success(CaptureStore.takeOpenInbox(this))
                "configure" -> {
                    CaptureStore.configure(
                        this,
                        call.argument<Boolean>("useLocation") == true,
                        call.argument<List<String>>("mutedApps").orEmpty(),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        CaptureListener.onCaptured = { channel.invokeMethod("captured", null) }
        capture = channel

        // The same channel as `Reminders` in lib/reminders/reminders.dart.
        val remind = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDERS)
        remind.setMethodCallHandler { call, result ->
            when (call.method) {
                "ask" ->
                    if (Build.VERSION.SDK_INT >= 33 && !granted(NOTIFY)) {
                        askingToNotify?.success(false)
                        askingToNotify = result
                        requestPermissions(arrayOf(NOTIFY), ASK_NOTIFY)
                    } else {
                        result.success(true)
                    }
                "schedule" -> {
                    Reminders.schedule(
                        this,
                        call.argument<List<Map<String, Any?>>>("items").orEmpty(),
                    )
                    result.success(null)
                }
                "cancel" -> {
                    Reminders.cancel(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        reminders = remind
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CaptureListener.onCaptured = null
        capture?.setMethodCallHandler(null)
        capture = null
        reminders?.setMethodCallHandler(null)
        reminders = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Straight to Quincena's switch where the system has one, else the list. */
    private fun openNotificationAccess() {
        val list = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        val intent = if (Build.VERSION.SDK_INT >= 30) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(this, CaptureListener::class.java).flattenToString(),
            )
        } else {
            list
        }
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(list)
        }
    }

    private fun granted(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /**
     * How much of the location the listener can see: `none`, `foreground`
     * (only while the app is open, which leaves out most payments) or
     * `always`.
     */
    private fun locationAccess(): String = when {
        !granted(FINE) && !granted(COARSE) -> "none"
        Build.VERSION.SDK_INT >= 29 &&
            !granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION) -> "foreground"
        else -> "always"
    }

    /** From Android 11, asking for the background shows the settings page. */
    private fun ask(permissions: Array<String>, result: MethodChannel.Result) {
        asking?.success(locationAccess())
        asking = result
        requestPermissions(permissions, ASK_LOCATION)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ASK_NOTIFY) {
            askingToNotify?.success(Build.VERSION.SDK_INT < 33 || granted(NOTIFY))
            askingToNotify = null
            return
        }
        if (requestCode != ASK_LOCATION) return
        asking?.success(locationAccess())
        asking = null
    }

    private companion object {
        const val CHANNEL = "dev.dlsoft.quincena/capture"
        const val REMINDERS = "dev.dlsoft.quincena/reminders"
        const val ASK_LOCATION = 4815
        const val ASK_NOTIFY = 4816
        const val NOTIFY = "android.permission.POST_NOTIFICATIONS"
        const val FINE = Manifest.permission.ACCESS_FINE_LOCATION
        const val COARSE = Manifest.permission.ACCESS_COARSE_LOCATION
    }
}
