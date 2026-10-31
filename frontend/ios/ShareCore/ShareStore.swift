import Darwin
import Foundation
import ImageIO
import Security

protocol ShareCredentialVault {
  func read() throws -> ShareCredential?
  func write(_ credential: ShareCredential) throws
}

struct ShareKeychain: ShareCredentialVault {
  let group: String?
  var account = "credential"
  private var query: [String: Any] {
    var value: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.huturu.app.share", kSecAttrAccount as String: account]
    if let group, !group.isEmpty { value[kSecAttrAccessGroup as String] = group }
    return value
  }
  func read() throws -> ShareCredential? {
    var query = query
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw ShareFailure.classified(.authentication, "공유 인증 저장소를 읽을 수 없습니다. 앱에서 다시 시도해 주세요.")
    }
    return try JSONDecoder().decode(ShareCredential.self, from: data)
  }
  func write(_ credential: ShareCredential) throws {
    let data = try JSONEncoder().encode(credential)
    let values: [String: Any] = [kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw ShareFailure.message("공유 인증을 저장할 수 없습니다. 앱에서 다시 시도해 주세요.")
    }
  }
}

/// Every app/extension transaction holds the same cross-process lock. The disk revision is
/// authoritative: an old Keychain value cannot make a blocked account ready again.
final class ShareStore {
  let directory: URL
  private let vault: ShareCredentialVault
  private let expectedBaseURL: String
  private let processLock = NSRecursiveLock()
  static let maxImageBytes = 10 * 1024 * 1024

