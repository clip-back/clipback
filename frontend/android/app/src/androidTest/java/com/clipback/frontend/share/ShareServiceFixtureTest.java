package com.clipback.frontend.share;

import android.test.InstrumentationTestCase;
import android.app.Activity;
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
import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Run explicitly with the loopback share_fixture_server.py and the fixture APK. */
public final class ShareServiceFixtureTest extends InstrumentationTestCase {
    private ShareStore store;
    @Override protected void setUp() throws Exception {
        super.setUp();
        assertEquals("http://10.0.2.2:18765/api/v1",ShareStore.baseUrl());
        store=new ShareStore(getInstrumentation().getTargetContext());
        cleanup();store.blockCredential();prepare();
        control(new JSONObject().put("next_save_status",201).put("save_delay_seconds",0).put("lose_response",false));
    }
    @Override protected void tearDown() throws Exception {
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
    public void testImageFileLimitUsesExistingShareErrorRegion() throws Exception {
        imageError(413,"image_file_too_large","이미지는 10MiB 이하만 저장할 수 있습니다.","android-share-image-file-limit");
    }
}
