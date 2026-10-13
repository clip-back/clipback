import Flutter
import UIKit

final class ShareBridge {
  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar
  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    channel = FlutterMethodChannel(name: "com.huturu.app/share", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let store = try ShareStore()
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "getState": result(try store.getState())
      case "blockCredential": result(try store.blockCredential())
      case "publishCredential":
        var credentialArgs = args
        credentialArgs["userId"] = (args["userId"] as? NSNumber)?.stringValue
        credentialArgs["sessionId"] = (args["sessionId"] as? NSNumber)?.stringValue
        let data = try JSONSerialization.data(withJSONObject: credentialArgs)
        result(try store.publish(JSONDecoder().decode(ShareCredential.self, from: data)))
      case "acknowledgeReceipts":
        try store.acknowledge(args["ids"] as? [String] ?? []); result(nil)
      case "presentDraft":
        guard let id = args["id"] as? String, UUID(uuidString: id) != nil,
              try store.draft(id) != nil, let host = registrar.viewController else {
          throw ShareFailure.message("초안을 다시 열 수 없습니다.")
        }
        var presenting = host
        while let presented = presenting.presentedViewController { presenting = presented }
        let composer = ShareComposerViewController(store: store, draftId: id) { [weak presenting] in
          presenting?.dismiss(animated: true) { result(nil) }
        }
        let navigation = UINavigationController(rootViewController: composer)
        navigation.modalPresentationStyle = .pageSheet
        navigation.isModalInPresentation = true
        presenting.present(navigation, animated: true)
      default: result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "share_storage", message: error.localizedDescription, details: nil)) }
  }
  deinit { channel.setMethodCallHandler(nil) }
}
