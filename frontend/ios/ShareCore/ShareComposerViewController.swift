import ImageIO
import UIKit

/// Extension-safe composer, embedded by either the extension or the main application's modal host.
final class ShareComposerViewController: UIViewController {
  private let store: ShareStore
  private let draftId: String
  private let onClose: () -> Void
  private lazy var service = ShareSaveService(store: store)
  private var credential: ShareCredential?
  private var submitting = false
  private var finished = false
  private var closed = false
  private var observer: NSObjectProtocol?
  private let statusLabel = UILabel()
  private let accountLabel = UILabel()
  private let saveButton = UIButton(type: .system)
  private let discardButton = UIButton(type: .system)

  init(store: ShareStore, draftId: String, onClose: @escaping () -> Void) {
    self.store = store; self.draftId = draftId; self.onClose = onClose
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = "허투루에 저장"
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(closeComposer))
    navigationItem.rightBarButtonItem?.accessibilityIdentifier = "share.close"
    isModalInPresentation = true
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)])
    let stack = UIStackView()
    stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
      stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24)])
    do {
      guard let draft = try store.draft(draftId) else { throw ShareFailure.message("초안이 없거나 보관 기간이 지났습니다.") }
      if draft.kind == "image", let url = store.imageURL(draft),
         let source = CGImageSourceCreateWithURL(url as CFURL, nil),
         let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
          kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 700,
          kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) {
        let preview = UIImageView(image: UIImage(cgImage: image))
        preview.contentMode = .scaleAspectFit
        preview.heightAnchor.constraint(equalToConstant: 240).isActive = true
        preview.accessibilityIdentifier = "share.image"
        stack.addArrangedSubview(preview)
      }
      let input = UILabel()
      input.text = draft.label; input.numberOfLines = 0; input.font = .preferredFont(forTextStyle: .title3)
      input.accessibilityIdentifier = "share.preview"
      stack.addArrangedSubview(input)
    } catch { statusLabel.text = error.localizedDescription }
    accountLabel.font = .preferredFont(forTextStyle: .subheadline); accountLabel.numberOfLines = 0
    accountLabel.accessibilityIdentifier = "share.account"
    statusLabel.font = .preferredFont(forTextStyle: .body); statusLabel.numberOfLines = 0
    statusLabel.accessibilityIdentifier = "share.status"
    saveButton.setTitle("저장", for: .normal)
    saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    saveButton.backgroundColor = UIColor(red: 0.22, green: 0.36, blue: 0.26, alpha: 1)
    saveButton.setTitleColor(.white, for: .normal); saveButton.layer.cornerRadius = 12
    saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    saveButton.accessibilityIdentifier = "share.save"
    saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
    discardButton.setTitle("초안 삭제", for: .normal)
    discardButton.accessibilityIdentifier = "share.discard"
    discardButton.addTarget(self, action: #selector(discard), for: .touchUpInside)
    [accountLabel, statusLabel, saveButton, discardButton].forEach(stack.addArrangedSubview)
    refreshCredential()
    observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
      object: nil, queue: .main) { [weak self] _ in self?.refreshCredential() }
  }
  private func refreshCredential() {
    guard !submitting, !finished, !closed else { return }
    do {
      credential = try store.currentCredential()
      guard let draft = try store.draft(draftId) else { saveButton.isEnabled = false; return }
      if let credential {
        accountLabel.text = "저장 계정: \(credential.accountLabel)"
        if let userId = draft.userId, userId != credential.userId {
          saveButton.isEnabled = false; statusLabel.text = ShareFailure.changedAccount.localizedDescription
        } else {
          saveButton.isEnabled = true
          statusLabel.text = draft.state == "unknown" || draft.state == "sending"
            ? "이전 저장 결과가 불명확합니다. 다시 시도하면 같은 저장을 확인합니다." : "링크·이미지와 저장 계정을 확인해 주세요."
        }
      } else {
        accountLabel.text = "앱에서 저장 계정 확인 필요"
        saveButton.isEnabled = false
        statusLabel.text = ShareFailure.authentication.localizedDescription
        try store.mark(draftId, state: "authRequired")
      }
    } catch { statusLabel.text = error.localizedDescription; saveButton.isEnabled = false }
    saveButton.alpha = saveButton.isEnabled ? 1 : 0.45
  }
  @objc private func save() {
    guard !submitting, !finished, let credential else { return }
    submitting = true; saveButton.isEnabled = false; discardButton.isEnabled = false
    statusLabel.text = "저장 중입니다…"
    service.save(draftId, expected: credential) { [weak self] result in
      guard let self, !self.closed else { return }
      self.submitting = false
      switch result {
      case .success:
        self.finished = true
        self.statusLabel.text = "저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."
        self.saveButton.setTitle("저장 완료", for: .normal)
        self.discardButton.isHidden = true
      case .failure(let error):
        self.refreshCredential()
        self.statusLabel.text = error.localizedDescription
        self.discardButton.isEnabled = true
      }
    }
  }
  @objc private func discard() {
    guard !submitting else { return }
    do { try store.discard(draftId); closed = true; onClose() }
    catch { statusLabel.text = error.localizedDescription }
  }
  @objc private func closeComposer() {
    guard !closed else { return }
    do {
      if submitting {
        try store.mark(draftId, state: "unknown")
        service.cancel()
      } else if !finished, let draft = try store.draft(draftId), draft.state == "pending", draft.userId == nil {
        try store.discard(draftId)
      }
      closed = true; onClose()
    } catch { statusLabel.text = error.localizedDescription }
  }
  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    service.cancel()
  }
}
