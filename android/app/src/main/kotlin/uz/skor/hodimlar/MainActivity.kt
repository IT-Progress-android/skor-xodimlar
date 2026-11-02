package uz.skor.hodimlar

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import com.yandex.mapkit.MapKitFactory

// local_auth (barmoq izi / Face ID) FragmentActivity talab qiladi.
class MainActivity: FlutterFragmentActivity() {
    companion object {
        private var mapKitKeySet = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
        // "So'nggi ilovalar" ro'yxatida ilova ichidagi ma'lumot (maosh,
        // xarita) rasmi ko'rinmasin. Skrinshot olish taqiqlanmaydi.
        // Android 13 dan pastda buni Flutter'dagi parda qiladi.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Fon GPS servisi jarayonni tirik saqlaydi: ekran "orqaga" bilan
        // yopilib qayta ochilganda MapKit allaqachon ishga tushgan bo'ladi
        // va ikkinchi setApiKey() AssertionError bilan ilovani yiqitadi.
        if (!mapKitKeySet) {
            MapKitFactory.setApiKey("4a1c79e4-1372-4abd-af85-7b7e6690d8c4")
            mapKitKeySet = true
        }
        super.configureFlutterEngine(flutterEngine)
        BackgroundSettingsChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }

    /**
     * Unlocks 120Hz / 90Hz display mode on Xiaomi HyperOS/MIUI, Samsung OneUI, etc.,
     * which otherwise throttle Flutter apps with PlatformViews (YandexMap) to 60Hz.
     */
    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                } ?: return

                val modes = currentDisplay.supportedModes
                if (modes.isNotEmpty()) {
                    val activeMode = currentDisplay.mode
                    val bestMode = modes
                        .filter {
                            it.physicalWidth == activeMode.physicalWidth &&
                                it.physicalHeight == activeMode.physicalHeight
                        }
                        .maxByOrNull { it.refreshRate }
                        ?: modes.maxByOrNull { it.refreshRate }

                    if (bestMode != null) {
                        val params = window.attributes
                        params.preferredDisplayModeId = bestMode.modeId
                        params.preferredRefreshRate = bestMode.refreshRate
                        window.attributes = params
                    }
                }
            } catch (_: Throwable) {}
        }
    }
}
