import UIKit
import UniformTypeIdentifiers

/// Test-only sender: exercises the real iOS share sheet with URL, text and file payloads.
@main
final class SenderAppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = SenderViewController()
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

final class SenderViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    let title = UILabel(); title.text = "공유 테스트 송신 앱"; title.font = .preferredFont(forTextStyle: .title1)
    title.accessibilityIdentifier = "sender.title"
    stack.addArrangedSubview(title)
    for (label, selector) in [("YouTube 링크 공유", #selector(shareURL)), ("Instagram 텍스트 공유", #selector(shareText)),
                              ("스크린샷 공유", #selector(shareImage)), ("느린 스크린샷 공유", #selector(shareSlowImage)),
                              ("지원하지 않는 공유", #selector(shareUnsupported))] {
      let button = UIButton(type: .system); button.setTitle(label, for: .normal)
      button.heightAnchor.constraint(equalToConstant: 52).isActive = true
      button.addTarget(self, action: selector, for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
    NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)])
  }
  @objc private func shareURL() {
    let arguments = ProcessInfo.processInfo.arguments
    let marker = arguments.firstIndex(of: "--recovery-url")
    let value = marker.flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
    show([URL(string: value ?? "https://youtu.be/dQw4w9WgXcQ")!])
  }
  @objc private func shareText() { show(["저장할 게시물 https://www.instagram.com/p/fixture/"]) }
  @objc private func shareUnsupported() { show(["https://example.com/unsupported"]) }
  @objc private func shareImage() {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("share-fixture.png")
    try! screenshot().write(to: file)
    show([file])
  }
  /// Hands the image over only after a delay, keeping the extension's preparation in progress.
  @objc private func shareSlowImage() {
    let data = screenshot()
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
      DispatchQueue.global().asyncAfter(deadline: .now() + 6) { completion(data, nil) }
      return nil
    }
    present(UIActivityViewController(activityItemsConfiguration: UIActivityItemsConfiguration(itemProviders: [provider])), animated: true)
  }
  private func screenshot() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
    return renderer.pngData { context in
      UIColor.systemGreen.setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
      ("허투루 스크린샷 테스트" as NSString).draw(at: CGPoint(x: 20, y: 120), withAttributes: [.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.white])
    }
  }
  private func show(_ items: [Any]) {
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    activity.popoverPresentationController?.sourceView = view
    present(activity, animated: true)
  }
}
