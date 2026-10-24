import Foundation

final class ShareSaveService: NSObject, URLSessionTaskDelegate {
  private let store: ShareStore
  private var session: URLSession?
  private var task: URLSessionDataTask?
  private let lock = NSLock()
  private var cancelled = false
  private let configuration: () -> URLSessionConfiguration
  init(store: ShareStore, configuration: @escaping () -> URLSessionConfiguration = { .ephemeral }) {
    self.store = store; self.configuration = configuration
  }

  func save(_ id: String, expected: ShareCredential,
            completion: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let (draft, credential) = try self.store.begin(id, expected: expected)
        let request = try self.request(draft, credential: credential)
        // Recheck after file preparation, immediately before handing the request to URLSession.
        guard credential.isValid, let latest = try self.store.currentCredential(), latest.revision == credential.revision,
              latest.userId == credential.userId, latest.sessionId == credential.sessionId else {
          throw ShareFailure.changedAccount
        }
        let config = self.configuration()
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request) { data, response, error in
          defer { session.finishTasksAndInvalidate() }
          do {
            if error != nil {
              try self.store.mark(id, state: "unknown")
              throw ShareFailure.message("저장 결과를 확인하지 못했습니다. 같은 초안으로 다시 시도하면 중복 저장되지 않습니다.")
            }
            guard let response = response as? HTTPURLResponse else {
              try self.store.mark(id, state: "unknown")
              throw ShareFailure.message("서버 응답을 확인하지 못했습니다. 같은 초안으로 다시 시도해 주세요.")
            }
            if response.statusCode == 401 {
              try self.store.rejectCredential(credential)
              try self.store.mark(id, state: "authRequired")
              throw ShareFailure.authentication
            }
            guard (200..<300).contains(response.statusCode), let data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let contentId = (json["id"] as? NSNumber)?.stringValue else {
              try self.store.mark(id, state: response.statusCode >= 500 || (200..<300).contains(response.statusCode) ? "unknown" : "failed")
              if response.statusCode >= 500 || (200..<300).contains(response.statusCode) {
                throw ShareFailure.message("저장 결과를 확인하지 못했습니다. 같은 초안으로 다시 시도해 주세요.")
              }
              if response.statusCode == 410 {
                throw ShareFailure.message("이미 저장한 뒤 삭제한 콘텐츠입니다. 이 초안을 삭제한 뒤 새로 공유해 주세요.")
              }
              let errorJSON = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
              if let detail = errorJSON?["detail"] as? [String: Any],
                 detail["code"] as? String == "image_uploads_paused" {
                throw ShareFailure.message("이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.")
              }
              if let detail = errorJSON?["detail"] as? [String: Any],
                 detail["code"] as? String == "image_quota_exceeded" {
                throw ShareFailure.message("이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.")
              }
              if response.statusCode == 413 {
                throw ShareFailure.message("이미지는 10MiB 이하만 저장할 수 있습니다.")
              }
              if response.statusCode == 409 {
                throw ShareFailure.message("이 초안의 저장 정보가 일치하지 않습니다. 초안을 삭제한 뒤 다시 공유해 주세요.")
              }
              throw ShareFailure.message("저장하지 못했습니다. 지원하는 링크·이미지인지 확인한 뒤 다시 시도해 주세요.")
            }
            try self.store.complete(draft, contentId: contentId)
            guard let current = try self.store.currentCredential(),
                  current.revision == credential.revision, current.userId == credential.userId else {
              throw ShareFailure.message("전송한 계정의 저장 결과는 보관했습니다. 계정이 변경되어 이 창을 닫아 주세요.")
            }
            DispatchQueue.main.async { completion(.success(contentId)) }
          } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
        self.lock.lock()
        if self.cancelled {
          self.lock.unlock()
          session.invalidateAndCancel()
          try self.store.mark(id, state: "unknown")
          return
        }
        self.session = session
        self.task = task
        task.resume()
        self.lock.unlock()
      } catch {
        try? self.store.mark(id, state: "authRequired")
        DispatchQueue.main.async { completion(.failure(error)) }
      }
    }
  }

  private func request(_ draft: ShareDraft, credential: ShareCredential) throws -> URLRequest {
    let endpoint = draft.kind == "image" ? "/uploads/screenshots" : "/contents/share"
    guard let url = URL(string: credential.apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + endpoint),
          url.scheme == "https" || (url.scheme == "http" && Self.isLocalTestHost(url.host)) else {
      throw ShareFailure.message("공유 서버 설정을 확인해 주세요.")
    }
    var request = URLRequest(url: url, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
    request.setValue(draft.id, forHTTPHeaderField: "Idempotency-Key")
    if draft.kind == "image", let file = store.imageURL(draft), let mime = draft.mimeType {
      let boundary = "huturu-\(UUID().uuidString)"
      var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8)
      body.append(try Data(contentsOf: file))
      body.append(Data("\r\n--\(boundary)--\r\n".utf8))
      request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
    } else {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: ["url": draft.url ?? "", "raw_text": draft.rawText ?? ""], options: .sortedKeys)
    }
    return request
  }
  private static func isLocalTestHost(_ host: String?) -> Bool {
    #if DEBUG
    return ["127.0.0.1", "localhost"].contains(host ?? "")
    #else
    return false
    #endif
  }
  func cancel() {
    lock.lock()
    cancelled = true
    task?.cancel()
    session?.invalidateAndCancel()
    lock.unlock()
  }
  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    // Never forward a sharing credential to a redirected host.
    completionHandler(nil)
  }
}
