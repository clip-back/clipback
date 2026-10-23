import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
  private var started = false
  private var completed = false
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    view.backgroundColor = .systemBackground
    isModalInPresentation = true
    receive()
  }
  private func receive() {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    do {
      let store = try ShareStore()
      if ShareInputNormalizer.isURLPayload(providers) {
        receiveURLs(providers, store: store)
        return
      }
      guard providers.count == 1, let provider = providers.first else { throw ShareFailure.unsupported }
      if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        let accepted = [UTType.png.identifier, UTType.jpeg.identifier, "org.webmproject.webp"]
        let type = accepted.first(where: provider.hasItemConformingToTypeIdentifier) ?? UTType.image.identifier
        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
          do {
            guard error == nil, let url else { throw ShareFailure.unsupported }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= ShareStore.maxImageBytes else { throw ShareFailure.fileTooLarge }
            // Copy while NSItemProvider's temporary URL and security grant are valid.
            let draft = try store.createImage(fileURL: url)
            DispatchQueue.main.async { self?.presentComposer(store, draft: draft) }
          } catch { DispatchQueue.main.async { self?.showError(error) } }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, error in
          do {
            guard error == nil, let url = value as? URL else { throw ShareFailure.unsupported }
            let draft = try store.createLink(url.absoluteString)
            DispatchQueue.main.async { self?.presentComposer(store, draft: draft) }
          } catch { DispatchQueue.main.async { self?.showError(error) } }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] value, error in
          do {
            guard error == nil, let text = value as? String else { throw ShareFailure.unsupported }
            let draft = try store.createLink(text)
            DispatchQueue.main.async { self?.presentComposer(store, draft: draft) }
          } catch { DispatchQueue.main.async { self?.showError(error) } }
        }
      } else { showError(ShareFailure.unsupported) }
    } catch { showError(error) }
  }
  private func receiveURLs(_ providers: [NSItemProvider], store: ShareStore) {
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL?] = Array(repeating: nil, count: providers.count)
    var failed = false
    for (index, provider) in providers.enumerated() {
      group.enter()
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, error in
        lock.lock()
        if error == nil, let url = value as? URL { urls[index] = url } else { failed = true }
        lock.unlock()
        group.leave()
      }
    }
    group.notify(queue: .main) { [weak self] in
      do {
        guard !failed else { throw ShareFailure.unsupported }
        // Preserve provider order even when URL reads complete out of order.
        let draft = try store.createLink(ShareInputNormalizer.singleURL(urls.compactMap { $0 }))
        self?.presentComposer(store, draft: draft)
      } catch { self?.showError(error) }
    }
  }
  private func presentComposer(_ store: ShareStore, draft: ShareDraft) {
    guard !completed else { return }
    let composer = ShareComposerViewController(store: store, draftId: draft.id) { [weak self] in self?.complete() }
    let navigation = UINavigationController(rootViewController: composer)
    addChild(navigation)
    navigation.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(navigation.view)
    NSLayoutConstraint.activate([
      navigation.view.topAnchor.constraint(equalTo: view.topAnchor),
      navigation.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      navigation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      navigation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
    navigation.didMove(toParent: self)
  }
  private func showError(_ error: Error) {
    guard !completed else { return }
    let alert = UIAlertController(title: "공유할 수 없습니다", message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "닫기", style: .default) { [weak self] _ in self?.complete() })
    present(alert, animated: true)
  }
  private func complete() {
    guard !completed else { return }
    completed = true
    extensionContext?.completeRequest(returningItems: nil)
  }
}
