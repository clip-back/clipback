import XCTest
@testable import Runner

private final class ShareResponseProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, Data))!
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let (status, data) = try Self.handler(request)
      let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}

final class ShareSaveServiceTests: XCTestCase {
  private var folder: URL!
  private var store: ShareStore!
  private var credential: ShareCredential!
  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    store = try ShareStore(directory: folder, vault: MemoryShareVault(), apiBaseUrl: "https://test.invalid/api/v1")
    let revision = try store.blockCredential()
    credential = ShareCredential(revision: revision, token: "test-only-share-token",
      expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)), userId: "7", sessionId: "11",
      accountLabel: "테스트 계정", apiBaseUrl: "https://test.invalid/api/v1")
    XCTAssertTrue(try store.publish(credential))
  }
  override func tearDownWithError() throws {
    ShareResponseProtocol.handler = nil
    try FileManager.default.removeItem(at: folder)
  }
  private func body(_ request: URLRequest) throws -> Data {
    if let data = request.httpBody { return data }
    let stream = try XCTUnwrap(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while true {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count == 0 { return data }
      guard count > 0 else { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
      data.append(buffer, count: count)
    }
  }
  private func service() -> ShareSaveService {
    ShareSaveService(store: store) {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [ShareResponseProtocol.self]
      return config
    }
  }
  func testResponseLossRetriesSameDraftKeyAndPersistsReceipt() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let first = service()
    ShareResponseProtocol.handler = { request in
      XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), draft.id)
      XCTAssertEqual(request.url?.path, "/api/v1/contents/share")
      XCTAssertEqual(try self.body(request), try JSONSerialization.data(withJSONObject: [
        "url": "https://youtu.be/dQw4w9WgXcQ", "raw_text": "https://youtu.be/dQw4w9WgXcQ"], options: .sortedKeys))
      throw URLError(.timedOut)
    }
    let failed = expectation(description: "response lost")
    first.save(draft.id, expected: credential) { result in
      if case .success = result { XCTFail("Unconfirmed result must not be success") }
      failed.fulfill()
    }
    wait(for: [failed], timeout: 5)
    XCTAssertEqual(try store.draft(draft.id)?.state, "unknown")
    XCTAssertEqual(try store.draft(draft.id)?.userId, "7")
    ShareResponseProtocol.handler = { request in
      XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), draft.id)
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-share-token")
      return (201, Data("{\"id\":42}".utf8))
    }
    let second = service()
    let saved = expectation(description: "same operation confirmed")
    second.save(draft.id, expected: credential) { result in
      XCTAssertEqual(try? result.get(), "42")
      saved.fulfill()
    }
    wait(for: [saved], timeout: 5)
    XCTAssertNil(try store.draft(draft.id))
    XCTAssertEqual((try store.getState()["receipts"] as? [[String: Any]])?.count, 1)
  }
  func testUnauthorizedPreservesDraftAndBlocksOnlySharingCredential() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    ShareResponseProtocol.handler = { _ in (401, Data()) }
    let service = service()
    let finished = expectation(description: "needs main app authentication")
    service.save(draft.id, expected: credential) { result in
      if case .success = result { XCTFail("401 cannot succeed") }
      finished.fulfill()
    }
    wait(for: [finished], timeout: 5)
    XCTAssertEqual(try store.draft(draft.id)?.state, "authRequired")
    XCTAssertNil(try store.currentCredential())
  }
  func testInFlightCompletionStaysWithOriginalAccountAfterSwitch() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let received = expectation(description: "request already sent")
    let releaseResponse = DispatchSemaphore(value: 0)
    ShareResponseProtocol.handler = { _ in
      received.fulfill()
      _ = releaseResponse.wait(timeout: .now() + 5)
      return (201, Data("{\"id\":42}".utf8))
    }
    let service = service()
    let finished = expectation(description: "old account result retained")
    service.save(draft.id, expected: credential) { result in
      if case .success = result { XCTFail("Do not display old-account success in a new account") }
      finished.fulfill()
    }
    wait(for: [received], timeout: 5)
    let revision = try store.blockCredential()
    let other = ShareCredential(revision: revision, token: "other-test-token", expiresAt: credential.expiresAt,
      userId: "8", sessionId: "12", accountLabel: "다른 계정", apiBaseUrl: credential.apiBaseUrl)
    XCTAssertTrue(try store.publish(other))
    releaseResponse.signal()
    wait(for: [finished], timeout: 5)
    let receipts = try store.getState()["receipts"] as? [[String: Any]]
    XCTAssertEqual(receipts?.first?["userId"] as? Int, 7)
    XCTAssertNil(try store.draft(draft.id))
    XCTAssertEqual(try store.currentCredential()?.userId, "8")
  }
  func testBlockedAccountNeverSubmitsRequest() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    _ = try store.blockCredential()
    ShareResponseProtocol.handler = { _ in XCTFail("Old account must not send"); return (201, Data("{\"id\":42}".utf8)) }
    let service = service()
    let finished = expectation(description: "rejected before send")
    service.save(draft.id, expected: credential) { result in
      if case .success = result { XCTFail("Blocked credentials cannot save") }
      finished.fulfill()
    }
    wait(for: [finished], timeout: 5)
    XCTAssertNil(try store.draft(draft.id)?.userId)
  }
  func testMalformedSuccessPreservesUnknownResultForRetry() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    ShareResponseProtocol.handler = { _ in (201, Data("not-json".utf8)) }
    let service = service()
    let finished = expectation(description: "unreadable successful response")
    service.save(draft.id, expected: credential) { result in
      if case .success = result { XCTFail("Malformed response cannot confirm completion") }
      finished.fulfill()
    }
    wait(for: [finished], timeout: 5)
    XCTAssertEqual(try store.draft(draft.id)?.state, "unknown")
    XCTAssertEqual(try store.draft(draft.id)?.userId, "7")
  }
}
