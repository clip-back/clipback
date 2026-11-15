import AuthenticationServices
import Flutter
import ImageIO
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleRevocations = AppleCredentialRevocations()
  private var shareBridge: ShareBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let shareRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClipbackShare") {
      shareBridge = ShareBridge(registrar: shareRegistrar)
    }
    if let imageRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClipbackImage") {
      HeicJpegConverter.register(messenger: imageRegistrar.messenger())
    }
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

/// Converts the save screen's HEIC/HEIF photo to JPEG (#380): full resolution,
/// orientation applied to the pixels, no source metadata (so no GPS).
/// Replies nil when the bytes cannot be decoded; the app then uploads the
/// original and the server's 415 shows the supported-format message.
enum HeicJpegConverter {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.huturu.app/image", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "heicToJpeg",
        let args = call.arguments as? [String: Any],
        let bytes = args["bytes"] as? FlutterStandardTypedData,
        let quality = args["quality"] as? Int
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let jpeg = convert(bytes.data, quality: Double(quality) / 100)
        DispatchQueue.main.async { result(jpeg.map { FlutterStandardTypedData(bytes: $0) }) }
      }
    }
  }

  static func convert(_ data: Data, quality: Double) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    // A "thumbnail" as large as the image keeps every pixel and applies the
    // EXIF/irot orientation to them.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(width, height),
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output, "public.jpeg" as CFString, 1, nil)
    else { return nil }
    // Only the quality is written: no EXIF, GPS or orientation from the source.
    CGImageDestinationAddImage(
      destination, image,
      [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? output as Data : nil
  }
}