  init(directory: URL? = nil, vault: ShareCredentialVault? = nil,
       apiBaseUrl: String = ShareConfiguration.apiBaseUrl) throws {
    guard let directory = directory ?? FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: ShareConfiguration.group) else {
      throw ShareFailure.message("공유 저장소를 열 수 없습니다. 앱 설정을 확인해 주세요.")
    }
    self.directory = directory.appendingPathComponent("ShareIntake", isDirectory: true)
    self.vault = vault ?? ShareKeychain(group: ShareConfiguration.keychainGroup)
    expectedBaseURL = apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
  }

  private func transaction<T>(_ body: (inout ShareDiskState) throws -> T) throws -> T {
    processLock.lock()
    defer { processLock.unlock() }
    let fd = open(directory.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { throw ShareFailure.message("공유 저장소를 잠글 수 없습니다.") }
    defer { close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw ShareFailure.message("공유 저장소를 잠글 수 없습니다.") }
    defer { flock(fd, LOCK_UN) }
    let url = directory.appendingPathComponent("state.json")
    var state = ShareDiskState()
    if FileManager.default.fileExists(atPath: url.path) {
      state = try JSONDecoder().decode(ShareDiskState.self, from: Data(contentsOf: url))
    } else if let retained = try vault.read() {
      // Keychain can survive app removal while the App Group does not. Never reuse its revision.
      state.revision = retained.revision + 1
    }
    try removeUnreferencedImages(state)
    let previousDrafts = state.drafts
    let result = try body(&state)
    try JSONEncoder().encode(state).write(to: url, options: .atomic)
    previousDrafts.filter { previous in !state.drafts.contains { $0.id == previous.id } }.forEach(removeImage)
    return result
  }

  private func removeUnreferencedImages(_ state: ShareDiskState) throws {
    // A process can exit after writing an image but before atomically recording its draft.
    // Only this store's UUID image filenames are eligible, under the same cross-process lock.
    let referenced = Set(state.drafts.compactMap(\.imageName))
    let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
    for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) {
      guard ["png", "jpg", "webp"].contains(file.pathExtension),
            UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
            !referenced.contains(file.lastPathComponent) else { continue }
      let values = try file.resourceValues(forKeys: keys)
      guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
      try FileManager.default.removeItem(at: file)
    }
  }

  private func credential(_ state: ShareDiskState) throws -> ShareCredential? {
    guard !state.blocked, let value = try vault.read(), value.revision == state.revision,
          value.apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == expectedBaseURL,
          !expectedBaseURL.isEmpty, value.isValid else { return nil }
    return value
  }

  func blockCredential() throws -> Int {
    try transaction { state in
      state.revision += 1
      state.blocked = true
      return state.revision
    }
  }

  func rejectCredential(_ rejected: ShareCredential) throws {
    try transaction { state in
      guard state.revision == rejected.revision, !state.blocked,
            let current = try vault.read(), current.revision == rejected.revision,
            current.token == rejected.token else { return }
      state.revision += 1
      state.blocked = true
    }
  }

  func publish(_ incoming: ShareCredential) throws -> Bool {
    try transaction { state in
      guard incoming.revision == state.revision, incoming.isValid,
            incoming.apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == expectedBaseURL,
            !expectedBaseURL.isEmpty else { return false }
      if let current = try vault.read(), current.revision == incoming.revision {
        guard current.userId == incoming.userId, current.sessionId == incoming.sessionId,
              (incoming.expiry ?? .distantPast) >= (current.expiry ?? .distantPast) else { return false }
      }
      try vault.write(incoming)
      state.blocked = false
      return true
    }
  }

  func getState() throws -> [String: Any] {
    try transaction { state in
      expire(&state)
      return ["revision": state.revision, "credential": try credential(state)?.publicValue ?? NSNull(),
        "drafts": state.drafts.map(\.publicValue), "receipts": state.receipts.filter { $0.apiBaseUrl == expectedBaseURL }.map(\.publicValue)]
    }
  }
  func currentCredential() throws -> ShareCredential? { try transaction { try credential($0) } }
  /// The account a kept share would save to. nil is login required, including an unreadable Keychain credential (Q9②);
  /// other errors are App Group lock or state file failures (Q9③).
  func savingCredential() throws -> ShareCredential? {
    do { return try currentCredential() }
    catch let failure as ShareFailure where failure.kind == .authentication { return nil }
  }
  func draft(_ id: String) throws -> ShareDraft? {
    try transaction { state in expire(&state); return state.drafts.first { $0.id == id } }
  }
  func imageURL(_ draft: ShareDraft) -> URL? {
    guard let name = draft.imageName, UUID(uuidString: draft.id) != nil,
          ["png", "jpg", "webp"].contains(where: { name == "\(draft.id).\($0)" }) else { return nil }
    return directory.appendingPathComponent(name)
  }

  func createLink(_ text: String) throws -> ShareDraft {
    guard text.count <= 5000 else { throw ShareFailure.refused(.textTooLong) }
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
      throw ShareFailure.refused(.other)
    }
    let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
    let urls = matches.compactMap(\.url).filter { ["https", "http"].contains($0.scheme?.lowercased() ?? "") }
    guard let url = urls.first else { throw ShareFailure.refused(.noLink) }
    guard urls.count == 1 else { throw ShareFailure.refused(.multipleLinks) }
    guard url.absoluteString.count <= 2048, Self.supportedHost(url.host), url.user == nil, url.password == nil,
          url.port == nil || url.port == (url.scheme?.lowercased() == "https" ? 443 : 80) else {
      throw ShareFailure.refused(.unsupportedLink)
    }
    let draft = ShareDraft(id: UUID().uuidString.lowercased(), kind: "link", label: url.absoluteString,
      createdAt: Date(), url: url.absoluteString, rawText: text, byteCount: text.utf8.count, state: "pending")
    return try insert(draft, image: nil)
  }
  static func supportedHost(_ host: String?) -> Bool {
    let host = host?.lowercased() ?? ""
    return host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be"
      || ["instagram.com", "www.instagram.com", "m.instagram.com"].contains(host)
  }

  func createImage(fileURL: URL) throws -> ShareDraft {
    var data = Data()
    do {
      let file = try FileHandle(forReadingFrom: fileURL)
      defer { try? file.close() }
      while let chunk = try file.read(upToCount: min(64 * 1024, Self.maxImageBytes + 1 - data.count)), !chunk.isEmpty {
        data.append(chunk)
        guard data.count <= Self.maxImageBytes else { throw ShareFailure.fileTooLarge }
      }
    } catch let failure as ShareFailure { throw failure }
    catch { throw ShareFailure.refused(.imageUnreadable) }
    return try createImage(data)
  }

  func createImage(_ data: Data) throws -> ShareDraft {
    guard data.count <= Self.maxImageBytes else { throw ShareFailure.fileTooLarge }
    guard !data.isEmpty,
          let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(imageSource) == 1 else { throw ShareFailure.refused(.imageFile) }
    let header = [UInt8](data.prefix(12))
    let mime: String
    let ext: String
    if header.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) { mime = "image/png"; ext = "png" }
    else if header.starts(with: [255, 216, 255]) { mime = "image/jpeg"; ext = "jpg" }
    else if header.count == 12, String(bytes: header[0..<4], encoding: .ascii) == "RIFF",
            String(bytes: header[8..<12], encoding: .ascii) == "WEBP" { mime = "image/webp"; ext = "webp" }
    else { throw ShareFailure.refused(.imageFormat) }
    let id = UUID().uuidString.lowercased()
    let draft = ShareDraft(id: id, kind: "image", label: "공유한 이미지", createdAt: Date(),
      imageName: "\(id).\(ext)", mimeType: mime, byteCount: data.count, state: "pending")
    do { return try insert(draft, image: data) }
    catch { removeImage(draft); throw error }
  }

  private func insert(_ draft: ShareDraft, image: Data?) throws -> ShareDraft {
    try transaction { state in
      expire(&state)
      guard state.drafts.count < 10,
            state.drafts.reduce(0, { $0 + $1.byteCount }) + draft.byteCount <= 100 * 1024 * 1024 else {
        throw ShareFailure.classified(.storageFull, "보관 가능한 초안이 가득 찼습니다. 앱에서 대기 항목을 저장하거나 삭제해 주세요.")
      }
      if let image, let url = imageURL(draft) { try image.write(to: url, options: .atomic) }
      state.drafts.append(draft)
      return draft
    }
  }

  func begin(_ id: String, expected: ShareCredential) throws -> (ShareDraft, ShareCredential) {
    try transaction { state in
      guard let current = try credential(state) else { throw ShareFailure.authentication }
      guard current.revision == expected.revision, current.userId == expected.userId,
            current.sessionId == expected.sessionId else { throw ShareFailure.changedAccount }
      guard let index = state.drafts.firstIndex(where: { $0.id == id }) else {
        throw ShareFailure.classified(.missing, "보관 기간이 지났거나 삭제된 초안입니다.")
      }
      if let userId = state.drafts[index].userId, userId != current.userId { throw ShareFailure.changedAccount }
      if let base = state.drafts[index].apiBaseUrl, base != expectedBaseURL {
        throw ShareFailure.classified(.otherEnvironment, "이 초안은 다른 서버 환경에서 전송되었습니다. 같은 서버 환경에서 다시 시도해 주세요.")
      }
      state.drafts[index].apiBaseUrl = expectedBaseURL
      state.drafts[index].userId = current.userId
      state.drafts[index].state = "sending"
      return (state.drafts[index], current)
    }
  }
  func mark(_ id: String, state newState: String) throws {
    try transaction { state in
      if let index = state.drafts.firstIndex(where: { $0.id == id }) { state.drafts[index].state = newState }
    }
  }
  func complete(_ draft: ShareDraft, contentId: String) throws {
    guard let userId = draft.userId, let apiBaseUrl = draft.apiBaseUrl else { throw ShareFailure.changedAccount }
    try transaction { state in
      state.receipts.removeAll { $0.id == draft.id }
      state.receipts.append(ShareReceipt(id: draft.id, userId: userId, contentId: contentId, apiBaseUrl: apiBaseUrl))
      state.drafts.removeAll { $0.id == draft.id }
    }
    removeImage(draft)
  }
  func discard(_ id: String) throws {
    let removed: ShareDraft? = try transaction { state in
      let draft = state.drafts.first { $0.id == id }
      state.drafts.removeAll { $0.id == id }
      return draft
    }
    if let removed { removeImage(removed) }
  }
  func acknowledge(_ ids: [String]) throws {
    try transaction { state in state.receipts.removeAll { ids.contains($0.id) && $0.apiBaseUrl == expectedBaseURL } }
  }
  private func expire(_ state: inout ShareDiskState) {
    let expired = state.drafts.filter { Date().timeIntervalSince($0.createdAt) > 7 * 24 * 60 * 60 }
    state.drafts.removeAll { draft in expired.contains { $0.id == draft.id } }
  }
  private func removeImage(_ draft: ShareDraft) {
    if let url = imageURL(draft) { try? FileManager.default.removeItem(at: url) }
  }
}
