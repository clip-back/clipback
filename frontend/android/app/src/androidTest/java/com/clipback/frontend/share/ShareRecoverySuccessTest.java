package com.clipback.frontend.share;

import android.app.Activity;
import android.content.Intent;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Recovery success copy (#478). Run like ShareServiceFixtureTest, against share_fixture_server.py. */
public final class ShareRecoverySuccessTest extends InstrumentationTestCase {
    private ShareStore store;
    @Override protected void setUp() throws Exception {
        super.setUp();
        assertEquals("http://10.0.2.2:18765/api/v1",ShareStore.baseUrl());
        store=new ShareStore(getInstrumentation().getTargetContext());
        cleanup();store.blockCredential();
        JSONObject auth=http("/auth/share-credential",new JSONObject());
        assertTrue(store.publishCredential(new JSONObject().put("revision",store.snapshot().getLong("revision"))
            .put("token",auth.getString("share_token")).put("expiresAt",auth.getString("expires_at"))
            .put("userId",auth.get("user_id")).put("sessionId",auth.get("session_id"))
            .put("accountLabel","공유 테스트 계정").put("apiBaseUrl",ShareStore.baseUrl())));
        http("/__test/control",new JSONObject().put("next_save_status",201).put("save_delay_seconds",0).put("lose_response",false));
    }
    @Override protected void tearDown() throws Exception { cleanup();store.blockCredential();super.tearDown(); }
    private void cleanup() throws Exception {
        JSONObject state=store.snapshot();
        for(int i=0;i<state.getJSONArray("drafts").length();i++)store.discard(state.getJSONArray("drafts").getJSONObject(i).getString("id"));
        for(int i=0;i<state.getJSONArray("receipts").length();i++)store.acknowledge(Collections.singletonList(state.getJSONArray("receipts").getJSONObject(i).getString("id")));
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
    private static void texts(View view,List<TextView> out) {
        if(view instanceof TextView)out.add((TextView)view);
        if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++)texts(((ViewGroup)view).getChildAt(i),out);
    }
    public void testRecoverySuccessShowsOnlySavedTitle() throws Exception {
        int before=http("/__test/state",null).getInt("saved");
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","https://youtu.be/dQw4w9WgXcQ",null,null);
        Activity activity=getInstrumentation().startActivitySync(new Intent(getInstrumentation().getTargetContext(),ShareRecoveryActivity.class)
            .putExtra("draftId",id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        try {
            List<TextView> found=new ArrayList<>();
            getInstrumentation().runOnMainSync(() -> { texts(activity.getWindow().getDecorView(),found);
                for(TextView view:found)if(view instanceof Button && "저장".contentEquals(view.getText()))view.performClick(); });
            List<TextView> saved=new ArrayList<>();List<String> all=new ArrayList<>();
            long until=System.currentTimeMillis()+15000;
            while(saved.isEmpty() && System.currentTimeMillis()<until) {
                getInstrumentation().runOnMainSync(() -> { List<TextView> views=new ArrayList<>();texts(activity.getWindow().getDecorView(),views);
                    saved.clear();all.clear();for(TextView view:views){all.add(view.getText().toString());if("저장했어요.".contentEquals(view.getText()))saved.add(view);} });
                if(saved.isEmpty())Thread.sleep(50);
            }
            assertEquals(all.toString(),1,saved.size());
            for(String value:all)assertFalse(value,value.contains("요약")); // both old success lines mentioned 요약
            // The detail line and its top padding are gone: the title is the content's only child.
            assertEquals(1,((ViewGroup)saved.get(0).getParent()).getChildCount());
            assertEquals(before+1,http("/__test/state",null).getInt("saved"));
            assertNull(store.draft(id));
        } finally { getInstrumentation().runOnMainSync(activity::finish); }
    }
}
