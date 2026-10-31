import Foundation
import UniformTypeIdentifiers

enum ShareInputNormalizer {
  static func isURLPayload(_ providers: [NSItemProvider]) -> Bool {
    !providers.isEmpty && providers.count <= 10 && providers.allSatisfy {
      $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        && !$0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
    }
  }

  static func singleURL(_ urls: [URL]) throws -> String {
    guard let first = urls.first,
          urls.allSatisfy({ ["https", "http"].contains($0.scheme?.lowercased() ?? "") }) else {
      throw ShareFailure.refused(.unsupportedLink)
    }
    guard urls.allSatisfy({ $0 == first || sameYouTubePage(first, $0) }) else { throw ShareFailure.refused(.multipleLinks) }
    return first.absoluteString
  }

  private static func sameYouTubePage(_ first: URL, _ second: URL) -> Bool {
    func page(_ url: URL) -> String? {
      guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
            ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(parts.host?.lowercased() ?? ""),
            parts.user == nil, parts.password == nil, parts.port == nil, parts.path == "/watch" else { return nil }
      let query = parts.queryItems ?? []
      let ids = query.filter { $0.name == "v" }.compactMap(\.value)
      guard ids.count == 1, ids[0].range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
      // Safari supplies the web page plus its mobile URL. Only its known routing hint is ignored.
      parts.host = "youtube.com"
      parts.queryItems = query.filter { !($0.name == "ra" && $0.value == "m") }.sorted {
        ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "")
      }
      return parts.string
    }
    guard let left = page(first), let right = page(second) else { return false }
    return left == right
  }
}

struct ShareCredential: Codable {
  let revision: Int
  let token: String
  let expiresAt: String
  let userId: String
  let sessionId: String
  let accountLabel: String
  let apiBaseUrl: String

  var expiry: Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt)
  }
  var isValid: Bool { (expiry ?? .distantPast) > Date() }
  var publicValue: [String: Any] {
    ["expiresAt": expiresAt, "userId": Int(userId) ?? 0, "sessionId": Int(sessionId) ?? 0,
     "accountLabel": accountLabel, "apiBaseUrl": apiBaseUrl]
  }
}

struct ShareDraft: Codable {
  let id: String
  let kind: String
  let label: String
  let createdAt: Date
  var url: String?
  var rawText: String?
  var imageName: String?
  var mimeType: String?
  var byteCount: Int
  var state: String
  var userId: String?
  var apiBaseUrl: String?

  var publicValue: [String: Any] {
    var value: [String: Any] = ["id": id, "kind": kind, "label": label, "state": state]
    if let userId { value["userId"] = Int(userId) }
    return value
  }
}

struct ShareReceipt: Codable {
  let id: String
  let userId: String
  let contentId: String
  let apiBaseUrl: String
  var publicValue: [String: Any] { ["id": id, "userId": Int(userId) ?? 0, "contentId": Int(contentId) ?? 0] }
}

struct ShareDiskState: Codable {
  var revision = 0
  var blocked = true
  var drafts: [ShareDraft] = []
  var receipts: [ShareReceipt] = []
}

/// Why a share was not accepted; the share save sheet words each reason.
enum ShareRefusal {
  case notSingle, textTooLong, noLink, multipleLinks, unsupportedLink, imageUnreadable, imageTooLarge, imageFormat, imageFile, other
}

/// The category the share save sheet picks its alert by. The recovery screen keeps showing the existing message.
enum ShareFailureKind: Equatable {
  case refused(ShareRefusal)
  case storageFull
  case authentication
  case unconfirmed, paused, rejected
  case imageQuota
  case accountChanged, otherEnvironment, savedBeforeAccountChange
  case deleted, mismatch, tooLarge
  case missing
}

enum ShareFailure: LocalizedError {
  case message(String)
  case classified(ShareFailureKind, String)
  var errorDescription: String? {
    switch self { case .message(let message), .classified(_, let message): return message }
  }
  var kind: ShareFailureKind? {
    if case .classified(let kind, _) = self { return kind }
    return nil
  }
  static let authentication = ShareFailure.classified(.authentication, "초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요.")
  static let changedAccount = ShareFailure.classified(.accountChanged, "저장 계정이 변경되었습니다. 이 창을 닫고 저장할 계정을 확인해 주세요.")
  static let fileTooLarge = refused(.imageTooLarge)
  static func refused(_ reason: ShareRefusal) -> ShareFailure {
    .classified(.refused(reason), reason == .imageTooLarge ? "이미지는 10MiB 이하만 저장할 수 있습니다."
      : "Instagram·YouTube 링크 하나 또는 PNG·JPEG·WebP 이미지 한 장(10MiB 이하)을 공유해 주세요.")
  }
}

enum ShareConfiguration {
  static let group = "group.com.huturu.app"
  static var apiBaseUrl: String {
    guard let url = Bundle.main.url(forResource: "ShareBuildConfig", withExtension: "plist"),
          let data = try? Data(contentsOf: url),
          let config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
          let value = config["apiBaseUrl"] else { return "" }
    return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }
  static var keychainGroup: String? {
    Bundle.main.object(forInfoDictionaryKey: "ShareKeychainGroup") as? String
  }
}
