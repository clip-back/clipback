package com.clipback.frontend.share;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import android.util.Base64;
import com.clipback.frontend.BuildConfig;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.text.SimpleDateFormat;
import java.util.*;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** The single durable authority for native sharing; never stores the main app's tokens. */
public final class ShareStore {
    static final Object LOCK = new Object();
    static final long MAX_IMAGE = 10L * 1024 * 1024;
    static final long MAX_TOTAL = 100L * 1024 * 1024;
    static final long MAX_AGE = 7L * 24 * 60 * 60 * 1000;
    private final File directory;
    private final AtomicFile file;

    public ShareStore(Context context) {
        directory = new File(context.getNoBackupFilesDir(), "native_share");
        directory.mkdirs();
        file = new AtomicFile(new File(directory, "state.json"));
    }
    private JSONObject read() throws Exception {
        if (!file.getBaseFile().exists() && !new File(file.getBaseFile().getPath() + ".bak").exists()) return new JSONObject().put("revision", 0)
            .put("drafts", new JSONArray()).put("receipts", new JSONArray());
        return new JSONObject(new String(file.readFully(), StandardCharsets.UTF_8));
    }
    private void write(JSONObject state) throws Exception {
        FileOutputStream out = null;
        try {
            out = file.startWrite();
            out.write(state.toString().getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
            file.finishWrite(out);
        } catch (Exception error) { if (out != null) file.failWrite(out); throw error; }
    }
    private SecretKey key() throws Exception {
        KeyStore keys = KeyStore.getInstance("AndroidKeyStore"); keys.load(null);
        String alias = "com.huturu.app.share.v1";
        if (!keys.containsAlias(alias)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey) keys.getKey(alias, null);
    }
    private String encrypt(JSONObject credential) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, key());
        return Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP) + ":" +
            Base64.encodeToString(cipher.doFinal(credential.toString().getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
    }
    private JSONObject credential(JSONObject state) throws Exception {
        if (!state.has("encryptedCredential")) return null;
        String[] pieces = state.getString("encryptedCredential").split(":", 2);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Base64.decode(pieces[0], Base64.NO_WRAP)));
        return new JSONObject(new String(cipher.doFinal(Base64.decode(pieces[1], Base64.NO_WRAP)), StandardCharsets.UTF_8));
    }
    static long expiry(String value) throws Exception {
        // ISO 8601 UTC responses can include fractional seconds or a numeric offset.
        String normalized = value.replaceAll("\\.\\d+", "").replace("Z", "+0000");
        normalized = normalized.replaceAll("([+-]\\d{2}):(\\d{2})$", "$1$2");
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US);
        format.setLenient(false); return format.parse(normalized).getTime();
    }
    static String baseUrl() { return BuildConfig.SHARE_API_BASE_URL.replaceAll("/+$", ""); }
    public long blockCredential() throws Exception { synchronized (LOCK) {
        JSONObject state = read(); long revision = state.getLong("revision") + 1;
        state.put("revision", revision); state.remove("encryptedCredential"); write(state); return revision;
    }}
    public boolean publishCredential(JSONObject incoming) throws Exception { synchronized (LOCK) {
        JSONObject state = read();
        if (incoming.getLong("revision") != state.getLong("revision")) return false;
        if (!baseUrl().equals(incoming.getString("apiBaseUrl").replaceAll("/+$", ""))) return false;
        if (expiry(incoming.getString("expiresAt")) <= System.currentTimeMillis()) return false;
        JSONObject existing = credential(state);
        if (existing != null && (!existing.getString("userId").equals(incoming.getString("userId")) ||
            !existing.getString("sessionId").equals(incoming.getString("sessionId")))) return false;
        if (existing != null && expiry(existing.getString("expiresAt")) > expiry(incoming.getString("expiresAt"))) return false;
        JSONObject permitted = new JSONObject();
        for (String field : new String[]{"token", "expiresAt", "userId", "sessionId", "accountLabel", "apiBaseUrl"})
            permitted.put(field, incoming.getString(field));
        state.put("encryptedCredential", encrypt(permitted)); write(state); return true;
    }}
    public JSONObject snapshot() throws Exception { synchronized (LOCK) {
        JSONObject state = read(); expire(state);
        JSONObject result = new JSONObject().put("revision", state.getLong("revision"));
        JSONObject auth = credential(state);
        if (auth != null) {
            auth.remove("token"); auth.put("userId", Long.parseLong(auth.getString("userId")));
            auth.put("sessionId", Long.parseLong(auth.getString("sessionId")));
        }
        result.put("credential", auth == null ? JSONObject.NULL : auth);
        JSONArray drafts = new JSONArray();
        for (int i=0; i<state.getJSONArray("drafts").length(); i++) {
            JSONObject draft = state.getJSONArray("drafts").getJSONObject(i);
            JSONObject summary = new JSONObject();
            for (String field : new String[]{"id", "kind", "label", "state", "userId"})
                if (draft.has(field)) summary.put(field, draft.get(field));
            if (summary.has("userId")) summary.put("userId", Long.parseLong(summary.getString("userId")));
            drafts.put(summary);
        }
        JSONArray allReceipts = state.getJSONArray("receipts"), receipts = new JSONArray();
        for (int i=0; i<allReceipts.length(); i++) {
            JSONObject receipt = allReceipts.getJSONObject(i);
            if (!baseUrl().equals(receipt.optString("apiBaseUrl"))) continue;
            receipt.put("userId", Long.parseLong(receipt.getString("userId")));
            receipt.put("contentId", Long.parseLong(receipt.getString("contentId")));
            receipts.put(receipt);
        }
        return result.put("drafts", drafts).put("receipts", receipts);
    }}
    private void expire(JSONObject state) throws Exception {
        JSONArray kept = new JSONArray(); boolean changed = false;
        List<File> expiredFiles = new ArrayList<>(); Set<String> referenced = new HashSet<>();
        JSONArray drafts = state.getJSONArray("drafts");
        for (int i=0; i<drafts.length(); i++) {
            JSONObject draft = drafts.getJSONObject(i);
            if (System.currentTimeMillis() - draft.getLong("createdAt") > MAX_AGE && !ShareService.isActive(draft.getString("id"))) {
                expiredFiles.add(imageFile(draft.getString("id"))); changed = true;
            } else { kept.put(draft); referenced.add(draft.getString("id") + ".image"); }
        }
        if (changed) { state.put("drafts", kept); write(state); }
        for (File image : expiredFiles) image.delete();
        File[] images = directory.listFiles((dir, name) -> name.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\.image"));
        if (images != null) for (File image : images) {
            if (!referenced.contains(image.getName()) && !image.delete() && image.exists())
                throw new IOException("공유 보관 파일을 정리하지 못했습니다. 다시 시도해 주세요.");
        }
    }
    public String create(String url, String text, byte[] bytes, String mime) throws Exception {
        return create(UUID.randomUUID().toString(), url, text, bytes, mime);
    }
    String create(String id, String url, String text, byte[] bytes, String mime) throws Exception { synchronized (LOCK) {
        UUID.fromString(id);
        JSONObject state = read(); expire(state); JSONArray drafts = state.getJSONArray("drafts");
        for (int i=0; i<drafts.length(); i++) if (id.equals(drafts.getJSONObject(i).getString("id"))) return id;
        if (drafts.length() >= 10) throw new IOException("보관 중인 공유가 10개입니다. 본앱에서 먼저 저장하거나 삭제해 주세요.");
        long total = bytes == null ? 0 : bytes.length;
        for (int i=0; i<drafts.length(); i++) total += imageFile(drafts.getJSONObject(i).getString("id")).length();
        if (total > MAX_TOTAL) throw new IOException("공유 보관 공간이 가득 찼습니다. 본앱에서 대기 항목을 정리해 주세요.");
        JSONObject draft = new JSONObject().put("id", id).put("createdAt", System.currentTimeMillis())
            .put("kind", bytes == null ? "link" : "image").put("state", "ready")
            .put("label", bytes == null ? url : "스크린샷");
        if (bytes == null) draft.put("url", url).put("rawText", text);
        else {
            if (bytes.length > MAX_IMAGE) throw new IOException("이미지는 10MiB 이하만 공유할 수 있습니다.");
            draft.put("mime", mime);
            try (FileOutputStream output = new FileOutputStream(imageFile(id))) { output.write(bytes); output.getFD().sync(); }
            catch (Exception failure) { imageFile(id).delete(); throw failure; }
        }
        drafts.put(draft);
        try { write(state); } catch (Exception error) { imageFile(id).delete(); throw error; }
        return id;
    }}
    public JSONObject draft(String id) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); expire(state);
        for (int i=0; i<state.getJSONArray("drafts").length(); i++) {
            JSONObject item = state.getJSONArray("drafts").getJSONObject(i);
            if (id.equals(item.getString("id"))) return item;
        }
        return null;
    }}
    File imageFile(String id) {
        // Only generated and validated UUIDs may address files.
        UUID.fromString(id); return new File(directory, id + ".image");
    }
    public JSONObject begin(String id, long expectedRevision, String expectedUser) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); JSONObject auth = credential(state);
        if (auth == null || expiry(auth.getString("expiresAt")) <= System.currentTimeMillis())
            throw new IOException("본앱에서 로그인 상태를 확인한 뒤 대기 중인 공유를 다시 열어 주세요.");
        if (state.getLong("revision") != expectedRevision || !auth.getString("userId").equals(expectedUser))
            throw new IOException("저장 계정이 변경되었습니다. 계정을 확인한 뒤 다시 시도해 주세요.");
        if (!baseUrl().equals(auth.getString("apiBaseUrl").replaceAll("/+$", ""))) throw new IOException("앱 환경이 변경되었습니다. 본앱에서 다시 준비해 주세요.");
        JSONArray drafts = state.getJSONArray("drafts");
        for (int i=0; i<drafts.length(); i++) {
            JSONObject item = drafts.getJSONObject(i); if (!id.equals(item.getString("id"))) continue;
            if (item.has("userId") && !item.getString("userId").equals(expectedUser)) throw new IOException("처음 저장을 요청한 계정에서만 재시도할 수 있습니다.");
            if (item.has("apiBaseUrl") && !baseUrl().equals(item.getString("apiBaseUrl"))) throw new IOException("다른 서버에서 시작한 공유입니다. 원래 앱 환경에서 확인해 주세요.");
            item.put("userId", expectedUser).put("apiBaseUrl", baseUrl()).put("state", "sending"); write(state);
            return new JSONObject().put("draft", item).put("credential", auth).put("revision", expectedRevision);
        }
        throw new IOException("공유 항목이 만료되었거나 삭제되었습니다.");
    }}
    public boolean sameAccount(long revision, String user) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); JSONObject auth = credential(state);
        return state.getLong("revision") == revision && auth != null && user.equals(auth.optString("userId"))
            && expiry(auth.getString("expiresAt")) > System.currentTimeMillis()
            && baseUrl().equals(auth.getString("apiBaseUrl").replaceAll("/+$", ""));
    }}
    public void rejectCredential(long expectedRevision, String expectedToken) throws Exception { synchronized (LOCK) {
        JSONObject state = read();
        JSONObject auth = credential(state);
        if (state.getLong("revision") == expectedRevision && auth != null && expectedToken.equals(auth.optString("token"))) {
            state.put("revision", expectedRevision + 1); state.remove("encryptedCredential"); write(state);
        }
    }}
    public void setState(String id, String value) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); JSONArray drafts = state.getJSONArray("drafts");
        for (int i=0; i<drafts.length(); i++) if (id.equals(drafts.getJSONObject(i).getString("id"))) drafts.getJSONObject(i).put("state", value);
        write(state);
    }}
    public void complete(String id, String user, String contentId) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); JSONArray receipts = state.getJSONArray("receipts");
        boolean exists = false;
        for (int i=0; i<receipts.length(); i++) if (id.equals(receipts.getJSONObject(i).getString("id"))) exists = true;
        if (!exists) receipts.put(new JSONObject().put("id", id).put("userId", user).put("contentId", contentId).put("apiBaseUrl", baseUrl()));
        removeDraft(state, id); write(state); imageFile(id).delete();
    }}
    public void discard(String id) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); removeDraft(state, id); write(state); imageFile(id).delete();
    }}
    private void removeDraft(JSONObject state, String id) throws Exception {
        JSONArray kept = new JSONArray(), drafts = state.getJSONArray("drafts");
        for (int i=0; i<drafts.length(); i++) if (!id.equals(drafts.getJSONObject(i).getString("id"))) kept.put(drafts.get(i));
        state.put("drafts", kept);
    }
    public void acknowledge(List<?> ids) throws Exception { synchronized (LOCK) {
        JSONObject state = read(); JSONArray kept = new JSONArray(), receipts = state.getJSONArray("receipts");
        for (int i=0; i<receipts.length(); i++) {
            JSONObject receipt = receipts.getJSONObject(i);
            if (!baseUrl().equals(receipt.optString("apiBaseUrl")) || !ids.contains(receipt.getString("id"))) kept.put(receipt);
        }
        state.put("receipts", kept); write(state);
    }}
}
