import UIKit
import UniformTypeIdentifiers

/// Share-menu entry: the share save sheet (Figma 233:3420) and completion toast (233:3430).
/// Pending-share recovery in the main application keeps using ShareComposerViewController.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
  private static let main = UIColor(red: 1, green: 0xD7 / 255, blue: 0x5C / 255, alpha: 1)
  private static let ink = UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1)
  private static let subtle = UIColor(red: 0x76 / 255, green: 0x76 / 255, blue: 0x76 / 255, alpha: 1)
  private static let subtler = UIColor(red: 0xD1 / 255, green: 0xD1 / 255, blue: 0xD1 / 255, alpha: 1)
  private static let toastDuration: TimeInterval = 1.5
  private var started = false
  private var completed = false
  private var preparing = false
  private var closing = false
  private var submitting = false
  private var finished = false
  private var store: ShareStore?
  private var service: ShareSaveService?
  private var draftId: String?
  private var credential: ShareCredential?
  private var loading: Progress?
  private let dimView = UIView()
  private let sheet = UIView()
  private let saveButton = UIButton(type: .custom)

  override init(nibName: String?, bundle: Bundle?) {
    super.init(nibName: nibName, bundle: bundle)
    // Keep the host app visible behind the dimmed backdrop.
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    dimView.backgroundColor = UIColor(white: 0, alpha: 0.5)
    dimView.isAccessibilityElement = true
    dimView.accessibilityLabel = "닫기"
    dimView.accessibilityTraits = .button
    dimView.accessibilityIdentifier = "share.dismiss"
    dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissSheet)))
    sheet.backgroundColor = .white
    sheet.layer.cornerRadius = 24
    sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    sheet.accessibilityIdentifier = "share.sheet"
    sheet.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag)))
    let handle = UIView()
    handle.backgroundColor = Self.subtler
    handle.layer.cornerRadius = 2.5
    saveButton.backgroundColor = Self.main
    saveButton.layer.cornerRadius = 8
    saveButton.setAttributedTitle(Self.text("저장하기", font: "Pretendard-SemiBold", size: 16, color: Self.ink), for: .normal)
    saveButton.titleLabel?.numberOfLines = 0
    saveButton.titleLabel?.textAlignment = .center
    // Preparation keeps the same look; only the tap is blocked until the draft and account are ready.
    saveButton.isEnabled = false
    saveButton.accessibilityIdentifier = "share.save"
    saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
    let guide = UILabel()
    guide.attributedText = Self.text("전송한 정보는 AI가 직접 분류해서 저장할게요!", font: "Pretendard-Medium", size: 14, color: Self.subtle)
    guide.numberOfLines = 0
    guide.textAlignment = .center
    let stack = UIStackView(arrangedSubviews: [saveButton, guide])
    stack.axis = .vertical
    stack.spacing = 16
    [dimView, sheet].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
    [handle, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; sheet.addSubview($0) }
    NSLayoutConstraint.activate([
      dimView.topAnchor.constraint(equalTo: view.topAnchor),
      dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      handle.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 8),
      handle.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
      handle.widthAnchor.constraint(equalToConstant: 50),
      handle.heightAnchor.constraint(equalToConstant: 5),
      stack.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 32),
      stack.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -16),
      saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
      saveButton.heightAnchor.constraint(greaterThanOrEqualTo: saveButton.titleLabel!.heightAnchor, constant: 36)]
      // Content grows the sheet upward; the bottom gap is max(Figma 32, home indicator inset).
      + Self.bottomGap(stack, container: sheet, view: view))
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    lowerSheet()
    UIView.animate(withDuration: 0.25) { self.sheet.transform = .identity }
    receive()
  }

  override func accessibilityPerformEscape() -> Bool {
    dismissSheet()
    return true
  }

  private func receive() {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    preparing = true
    do {
      let store = try ShareStore()
      self.store = store
      if ShareInputNormalizer.isURLPayload(providers) {
        receiveURLs(providers, store: store)
        return
      }
      guard providers.count == 1, let provider = providers.first else { throw ShareFailure.refused(.notSingle) }
      if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        let accepted = [UTType.png.identifier, UTType.jpeg.identifier, "org.webmproject.webp"]
        let type = accepted.first(where: provider.hasItemConformingToTypeIdentifier) ?? UTType.image.identifier
        loading = provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
          do {
            guard error == nil, let url else { throw ShareFailure.refused(.imageUnreadable) }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= ShareStore.maxImageBytes else { throw ShareFailure.fileTooLarge }
            // Copy while NSItemProvider's temporary URL and security grant are valid.
            let draft = try store.createImage(fileURL: url)
            DispatchQueue.main.async { self?.prepared(.success(draft)) }
          } catch { DispatchQueue.main.async { self?.prepared(.failure(error)) } }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, error in
          do {
            guard error == nil, let url = value as? URL else { throw ShareFailure.refused(.other) }
            let draft = try store.createLink(url.absoluteString)
            DispatchQueue.main.async { self?.prepared(.success(draft)) }
          } catch { DispatchQueue.main.async { self?.prepared(.failure(error)) } }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] value, error in
          do {
            guard error == nil, let text = value as? String else { throw ShareFailure.refused(.other) }
            let draft = try store.createLink(text)
            DispatchQueue.main.async { self?.prepared(.success(draft)) }
          } catch { DispatchQueue.main.async { self?.prepared(.failure(error)) } }
        }
      } else { prepared(.failure(ShareFailure.refused(.other))) }
    } catch { prepared(.failure(error)) }
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
        guard !failed else { throw ShareFailure.refused(.other) }
        // Preserve provider order even when URL reads complete out of order.
        let draft = try store.createLink(ShareInputNormalizer.singleURL(urls.compactMap { $0 }))
        self?.prepared(.success(draft))
      } catch { self?.prepared(.failure(error)) }
    }
  }

  /// The draft is stored first; the saving account is checked only after that.
  private func prepared(_ result: Result<ShareDraft, Error>) {
    preparing = false
    switch result {
    case .failure(let error):
      // Nothing was kept, so these win over login required.
      if closing { complete() } else { showAlert(Self.preparationAlert(error)) }
    case .success(let draft):
      guard !closing else {
        // Dismissed while preparing: a draft that arrived late is not kept.
        try? store?.discard(draft.id)
        complete()
        return
      }
      guard let store else { return }
      draftId = draft.id
      service = ShareSaveService(store: store)
      // An unreadable credential also counts as login required: the share is already kept.
      guard let credential = try? store.currentCredential() else {
        try? store.mark(draft.id, state: "authRequired")
        // The sheet goes down before the alert; iOS cannot open the app, so the message says to.
        UIView.animate(withDuration: 0.25, animations: {
          self.lowerSheet()
        }, completion: { _ in self.showAlert(Self.saveAlert(.authentication)) })
        return
      }
      self.credential = credential
      saveButton.isEnabled = true
    }
  }

  @objc private func save() {
    guard let draftId, let credential, let service, !submitting, !finished, !closing else { return }
    submitting = true
    saveButton.isEnabled = false
    service.save(draftId, expected: credential) { [weak self] result in
      guard let self, !self.closing else { return }
      self.submitting = false
      switch result {
      case .success:
        self.finished = true
        self.showSavedToast()
      case .failure(let error):
        // The sheet stays behind the alert with "저장하기" disabled.
        var kind = (error as? ShareFailure)?.kind
        if Self.saveAlert(kind).retry, self.accountChangedSinceSave() { kind = .accountChanged }
        self.showAlert(Self.saveAlert(kind))
      }
    }
  }

  /// Same meaning as the former close button: an unsent draft is discarded, an in-flight save is kept as unknown.
  @objc private func dismissSheet() {
    guard !closing, !finished, !completed else { return }
    closing = true
    loading?.cancel()
    if let store, let draftId {
      if submitting {
        try? store.mark(draftId, state: "unknown")
        service?.cancel()
      } else if let draft = try? store.draft(draftId), draft.state == "pending", draft.userId == nil {
        try? store.discard(draftId)
      }
    }
    UIView.animate(withDuration: 0.25, animations: {
      self.lowerSheet()
      self.dimView.alpha = 0
    }, completion: { _ in
      // A pending preparation finishes (and discards its draft) before the extension ends.
      if !self.preparing { self.complete() }
    })
  }

  /// Moves the sheet just below the screen; animated callers slide it down.
  private func lowerSheet() { sheet.transform = CGAffineTransform(translationX: 0, y: sheet.bounds.height) }

  @objc private func drag(_ gesture: UIPanGestureRecognizer) {
    guard !closing, !finished else { return }
    let offset = max(0, gesture.translation(in: view).y)
    switch gesture.state {
    case .changed:
      sheet.transform = CGAffineTransform(translationX: 0, y: offset)
    case .ended, .cancelled:
      if offset > sheet.bounds.height / 3 || gesture.velocity(in: view).y > 800 {
        dismissSheet()
      } else {
        UIView.animate(withDuration: 0.2) { self.sheet.transform = .identity }
      }
    default: break
    }
  }

  private func showSavedToast() {
    let toast = UIView()
    toast.backgroundColor = Self.ink
    toast.layer.cornerRadius = 4
    toast.isAccessibilityElement = true
    toast.accessibilityLabel = "저장 완료!"
    toast.accessibilityIdentifier = "share.toast"
    let check = UIView()
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 16.6667, y: 5))
    path.addLine(to: CGPoint(x: 7.5, y: 14.1667))
    path.addLine(to: CGPoint(x: 3.33333, y: 10))
    let stroke = CAShapeLayer()
    stroke.path = path.cgPath
    stroke.strokeColor = Self.main.cgColor
    stroke.fillColor = nil
    stroke.lineWidth = 1.66667
    stroke.lineCap = .round
    stroke.lineJoin = .round
    check.layer.addSublayer(stroke)
    let label = UILabel()
    label.attributedText = Self.text("저장 완료!", font: "Pretendard-SemiBold", size: 16, color: Self.main)
    label.numberOfLines = 0
    let row = UIStackView(arrangedSubviews: [check, label])
    row.spacing = 8
    row.alignment = .center
    [toast, row].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
    view.addSubview(toast)
    toast.addSubview(row)
    NSLayoutConstraint.activate([
      check.widthAnchor.constraint(equalToConstant: 20),
      check.heightAnchor.constraint(equalToConstant: 20),
      toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      toast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      row.centerXAnchor.constraint(equalTo: toast.centerXAnchor),
      row.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
      row.leadingAnchor.constraint(greaterThanOrEqualTo: toast.leadingAnchor, constant: 16),
      row.topAnchor.constraint(greaterThanOrEqualTo: toast.topAnchor, constant: 12)]
      + Self.bottomGap(toast, container: view, view: view))
    toast.alpha = 0
    UIView.animate(withDuration: 0.25, animations: {
      self.lowerSheet()
    }, completion: { _ in
      UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
      UIAccessibility.post(notification: .announcement, argument: "저장 완료!")
      // Temporary duration: the design has no value yet (docs/figma-ui-alignment-plan.md).
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.toastDuration) { self.complete() }
    })
  }

  /// A retry must not go to an account that replaced the one this save started with.
  private func accountChangedSinceSave() -> Bool {
    guard let credential, let current = try? store?.currentCredential() else { return false }
    return current.revision != credential.revision || current.userId != credential.userId
      || current.sessionId != credential.sessionId
  }

  private struct Alert {
    let title: String
    let message: String
    var retry = false
    var discard = false
  }

  /// Copy shared with Android (spec #122): before anything is kept.
  private static func preparationAlert(_ error: Error) -> Alert {
    switch (error as? ShareFailure)?.kind {
    case .refused(let reason)?:
      let message: String
      switch reason {
      case .notSingle: message = "링크 하나 또는 이미지 한 장만 공유할 수 있습니다."
      case .textTooLong: message = "공유 텍스트가 너무 깁니다."
      case .noLink: message = "Instagram 또는 YouTube 링크를 공유해 주세요."
      case .multipleLinks: message = "한 번에 링크 하나만 공유해 주세요."
      case .unsupportedLink: message = "Instagram 또는 YouTube 링크만 저장할 수 있습니다."
      case .imageUnreadable: message = "이미지를 읽을 수 없습니다."
      case .imageTooLarge: message = "이미지는 10MiB 이하만 공유할 수 있습니다."
      case .imageFormat: message = "PNG, JPEG, WebP 이미지만 지원합니다. HEIC와 동영상은 지원하지 않습니다."
      case .imageFile: message = "이미지 파일을 읽을 수 없습니다."
      case .other: message = "Instagram·YouTube 링크 또는 PNG·JPEG·WebP 이미지를 공유해 주세요."
      }
      return Alert(title: "공유할 수 없어요", message: message)
    case .storageFull?:
      return Alert(title: "보관하지 못했어요",
        message: "보관 중인 공유가 가득 찼어요. 허투루 앱에서 저장 대기 공유를 저장하거나 삭제한 뒤 다시 공유해 주세요.")
    default:
      // Image/state writes, App Group and lock failures.
      return Alert(title: "보관하지 못했어요", message: "공유 내용을 보관하지 못했어요. 다시 공유해 주세요.")
    }
  }

  /// Copy shared with Android (spec #122): the share is already kept unless the alert discards it.
  private static func saveAlert(_ kind: ShareFailureKind?) -> Alert {
    let retryTitle = "저장하지 못했어요"
    let changedTitle = "저장 환경이 바뀌었어요"
    let finalTitle = "다시 저장할 수 없어요"
    switch kind {
    case .authentication?:
      return Alert(title: "로그인이 필요해요", message: ShareFailure.authentication.localizedDescription)
    case .unconfirmed?:
      return Alert(title: retryTitle, message: "저장 결과를 확인하지 못했습니다. 다시 시도해도 중복 저장되지 않습니다.", retry: true)
    case .paused?:
      return Alert(title: retryTitle, message: "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.", retry: true)
    case .rejected?:
      // 400/415/422 cannot tell a bad input from a temporary link lookup failure.
      return Alert(title: retryTitle, message: "지금 링크 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요. "
        + "계속 실패하면 Instagram·YouTube 링크나 PNG·JPEG·WebP 이미지인지 확인해 주세요.", retry: true)
    case .imageQuota?:
      return Alert(title: "지금은 저장할 수 없어요", message: "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.")
    case .accountChanged?:
      return Alert(title: changedTitle, message: ShareFailure.changedAccount.localizedDescription)
    case .otherEnvironment?:
      return Alert(title: changedTitle, message: "이 초안은 다른 서버 환경에서 전송되었습니다. 같은 서버 환경의 허투루 앱에서 다시 저장해 주세요.")
    case .savedBeforeAccountChange?:
      return Alert(title: changedTitle, message: "전송한 계정의 저장 결과는 보관했습니다. 계정이 변경되어 이 창을 닫아 주세요.")
    case .deleted?:
      return Alert(title: finalTitle, message: "이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요.", discard: true)
    case .mismatch?:
      return Alert(title: finalTitle, message: "이 초안의 저장 정보가 일치하지 않습니다. 다시 공유해 주세요.", discard: true)
    case .tooLarge?:
      return Alert(title: finalTitle, message: "이미지는 10MiB 이하만 저장할 수 있습니다.", discard: true)
    case .missing?:
      return Alert(title: "공유 항목이 없어요", message: "보관 기간이 지났거나 삭제된 초안입니다.")
    case .refused?, .storageFull?, nil:
      // On-device failures before sending, such as reading the kept image or the server setting.
      return Alert(title: retryTitle, message: "지금 저장하지 못했어요. 잠시 후 다시 시도해 주세요.", retry: true)
    }
  }

  /// OS alert over the sheet. [다시 시도] repeats the same request; [닫기] keeps or discards the share.
  private func showAlert(_ content: Alert) {
    guard !completed, !closing else { return }
    let alert = UIAlertController(title: content.title, message: content.message, preferredStyle: .alert)
    if content.retry {
      let retry = UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in self?.save() }
      retry.accessibilityIdentifier = "share.retry"
      alert.addAction(retry)
    }
    let close = UIAlertAction(title: "닫기", style: .cancel) { [weak self] _ in
      guard let self else { return }
      if content.discard, let draftId = self.draftId { try? self.store?.discard(draftId) }
      self.dismissSheet()
    }
    close.accessibilityIdentifier = "share.close"
    alert.addAction(close)
    present(alert, animated: true)
  }

  private func complete() {
    guard !completed else { return }
    completed = true
    extensionContext?.completeRequest(returningItems: nil)
  }

  private static func bottomGap(_ item: UIView, container: UIView, view: UIView) -> [NSLayoutConstraint] {
    let figma = item.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32)
    figma.priority = .defaultLow
    return [figma,
      item.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -32),
      item.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)]
  }

  /// Pretendard with Figma's -2.5% tracking, scaled for the user's text size.
  private static func text(_ value: String, font name: String, size: CGFloat, color: UIColor) -> NSAttributedString {
    let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: name.hasSuffix("SemiBold") ? .semibold : .medium)
    let font = UIFontMetrics.default.scaledFont(for: base)
    return NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color, .kern: -0.025 * font.pointSize])
  }
}
