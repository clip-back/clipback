import XCTest

final class ShareUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  private func tapReady(_ element: XCUIElement) {
    var lastFrame = CGRect.null
    var stableSince = Date()
    let ready = NSPredicate { _, _ in
      guard element.exists, element.isHittable else { stableSince = Date(); return false }
      let frame = element.frame
      if frame != lastFrame { lastFrame = frame; stableSince = Date(); return false }
      return Date().timeIntervalSince(stableSince) >= 0.7
    }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: element)], timeout: 8), .completed)
    element.tap()
  }
  private func openShare(_ sender: XCUIApplication, button: String) {
    let input = sender.buttons[button]
    XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: input)], timeout: 5) == .completed)
    tapReady(input)
    capture("ios-share-chooser")
    let target = sender.cells["허투루"]
    if !target.waitForExistence(timeout: 5) {
      let more = sender.cells["More"]
      if more.exists { more.tap() }
      else if sender.cells["더 보기"].exists { sender.cells["더 보기"].tap() }
    }
    XCTAssertTrue(target.waitForExistence(timeout: 5), sender.debugDescription)
    tapReady(target)
  }
  private func control(_ values: [String: Any]) {
    var request = URLRequest(url: URL(string: "http://127.0.0.1:18765/__test/control")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try! JSONSerialization.data(withJSONObject: values)
    let finished = expectation(description: "fixture control")
    URLSession.shared.dataTask(with: request) { _, response, error in
      XCTAssertNil(error)
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      finished.fulfill()
    }.resume()
    wait(for: [finished], timeout: 5)
  }
  private func fixtureState(_ key: String) -> Int {
    let finished = expectation(description: "fixture \(key)")
    var count = -1
    URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:18765/__test/state")!) { data, _, error in
      XCTAssertNil(error)
      if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        count = json[key] as? Int ?? -1
      }
      finished.fulfill()
    }.resume()
    wait(for: [finished], timeout: 5)
    return count
  }
  private func savedCount() -> Int { fixtureState("saved") }
  /// Every save POST the fixture received, including repeats with the same Idempotency-Key.
  private func saveRequests() -> Int { fixtureState("save_requests") }
  /// The share save sheet (Figma 233:3420) carries only the handle, "저장하기" and the guide.
  private func assertSaveSheet(_ host: XCUIApplication) {
    let save = host.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), host.debugDescription)
    XCTAssertEqual(save.label, "저장하기")
    XCTAssertTrue(host.otherElements["share.sheet"].exists, host.debugDescription)
    XCTAssertTrue(host.staticTexts["전송한 정보는 AI가 직접 분류해서 저장할게요!"].exists, host.debugDescription)
    for removed in ["share.close", "share.discard", "share.account", "share.status", "share.preview", "share.image"] {
      XCTAssertFalse(host.descendants(matching: .any)[removed].exists, removed)
    }
    XCTAssertFalse(host.staticTexts["허투루에 저장"].exists, host.debugDescription)
  }
  /// The completion toast (Figma 233:3430) is drawn inside the extension, which then returns to the host.
  private func assertSavedToastThenReturn(_ host: XCUIApplication, returned: XCUIElement) {
    let toast = host.otherElements["share.toast"]
    XCTAssertTrue(toast.waitForExistence(timeout: 35), host.debugDescription)
    XCTAssertEqual(toast.label, "저장 완료!")
    XCTAssertFalse(host.buttons["share.save"].isHittable)
    capture("ios-share-saved-toast")
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: toast)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, host.debugDescription)
    XCTAssertTrue(returned.waitForExistence(timeout: 5), host.debugDescription)
  }
  private func eventually(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if condition() { return true }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    return false
  }
  /// Pending shares as the main app's prompt reports them. Relaunching resets a prompt dismissed earlier.
  private func pendingShareCount(_ main: XCUIApplication) -> Int {
    main.launch()
    XCTAssertTrue(main.images["홈"].waitForExistence(timeout: 15), main.debugDescription)
    // The prompt's text is exposed as a non-text element in the observed Flutter accessibility tree.
    let prompt = main.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '저장 대기 중인 공유 '")).firstMatch
    guard prompt.waitForExistence(timeout: 5) else { return 0 }
    return Int(prompt.label.dropFirst("저장 대기 중인 공유 ".count).dropLast()) ?? -1
  }
  private func dragSheetDown(_ host: XCUIApplication) {
    let sheet = host.otherElements["share.sheet"]
    let handle = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
    handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: sheet.frame.height * 0.8)))
  }
  private func tapBackdrop(_ host: XCUIApplication) {
    host.buttons["share.dismiss"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
  }
  private func assertReturned(_ sender: XCUIApplication, timeout: TimeInterval = 5) {
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sender.otherElements["share.sheet"])
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed, sender.debugDescription)
    XCTAssertTrue(sender.staticTexts["sender.title"].isHittable, sender.debugDescription)
  }
  /// Kept pending shares continue in the main app's existing recovery modal.
  private func resumeInMain(_ main: XCUIApplication, label: String) {
    main.activate()
    let confirm = main.buttons["확인"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 15), main.debugDescription)
    tapReady(confirm)
    let draft = main.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    XCTAssertTrue(draft.waitForExistence(timeout: 5), main.debugDescription)
    for _ in 0..<3 where !draft.isHittable { main.swipeUp() }
    tapReady(draft)
    let save = main.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), main.debugDescription)
    tapReady(save)
    XCTAssertTrue(main.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), main.debugDescription)
    tapReady(main.buttons["share.close"])
    XCTAssertFalse(main.buttons["share.save"].waitForExistence(timeout: 2))
  }
  private let unconfirmedMessage = "저장 결과를 확인하지 못했습니다. 다시 시도해도 중복 저장되지 않습니다."
  private let loginTitle = "로그인이 필요해요"
  private let loginMessage = "초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요."
  private let instagramURL = "https://www.instagram.com/p/fixture/"
  /// Failures show an OS alert per category: its title, message and [다시 시도]/[닫기] only (iOS has no [허투루 열기]).
  /// The alert is accessibility-modal, so the disabled "저장하기" behind it is not queryable; the alert blocks it.
  private func assertAlert(_ host: XCUIApplication, title: String, message: String, retry: Bool = false,
                           timeout: TimeInterval = 10) {
    let alert = host.alerts[title]
    XCTAssertTrue(alert.waitForExistence(timeout: timeout), host.debugDescription)
    XCTAssertTrue(alert.staticTexts[message].exists, host.debugDescription)
    XCTAssertEqual(alert.buttons.count, retry ? 2 : 1, host.debugDescription)
    XCTAssertTrue(alert.buttons["share.close"].exists, host.debugDescription)
    XCTAssertEqual(alert.buttons["share.retry"].exists, retry, host.debugDescription)
    // No alert points to an action the sheet does not have.
    for text in alert.staticTexts.allElementsBoundByIndex.map(\.label) {
      for removed in ["초안 삭제", "초안을 삭제", "같은 초안으로"] { XCTAssertFalse(text.contains(removed), text) }
    }
  }
  private func uniqueURL() -> String {
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ&fixture=\(UUID().uuidString.lowercased())"
  }
  /// Shares a unique link and fails its save with the fixture settings, leaving the category alert open.
  private func failSave(_ sender: XCUIApplication, _ settings: [String: Any], title: String = "저장하지 못했어요",
                        message: String, retry: Bool, button: String = "YouTube 링크 공유", timeout: TimeInterval = 10) {
    control(settings)
    openShare(sender, button: button)
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    tapReady(save)
    assertAlert(sender, title: title, message: message, retry: retry, timeout: timeout)
  }
  /// A retryable failure saves through [다시 시도] without a duplicate, and is kept on [닫기] for the main app.
  private func retryOrKeep(_ settings: [String: Any], message: String, captureName: String, timeout: TimeInterval = 10) {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launchArguments = ["--recovery-url", uniqueURL()]
    sender.launch()
    var before = savedCount()
    var requests = saveRequests()
    failSave(sender, settings, message: message, retry: true, timeout: timeout)
    capture(captureName)
    tapReady(sender.alerts.buttons["share.retry"])
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    XCTAssertEqual(savedCount(), before + 1)
    XCTAssertEqual(saveRequests(), requests + 2)

    let sharedURL = uniqueURL()
    sender.launchArguments = ["--recovery-url", sharedURL]
    sender.launch()
    before = savedCount()
    requests = saveRequests()
    failSave(sender, settings, message: message, retry: true, timeout: timeout)
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    // Closing keeps the share; retrying it in the main app with the same key does not save twice.
    resumeInMain(main, label: sharedURL)
    XCTAssertEqual(savedCount(), before + 1)
    XCTAssertEqual(saveRequests(), requests + 2)
  }
  private func recoverInterruptedSave(terminateSender: Bool) {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    XCTAssertTrue(main.images["홈"].waitForExistence(timeout: 15), main.debugDescription)
    if main.buttons["나중에"].waitForExistence(timeout: 3) { tapReady(main.buttons["나중에"]) }
    // The unlabeled plus is centered 14 points below the observed bottom navigation's top.
    let home = main.images["홈"]
    main.coordinate(withNormalizedOffset: .zero).withOffset(
      CGVector(dx: main.frame.midX, dy: home.frame.minY + 14)).tap()
    XCTAssertTrue(main.descendants(matching: .any).matching(NSPredicate(format: "label == '콘텐츠 저장하기'")).firstMatch.waitForExistence(timeout: 8), main.debugDescription)
    let input = main.textFields.firstMatch
    tapReady(input)
    let manualURL = "https://youtu.be/dQw4w9WgXcQ?manual=keep"
    input.typeText(manualURL)
    let suffix = terminateSender ? "termination" : "close"
    capture("ios-interrupted-\(suffix)-manual-before")

    let sharedURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&fixture=\(UUID().uuidString.lowercased())"
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launchArguments = ["--recovery-url", sharedURL]
    sender.launch()
    let before = savedCount()
    let requests = saveRequests()
    control(["save_delay_seconds": terminateSender ? 20 : 10])
    openShare(sender, button: "YouTube 링크 공유")
    tapReady(sender.buttons["share.save"])
    // The fixture commits before delaying its reply, so this proves a request already reached the server.
    XCTAssertTrue(eventually { self.saveRequests() == requests + 1 })
    XCTAssertEqual(savedCount(), before + 1)
    XCTAssertTrue(sender.otherElements["share.sheet"].exists, sender.debugDescription)
    capture("ios-interrupted-\(suffix)-in-flight")
    if terminateSender {
      sender.terminate()
      XCTAssertEqual(sender.state, .notRunning)
    } else {
      dragSheetDown(sender)
      assertReturned(sender)
      capture("ios-interrupted-close-sender-return")
    }
    main.activate()
    let confirm = main.buttons["확인"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 15), main.debugDescription)
    tapReady(confirm)
    let draft = main.descendants(matching: .any).matching(NSPredicate(format: "label == %@", sharedURL)).firstMatch
    XCTAssertTrue(draft.waitForExistence(timeout: 5), main.debugDescription)
    for _ in 0..<3 where !draft.isHittable { main.swipeUp() }
    tapReady(draft)
    let save = main.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), main.debugDescription)
    XCTAssertTrue(main.staticTexts["이전 저장 결과가 불명확합니다. 다시 시도하면 같은 저장을 확인합니다."].exists,
                  main.debugDescription)
    capture("ios-interrupted-\(suffix)-recovery")
    tapReady(save)
    XCTAssertTrue(main.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 15), main.debugDescription)
    XCTAssertEqual(savedCount(), before + 1)
    XCTAssertEqual(saveRequests(), requests + 2)
    tapReady(main.buttons["share.close"])
    XCTAssertTrue(input.waitForExistence(timeout: 8), main.debugDescription)
    if main.buttons["나중에"].waitForExistence(timeout: 3) { tapReady(main.buttons["나중에"]) }
    XCTAssertEqual(input.value as? String, manualURL)
    XCTAssertTrue(main.descendants(matching: .any).matching(NSPredicate(format: "label == '콘텐츠 저장하기'")).firstMatch.exists, main.debugDescription)
    capture("ios-interrupted-\(suffix)-manual-preserved")
  }
  func testCloseDuringSaveRecoversWithoutDuplicateAndPreservesManualInput() {
    recoverInterruptedSave(terminateSender: false)
  }
  func testSenderTerminationDuringSaveRecoversWithoutDuplicateAndPreservesManualInput() {
    recoverInterruptedSave(terminateSender: true)
  }
  func testDismissBeforeSaveKeepsNoPendingShare() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let requests = saveRequests()
    openShare(sender, button: "YouTube 링크 공유")
    assertSaveSheet(sender)
    dragSheetDown(sender)
    assertReturned(sender)
    openShare(sender, button: "스크린샷 공유")
    assertSaveSheet(sender)
    tapBackdrop(sender)
    assertReturned(sender)
    XCTAssertEqual(saveRequests(), requests)
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  func testPreparationDismissKeepsNothingAndRepeatedTapsSaveOnce() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let requests = saveRequests()
    // The slow input keeps preparation running: the sheet is already shown with "저장하기" blocked.
    openShare(sender, button: "느린 스크린샷 공유")
    let save = sender.buttons["share.save"]
    assertSaveSheet(sender)
    XCTAssertFalse(save.isEnabled)
    capture("ios-share-preparing")
    tapBackdrop(sender)
    assertReturned(sender, timeout: 10)
    XCTAssertEqual(pendingShareCount(main), pending)

    sender.activate()
    openShare(sender, button: "느린 스크린샷 공유")
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    // Wait until the sheet has slid in so the taps land on "저장하기", not on the backdrop.
    tapReady(save); save.tap()
    XCTAssertFalse(save.isEnabled)
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed, sender.debugDescription)
    control(["save_delay_seconds": 3])
    save.tap(); save.tap(); save.tap()
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    XCTAssertEqual(saveRequests(), requests + 1)
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  func testSocketTimeoutRetriesWithoutDuplicate() {
    retryOrKeep(["save_delay_seconds": 35], message: unconfirmedMessage, captureName: "ios-share-timeout", timeout: 40)
  }
  func testSocketResponseLossRetriesWithoutDuplicate() {
    retryOrKeep(["lose_response": true], message: unconfirmedMessage, captureName: "ios-share-response-lost")
  }
  func testServerErrorRetriesWithoutDuplicate() {
    retryOrKeep(["next_save_status": 500], message: unconfirmedMessage, captureName: "ios-share-server-error")
  }
  func testUnprocessableLinkRetriesWithoutDuplicate() {
    retryOrKeep(["next_save_status": 422], message: "지금 링크 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요. "
      + "계속 실패하면 Instagram·YouTube 링크나 PNG·JPEG·WebP 이미지인지 확인해 주세요.", captureName: "ios-share-unprocessable")
  }
  func testSignedOutShareIsKeptBeforeLoginAlertAndResumesInMain() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    let sharedURL = uniqueURL()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launchArguments = ["--recovery-url", sharedURL]
    sender.launch()
    let requests = saveRequests()
    // A 401 blocks the sharing credential until the main app publishes it again.
    failSave(sender, ["next_save_status": 401], title: loginTitle, message: loginMessage, retry: false,
             button: "Instagram 텍스트 공유")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    // Signed out: the share is kept first, then the login alert replaces the sheet without a save request.
    openShare(sender, button: "YouTube 링크 공유")
    assertAlert(sender, title: loginTitle, message: loginMessage)
    capture("ios-share-login-required")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    XCTAssertEqual(saveRequests(), requests + 1)
    XCTAssertEqual(pendingShareCount(main), pending + 2)
    resumeInMain(main, label: sharedURL)
    resumeInMain(main, label: instagramURL)
    XCTAssertEqual(saveRequests(), requests + 3)
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  func testDeviceStorageFullKeepsNothingAndNeverSaysKept() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    XCTAssertLessThan(pending, 10)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    // Signed out after a 401, each share is kept with a login alert until the device keeps 10.
    failSave(sender, ["next_save_status": 401], title: loginTitle, message: loginMessage, retry: false,
             button: "Instagram 텍스트 공유")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    for _ in (pending + 1)..<10 {
      openShare(sender, button: "Instagram 텍스트 공유")
      assertAlert(sender, title: loginTitle, message: loginMessage)
      tapReady(sender.alerts.buttons["share.close"])
      assertReturned(sender)
    }
    openShare(sender, button: "Instagram 텍스트 공유")
    let title = "보관하지 못했어요"
    assertAlert(sender, title: title, message: "보관 중인 공유가 가득 찼어요. 허투루 앱에서 저장 대기 공유를 저장하거나 삭제한 뒤 다시 공유해 주세요.")
    XCTAssertFalse(sender.alerts[title].staticTexts.allElementsBoundByIndex.contains { $0.label.contains("보관했습니다") })
    capture("ios-share-storage-full")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    XCTAssertEqual(pendingShareCount(main), 10)
    for _ in pending..<10 { resumeInMain(main, label: instagramURL) }
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  func testUnauthorizedDraftResumesInMainNativeModal() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    control(["next_save_status": 401])
    openShare(sender, button: "Instagram 텍스트 공유")
    XCTAssertTrue(sender.buttons["share.save"].waitForExistence(timeout: 10))
    tapReady(sender.buttons["share.save"])
    let message = sender.staticTexts["초안을 보관했습니다. 허투루 앱을 열어 로그인을 확인한 뒤 대기 항목을 선택해 주세요."]
    XCTAssertTrue(message.waitForExistence(timeout: 10), sender.debugDescription)
    // The OS alert is accessibility-modal, so the disabled "저장하기" behind it is not queryable; the alert blocks it.
    XCTAssertTrue(sender.alerts.firstMatch.exists, sender.debugDescription)
    capture("ios-share-auth-required")
    tapReady(sender.buttons["share.close"])
    main.activate()
    let confirm = main.buttons["확인"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 15), main.debugDescription)
    capture("ios-share-pending-in-main")
    confirm.tap()
    let draft = main.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "https://www.instagram.com/p/fixture/")).firstMatch
    XCTAssertTrue(draft.waitForExistence(timeout: 5), main.debugDescription)
    draft.tap()
    let save = main.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), main.debugDescription)
    capture("ios-share-recovery-modal")
    tapReady(save)
    XCTAssertTrue(main.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35))
    tapReady(main.buttons["share.close"])
    XCTAssertFalse(main.buttons["share.save"].waitForExistence(timeout: 2))
    XCTAssertEqual(main.state, .runningForeground)
    capture("ios-share-recovery-main-return")
  }
  func testExternalLinkSaveReturnsToSenderWithoutMainApp() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.terminate()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let requests = saveRequests()
    openShare(sender, button: "YouTube 링크 공유")
    assertSaveSheet(sender)
    capture("ios-share-sheet")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.isEnabled, sender.debugDescription)
    tapReady(save)
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    XCTAssertEqual(saveRequests(), requests + 1)
    XCTAssertEqual(main.state, .notRunning)
    capture("ios-share-sender-return")
  }
  func testImageSaveAndUnsupportedInput() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let requests = saveRequests()
    openShare(sender, button: "스크린샷 공유")
    // Images use the same sheet as links, without a preview.
    assertSaveSheet(sender)
    capture("ios-image-sheet")
    tapReady(sender.buttons["share.save"])
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    XCTAssertEqual(saveRequests(), requests + 1)
    openShare(sender, button: "지원하지 않는 공유")
    assertAlert(sender, title: "공유할 수 없어요", message: "Instagram 또는 YouTube 링크만 저장할 수 있습니다.")
    capture("ios-share-error")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  func testServerRejectionsRetryKeepOrDiscardByCategory() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    let pending = pendingShareCount(main)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let before = savedCount()
    // Image saving paused: [다시 시도] saves once it resumes.
    failSave(sender, ["next_save_status": 409, "next_save_detail": ["code": "image_uploads_paused"]],
             message: "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.", retry: true, button: "스크린샷 공유")
    capture("ios-share-image-paused")
    tapReady(sender.alerts.buttons["share.retry"])
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    XCTAssertEqual(savedCount(), before + 1)
    // Server image quota: kept on [닫기] to continue later in the main app.
    failSave(sender, ["next_save_status": 409, "next_save_detail": ["code": "image_quota_exceeded"]], title: "지금은 저장할 수 없어요",
             message: "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.", retry: false, button: "스크린샷 공유")
    capture("ios-share-image-quota")
    tapReady(sender.alerts.buttons["share.close"])
    assertReturned(sender)
    // 410·409·413 cannot succeed again: [닫기] discards the share.
    for (status, detail, message, button, artifact) in [
      (410, nil, "이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요.", "YouTube 링크 공유", "ios-share-deleted"),
      (409, nil, "이 초안의 저장 정보가 일치하지 않습니다. 다시 공유해 주세요.", "YouTube 링크 공유", "ios-share-mismatch"),
      (413, ["code": "image_file_too_large"], "이미지는 10MiB 이하만 저장할 수 있습니다.", "스크린샷 공유", "ios-share-image-file-limit")
    ] as [(Int, [String: String]?, String, String, String)] {
      var settings: [String: Any] = ["next_save_status": status]
      if let detail { settings["next_save_detail"] = detail }
      failSave(sender, settings, title: "다시 저장할 수 없어요", message: message, retry: false, button: button)
      capture(artifact)
      tapReady(sender.alerts.buttons["share.close"])
      assertReturned(sender)
    }
    XCTAssertEqual(pendingShareCount(main), pending + 1)
    resumeInMain(main, label: "공유한 이미지")
    XCTAssertEqual(savedCount(), before + 2)
    XCTAssertEqual(pendingShareCount(main), pending)
  }
  // Prepare Safari with simctl openurl and Photos with simctl addmedia before these OS-host tests.
  func testSafariSharesPreparedYouTubePage() {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    safari.launch()
    let share = safari.buttons.matching(NSPredicate(format: "label == 'Share' OR label == '공유' OR identifier == 'Share' ")).firstMatch
    XCTAssertTrue(share.waitForExistence(timeout: 10), safari.debugDescription)
    tapReady(share)
    let target = safari.cells["허투루"]
    XCTAssertTrue(target.waitForExistence(timeout: 10), safari.debugDescription)
    capture("ios-safari-share-chooser")
    tapReady(target)
    let save = safari.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), safari.debugDescription)
    capture("ios-safari-sheet")
    tapReady(save)
    assertSavedToastThenReturn(safari, returned: share)
  }
  func testPhotosSharesPreparedScreenshot() {
    let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
    photos.launch()
    for label in ["Continue", "계속"] where photos.buttons[label].waitForExistence(timeout: 2) {
      tapReady(photos.buttons[label])
    }
    let share = photos.buttons.matching(NSPredicate(format: "label == 'Share' OR label == '공유' OR identifier == 'Share' ")).firstMatch
    if !share.exists {
      let recent = photos.buttons.matching(NSPredicate(format: "label == '오늘 저장됨' OR label == 'Saved Today'")).firstMatch
      if recent.exists { tapReady(recent) }
      else if photos.buttons["all_photos_grid"].exists { tapReady(photos.buttons["all_photos_grid"]) }
      // A collection with one photo opens that photo directly.
      if !share.waitForExistence(timeout: 2) {
        let candidates = photos.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,' OR label BEGINSWITH '사진,'"))
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 8), photos.debugDescription)
        let photo = candidates.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? candidates.firstMatch
        tapReady(photo)
      }
    }
    XCTAssertTrue(share.waitForExistence(timeout: 8), photos.debugDescription)
    tapReady(share)
    let target = photos.cells["허투루"]
    XCTAssertTrue(target.waitForExistence(timeout: 10), photos.debugDescription)
    capture("ios-photos-share-chooser")
    tapReady(target)
    let save = photos.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), photos.debugDescription)
    capture("ios-photos-sheet")
    tapReady(save)
    assertSavedToastThenReturn(photos, returned: share)
  }
  // Run image_storage_live_preview.dart against 18766 and complete actual guest login first.
  // No fixture control endpoint or manually published native credential is used.
  func testRealBackendNativeImageWithExistingSession() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.activate()
    XCTAssertTrue(main.images["홈"].waitForExistence(timeout: 15), main.debugDescription)
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    openShare(sender, button: "스크린샷 공유")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    capture("ios-real-image-sheet")
    tapReady(save)
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    main.activate()
    capture("ios-real-image-return")
  }
  private func realImageError(_ title: String, _ message: String, retry: Bool, artifact: String) {
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    openShare(sender, button: "스크린샷 공유")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    tapReady(save)
    assertAlert(sender, title: title, message: message, retry: retry, timeout: 15)
    capture(artifact)
    tapReady(sender.alerts.buttons["share.close"])
    XCUIApplication(bundleIdentifier: "com.huturu.app").activate()
  }
  func testRealBackendImagePauseWithExistingSession() {
    realImageError("저장하지 못했어요", "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.", retry: true, artifact: "ios-real-share-pause")
  }
  func testRealBackendImageQuotaWithExistingSession() {
    realImageError("지금은 저장할 수 없어요", "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.", retry: false,
                   artifact: "ios-real-share-quota")
  }
  // Install share_preview.dart with SHARE_PREVIEW_REAL_BACKEND=true and port 18766 before this test.
  func testRealBackendGuestLoginThenNativeSave() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    let guest = main.buttons["게스트로 시작하기"]
    XCTAssertTrue(guest.waitForExistence(timeout: 15), main.debugDescription)
    tapReady(guest)
    let signedIn = expectation(for: NSPredicate { _, _ in !guest.exists }, evaluatedWith: nil)
    wait(for: [signedIn], timeout: 15)
    for _ in 0..<2 { tapReady(main.buttons["다음"]) }
    tapReady(main.buttons["시작하기"])
    tapReady(main.buttons["완료"])
    XCTAssertTrue(main.images["홈"].waitForExistence(timeout: 15), main.debugDescription)
    if main.buttons["나중에"].exists { tapReady(main.buttons["나중에"]) }
    capture("ios-real-backend-home")
    // In the observed home accessibility tree, search is the first unlabeled header button, before notifications.
    tapReady(main.buttons.matching(NSPredicate(format: "label == ''")).firstMatch)
    let search = main.textFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 8), main.debugDescription)
    tapReady(search)
    search.typeText("share warm state")
    capture("ios-real-backend-search-before")
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    openShare(sender, button: "Instagram 텍스트 공유")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    capture("ios-real-backend-sheet")
    tapReady(save)
    assertSavedToastThenReturn(sender, returned: sender.staticTexts["sender.title"])
    main.activate()
    XCTAssertTrue(search.waitForExistence(timeout: 8), main.debugDescription)
    XCTAssertEqual(search.value as? String, "share warm state")
    capture("ios-real-backend-search-preserved")
  }
}
