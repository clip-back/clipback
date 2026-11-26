package com.clipback.frontend.share;

import android.app.Activity;
import android.content.Intent;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
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
            LinearLayout content=content(activity);float density=activity.getResources().getDisplayMetrics().density;
            String[] problem=new String[1];
            getInstrumentation().runOnMainSync(() -> problem[0]=successProblem(content,density));
            assertNull(problem[0],problem[0]);
            assertEquals(before+1,http("/__test/state",null).getInt("saved"));
            assertNull(store.draft(id));
            // The check must reject each way the removed line or spacing could come back unnoticed.
            String[] mutated=new String[6];
            getInstrumentation().runOnMainSync(() -> {
                TextView title=(TextView)content.getChildAt(0);View parent=(View)content.getParent();
                ViewGroup.MarginLayoutParams margins=(ViewGroup.MarginLayoutParams)title.getLayoutParams();
                title.setVisibility(View.INVISIBLE);mutated[0]=successProblem(content,density);title.setVisibility(View.VISIBLE);
                parent.setVisibility(View.INVISIBLE);mutated[1]=successProblem(content,density);parent.setVisibility(View.VISIBLE);
                TextView extra=new TextView(activity);content.addView(extra);mutated[2]=successProblem(content,density);content.removeView(extra);
                title.setPadding(0,Math.round(24*density),0,0);mutated[3]=successProblem(content,density);title.setPadding(0,0,0,0);
                margins.topMargin=Math.round(24*density);mutated[4]=successProblem(content,density);margins.topMargin=0;
                mutated[5]=successProblem(content,density);
            });
            String[] cases={"hidden title","hidden parent","extra body","moved padding","moved margin"};
            for(int i=0;i<cases.length;i++)assertNotNull(cases[i],mutated[i]);
            assertNull("restored",mutated[5]);
        } finally { getInstrumentation().runOnMainSync(activity::finish); }
    }
    private static LinearLayout content(Activity activity) throws Exception {
        java.lang.reflect.Field field=ShareRecoveryActivity.class.getDeclaredField("content");field.setAccessible(true);
        return (LinearLayout)field.get(activity);
    }
    /** Null when the recovery body shows only the visible "저장했어요." title without its own spacing (call on the main thread). */
    private static String successProblem(LinearLayout content,float density) {
        int d24=Math.round(24*density),d20=Math.round(20*density);
        if(content.getPaddingLeft()!=d24||content.getPaddingTop()!=d20||content.getPaddingRight()!=d24||content.getPaddingBottom()!=d24)return "body padding changed";
        if(content.getChildCount()!=1)return "body children="+content.getChildCount();
        View child=content.getChildAt(0);
        if(!(child instanceof TextView)||!"저장했어요.".contentEquals(((TextView)child).getText()))return "body child is not the title";
        if(!child.isShown())return "title not shown";
        if(child.getPaddingLeft()!=0||child.getPaddingTop()!=0||child.getPaddingRight()!=0||child.getPaddingBottom()!=0)return "title padding";
        ViewGroup.MarginLayoutParams margins=(ViewGroup.MarginLayoutParams)child.getLayoutParams();
        if(margins.leftMargin!=0||margins.topMargin!=0||margins.rightMargin!=0||margins.bottomMargin!=0)return "title margin";
        return null;
    }
}
