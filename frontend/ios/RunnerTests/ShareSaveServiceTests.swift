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
    var kind: ShareFailureKind?
    service.save(draft.id, expected: credential) { result in
      if case .failure(let error) = result { kind = (error as? ShareFailure)?.kind }
      else { XCTFail("Do not display old-account success in a new account") }
      finished.fulfill()
    }
    wait(for: [received], timeout: 5)
    let revision = try store.blockCredential()
    let other = ShareCredential(revision: revision, token: "other-test-token", expiresAt: credential.expiresAt,
      userId: "8", sessionId: "12", accountLabel: "다른 계정", apiBaseUrl: credential.apiBaseUrl)
    XCTAssertTrue(try store.publish(other))
    releaseResponse.signal()
    wait(for: [finished], timeout: 5)
    XCTAssertEqual(kind, .savedBeforeAccountChange)
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
  private func failure(_ id: String, expected: ShareCredential) -> Error? {
    let finished = expectation(description: "save \(id)")
    var failure: Error?
    service().save(id, expected: expected) { result in
      if case .failure(let error) = result { failure = error }
      finished.fulfill()
    }
    wait(for: [finished], timeout: 5)
    return failure
  }
  /// The share save sheet picks its alert by category; the recovery screen keeps each existing message.
  func testFailureCategoriesKeepExistingMessagesAndStates() throws {
    let unconfirmed = "저장 결과를 확인하지 못했습니다. 같은 초안으로 다시 시도해 주세요."
    let rejected = "저장하지 못했습니다. 지원하는 링크·이미지인지 확인한 뒤 다시 시도해 주세요."
    let cases: [(Int?, String, ShareFailureKind, String, String)] = [
      (nil, "", .unconfirmed, "저장 결과를 확인하지 못했습니다. 같은 초안으로 다시 시도하면 중복 저장되지 않습니다.", "unknown"),
      (500, "{}", .unconfirmed, unconfirmed, "unknown"),
      (201, "not-json", .unconfirmed, unconfirmed, "unknown"),
      (400, "{}", .rejected, rejected, "failed"),
      (415, "{}", .rejected, rejected, "failed"),
      (422, "{}", .rejected, rejected, "failed"),
      (403, "{}", .rejected, rejected, "failed"),
      (429, "{}", .rejected, rejected, "failed"),
      (409, "{\"detail\":{\"code\":\"image_uploads_paused\"}}", .paused, "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.", "failed"),
      (409, "{\"detail\":{\"code\":\"image_quota_exceeded\"}}", .imageQuota, "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.", "failed"),
      (410, "{}", .deleted, "이미 저장한 뒤 삭제한 콘텐츠입니다. 이 초안을 삭제한 뒤 새로 공유해 주세요.", "failed"),
      (409, "{\"detail\":\"공유 입력이 달라졌어요.\"}", .mismatch, "이 초안의 저장 정보가 일치하지 않습니다. 초안을 삭제한 뒤 다시 공유해 주세요.", "failed"),
      (413, "{\"detail\":{\"code\":\"image_file_too_large\"}}", .tooLarge, "이미지는 10MiB 이하만 저장할 수 있습니다.", "failed"),
      // Last: a 401 blocks the sharing credential for every later save.
      (401, "{}", .authentication, "초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요.", "authRequired")
    ]
    for (status, body, kind, message, state) in cases {
      let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
      ShareResponseProtocol.handler = { _ in
        guard let status else { throw URLError(.networkConnectionLost) }
        return (status, Data(body.utf8))
      }
      let error = try XCTUnwrap(failure(draft.id, expected: credential), "\(String(describing: status))")
      XCTAssertEqual((error as? ShareFailure)?.kind, kind, "\(String(describing: status))")
      XCTAssertEqual(error.localizedDescription, message)
      XCTAssertEqual(try store.draft(draft.id)?.state, state)
      try store.discard(draft.id)
    }
  }
  func testAccountSwitchBeforeSendKeepsDraftUnsent() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let other = ShareCredential(revision: try store.blockCredential(), token: "other-test-token", expiresAt: credential.expiresAt,
      userId: "8", sessionId: "12", accountLabel: "다른 계정", apiBaseUrl: credential.apiBaseUrl)
    XCTAssertTrue(try store.publish(other))
    ShareResponseProtocol.handler = { _ in XCTFail("A switched account must not send"); return (201, Data("{\"id\":42}".utf8)) }
    XCTAssertEqual((failure(draft.id, expected: credential) as? ShareFailure)?.kind, .accountChanged)
    XCTAssertNotNil(try store.draft(draft.id))
    XCTAssertNil(try store.draft(draft.id)?.userId)
  }
  func testAccountSwitchAfterFailedSendKeepsDraftAndNeverSendsWithNewAccount() throws {
    let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
    let received = expectation(description: "request already sent")
    let releaseResponse = DispatchSemaphore(value: 0)
    ShareResponseProtocol.handler = { _ in
      received.fulfill()
      _ = releaseResponse.wait(timeout: .now() + 5)
      return (500, Data("{}".utf8))
    }
    let finished = expectation(description: "failed after switch")
    var kind: ShareFailureKind?
    service().save(draft.id, expected: credential) { result in
      if case .failure(let error) = result { kind = (error as? ShareFailure)?.kind }
      finished.fulfill()
    }
    wait(for: [received], timeout: 5)
    let other = ShareCredential(revision: try store.blockCredential(), token: "other-test-token", expiresAt: credential.expiresAt,
      userId: "8", sessionId: "12", accountLabel: "다른 계정", apiBaseUrl: credential.apiBaseUrl)
    XCTAssertTrue(try store.publish(other))
    releaseResponse.signal()
    wait(for: [finished], timeout: 5)
    XCTAssertEqual(kind, .unconfirmed)
    XCTAssertEqual(try store.draft(draft.id)?.userId, "7")
    // Retrying the kept share, with either account, never reaches the server for the new account.
    ShareResponseProtocol.handler = { _ in XCTFail("A switched account must not send"); return (201, Data("{\"id\":42}".utf8)) }
    XCTAssertEqual((failure(draft.id, expected: credential) as? ShareFailure)?.kind, .accountChanged)
    XCTAssertEqual((failure(draft.id, expected: other) as? ShareFailure)?.kind, .accountChanged)
    XCTAssertEqual(try store.draft(draft.id)?.userId, "7")
  }
  func testQuotaAndFileSizeErrorsKeepDraftAndAuthenticationWithSpecificMessages() throws {
    for (status, detail, message) in [
      (409, "{\"code\":\"image_uploads_paused\"}", "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요."),
      (409, "{\"code\":\"image_quota_exceeded\"}", "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요."),
      (413, "{\"code\":\"image_file_too_large\"}", "이미지는 10MiB 이하만 저장할 수 있습니다.")
    ] {
      let draft = try store.createLink("https://youtu.be/dQw4w9WgXcQ")
      ShareResponseProtocol.handler = { _ in (status, Data("{\"detail\":\(detail)}".utf8)) }
      let saving = service()
      let finished = expectation(description: "specific image error \(status)")
      saving.save(draft.id, expected: credential) { result in
        if case .failure(let error) = result { XCTAssertEqual(error.localizedDescription, message) }
        else { XCTFail("An image limit rejection cannot succeed") }
        finished.fulfill()
      }
      wait(for: [finished], timeout: 5)
      XCTAssertEqual(try store.draft(draft.id)?.state, "failed")
      XCTAssertNotNil(try store.currentCredential())
    }
  }
}
