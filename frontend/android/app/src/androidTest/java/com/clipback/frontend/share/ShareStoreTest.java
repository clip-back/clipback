package com.clipback.frontend.share;

import android.content.Intent;
import android.test.InstrumentationTestCase;
import org.json.JSONObject;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Collections;

/** Runs against actual Android Keystore and the app-private durable store. */
public final class ShareStoreTest extends InstrumentationTestCase {
    private ShareStore store;
    @Override protected void setUp() throws Exception {
        super.setUp(); store=new ShareStore(getInstrumentation().getTargetContext()); clearDraftsAndReceipts(); store.blockCredential();
    }
    @Override protected void tearDown() throws Exception { clearDraftsAndReceipts(); store.blockCredential(); super.tearDown(); }
    private void clearDraftsAndReceipts() throws Exception {
        JSONObject state=store.snapshot();
        for(int i=0;i<state.getJSONArray("drafts").length();i++)store.discard(state.getJSONArray("drafts").getJSONObject(i).getString("id"));
        for(int i=0;i<state.getJSONArray("receipts").length();i++)store.acknowledge(Collections.singletonList(state.getJSONArray("receipts").getJSONObject(i).getString("id")));
    }
    private JSONObject credential(long revision,String user,String expires) throws Exception {
        return new JSONObject().put("revision",revision).put("token","fixture-share-token-never-main-token").put("expiresAt",expires)
            .put("userId",user).put("sessionId","11").put("accountLabel","테스트 계정").put("apiBaseUrl",ShareStore.baseUrl());
    }
    private long revision() throws Exception { return store.snapshot().getLong("revision"); }
    public void testCredentialEncryptedAndRedactedAcrossStoreRecreation() throws Exception {
        assertTrue(store.publishCredential(credential(revision(),"7","2035-01-01T00:00:00Z")));
        JSONObject restored=new ShareStore(getInstrumentation().getTargetContext()).snapshot();
        assertEquals("7",restored.getJSONObject("credential").getString("userId"));
        assertFalse(restored.getJSONObject("credential").has("token"));
        File state=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share/state.json");
        String encoded=new String(Files.readAllBytes(state.toPath()),StandardCharsets.UTF_8);
        assertFalse(encoded.contains("fixture-share-token")); assertFalse(encoded.contains("테스트 계정"));
    }
    public void testBlockRejectsLateMintAndOlderExpiry() throws Exception {
        long old=revision(); long next=store.blockCredential();
        assertFalse(store.publishCredential(credential(old,"7","2035-01-01T00:00:00Z")));
        assertTrue(store.publishCredential(credential(next,"7","2035-01-01T00:00:00Z")));
        assertFalse(store.publishCredential(credential(next,"7","2034-01-01T00:00:00Z")));
        assertFalse(store.publishCredential(credential(next,"8","2036-01-01T00:00:00Z")));
        assertNull(new ShareStore(getInstrumentation().getTargetContext()).snapshot().getJSONObject("credential").opt("token"));
    }
    public void testEnvironmentAndExpiredCredentialRejected() throws Exception {
        assertFalse(store.publishCredential(credential(revision(),"7","2000-01-01T00:00:00Z")));
        assertFalse(store.publishCredential(credential(revision(),"7","2035-01-01T00:00:00Z").put("apiBaseUrl","https://elsewhere.invalid/api/v1")));
    }
    public void testLateUnauthorizedCannotBlockReplacementShareCredential() throws Exception {
        long current=revision();
        assertTrue(store.publishCredential(credential(current,"7","2034-01-01T00:00:00Z").put("token","old-share-token")));
        assertTrue(store.publishCredential(credential(current,"7","2035-01-01T00:00:00Z").put("token","replacement-share-token")));
        store.rejectCredential(current,"old-share-token");
        assertEquals(current,revision());assertFalse(store.snapshot().isNull("credential"));
        store.rejectCredential(current,"replacement-share-token");
        assertEquals(current+1,revision());assertTrue(store.snapshot().isNull("credential"));
    }
    public void testAccountGuardAndSubmittedDraftOwnership() throws Exception {
        long first=revision(); assertTrue(store.publishCredential(credential(first,"7","2035-01-01T00:00:00Z")));
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);
        store.begin(id,first,"7");
        long second=store.blockCredential(); assertTrue(store.publishCredential(credential(second,"8","2035-01-01T00:00:00Z")));
        try { store.begin(id,first,"7"); fail("stale revision must fail"); } catch(java.io.IOException expected) { }
        try { store.begin(id,second,"8"); fail("submitted draft cannot change user"); } catch(java.io.IOException expected) { }
        assertEquals("7",store.draft(id).getString("userId"));
        assertFalse(store.sameAccount(first,"7"));
    }
    public void testRetryKeepsOperationAndReceiptsAreDurable() throws Exception {
        long current=revision(); store.publishCredential(credential(current,"7","2035-01-01T00:00:00Z"));
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);
        store.begin(id,current,"7"); store.setState(id,"unknown");
        assertEquals(id,new ShareStore(getInstrumentation().getTargetContext()).begin(id,current,"7").getJSONObject("draft").getString("id"));
        String content="1001";
        store.complete(id,"7",content); store.complete(id,"7",content);
        assertNull(store.draft(id)); assertEquals(1,store.snapshot().getJSONArray("receipts").length());
        store.acknowledge(Collections.singletonList(id)); assertEquals(0,store.snapshot().getJSONArray("receipts").length());
    }
    public void testCapacityRejectsWithoutEvictingAndNewSharesHaveDifferentKeys() throws Exception {
        String first=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);
        for(int i=1;i<10;i++)assertFalse(first.equals(store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null)));
        try { store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null); fail("limit"); } catch(java.io.IOException expected) { }
        assertNotNull(store.draft(first)); assertEquals(10,store.snapshot().getJSONArray("drafts").length());
    }
    public void testExternalIntentCannotSelectPrivateDraftOrCredentials() throws Exception {
        Intent intent=new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"https://youtu.be/dQw4w9WgXcQ")
            .putExtra("draftId","malicious").putExtra("apiBaseUrl","https://elsewhere.invalid").putExtra("userId","attacker");
        String id=ShareInput.receive(getInstrumentation().getTargetContext(),intent,store);
        assertFalse("malicious".equals(id)); assertFalse(store.draft(id).has("userId"));
        assertFalse(store.draft(id).has("apiBaseUrl"));
    }
    public void testUnsupportedPayloadsAndMultipleUrlsRejected() throws Exception {
        for(Intent intent:new Intent[]{new Intent(Intent.ACTION_SEND_MULTIPLE).setType("image/png"),
            new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"https://example.com"),
            new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"https://youtu.be/dQw4w9WgXcQ https://instagram.com/p/test/")}) {
            try { ShareInput.receive(getInstrumentation().getTargetContext(),intent,store); fail("unsupported input"); } catch(java.io.IOException expected) { }
        }
        assertNull(ShareInput.imageMime("not an image".getBytes(StandardCharsets.UTF_8)));
        Intent music=new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"https://music.youtube.com:443/watch?v=dQw4w9WgXcQ");
        assertNotNull(store.draft(ShareInput.receive(getInstrumentation().getTargetContext(),music,store)));
        for(String value:new String[]{"https://youtube.com.evil.invalid/watch?v=dQw4w9WgXcQ","https://user:pass@youtube.com/watch?v=dQw4w9WgXcQ","https://youtube.com:8443/watch?v=dQw4w9WgXcQ"}) {
            try { ShareInput.receive(getInstrumentation().getTargetContext(),new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,value),store); fail("invalid host or authority"); } catch(java.io.IOException expected) { }
        }
    }
    public void testCredentialStorageFailureDoesNotAdvanceRevision() throws Exception {
        long before=revision();
        File directory=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share");
        assertTrue(directory.setWritable(false));
        try {
            try { store.blockCredential(); fail("unwritable storage must be reported"); } catch(java.io.IOException expected) { }
        } finally { assertTrue(directory.setWritable(true)); }
        assertEquals(before,revision());
    }
    public void testMissingKeystoreKeyFailsClosedAndCanBeReprepared() throws Exception {
        long before=revision();store.publishCredential(credential(before,"7","2035-01-01T00:00:00Z"));
        java.security.KeyStore keys=java.security.KeyStore.getInstance("AndroidKeyStore");keys.load(null);keys.deleteEntry("com.huturu.app.share.v1");
        try {
            try { store.snapshot(); fail("encrypted credential must not silently fall back"); } catch(javax.crypto.AEADBadTagException expected) { }
        } finally { store.blockCredential(); }
        assertTrue(store.publishCredential(credential(revision(),"7","2035-01-01T00:00:00Z")));
    }
    public void testSubmittedDraftCannotBeRetriedInAnotherEnvironment() throws Exception {
        long current=revision();store.publishCredential(credential(current,"7","2035-01-01T00:00:00Z"));
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);store.begin(id,current,"7");
        assertEquals(ShareStore.baseUrl(),store.draft(id).getString("apiBaseUrl"));
        File file=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share/state.json");
        JSONObject state=new JSONObject(new String(Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));
        state.getJSONArray("drafts").getJSONObject(0).put("apiBaseUrl","https://other-environment.invalid/api/v1");
        Files.write(file.toPath(),state.toString().getBytes(StandardCharsets.UTF_8));
        try { store.begin(id,current,"7"); fail("submitted draft environment must remain bound"); } catch(java.io.IOException expected) { }
    }
    public void testOtherEnvironmentReceiptIsNotExposedOrAcknowledged() throws Exception {
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);store.complete(id,"7","1001");
        File file=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share/state.json");
        JSONObject state=new JSONObject(new String(Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));
        state.getJSONArray("receipts").getJSONObject(0).put("apiBaseUrl","https://other-environment.invalid/api/v1");
        Files.write(file.toPath(),state.toString().getBytes(StandardCharsets.UTF_8));
        try {
            assertEquals(0,store.snapshot().getJSONArray("receipts").length());store.acknowledge(Collections.singletonList(id));
            JSONObject persisted=new JSONObject(new String(Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));
            assertEquals(1,persisted.getJSONArray("receipts").length());
        } finally {
            state.put("receipts",new org.json.JSONArray());Files.write(file.toPath(),state.toString().getBytes(StandardCharsets.UTF_8));
        }
    }
    public void testAtomicBackupRecoveryPreservesDurableAccountRevision() throws Exception {
        long current=revision();store.publishCredential(credential(current,"7","2035-01-01T00:00:00Z"));
        File file=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share/state.json");
        assertTrue(file.renameTo(new File(file.getPath()+".bak")));
        JSONObject restored=new ShareStore(getInstrumentation().getTargetContext()).snapshot();
        assertEquals(current,restored.getLong("revision"));assertEquals("7",restored.getJSONObject("credential").getString("userId"));
    }
    public void testSnapshotCleansOnlyOrphanedOwnedImages() throws Exception {
        String active=store.create(null,null,new byte[]{1,2,3},"image/png");
        File orphan=store.imageFile(java.util.UUID.randomUUID().toString());Files.write(orphan.toPath(),new byte[]{1,2,3});
        File unrelated=new File(orphan.getParentFile(),"notes.image");Files.write(unrelated.toPath(),new byte[]{1});
        try {
            store.snapshot();assertTrue(store.imageFile(active).exists());assertFalse(orphan.exists());assertTrue(unrelated.exists());
        } finally { unrelated.delete(); }
    }
}
