package com.clipback.frontend.share;

import android.os.Handler;
import android.os.Looper;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** Process-owned requests survive Activity recreation without re-sending. */
final class ShareService {
    interface Listener { void finished(String id, String message, boolean success); }
    private static final ExecutorService EXECUTOR = Executors.newCachedThreadPool();
    private static final ScheduledExecutorService TIMEOUTS = Executors.newSingleThreadScheduledExecutor();
    private static final Map<String, List<Listener>> ACTIVE = new HashMap<>();
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    static synchronized boolean isActive(String id) { return ACTIVE.containsKey(id); }
    static synchronized void observe(String id, Listener listener) { if (ACTIVE.containsKey(id)) ACTIVE.get(id).add(listener); }
    static synchronized void detach(Listener listener) { for (List<Listener> list : ACTIVE.values()) list.remove(listener); }
    static void execute(ShareStore store, String id, long revision, String user, Listener listener) {
        synchronized (ShareService.class) {
            if (ACTIVE.containsKey(id)) { ACTIVE.get(id).add(listener); return; }
            ACTIVE.put(id, new ArrayList<>(Collections.singletonList(listener)));
        }
        EXECUTOR.execute(() -> {
            boolean success = false, transmitted = false;
            String message;
            HttpURLConnection connection = null; ScheduledFuture<?> deadline = null;
            try {
                JSONObject request = store.begin(id, revision, user), draft = request.getJSONObject("draft"), auth = request.getJSONObject("credential");
                String endpoint = "image".equals(draft.getString("kind")) ? "/uploads/screenshots" : "/contents/share";
                connection = (HttpURLConnection) new URL(ShareStore.baseUrl() + endpoint).openConnection();
                connection.setInstanceFollowRedirects(false); connection.setRequestMethod("POST");
                connection.setConnectTimeout(30000); connection.setReadTimeout(30000); connection.setDoOutput(true);
                connection.setRequestProperty("Authorization", "Bearer " + auth.getString("token"));
                connection.setRequestProperty("Idempotency-Key", id);
                connection.setRequestProperty("Accept", "application/json");
                byte[] body = body(store, draft, connection);
                connection.setFixedLengthStreamingMode(body.length);
                HttpURLConnection timed = connection;
                deadline = TIMEOUTS.schedule(timed::disconnect, 30, TimeUnit.SECONDS);
                // Re-check immediately before opening the socket; an already submitted write may finish for its original user.
                if (!store.sameAccount(revision, user)) throw new IOException("저장 계정이 변경되었습니다. 다시 확인해 주세요.");
                transmitted = true;
                try (OutputStream output = connection.getOutputStream()) { output.write(body); }
                int status = connection.getResponseCode();
                if (status >= 200 && status < 300) {
                    JSONObject response = new JSONObject(read(connection.getInputStream()));
                    String contentId = response.getString("id");
                    if (Long.parseLong(contentId) <= 0) throw new IOException("저장 응답을 확인할 수 없습니다.");
                    store.complete(id, user, contentId);
                    success = store.sameAccount(revision, user);
                    message = success ? "저장했어요. 요약과 분류는 계속 처리될 수 있어요." : "요청한 계정에 저장했습니다. 계정이 변경되어 본앱에서 확인해 주세요.";
                } else {
                    if (status == 401) { store.rejectCredential(revision, auth.getString("token")); store.setState(id, "authRequired"); message = "로그인 상태 확인이 필요해요. 초안을 보관했습니다. 본앱을 열어 대기 중인 공유를 다시 선택해 주세요."; }
                    else { store.setState(id, "failed"); message = errorMessage(status); }
                }
            } catch (Exception error) {
                try { store.setState(id, transmitted ? "unknown" : "failed"); } catch (Exception ignored) { }
                message = transmitted ? "저장 결과를 확인하지 못했어요. 초안을 보관했습니다. 다시 시도해도 같은 요청으로 확인합니다." :
                    (error.getMessage() != null ? error.getMessage() : "공유 정보를 보관하지 못했습니다. 다시 시도해 주세요.");
            } finally { if (deadline != null) deadline.cancel(false); if (connection != null) connection.disconnect(); }
            final String result = message; final boolean done = success;
            final List<Listener> listeners;
            synchronized (ShareService.class) { listeners = ACTIVE.remove(id); }
            MAIN.post(() -> { if (listeners != null) for (Listener target : listeners) target.finished(id, result, done); });
        });
    }
    private static String errorMessage(int status) {
        if (status == 409) return "이 요청의 입력이 기존 저장과 다릅니다. 원래 공유 항목을 확인해 주세요.";
        if (status == 410) return "이미 삭제된 저장 항목입니다. 이 공유는 다시 저장하지 않습니다.";
        if (status == 413) return "이미지는 10MiB 이하만 저장할 수 있습니다.";
        if (status == 400 || status == 415 || status == 422) return "공유 링크나 이미지 형식을 확인해 주세요. Instagram·YouTube 링크와 PNG·JPEG·WebP를 지원합니다.";
        return "지금 저장하지 못했어요. 잠시 후 같은 항목으로 다시 시도해 주세요.";
    }
    private static byte[] body(ShareStore store, JSONObject draft, HttpURLConnection connection) throws Exception {
        if ("link".equals(draft.getString("kind"))) {
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            return new JSONObject().put("url", draft.getString("url")).put("raw_text", draft.getString("rawText")).toString().getBytes(StandardCharsets.UTF_8);
        }
        String boundary = "huturu-" + draft.getString("id");
        connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        body.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"screenshot." +
            ("image/jpeg".equals(draft.getString("mime")) ? "jpg" : "image/webp".equals(draft.getString("mime")) ? "webp" : "png") +
            "\"\r\nContent-Type: "+draft.getString("mime")+"\r\n\r\n").getBytes(StandardCharsets.UTF_8));
        try (InputStream input = new FileInputStream(store.imageFile(draft.getString("id")))) {
            byte[] buffer = new byte[8192]; int count; while ((count = input.read(buffer)) != -1) body.write(buffer, 0, count);
        }
        body.write(("\r\n--"+boundary+"--\r\n").getBytes(StandardCharsets.UTF_8)); return body.toByteArray();
    }
    private static String read(InputStream input) throws Exception {
        try (InputStream stream = input; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int count;
            while ((count = stream.read(buffer)) != -1) { if (out.size() + count > 1024*1024) throw new IOException("응답 크기 초과"); out.write(buffer,0,count); }
            return out.toString("UTF-8");
        }
    }
}
