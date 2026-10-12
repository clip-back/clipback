import XCTest
import Security
import UIKit
@testable import Runner

final class MemoryShareVault: ShareCredentialVault {
  var value: ShareCredential?
  var fails = false
  func read() throws -> ShareCredential? { value }
  func write(_ credential: ShareCredential) throws {
    if fails { throw ShareFailure.message("test storage failure") }
    value = credential
  }
}

final class ShareStoreTests: XCTestCase {
  private var folder: URL!
  private var vault: MemoryShareVault!
  private var store: ShareStore!
  private let base = "https://test.invalid/api/v1"
  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    vault = MemoryShareVault()
    store = try ShareStore(directory: folder, vault: vault, apiBaseUrl: base)
  }
  override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }
  private func credential(_ revision: Int, user: String = "7", session: String = "11", offset: TimeInterval = 3600) -> ShareCredential {
    ShareCredential(revision: revision, token: "test-only", expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(offset)),
      userId: user, sessionId: session, accountLabel: "테스트 계정", apiBaseUrl: base)
  }
  func testDurableRevisionRejectsLateAccountAndOlderExpiry() throws {
    let revision = try store.blockCredential()
    XCTAssertTrue(try store.publish(credential(revision)))
    XCTAssertFalse(try store.publish(credential(revision, offset: 60)))
    let next = try store.blockCredential()
    XCTAssertNil(try store.currentCredential())
    XCTAssertFalse(try store.publish(credential(revision)))
    let reopened = try ShareStore(directory: folder, vault: vault, apiBaseUrl: base)
    XCTAssertEqual(try reopened.getState()["revision"] as? Int, next)
    XCTAssertNil(try reopened.currentCredential())
    XCTAssertTrue(try reopened.publish(credential(next, user: "8", session: "12")))
  }
  func testVaultFailureDoesNotUnblockCredential() throws {
    let revision = try store.blockCredential()
    vault.fails = true
    XCTAssertThrowsError(try store.publish(credential(revision)))
    XCTAssertNil(try store.currentCredential())
  }
  func testSubmittedDraftKeepsIdentityAndOriginalAccountAcrossReopen() throws {
    let revision = try store.blockCredential()
    let value = credential(revision)
    XCTAssertTrue(try store.publish(value))
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let submitted = try store.begin(draft.id, expected: value).0
    try store.mark(draft.id, state: "unknown")
    let reopened = try ShareStore(directory: folder, vault: vault, apiBaseUrl: base)
    XCTAssertEqual(try reopened.begin(draft.id, expected: value).0.id, submitted.id)
    let next = try store.blockCredential()
    let other = credential(next, user: "8", session: "12")
    XCTAssertTrue(try store.publish(other))
    XCTAssertThrowsError(try store.begin(draft.id, expected: other))
    XCTAssertThrowsError(try store.begin(draft.id, expected: value))
    XCTAssertEqual(try store.draft(draft.id)?.userId, "7")
  }
  func testCompletionReceiptPersistsUntilAcknowledgedWithoutDraftReplay() throws {
    let revision = try store.blockCredential()
    let value = credential(revision)
    XCTAssertTrue(try store.publish(value))
    let draft = try store.createLink("https://www.instagram.com/p/fixture/")
    let submitted = try store.begin(draft.id, expected: value).0
    try store.complete(submitted, contentId: "42")
    XCTAssertNil(try store.draft(draft.id))
    let state = try store.getState()
    XCTAssertEqual((state["receipts"] as? [[String: Any]])?.first?["contentId"] as? Int, 42)
    try store.acknowledge([draft.id])
    XCTAssertTrue((try store.getState()["receipts"] as? [[String: Any]])!.isEmpty)
  }
  func testUnsupportedAndCapacityDoNotEvictExistingDrafts() throws {
    XCTAssertThrowsError(try store.createLink("https://example.com/private"))
    XCTAssertThrowsError(try store.createLink("https://name:password@youtu.be/dQw4w9WgXcQ"))
    XCTAssertThrowsError(try store.createLink("https://youtu.be:1234/dQw4w9WgXcQ"))
    XCTAssertThrowsError(try store.createLink("https://youtu.be/dQw4w9WgXcQ https://youtu.be/other"))
    XCTAssertThrowsError(try store.createImage(Data("not an image".utf8)))
    let first = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    for _ in 1..<10 { _ = try store.createLink("https://youtu.be/dQw4w9WgXcQ") }
    XCTAssertThrowsError(try store.createLink("https://youtu.be/dQw4w9WgXcQ"))
    XCTAssertNotNil(try store.draft(first.id))
  }
  func testOldUnauthorizedCannotBlockNewlyPublishedCredential() throws {
    let revision = try store.blockCredential()
    let old = credential(revision)
    XCTAssertTrue(try store.publish(old))
    let refreshed = ShareCredential(revision: revision, token: "new-share-token", expiresAt: old.expiresAt,
      userId: old.userId, sessionId: old.sessionId, accountLabel: old.accountLabel, apiBaseUrl: old.apiBaseUrl)
    XCTAssertTrue(try store.publish(refreshed))
    try store.rejectCredential(old)
    XCTAssertEqual(try store.currentCredential()?.token, "new-share-token")
    try store.rejectCredential(refreshed)
    XCTAssertNil(try store.currentCredential())
    XCTAssertEqual(try store.getState()["revision"] as? Int, revision + 1)
  }
  func testSubmittedDraftAndReceiptStayInOriginalEnvironment() throws {
    let revision = try store.blockCredential()
    let original = credential(revision)
    XCTAssertTrue(try store.publish(original))
    let first = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let second = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let firstSent = try store.begin(first.id, expected: original).0
    _ = try store.begin(second.id, expected: original)
    try store.complete(firstSent, contentId: "42")
    let otherBase = "https://other.invalid/api/v1"
    let otherStore = try ShareStore(directory: folder, vault: vault, apiBaseUrl: otherBase)
    let next = try otherStore.blockCredential()
    let other = ShareCredential(revision: next, token: "other-environment-token", expiresAt: original.expiresAt,
      userId: original.userId, sessionId: original.sessionId, accountLabel: original.accountLabel, apiBaseUrl: otherBase)
    XCTAssertTrue(try otherStore.publish(other))
    XCTAssertThrowsError(try otherStore.begin(second.id, expected: other))
    XCTAssertTrue((try otherStore.getState()["receipts"] as? [[String: Any]])!.isEmpty)
    XCTAssertEqual((try store.getState()["receipts"] as? [[String: Any]])?.count, 1)
  }
  func testSharedKeychainGroupRoundTrip() throws {
    let group = try XCTUnwrap(ShareConfiguration.keychainGroup)
    let account = "test-\(UUID().uuidString)"
    let keychain = ShareKeychain(group: group, account: account)
    defer {
      SecItemDelete([kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.huturu.app.share", kSecAttrAccount as String: account,
        kSecAttrAccessGroup as String: group] as CFDictionary)
    }
    try keychain.write(credential(1))
    XCTAssertEqual(try keychain.read()?.userId, "7")
    XCTAssertEqual(try keychain.read()?.revision, 1)
  }
  func testWrongEnvironmentCannotPublishOrRead() throws {
    let revision = try store.blockCredential()
    XCTAssertTrue(try store.publish(credential(revision)))
    let other = try ShareStore(directory: folder, vault: vault, apiBaseUrl: "https://other.invalid/api/v1")
    XCTAssertNil(try other.currentCredential())
    XCTAssertFalse(try other.publish(credential(revision)))
  }
  func testReopenRemovesOnlyUnreferencedOwnedImages() throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
      UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    let kept = try store.createImage(image)
    let orphan = store.directory.appendingPathComponent("\(UUID().uuidString.lowercased()).png")
    let unrelated = store.directory.appendingPathComponent("unrelated.png")
    try image.write(to: orphan)
    try image.write(to: unrelated)
    let reopened = try ShareStore(directory: folder, vault: vault, apiBaseUrl: base)
    _ = try reopened.getState()
    XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(store.imageURL(kept)).path))
  }
  func testSafariDuplicateURLProvidersNormalizeToOneLink() throws {
    let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
    let providers = [NSItemProvider(object: url as NSURL), NSItemProvider(object: url as NSURL)]
    XCTAssertTrue(ShareInputNormalizer.isURLPayload(providers))
    XCTAssertEqual(try ShareInputNormalizer.singleURL([url, url]), url.absoluteString)
    let mobile = URL(string: "https://m.youtube.com/watch?v=dQw4w9WgXcQ&ra=m")!
    XCTAssertEqual(try ShareInputNormalizer.singleURL([url, mobile]), url.absoluteString)
    XCTAssertEqual(try ShareInputNormalizer.singleURL([mobile, url]), mobile.absoluteString)
    XCTAssertThrowsError(try ShareInputNormalizer.singleURL([url, URL(string: "https://m.youtube.com/watch?v=aaaaaaaaaaa&ra=m")!]))
    XCTAssertThrowsError(try ShareInputNormalizer.singleURL([url, URL(string: "https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=20")!]))
    XCTAssertThrowsError(try ShareInputNormalizer.singleURL([url, URL(string: "https://evil.test/watch?v=dQw4w9WgXcQ")!]))
    XCTAssertThrowsError(try ShareInputNormalizer.singleURL([url, URL(string: "https://youtu.be/another")!]))
    XCTAssertThrowsError(try ShareInputNormalizer.singleURL([URL(fileURLWithPath: "/private/tmp/metadata")]))
    XCTAssertFalse(ShareInputNormalizer.isURLPayload([providers[0], NSItemProvider(object: UIImage())]))
    XCTAssertFalse(ShareInputNormalizer.isURLPayload([NSItemProvider(object: UIImage()), NSItemProvider(object: UIImage())]))
    XCTAssertFalse(ShareInputNormalizer.isURLPayload([providers[0], NSItemProvider(object: "another link" as NSString)]))
  }
}
