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
  private func savedCount() -> Int {
    let finished = expectation(description: "fixture receipt count")
    var count = -1
    URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:18765/__test/state")!) { data, _, error in
      XCTAssertNil(error)
      if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        count = json["saved"] as? Int ?? -1
      }
      finished.fulfill()
    }.resume()
    wait(for: [finished], timeout: 5)
    return count
  }
  private func retryUnconfirmedSave(_ settings: [String: Any], captureName: String) {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    let before = savedCount()
    control(settings)
    openShare(sender, button: "YouTube 링크 공유")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    tapReady(save)
    let unknown = sender.staticTexts["저장 결과를 확인하지 못했습니다. 같은 초안으로 다시 시도하면 중복 저장되지 않습니다."]
    XCTAssertTrue(unknown.waitForExistence(timeout: 40), sender.debugDescription)
    capture(captureName)
    XCTAssertTrue(save.isEnabled)
    tapReady(save)
    XCTAssertTrue(sender.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), sender.debugDescription)
    XCTAssertEqual(savedCount(), before + 1)
    tapReady(sender.buttons["share.close"])
    XCTAssertTrue(sender.staticTexts["sender.title"].waitForExistence(timeout: 5))
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
    control(["save_delay_seconds": terminateSender ? 20 : 10])
    openShare(sender, button: "YouTube 링크 공유")
    tapReady(sender.buttons["share.save"])
    XCTAssertTrue(sender.staticTexts["저장 중입니다…"].waitForExistence(timeout: 3), sender.debugDescription)
    // The fixture commits before delaying its reply, so this proves a request already reached the server.
    XCTAssertEqual(savedCount(), before + 1)
    capture("ios-interrupted-\(suffix)-in-flight")
    if terminateSender {
      sender.terminate()
      XCTAssertEqual(sender.state, .notRunning)
    } else {
      sender.buttons["share.close"].tap()
      XCTAssertTrue(sender.staticTexts["sender.title"].waitForExistence(timeout: 5), sender.debugDescription)
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
  func testSocketTimeoutRetriesWithoutDuplicate() {
    retryUnconfirmedSave(["save_delay_seconds": 35], captureName: "ios-share-timeout")
  }
  func testSocketResponseLossRetriesWithoutDuplicate() {
    retryUnconfirmedSave(["lose_response": true], captureName: "ios-share-response-lost")
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
    XCTAssertFalse(sender.buttons["share.save"].isEnabled)
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
    openShare(sender, button: "YouTube 링크 공유")
    let save = sender.buttons["share.save"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
    capture("ios-share-preview")
    XCTAssertTrue(save.isEnabled, sender.debugDescription)
    tapReady(save)
    let success = sender.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."]
    XCTAssertTrue(success.waitForExistence(timeout: 35), sender.debugDescription)
    capture("ios-share-success")
    tapReady(sender.buttons["share.close"])
    XCTAssertTrue(sender.staticTexts["sender.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(main.state, .notRunning)
    capture("ios-share-sender-return")
  }
  func testImageSaveAndUnsupportedInput() {
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    openShare(sender, button: "스크린샷 공유")
    XCTAssertTrue(sender.buttons["share.save"].waitForExistence(timeout: 10), sender.debugDescription)
    capture("ios-image-preview")
    tapReady(sender.buttons["share.save"])
    XCTAssertTrue(sender.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), sender.debugDescription)
    tapReady(sender.buttons["share.close"])
    XCTAssertTrue(sender.staticTexts["sender.title"].waitForExistence(timeout: 5))
    openShare(sender, button: "지원하지 않는 공유")
    XCTAssertTrue(sender.alerts["공유할 수 없습니다"].waitForExistence(timeout: 10), sender.debugDescription)
    capture("ios-share-error")
    sender.alerts.buttons["닫기"].tap()
  }
  func testImageQuotaAndFileLimitAppearInExistingShareErrorRegion() {
    let main = XCUIApplication(bundleIdentifier: "com.huturu.app")
    main.launch()
    let sender = XCUIApplication(bundleIdentifier: "com.huturu.sharetestsender")
    sender.launch()
    for (status, code, message, artifact) in [
      (409, "image_uploads_paused", "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.", "ios-share-image-paused"),
      (409, "image_quota_exceeded", "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.", "ios-share-image-quota"),
      (413, "image_file_too_large", "이미지는 10MiB 이하만 저장할 수 있습니다.", "ios-share-image-file-limit")
    ] {
      let before = savedCount()
      control(["next_save_status": status, "next_save_detail": ["code": code]])
      openShare(sender, button: "스크린샷 공유")
      let save = sender.buttons["share.save"]
      XCTAssertTrue(save.waitForExistence(timeout: 10), sender.debugDescription)
      tapReady(save)
      XCTAssertTrue(sender.staticTexts[message].waitForExistence(timeout: 10), sender.debugDescription)
      XCTAssertTrue(save.isEnabled)
      XCTAssertEqual(savedCount(), before)
      capture(artifact)
      if code == "image_uploads_paused" {
        tapReady(save)
        XCTAssertTrue(sender.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), sender.debugDescription)
        XCTAssertEqual(savedCount(), before + 1)
        capture("ios-share-image-pause-resumed")
      }
      tapReady(sender.buttons["share.close"])
    }
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
    capture("ios-safari-preview")
    tapReady(save)
    XCTAssertTrue(safari.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), safari.debugDescription)
    capture("ios-safari-success")
    tapReady(safari.buttons["share.close"])
    XCTAssertTrue(share.waitForExistence(timeout: 5))
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
    capture("ios-photos-preview")
    tapReady(save)
    XCTAssertTrue(photos.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), photos.debugDescription)
    capture("ios-photos-success")
    tapReady(photos.buttons["share.close"])
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
    capture("ios-real-backend-preview")
    tapReady(save)
    XCTAssertTrue(sender.staticTexts["저장 완료! 분류와 요약은 앱에서 확인할 수 있습니다."].waitForExistence(timeout: 35), sender.debugDescription)
    capture("ios-real-backend-success")
    tapReady(sender.buttons["share.close"])
    XCTAssertTrue(sender.staticTexts["sender.title"].waitForExistence(timeout: 5))
    main.activate()
    XCTAssertTrue(search.waitForExistence(timeout: 8), main.debugDescription)
    XCTAssertEqual(search.value as? String, "share warm state")
    capture("ios-real-backend-search-preserved")
  }
}
