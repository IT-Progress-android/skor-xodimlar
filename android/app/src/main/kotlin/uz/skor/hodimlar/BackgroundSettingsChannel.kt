package uz.skor.hodimlar

import android.app.Activity
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Fon GPS kuzatuvi uchun telefonning batareya va autostart sozlamalarini
 * ochadi. Xiaomi/Huawei/Oppo/Vivo kabi telefonlar bu sozlamalarsiz fon
 * servisini o'ldiradi — natijada rahbar xaritasida xodimning harakati
 * yozilmaydi. Bu sozlamalar ishlab chiqaruvchiga xos, shuning uchun har
 * biri uchun ma'lum ekranlar ketma-ket sinab ko'riladi.
 */
class BackgroundSettingsChannel(private val activity: Activity) {

    companion object {
        const val CHANNEL = "uz.skor.hodimlar/background_settings"

        /** MIUI'ning "Autostart" ruxsati uchun AppOps raqami. */
        private const val MIUI_OP_AUTOSTART = 10008

        /** Vivo/iQOO: fonda ishga tushish ruxsatlari jadvali. */
        private const val VIVO_BG_START_URI =
            "content://com.vivo.permissionmanager.provider.permission/start_bg_activity"

        /** Ishlab chiqaruvchilarning autostart ekranlari (birinchi topilgani ochiladi). */
        private val AUTOSTART_COMPONENTS = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.MainActivity"),
        )
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "openBatterySettings" -> result.success(openBatterySettings())
                "openAutostartSettings" -> result.success(openAutostartSettings())
                "autostartState" -> result.success(autostartState())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Autostart'ning telefondagi haqiqiy holati: "on" / "off".
     * Holatni faqat Xiaomi (MIUI/HyperOS) va Vivo beradi; boshqa
     * ishlab chiqaruvchilarda "unknown" — u holda ilova bu qadamni so'ramaydi.
     */
    private fun autostartState(): String {
        val brand = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return when {
            brand.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco") -> miuiAutostartState()
            brand.contains("vivo") || brand.contains("iqoo") -> vivoAutostartState()
            else -> "unknown"
        }
    }

    private fun vivoAutostartState(): String = try {
        activity.contentResolver.query(
            Uri.parse(VIVO_BG_START_URI),
            null,
            "pkgname = ?",
            arrayOf(activity.packageName),
            null,
        )?.use { c ->
            if (c.moveToFirst()) {
                val idx = c.getColumnIndex("currentstate")
                // 0 — ruxsat berilgan, 1 — taqiqlangan.
                if (idx >= 0) (if (c.getInt(idx) == 0) "on" else "off") else "unknown"
            } else {
                "unknown"
            }
        } ?: "unknown"
    } catch (_: Exception) {
        "unknown"
    }

    private fun miuiAutostartState(): String {
        return try {
            val ops = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val method = AppOpsManager::class.java.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java,
            )
            val mode = method.invoke(ops, MIUI_OP_AUTOSTART, Process.myUid(), activity.packageName) as Int
            if (mode == AppOpsManager.MODE_ALLOWED) "on" else "off"
        } catch (_: Exception) {
            "unknown"
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(activity.packageName)
    }

    private fun canOpen(intent: Intent): Boolean =
        intent.resolveActivity(activity.packageManager) != null

    private fun tryStart(intent: Intent): Boolean = try {
        if (canOpen(intent)) {
            activity.startActivity(intent)
            true
        } else {
            false
        }
    } catch (_: Exception) {
        false
    }

    private fun appDetailsIntent() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))

    private fun findAutostartIntent(): Intent? {
        for (component in AUTOSTART_COMPONENTS) {
            val intent = Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (canOpen(intent)) return intent
        }
        return null
    }

    private fun openAutostartSettings(): Boolean {
        val intent = findAutostartIntent()
        return (intent != null && tryStart(intent)) || tryStart(appDetailsIntent())
    }

    private fun openBatterySettings(): Boolean {
        val pkg = activity.packageName
        // Xiaomi: ilovaning o'zi uchun "Batareya tejash" ekrani (Cheklovsiz).
        val miui = Intent().setComponent(
            ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"),
        ).putExtra("package_name", pkg).putExtra("package_label", "Skor Xodimlar")
        if (tryStart(miui)) return true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        ) {
            return true
        }
        return tryStart(appDetailsIntent())
    }
}
