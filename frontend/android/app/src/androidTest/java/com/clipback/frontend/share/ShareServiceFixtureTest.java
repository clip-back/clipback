package com.clipback.frontend.share;

import android.test.InstrumentationTestCase;
import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Run explicitly with the loopback share_fixture_server.py and the fixture APK. */
public final class ShareServiceFixtureTest extends InstrumentationTestCase {
    private ShareStore store;
    private Activity activity;
    @Override protected void setUp() throws Exception {
        super.setUp();
        assertEquals("http://10.0.2.2:18765/api/v1",ShareStore.baseUrl());
        store=new ShareStore(getInstrumentation().getTargetContext());
        cleanup();store.blockCredential();prepare();
        control(new JSONObject().put("next_save_status",201).put("save_delay_seconds",0).put("lose_response",false));
    }
    @Override protected void tearDown() throws Exception {
        if(activity!=null)getInstrumentation().runOnMainSync(() -> activity.finish());
        cleanup();store.blockCredential();super.tearDown();
    }
    private void cleanup() throws Exception {
        JSONObject state=store.snapshot();
        for(int i=0;i<state.getJSONArray("drafts").length();i++)store.discard(state.getJSONArray("drafts").getJSONObject(i).getString("id"));
        for(int i=0;i<state.getJSONArray("receipts").length();i++)store.acknowledge(Collections.singletonList(state.getJSONArray("receipts").getJSONObject(i).getString("id")));
    }
    private void prepare() throws Exception {
        JSONObject auth=http("/auth/share-credential",new JSONObject());
        assertTrue(store.publishCredential(new JSONObject().put("revision",store.snapshot().getLong("revision"))
            .put("token",auth.getString("share_token")).put("expiresAt",auth.getString("expires_at"))
            .put("userId",auth.get("user_id")).put("sessionId",auth.get("session_id"))
            .put("accountLabel","공유 테스트 계정").put("apiBaseUrl",ShareStore.baseUrl())));
    }
    private JSONObject http(String path,JSONObject body) throws Exception {
        HttpURLConnection connection=(HttpURLConnection)new URL(ShareStore.baseUrl()+path).openConnection();
        connection.setConnectTimeout(5000);connection.setReadTimeout(5000);
        if(body!=null){connection.setRequestMethod("POST");connection.setDoOutput(true);connection.setRequestProperty("Content-Type","application/json");
            try(OutputStream output=connection.getOutputStream()){output.write(body.toString().getBytes(StandardCharsets.UTF_8));}}
        try(InputStream input=connection.getInputStream();ByteArrayOutputStream output=new ByteArrayOutputStream()) {
            byte[] buffer=new byte[1024];int count;while((count=input.read(buffer))!=-1)output.write(buffer,0,count);
            return new JSONObject(output.toString("UTF-8"));
        }finally{connection.disconnect();}
    }
    private void control(JSONObject value) throws Exception { http("/__test/control",value); }
    private int saved() throws Exception {return http("/__test/state",null).getInt("saved");}
    private int saveRequests() throws Exception {return http("/__test/state",null).getInt("save_requests");}
    private String draft() throws Exception {return store.create("https://youtu.be/dQw4w9WgXcQ","https://youtu.be/dQw4w9WgXcQ",null,null);}
    private boolean save(String id) throws Exception {
        CountDownLatch finished=new CountDownLatch(1);boolean[] success={false};
        ShareService.execute(store,id,store.snapshot().getLong("revision"),"7",(ignored,message,result)->{success[0]=result;finished.countDown();});
        assertTrue("Native request must finish within its deadline",finished.await(40,TimeUnit.SECONDS));return success[0];
    }
    public void testConcurrentNativeRequestsShareOneWriteAndReceipt() throws Exception {
        int before=saved();String id=draft();control(new JSONObject().put("save_delay_seconds",1));
        CountDownLatch finished=new CountDownLatch(2);boolean[] results={false,false};long revision=store.snapshot().getLong("revision");
        ShareService.execute(store,id,revision,"7",(ignored,message,result)->{results[0]=result;finished.countDown();});
        ShareService.execute(store,id,revision,"7",(ignored,message,result)->{results[1]=result;finished.countDown();});
        assertTrue(finished.await(10,TimeUnit.SECONDS));assertTrue(results[0]);assertTrue(results[1]);
        assertEquals(before+1,saved());assertEquals(1,store.snapshot().getJSONArray("receipts").length());assertNull(store.draft(id));
    }
    public void testUnauthorizedKeepsDraftAndOnlyBlocksShareCredential() throws Exception {
        String id=draft();control(new JSONObject().put("next_save_status",401));
        assertFalse(save(id));assertEquals("authRequired",store.draft(id).getString("state"));assertTrue(store.snapshot().isNull("credential"));
        prepare();assertTrue(save(id));assertNull(store.draft(id));
    }
    public void testLostResponseRetryDoesNotCreateSecondContent() throws Exception {
        int before=saved();String id=draft();control(new JSONObject().put("lose_response",true));
        boolean completed=save(id);
        if(!completed){assertEquals("unknown",store.draft(id).getString("state"));assertTrue(save(id));}
        assertEquals(before+1,saved());assertEquals(1,store.snapshot().getJSONArray("receipts").length());
    }
    public void testThirtySecondDeadlinePreservesSameOperationForRetry() throws Exception {
        int before=saved();String id=draft();control(new JSONObject().put("save_delay_seconds",31));
        long start=System.currentTimeMillis();assertFalse(save(id));long elapsed=System.currentTimeMillis()-start;
        assertTrue("Expected the network deadline",elapsed>=29000 && elapsed<39000);
        assertEquals("unknown",store.draft(id).getString("state"));assertTrue(save(id));
        assertEquals(before+1,saved());assertNull(store.draft(id));
    }
    public void testImageRetryUsesOriginalBytesAndRemovesOwnedFileAfterSuccess() throws Exception {
        int before=saved();ByteArrayOutputStream image=new ByteArrayOutputStream();
        android.graphics.Bitmap bitmap=android.graphics.Bitmap.createBitmap(24,24,android.graphics.Bitmap.Config.ARGB_8888);
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,image);bitmap.recycle();
        String id=store.create(null,null,image.toByteArray(),"image/png");
        control(new JSONObject().put("lose_response",true));
        if(!save(id))assertTrue(save(id));
        assertEquals(before+1,saved());assertFalse(store.imageFile(id).exists());assertNull(store.draft(id));
    }
    public void testAccountChangeDuringSubmittedRequestDoesNotShowSuccessForNewAccount() throws Exception {
        int before=saved();String id=draft();control(new JSONObject().put("save_delay_seconds",2));
        CountDownLatch finished=new CountDownLatch(1);boolean[] success={true};
        ShareService.execute(store,id,store.snapshot().getLong("revision"),"7",(ignored,message,result)->{success[0]=result;finished.countDown();});
        long deadline=System.currentTimeMillis()+5000;
        while(saved()==before && System.currentTimeMillis()<deadline)Thread.sleep(20);
        assertEquals(before+1,saved());store.blockCredential();
        assertTrue(finished.await(10,TimeUnit.SECONDS));assertFalse(success[0]);
        assertEquals("7",store.snapshot().getJSONArray("receipts").getJSONObject(0).getString("userId"));
        assertNull(store.draft(id));assertTrue(store.snapshot().isNull("credential"));
    }
    private TextView text(View view, String value) {
        if (view instanceof TextView && value.contentEquals(((TextView)view).getText())) return (TextView)view;
        if (view instanceof ViewGroup) for (int i=0;i<((ViewGroup)view).getChildCount();i++) {
            TextView found=text(((ViewGroup)view).getChildAt(i),value); if(found!=null)return found;
        }
        return null;
    }
    private void imageError(int status, String code, String message, String artifact) throws Exception {
        ByteArrayOutputStream image=new ByteArrayOutputStream();
        android.graphics.Bitmap bitmap=android.graphics.Bitmap.createBitmap(24,24,android.graphics.Bitmap.Config.ARGB_8888);
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,image);bitmap.recycle();
        String id=store.create(null,null,image.toByteArray(),"image/png");
        control(new JSONObject().put("next_save_status",status).put("next_save_detail",new JSONObject().put("code",code)));
        Intent intent=new Intent(getInstrumentation().getTargetContext(),ShareRecoveryActivity.class)
            .putExtra("draftId",id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        Activity activity=getInstrumentation().startActivitySync(intent);
        try {
            getInstrumentation().runOnMainSync(() -> ((Button)text(activity.getWindow().getDecorView(),"저장")).performClick());
            long until=System.currentTimeMillis()+10000;boolean[] found={false};
            while(System.currentTimeMillis()<until) {
                getInstrumentation().runOnMainSync(() -> found[0]=text(activity.getWindow().getDecorView(),message)!=null);
                if(found[0])break;Thread.sleep(50);
            }
            assertTrue("The existing share status must show the specific image error",found[0]);
            assertEquals("failed",store.draft(id).getString("state"));
            assertFalse(store.snapshot().isNull("credential"));
            android.graphics.Bitmap screenshot=getInstrumentation().getUiAutomation().takeScreenshot();
            assertNotNull(screenshot);
            File destination=new File(getInstrumentation().getTargetContext().getExternalFilesDir(null),artifact+".png");
            try(OutputStream output=new FileOutputStream(destination)) { screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG,100,output); }
            screenshot.recycle();
        } finally { getInstrumentation().runOnMainSync(activity::finish); }
    }
    public void testImageQuotaUsesExistingShareErrorRegion() throws Exception {
        imageError(409,"image_quota_exceeded","이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.","android-share-image-quota");
    }
    public void testImagePauseUsesExistingShareErrorRegion() throws Exception {
        int before=saved();
        imageError(409,"image_uploads_paused","이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.","android-share-image-paused");
        assertEquals(before,saved());
        String id=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        assertTrue(save(id));assertEquals(before+1,saved());
        assertNull(store.draft(id));assertFalse(store.imageFile(id).exists());
    }
    public void testImageFileLimitUsesExistingShareErrorRegion() throws Exception {
        imageError(413,"image_file_too_large","이미지는 10MiB 이하만 저장할 수 있습니다.","android-share-image-file-limit");
    }
    private Intent sharedLink() {
        return new Intent(getInstrumentation().getTargetContext(),ShareActivity.class).setAction(Intent.ACTION_SEND).setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT,"https://youtu.be/dQw4w9WgXcQ").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    }
    private String onlyDraft() throws Exception {
        assertEquals(1,store.snapshot().getJSONArray("drafts").length());return store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
    }
    private void tapSaveRepeatedly() throws Exception { for(int i=0;i<3;i++)ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save")); }
    /** The sheet goes down, the in-window completion toast shows for a moment, then the share window closes by itself. */
    private void assertCompletedOnce(int before,int requests) throws Exception {
        long until=System.currentTimeMillis()+15000;java.util.List<String>[] texts=new java.util.List[1];
        while(System.currentTimeMillis()<until) {
            getInstrumentation().runOnMainSync(() -> texts[0]=ShareActivityTest.visibleTexts(activity.getWindow().getDecorView()));
            if(texts[0].equals(Collections.singletonList("저장 완료!")))break;Thread.sleep(20);
        }
        assertEquals(Collections.singletonList("저장 완료!"),texts[0]);
        long shown=System.currentTimeMillis();assertFalse(activity.isFinishing());
        ShareActivityTest.awaitFinishing(activity);long elapsed=System.currentTimeMillis()-shown;
        assertTrue("The completion toast stays for about 1.5 seconds: "+elapsed,elapsed>=1000 && elapsed<4000);
        assertEquals(requests+1,saveRequests());assertEquals(before+1,saved());assertEquals(0,store.snapshot().getJSONArray("drafts").length());
    }
    public void testLinkShareSavesOnceDespiteTapsWhilePreparingAndSaving() throws Exception {
        int before=saved(),requests=saveRequests();control(new JSONObject().put("save_delay_seconds",1));
        synchronized(ShareStore.LOCK) { activity=getInstrumentation().startActivitySync(sharedLink());tapSaveRepeatedly(); }
        ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        assertEquals(requests,saveRequests());tapSaveRepeatedly();assertCompletedOnce(before,requests);
    }
    public void testImageShareUsesSameSheetAndSavesOnce() throws Exception {
        int before=saved(),requests=saveRequests();
        Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        ShareTestSenderActivity.shareDirectly(getInstrumentation(),"image");
        activity=monitor.waitForActivityWithTimeout(10000);getInstrumentation().removeMonitor(monitor);assertNotNull(activity);
        ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        assertEquals("image",store.draft(onlyDraft()).getString("kind"));
        java.util.List<String>[] texts=new java.util.List[1];
        getInstrumentation().runOnMainSync(() -> texts[0]=ShareActivityTest.visibleTexts(activity.getWindow().getDecorView()));
        assertEquals(Arrays.asList("저장하기",ShareActivityTest.GUIDE),texts[0]);
        tapSaveRepeatedly();assertCompletedOnce(before,requests);
    }
    public void testCloseDuringSaveAfterRecreationKeepsShareAndRetryDoesNotDuplicate() throws Exception {
        int before=saved(),requests=saveRequests();
        activity=getInstrumentation().startActivitySync(sharedLink());ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        String id=onlyDraft();control(new JSONObject().put("save_delay_seconds",2).put("lose_response",true));
        ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
        long until=System.currentTimeMillis()+5000;while(saveRequests()==requests && System.currentTimeMillis()<until)Thread.sleep(20);
        assertEquals(requests+1,saveRequests());
        Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        getInstrumentation().runOnMainSync(() -> activity.recreate());
        activity=recreated.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(recreated);assertNotNull(activity);
        getInstrumentation().waitForIdleSync();
        getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);ShareActivityTest.awaitFinishing(activity);
        assertEquals("unknown",store.draft(id).getString("state"));
        until=System.currentTimeMillis()+40000;while(ShareService.isActive(id) && System.currentTimeMillis()<until)Thread.sleep(50);
        assertEquals("unknown",store.draft(id).getString("state"));
        assertTrue(save(id));assertEquals(before+1,saved());assertNull(store.draft(id));
    }
    private void assertFailureAlertKeepsShare(int status,String message,String state) throws Exception {
        activity=getInstrumentation().startActivitySync(sharedLink());ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        String id=onlyDraft();control(new JSONObject().put("next_save_status",status));
        ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
        ShareActivityTest.pressAlertButton(getInstrumentation(),ShareActivityTest.awaitAlert(getInstrumentation(),message),"닫기");
        ShareActivityTest.awaitFinishing(activity);assertEquals(state,store.draft(id).getString("state"));
    }
    public void testServerFailureShowsExistingMessageInAlertAndKeepsShare() throws Exception {
        assertFailureAlertKeepsShare(500,"지금 저장하지 못했어요. 잠시 후 같은 항목으로 다시 시도해 주세요.","failed");
    }
    public void testUnauthorizedSaveShowsExistingMessageInAlertAndKeepsShare() throws Exception {
        assertFailureAlertKeepsShare(401,"로그인 상태 확인이 필요해요. 초안을 보관했습니다. 본앱을 열어 대기 중인 공유를 다시 선택해 주세요.","authRequired");
    }
}
