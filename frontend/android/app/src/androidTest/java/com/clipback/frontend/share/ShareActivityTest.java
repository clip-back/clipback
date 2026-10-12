package com.clipback.frontend.share;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.test.InstrumentationTestCase;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import org.json.JSONObject;

public final class ShareActivityTest extends InstrumentationTestCase {
    private ShareStore store;
    private Activity activity;
    @Override protected void setUp() throws Exception {
        super.setUp();store=new ShareStore(getInstrumentation().getTargetContext());clear();store.blockCredential();
    }
    @Override protected void tearDown() throws Exception {
        if(activity!=null)getInstrumentation().runOnMainSync(() -> activity.finish());
        clear();store.blockCredential();super.tearDown();
    }
    private void clear() throws Exception {
        JSONObject state=store.snapshot();for(int i=0;i<state.getJSONArray("drafts").length();i++)store.discard(state.getJSONArray("drafts").getJSONObject(i).getString("id"));
    }
    private Intent incoming() {
        return new Intent(getInstrumentation().getTargetContext(),ShareActivity.class).setAction(Intent.ACTION_SEND).setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT,"https://youtu.be/dQw4w9WgXcQ").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    }
    private void awaitDrafts(int count) throws Exception {
        long until=System.currentTimeMillis()+5000;
        while(System.currentTimeMillis()<until) { if(store.snapshot().getJSONArray("drafts").length()==count)return;Thread.sleep(50); }
        assertEquals(count,store.snapshot().getJSONArray("drafts").length());
    }
    private TextView find(View view,String text) {
        if(view instanceof TextView && text.contentEquals(((TextView)view).getText()))return (TextView)view;
        if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++){TextView found=find(((ViewGroup)view).getChildAt(i),text);if(found!=null)return found;}
        return null;
    }
    private void awaitText(String text) throws Exception {
        long until=System.currentTimeMillis()+5000;
        while(System.currentTimeMillis()<until) { final boolean[] found={false};getInstrumentation().runOnMainSync(() -> found[0]=find(activity.getWindow().getDecorView(),text)!=null);if(found[0])return;Thread.sleep(50); }
        fail("Missing text: "+text);
    }
    public void testUnauthenticatedShareSurvivesRecreationAndCloseWithoutLauncher() throws Exception {
        Instrumentation.ActivityMonitor main=getInstrumentation().addMonitor("com.clipback.frontend.MainActivity",null,false);
        activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitText("로그인 상태 확인이 필요해요");
        String id=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        getInstrumentation().runOnMainSync(() -> activity.recreate());
        Activity next=recreated.waitForActivityWithTimeout(5000);assertNotNull(next);activity=next;
        awaitText("로그인 상태 확인이 필요해요");assertEquals(1,store.snapshot().getJSONArray("drafts").length());
        assertEquals(id,store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id"));
        getInstrumentation().runOnMainSync(() -> ((Button)find(activity.getWindow().getDecorView(),"닫기")).performClick());
        getInstrumentation().waitForIdleSync();assertNotNull(store.draft(id));assertEquals(0,main.getHits());
        getInstrumentation().removeMonitor(main);getInstrumentation().removeMonitor(recreated);
    }
    public void testNewIntentQueuesDraftWithoutReplacingCurrentPreview() throws Exception {
        activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitText("로그인 상태 확인이 필요해요");
        String first=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        Intent next=incoming().putExtra(Intent.EXTRA_TEXT,"https://instagram.com/p/fixture/");
        getInstrumentation().runOnMainSync(() -> ((ShareActivity)activity).onNewIntent(next));
        awaitDrafts(2);awaitText("https://youtu.be/dQw4w9WgXcQ");assertNotNull(store.draft(first));
    }
    public void testRecoveryHostReturnsWithoutDiscardingAuthRequiredDraft() throws Exception {
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);store.setState(id,"authRequired");
        Intent recover=new Intent(getInstrumentation().getTargetContext(),ShareRecoveryActivity.class).putExtra("draftId",id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        activity=getInstrumentation().startActivitySync(recover);awaitText("로그인 상태 확인이 필요해요");
        getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);getInstrumentation().waitForIdleSync();assertTrue(activity.isFinishing());assertNotNull(store.draft(id));
    }
    public void testCloseImmediatelyAfterSavePreservesQueuedRequest() throws Exception {
        long revision=store.snapshot().getLong("revision");
        store.publishCredential(new JSONObject().put("revision",revision).put("token","fixture-share-token")
            .put("expiresAt","2035-01-01T00:00:00Z").put("userId",7).put("sessionId",11)
            .put("accountLabel","테스트 계정").put("apiBaseUrl",ShareStore.baseUrl()));
        activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitText("저장 계정: 테스트 계정");
        String id=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        final Throwable[] failure={null};
        getInstrumentation().runOnMainSync(() -> {
            synchronized(ShareStore.LOCK) {
                try {
                    // Hold the worker before begin(): the save is queued but the draft is still ready.
                    ((Button)find(activity.getWindow().getDecorView(),"저장")).performClick();
                    assertTrue(ShareService.isActive(id));
                    ((Button)find(activity.getWindow().getDecorView(),"닫기")).performClick();
                    assertNotNull("A queued save must survive closing",store.draft(id));
                    assertEquals("unknown",store.draft(id).getString("state"));
                } catch(Throwable error) { failure[0]=error; }
                finally { try { store.blockCredential(); } catch(Exception error) { failure[0]=error; } }
            }
        });
        long deadline=System.currentTimeMillis()+5000;
        while(ShareService.isActive(id) && System.currentTimeMillis()<deadline)Thread.sleep(20);
        assertFalse(ShareService.isActive(id));assertNotNull(store.draft(id));
        if(failure[0]!=null)throw new AssertionError(failure[0]);
    }
}
