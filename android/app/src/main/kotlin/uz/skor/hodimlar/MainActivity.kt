package uz.skor.hodimlar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.yandex.mapkit.MapKitFactory

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MapKitFactory.setApiKey("4a1c79e4-1372-4abd-af85-7b7e6690d8c4")
        super.configureFlutterEngine(flutterEngine)
    }
}
