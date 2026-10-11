import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleRevocations = AppleCredentialRevocations()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClipbackSocialAuth") else {
      return
    }
    let config = FlutterMethodChannel(
      name: "clipback/social-auth-config", binaryMessenger: registrar.messenger())
    config.setMethodCallHandler { call, result in
      guard call.method == "hasUrlScheme", let scheme = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
        as? [[String: Any]] ?? []
      let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
      result(schemes.contains(scheme))
    }
    let events = FlutterEventChannel(
      name: "clipback/apple-credential-revocations", binaryMessenger: registrar.messenger())
    events.setStreamHandler(appleRevocations)
  }
}

private final class AppleCredentialRevocations: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    stopObserving()
    observer = NotificationCenter.default.addObserver(
      forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
      object: nil,
      queue: .main
    ) { _ in events(NSNull()) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    return nil
  }

  private func stopObserving() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
  }

  deinit { stopObserving() }
}
