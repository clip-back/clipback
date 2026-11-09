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
    private String captureInput;
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
        if(captureInput!=null)captureState("SL-03-"+captureInput);
        ShareActivityTest.awaitFinishing(activity);long elapsed=System.currentTimeMillis()-shown;
        assertTrue("The completion toast stays for about 1.5 seconds: "+elapsed,elapsed>=1000 && elapsed<4000);
        assertEquals(requests+1,saveRequests());assertEquals(before+1,saved());assertEquals(0,store.snapshot().getJSONArray("drafts").length());
    }
    /** Native capture entry point; also reusable after review with the same fixture and device settings. */
    private void captureState(String name) throws Exception {
        File directory=new File(getInstrumentation().getTargetContext().getExternalFilesDir(null),"share-loading");
        assertTrue(directory.isDirectory() || directory.mkdirs());
        android.graphics.Bitmap screenshot=getInstrumentation().getUiAutomation().takeScreenshot();
        assertNotNull(screenshot);
        try(FileOutputStream output=new FileOutputStream(new File(directory,name+".png"))) {
            assertTrue(screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG,100,output));
        }
        android.view.WindowInsets[] insets=new android.view.WindowInsets[1];
        int[] rootSize=new int[2], sheetPadding=new int[4];
        getInstrumentation().runOnMainSync(() -> {
            View root=activity.getWindow().getDecorView();insets[0]=root.getRootWindowInsets();
            rootSize[0]=root.getWidth();rootSize[1]=root.getHeight();
            View sheet=ShareActivityTest.tagged(activity,"share.sheet");
            if(sheet!=null) {
                sheetPadding[0]=sheet.getPaddingLeft();sheetPadding[1]=sheet.getPaddingTop();
                sheetPadding[2]=sheet.getPaddingRight();sheetPadding[3]=sheet.getPaddingBottom();
            }
        });
        JSONObject evidence=new JSONObject().put("state",name).put("capturedAt",System.currentTimeMillis())
            .put("rootSizePx",new org.json.JSONArray(rootSize)).put("sheetPaddingPx",new org.json.JSONArray(sheetPadding))
            .put("systemInsetsPx",insets[0]==null ? JSONObject.NULL : new org.json.JSONArray(new int[]{
                insets[0].getSystemWindowInsetLeft(),insets[0].getSystemWindowInsetTop(),
                insets[0].getSystemWindowInsetRight(),insets[0].getSystemWindowInsetBottom()}))
            .put("inputProvenance","native instrumentation/explicit share intent")
            .put("fontScale",getInstrumentation().getTargetContext().getResources().getConfiguration().fontScale)
            .put("density",getInstrumentation().getTargetContext().getResources().getDisplayMetrics().density)
            .put("width",screenshot.getWidth()).put("height",screenshot.getHeight())
            .put("os",android.os.Build.VERSION.RELEASE).put("sdk",android.os.Build.VERSION.SDK_INT)
            .put("fixture",http("/__test/state",null));
        try(FileOutputStream output=new FileOutputStream(new File(directory,name+".json"))) {
            output.write(evidence.toString(2).getBytes(StandardCharsets.UTF_8));
        }
        screenshot.recycle();
    }
    public void testCaptureShareLoadingStates() throws Exception {
        for(String input:new String[]{"youtube","instagram","image"}) {
            captureInput=input;
            if("image".equals(input)) {
                Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
                ShareTestSenderActivity.shareDirectly(getInstrumentation(),"image");
                activity=monitor.waitForActivityWithTimeout(10000);getInstrumentation().removeMonitor(monitor);assertNotNull(activity);
            } else {
                Intent intent=sharedLink();
                if("instagram".equals(input))intent.putExtra(Intent.EXTRA_TEXT,"https://www.instagram.com/p/fixture/");
                activity=getInstrumentation().startActivitySync(intent);
            }
            ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
            ShareActivityTest.settledLocation(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            captureState("SL-01-"+input);
            int before=saved(),requests=saveRequests();
            control(new JSONObject().put("hold_save",true));
            try {
                ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
                long until=System.currentTimeMillis()+5000;
                while(saveRequests()==requests && System.currentTimeMillis()<until)Thread.sleep(20);
                assertEquals(requests+1,saveRequests());
                captureState("SL-02-"+input);
                tapSaveRepeatedly();assertEquals(requests+1,saveRequests());
                if("youtube".equals(input)) {
                    Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
                    getInstrumentation().runOnMainSync(() -> activity.recreate());
                    activity=monitor.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(monitor);assertNotNull(activity);
                    getInstrumentation().waitForIdleSync();captureState("SL-07-youtube");
                }
            } finally { control(new JSONObject().put("release_save",true)); }
            assertCompletedOnce(before,requests);
        }
    }
    public void testCapturePreparationAndDismissStates() throws Exception {
        synchronized(ShareStore.LOCK) {
            activity=getInstrumentation().startActivitySync(sharedLink());
            ShareActivityTest.settledLocation(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            assertFalse(ShareActivityTest.tagged(activity,"share.save").isEnabled());
            captureState("SL-08-preparing");
        }
        ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        String id=onlyDraft();int requests=saveRequests();
        control(new JSONObject().put("hold_save",true));
        try {
            ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            long until=System.currentTimeMillis()+5000;
            while(saveRequests()==requests && System.currentTimeMillis()<until)Thread.sleep(20);
            assertEquals(requests+1,saveRequests());
            captureState("SL-06-before-back");
            getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);
            ShareActivityTest.awaitFinishing(activity);captureState("SL-06-after-back");
        } finally { control(new JSONObject().put("release_save",true)); }
        long until=System.currentTimeMillis()+5000;
        while(ShareService.isActive(id) && System.currentTimeMillis()<until)Thread.sleep(20);
        assertFalse(ShareService.isActive(id));captureState("SL-06-after-late-response");
    }
    public void testCaptureRetryStates() throws Exception {
        JSONObject[] failures={new JSONObject().put("next_save_status",500),new JSONObject().put("lose_response",true),
            new JSONObject().put("save_delay_seconds",31),new JSONObject().put("next_save_status",422)};
        for(int index=0;index<failures.length;index++) {
            int before=saved(),requests=saveRequests();
            android.view.accessibility.AccessibilityNodeInfo alert=failSave(failures[index],RETRY_TITLE,index==3?CHECK_INPUT:UNCONFIRMED,"다시 시도","닫기");
            captureState("SL-04-failure-"+index);
            control(new JSONObject().put("hold_save",true));
            try {
                ShareActivityTest.pressAlertButton(getInstrumentation(),alert,"다시 시도");
                long until=System.currentTimeMillis()+5000;
                while(saveRequests()<requests+2 && System.currentTimeMillis()<until)Thread.sleep(20);
                assertEquals(requests+2,saveRequests());captureState("SL-04-retry-"+index);
            } finally { control(new JSONObject().put("release_save",true)); }
            assertCompletedOnce(before,requests+1);
        }
    }
    public void testCaptureNonRetryableStates() throws Exception {
        int[] statuses={401,410,409,413,409};
        String[] titles={"로그인이 필요해요","다시 저장할 수 없어요","다시 저장할 수 없어요","다시 저장할 수 없어요","지금은 저장할 수 없어요"};
        String[] names={"401","410","409","413","quota"};
        for(int index=0;index<statuses.length;index++) {
            cleanup();store.blockCredential();prepare();
            activity=getInstrumentation().startActivitySync(sharedLink());
            ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
            JSONObject failure=new JSONObject().put("next_save_status",statuses[index]);
            if(index==4)failure.put("next_save_detail",new JSONObject().put("code","image_quota_exceeded"));
            control(failure);
            ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            android.view.accessibility.AccessibilityNodeInfo alert=ShareActivityTest.awaitAlert(getInstrumentation(),titles[index]);
            if(index==0)ShareActivityTest.awaitSheetHidden(getInstrumentation(),activity);
            captureState("SL-05-"+names[index]);
            closeAlert(alert);
            assertEquals(index==0 || index==4 ? 1 : 0,store.snapshot().getJSONArray("drafts").length());
        }
    }
    public void testProgressEndsOnFailureAndStartsAgainOnRetry() throws Exception {
        int before=saved(),requests=saveRequests();
        activity=getInstrumentation().startActivitySync(sharedLink());
        ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        control(new JSONObject().put("hold_save",true).put("next_save_status",500));
        try {
            ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            getInstrumentation().waitForIdleSync();
            assertEquals("전송 중 ...",((Button)ShareActivityTest.tagged(activity,"share.save")).getText().toString());
            assertEquals("전송 중",ShareActivityTest.tagged(activity,"share.save").getContentDescription().toString());
            awaitSaveRequests(requests+1);
        } finally { control(new JSONObject().put("release_save",true)); }
        android.view.accessibility.AccessibilityNodeInfo alert=ShareActivityTest.awaitAlert(getInstrumentation(),RETRY_TITLE,UNCONFIRMED,"다시 시도","닫기");
        Button save=(Button)ShareActivityTest.tagged(activity,"share.save");
        assertEquals("저장하기",save.getText().toString());assertFalse(save.isEnabled());
        assertEquals("저장하기",save.getContentDescription().toString());
        assertNull(save.getCompoundDrawables()[2]);
        control(new JSONObject().put("hold_save",true));
        try {
            ShareActivityTest.pressAlertButton(getInstrumentation(),alert,"다시 시도");
            assertEquals("전송 중 ...",save.getText().toString());assertFalse(save.isEnabled());
            assertEquals("전송 중",save.getContentDescription().toString());
            assertNotNull(save.getCompoundDrawables()[2]);
            awaitSaveRequests(requests+2);
        } finally { control(new JSONObject().put("release_save",true)); }
        assertCompletedOnce(before,requests+1);
    }
    private void awaitSaveRequests(int expected) throws Exception {
        long until=System.currentTimeMillis()+5000;
        while(saveRequests()<expected && System.currentTimeMillis()<until)Thread.sleep(20);
        assertEquals(expected,saveRequests());
    }
    public void testHeldSaveShowsProgressAndRejectsRepeatedTaps() throws Exception { assertHeldProgress(false,false); }
    public void testHeldImageShowsProgressAndRejectsRepeatedTaps() throws Exception { assertHeldProgress(true,false); }
    public void testHeldSaveRestoresProgressAfterRecreation() throws Exception { assertHeldProgress(false,true); }
    private void assertHeldProgress(boolean image,boolean recreate) throws Exception {
        int before=saved(), requests=saveRequests();
        control(new JSONObject().put("hold_save",true));
        try {
            if(image) {
                Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
                ShareTestSenderActivity.shareDirectly(getInstrumentation(),"image");
                activity=monitor.waitForActivityWithTimeout(10000);getInstrumentation().removeMonitor(monitor);assertNotNull(activity);
            } else activity=getInstrumentation().startActivitySync(sharedLink());
            ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
            ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
            if(recreate) {
                Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
                getInstrumentation().runOnMainSync(() -> activity.recreate());
                activity=monitor.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(monitor);assertNotNull(activity);
            }
            Button button=(Button)ShareActivityTest.tagged(activity,"share.save");
            getInstrumentation().waitForIdleSync();
            assertEquals("전송 중 ...",button.getText().toString());
            assertEquals("전송 중",button.getContentDescription().toString());
            assertFalse(button.isEnabled());
            assertNotNull(button.getCompoundDrawables()[2]);
            assertTrue(ShareActivityTest.visibleTexts(activity.getWindow().getDecorView())
                .contains("저장하고 있어요... 잠시만 기다려주세요 !"));
            assertEquals(View.GONE,ShareActivityTest.tagged(activity,"share.toast").getVisibility());
            tapSaveRepeatedly();
            long until=System.currentTimeMillis()+5000;
            while(saveRequests()==requests && System.currentTimeMillis()<until)Thread.sleep(20);
            assertEquals(requests+1,saveRequests());
        } finally { control(new JSONObject().put("release_save",true)); }
        assertCompletedOnce(before,requests);
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
    static final String RETRY_TITLE="저장하지 못했어요", UNCONFIRMED="저장 결과를 확인하지 못했습니다. 다시 시도해도 중복 저장되지 않습니다.",
        CHECK_INPUT="지금 링크 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요. 계속 실패하면 Instagram·YouTube 링크나 PNG·JPEG·WebP 이미지인지 확인해 주세요.",
        FINAL_TITLE="다시 저장할 수 없어요";
    /** Opens the sheet, lets the next save fail as configured and returns the alert. */
    private android.view.accessibility.AccessibilityNodeInfo failSave(JSONObject failure,String title,String message,String... buttons) throws Exception {
        activity=getInstrumentation().startActivitySync(sharedLink());ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        control(failure);ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
        return ShareActivityTest.awaitAlert(getInstrumentation(),title,message,buttons);
    }
    private void closeAlert(android.view.accessibility.AccessibilityNodeInfo alert) throws Exception {
        ShareActivityTest.pressAlertButton(getInstrumentation(),alert,"닫기");ShareActivityTest.awaitFinishing(activity);
    }
    /** [닫기] keeps the share; the same key then saves once. */
    private void assertCloseKeepsShare(JSONObject failure,String title,String message,String state,String... buttons) throws Exception {
        int before=saved();closeAlert(failSave(failure,title,message,buttons));
        String id=onlyDraft();assertEquals(state,store.draft(id).getString("state"));
        control(new JSONObject().put("next_save_status",201));assertTrue(save(id));assertEquals(before+1,saved());
    }
    /** [다시 시도] sends the same share again and completes with a single saved content. */
    private void assertRetrySavesOnce(JSONObject failure,String message,int requests) throws Exception {
        int before=saved(),start=saveRequests();
        android.view.accessibility.AccessibilityNodeInfo alert=failSave(failure,RETRY_TITLE,message,"다시 시도","닫기");
        control(new JSONObject().put("next_save_status",201));
        ShareActivityTest.pressAlertButton(getInstrumentation(),alert,"다시 시도");
        assertCompletedOnce(before,start+requests-1);
    }
    public void testServerFailureShowsRetryAlertAndCloseKeepsShare() throws Exception {
        assertCloseKeepsShare(new JSONObject().put("next_save_status",500),RETRY_TITLE,UNCONFIRMED,"failed","다시 시도","닫기");
    }
    public void testServerFailureRetrySavesOnce() throws Exception {
        assertRetrySavesOnce(new JSONObject().put("next_save_status",500),UNCONFIRMED,2);
    }
    public void testUnprocessableShareShowsRetryAlertAndCloseKeepsShare() throws Exception {
        assertCloseKeepsShare(new JSONObject().put("next_save_status",422),RETRY_TITLE,CHECK_INPUT,"failed","다시 시도","닫기");
    }
    public void testUnprocessableShareRetrySavesOnce() throws Exception {
        assertRetrySavesOnce(new JSONObject().put("next_save_status",422),CHECK_INPUT,2);
    }
    public void testLostResponseAlertCloseKeepsShareWithoutDuplicate() throws Exception {
        assertCloseKeepsShare(new JSONObject().put("lose_response",true),RETRY_TITLE,UNCONFIRMED,"unknown","다시 시도","닫기");
    }
    public void testLostResponseRetrySavesOnce() throws Exception {
        // The first request already stored the content; the retry only confirms it.
        assertRetrySavesOnce(new JSONObject().put("lose_response",true),UNCONFIRMED,2);
    }
    public void testThirtySecondDeadlineRetrySavesOnce() throws Exception {
        assertRetrySavesOnce(new JSONObject().put("save_delay_seconds",31),UNCONFIRMED,2);
    }
    public void testImageQuotaAlertCloseKeepsShare() throws Exception {
        assertCloseKeepsShare(new JSONObject().put("next_save_status",409).put("next_save_detail",new JSONObject().put("code","image_quota_exceeded")),
            "지금은 저장할 수 없어요","이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.","failed","닫기");
    }
    public void testUnauthorizedSaveShowsLoginAlertAndKeepsShare() throws Exception {
        android.view.accessibility.AccessibilityNodeInfo alert=failSave(new JSONObject().put("next_save_status",401),"로그인이 필요해요",ShareActivityTest.LOGIN,"허투루 열기","닫기");
        // Login required at save time also lowers the sheet before the alert.
        ShareActivityTest.awaitSheetHidden(getInstrumentation(),activity);closeAlert(alert);
        assertEquals("authRequired",store.draft(onlyDraft()).getString("state"));
    }
    public void testAccountChangeDuringSaveKeepsShareForOriginalAccountOnly() throws Exception {
        int requests=saveRequests();
        activity=getInstrumentation().startActivitySync(sharedLink());ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        String id=onlyDraft();control(new JSONObject().put("save_delay_seconds",4).put("lose_response",true));
        ShareActivityTest.tap(getInstrumentation(),ShareActivityTest.tagged(activity,"share.save"));
        long until=System.currentTimeMillis()+5000;while(saveRequests()==requests && System.currentTimeMillis()<until)Thread.sleep(20);
        store.blockCredential();
        android.view.accessibility.AccessibilityNodeInfo alert=ShareActivityTest.awaitAlert(getInstrumentation(),"저장 환경이 바뀌었어요","저장 계정이 변경되었습니다. 이 창을 닫고 저장할 계정을 확인해 주세요.","닫기");
        captureState("SL-05-account-change");closeAlert(alert);
        assertEquals("unknown",store.draft(id).getString("state"));assertEquals("7",store.draft(id).getString("userId"));
        assertEquals(requests+1,saveRequests());
    }
    private void assertIrreversibleDiscards(int status,String message,boolean recreateAndBack) throws Exception {
        android.view.accessibility.AccessibilityNodeInfo alert=failSave(new JSONObject().put("next_save_status",status),FINAL_TITLE,message,"닫기");
        if(recreateAndBack) {
            Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
            getInstrumentation().runOnMainSync(() -> activity.recreate());
            activity=recreated.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(recreated);assertNotNull(activity);
            ShareActivityTest.awaitAlert(getInstrumentation(),FINAL_TITLE,message,"닫기");
            getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);ShareActivityTest.awaitFinishing(activity);
        } else closeAlert(alert);
        assertEquals(0,store.snapshot().getJSONArray("drafts").length());
    }
    public void testDeletedContentAlertDiscardsShare() throws Exception {
        assertIrreversibleDiscards(410,"이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요.",false);
    }
    public void testMismatchedShareAlertDiscardsShare() throws Exception {
        assertIrreversibleDiscards(409,"이 초안의 저장 정보가 일치하지 않습니다. 다시 공유해 주세요.",false);
    }
    public void testTooLargeAlertDiscardsShare() throws Exception {
        assertIrreversibleDiscards(413,"이미지는 10MiB 이하만 저장할 수 있습니다.",false);
    }
    public void testRecreatedIrreversibleAlertBackStillDiscards() throws Exception {
        assertIrreversibleDiscards(410,"이미 저장한 뒤 삭제한 콘텐츠입니다. 새로 공유해 주세요.",true);
    }
    public void testRecreatedRetryAlertBackStillKeepsShare() throws Exception {
        failSave(new JSONObject().put("next_save_status",500),RETRY_TITLE,UNCONFIRMED,"다시 시도","닫기");
        Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        getInstrumentation().runOnMainSync(() -> activity.recreate());
        activity=recreated.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(recreated);assertNotNull(activity);
        ShareActivityTest.awaitAlert(getInstrumentation(),RETRY_TITLE,UNCONFIRMED,"다시 시도","닫기");
        getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);ShareActivityTest.awaitFinishing(activity);
        assertEquals("failed",store.draft(onlyDraft()).getString("state"));
    }
    /** A save left "sending" by a killed process is unconfirmed when the same share window comes back. */
    public void testRecreatedWindowWithUnconfirmedSaveOffersRetry() throws Exception {
        int before=saved(),requests=saveRequests();
        activity=getInstrumentation().startActivitySync(sharedLink());ShareActivityTest.awaitSaveEnabled(getInstrumentation(),activity);
        String id=onlyDraft();store.begin(id,store.snapshot().getLong("revision"),"7");
        Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        getInstrumentation().runOnMainSync(() -> activity.recreate());
        activity=recreated.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(recreated);assertNotNull(activity);
        ShareActivityTest.pressAlertButton(getInstrumentation(),ShareActivityTest.awaitAlert(getInstrumentation(),RETRY_TITLE,UNCONFIRMED,"다시 시도","닫기"),"다시 시도");
        assertCompletedOnce(before,requests);
    }
}
