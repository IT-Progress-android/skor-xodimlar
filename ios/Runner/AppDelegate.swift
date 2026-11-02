import Flutter
import UIKit
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setApiKey("4a1c79e4-1372-4abd-af85-7b7e6690d8c4")
    registerPrivacyCover()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Ilova faolligini yo'qotganda (so'nggi ilovalar, boshqaruv markazi)
  // ekran xira parda bilan yopiladi — ilova almashtirgichdagi rasmda ichidagi
  // ma'lumot ko'rinmaydi. Flutter pardasi bu rasm olinishiga ulgurmasligi
  // mumkin, shuning uchun native. SceneDelegate metodlari qayta yozilmaydi
  // (Flutter hayot sikli buzilmasin) — tizim bildirishnomalari ishlatiladi.
  private var privacyView: UIView?

  private func registerPrivacyCover() {
    let center = NotificationCenter.default
    center.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.showPrivacyCover() }
    center.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.hidePrivacyCover() }
  }

  private func showPrivacyCover() {
    guard privacyView == nil,
      let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })
    else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    privacyView = blur
  }

  private func hidePrivacyCover() {
    privacyView?.removeFromSuperview()
    privacyView = nil
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
