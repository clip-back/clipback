package com.clipback.frontend.share;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.SystemClock;
import android.test.InstrumentationTestCase;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.Button;
import android.widget.TextView;
import org.json.JSONObject;
import java.io.File;
import java.util.ArrayList;
import java.util.List;

public final class ShareActivityTest extends InstrumentationTestCase {
    static final String GUIDE="전송한 정보는 AI가 직접 분류해서 저장할게요!";
    static final String LOGIN="초안을 보관했어요. 본앱을 열어 로그인 상태를 확인한 뒤 대기 중인 공유를 선택해 주세요.";
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
    private void signIn() throws Exception {
        store.publishCredential(new JSONObject().put("revision",store.snapshot().getLong("revision")).put("token","fixture-share-token")
            .put("expiresAt","2035-01-01T00:00:00Z").put("userId",7).put("sessionId",11)
            .put("accountLabel","테스트 계정").put("apiBaseUrl",ShareStore.baseUrl()));
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
    /** Visible user-facing texts and labels of the share window. */
    static List<String> visibleTexts(View view) {
        List<String> texts=new ArrayList<>();collect(view,texts);return texts;
    }
    private static void collect(View view,List<String> texts) {
        if(!view.isShown())return;
        if(view instanceof TextView && ((TextView)view).getText().length()>0)texts.add(((TextView)view).getText().toString());
        if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++)collect(((ViewGroup)view).getChildAt(i),texts);
    }
    static View tagged(Activity activity,String tag) { return activity.getWindow().getDecorView().findViewWithTag(tag); }
    static void awaitSaveEnabled(Instrumentation instrumentation,Activity activity) throws Exception {
        long until=System.currentTimeMillis()+5000;
        while(System.currentTimeMillis()<until) {
            boolean[] enabled={false};instrumentation.runOnMainSync(() -> { View save=tagged(activity,"share.save");enabled[0]=save!=null && save.isShown() && save.isEnabled(); });
            if(enabled[0])return;Thread.sleep(50);
        }
        fail("저장하기 must become available");
    }
    /** Waits until the view stops moving (the sheet slides in) and returns its screen position. */
    static int[] settledLocation(Instrumentation instrumentation,View view) throws Exception {
        assertNotNull("The share sheet view is missing",view);
        int[] location=new int[2],previous=new int[]{-1,-1};long until=System.currentTimeMillis()+5000;
        while(System.currentTimeMillis()<until) {
            instrumentation.runOnMainSync(() -> view.getLocationOnScreen(location));
            if(location[0]==previous[0] && location[1]==previous[1])return location;
            previous[0]=location[0];previous[1]=location[1];Thread.sleep(100);
        }
        fail("The sheet keeps moving");return location;
    }
    /** Sends a real touch so disabled views ignore it the same way as a finger tap. */
    static void tap(Instrumentation instrumentation,View view) throws Exception {
        int[] location=settledLocation(instrumentation,view);
        float x=location[0]+view.getWidth()/2f, y=location[1]+view.getHeight()/2f;long down=SystemClock.uptimeMillis();
        instrumentation.sendPointerSync(MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,x,y,0));
        instrumentation.sendPointerSync(MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x,y,0));
    }
    static void tapAt(Instrumentation instrumentation,float x,float y) {
        long down=SystemClock.uptimeMillis();
        instrumentation.sendPointerSync(MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,x,y,0));
        instrumentation.sendPointerSync(MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x,y,0));
    }
    /** Drags from the top edge of the sheet (the handle) towards the bottom of the screen. */
    static void dragSheetDown(Instrumentation instrumentation,Activity activity) throws Exception {
        View sheet=tagged(activity,"share.sheet");int[] location=settledLocation(instrumentation,sheet);
        float x=location[0]+sheet.getWidth()/2f, y=location[1]+10*activity.getResources().getDisplayMetrics().density;
        long down=SystemClock.uptimeMillis();
        instrumentation.sendPointerSync(MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,x,y,0));
        for(int step=1;step<=10;step++)instrumentation.sendPointerSync(MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,x,y+step*sheet.getHeight()/8f,0));
        instrumentation.sendPointerSync(MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x,y+10*sheet.getHeight()/8f,0));
    }
    static void awaitFinishing(Activity activity) throws Exception {
        long until=System.currentTimeMillis()+5000;
        while(System.currentTimeMillis()<until && !activity.isFinishing())Thread.sleep(20);
        assertTrue("The share window must close",activity.isFinishing());
    }
    /** OS alert dialogs live in their own window, so they are read through accessibility like a user would. */
    static AccessibilityNodeInfo awaitAlert(Instrumentation instrumentation,String message) throws Exception {
        long until=System.currentTimeMillis()+10000;
        while(System.currentTimeMillis()<until) {
            AccessibilityNodeInfo root=instrumentation.getUiAutomation().getRootInActiveWindow();
            if(root!=null && !root.findAccessibilityNodeInfosByText(message).isEmpty())return root;
            Thread.sleep(100);
        }
        fail("Missing alert: "+message);return null;
    }
    static void pressAlertButton(Instrumentation instrumentation,AccessibilityNodeInfo root,String label) {
        for(AccessibilityNodeInfo node:root.findAccessibilityNodeInfosByText(label))
            if(label.contentEquals(node.getText()) && node.isClickable()) { assertTrue(node.performAction(AccessibilityNodeInfo.ACTION_CLICK));instrumentation.waitForIdleSync();return; }
        fail("Missing alert button: "+label);
    }
    private Activity recreate() throws Exception {
        Instrumentation.ActivityMonitor recreated=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        getInstrumentation().runOnMainSync(() -> activity.recreate());
        Activity next=recreated.waitForActivityWithTimeout(5000);getInstrumentation().removeMonitor(recreated);assertNotNull(next);return next;
    }
    public void testUnauthenticatedShareSurvivesRecreationAndCloseWithoutLauncher() throws Exception {
        Instrumentation.ActivityMonitor main=getInstrumentation().addMonitor("com.clipback.frontend.MainActivity",null,false);
        activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitAlert(getInstrumentation(),LOGIN);
        String id=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        assertEquals("authRequired",store.draft(id).getString("state"));
        activity=recreate();
        AccessibilityNodeInfo alert=awaitAlert(getInstrumentation(),LOGIN);assertEquals(1,store.snapshot().getJSONArray("drafts").length());
        assertEquals(id,store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id"));
        pressAlertButton(getInstrumentation(),alert,"닫기");awaitFinishing(activity);
        assertNotNull(store.draft(id));assertEquals("authRequired",store.draft(id).getString("state"));assertEquals(0,main.getHits());
        getInstrumentation().removeMonitor(main);
    }
    public void testNewIntentQueuesDraftWithoutReplacingCurrentShare() throws Exception {
        signIn();activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitSaveEnabled(getInstrumentation(),activity);
        String first=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        Intent next=incoming().putExtra(Intent.EXTRA_TEXT,"https://instagram.com/p/fixture/");
        getInstrumentation().runOnMainSync(() -> ((ShareActivity)activity).onNewIntent(next));
        awaitDrafts(2);assertNotNull(store.draft(first));assertFalse(activity.isFinishing());awaitSaveEnabled(getInstrumentation(),activity);
    }
    public void testRecoveryHostReturnsWithoutDiscardingAuthRequiredDraft() throws Exception {
        String id=store.create("https://youtu.be/dQw4w9WgXcQ","fixture",null,null);store.setState(id,"authRequired");
        Intent recover=new Intent(getInstrumentation().getTargetContext(),ShareRecoveryActivity.class).putExtra("draftId",id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        activity=getInstrumentation().startActivitySync(recover);awaitText("로그인 상태 확인이 필요해요");
        getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);getInstrumentation().waitForIdleSync();assertTrue(activity.isFinishing());assertNotNull(store.draft(id));
    }
    public void testSheetShowsOnlySaveButtonAndGuide() throws Exception {
        signIn();activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitSaveEnabled(getInstrumentation(),activity);
        List<String>[] texts=new List[1];getInstrumentation().runOnMainSync(() -> texts[0]=visibleTexts(activity.getWindow().getDecorView()));
        assertEquals(java.util.Arrays.asList("저장하기",GUIDE),texts[0]);
        assertTrue(tagged(activity,"share.save") instanceof Button);
    }
    private interface Gesture { void run() throws Exception; }
    private void assertCloseBeforeSaveLeavesNothing(boolean recreate,Gesture close) throws Exception {
        signIn();activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitSaveEnabled(getInstrumentation(),activity);
        if(recreate) { activity=recreate();awaitSaveEnabled(getInstrumentation(),activity); }
        close.run();awaitFinishing(activity);awaitDrafts(0);
    }
    public void testDragDownBeforeSaveLeavesNothing() throws Exception {
        assertCloseBeforeSaveLeavesNothing(false,() -> dragSheetDown(getInstrumentation(),activity));
    }
    public void testBackgroundTapBeforeSaveLeavesNothing() throws Exception {
        assertCloseBeforeSaveLeavesNothing(false,() -> tapAt(getInstrumentation(),activity.getWindow().getDecorView().getWidth()/2f,activity.getWindow().getDecorView().getHeight()/4f));
    }
    public void testBackBeforeSaveLeavesNothing() throws Exception {
        assertCloseBeforeSaveLeavesNothing(false,() -> getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK));
    }
    public void testRecreatedSheetStillLeavesNothingOnDragDown() throws Exception {
        assertCloseBeforeSaveLeavesNothing(true,() -> dragSheetDown(getInstrumentation(),activity));
    }
    public void testCloseImmediatelyAfterSavePreservesQueuedRequest() throws Exception {
        signIn();activity=getInstrumentation().startActivitySync(incoming());awaitDrafts(1);awaitSaveEnabled(getInstrumentation(),activity);
        String id=store.snapshot().getJSONArray("drafts").getJSONObject(0).getString("id");
        final Throwable[] failure={null};
        getInstrumentation().runOnMainSync(() -> {
            synchronized(ShareStore.LOCK) {
                try {
                    // Hold the worker before begin(): the save is queued but the draft is still ready.
                    tagged(activity,"share.save").performClick();
                    assertTrue(ShareService.isActive(id));
                    // A tap on the dimmed background closes the sheet.
                    activity.getWindow().getDecorView().findViewWithTag("share.background").performClick();
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
    /** Closing while the shared content is still being stored cancels the intake; a late draft is discarded. */
    private void assertCloseWhilePreparingLeavesNothing(Activity started) throws Exception {
        activity=started;
        tap(getInstrumentation(),tagged(activity,"share.save"));
        getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);
        awaitFinishing(activity);
    }
    private void awaitPreparedDraftDiscarded() throws Exception {
        // The held intake now stores its draft and the cancelled sheet discards it again.
        Thread.sleep(1000);awaitDrafts(0);
        File[] files=new File(getInstrumentation().getTargetContext().getNoBackupFilesDir(),"native_share").listFiles((dir,name) -> name.endsWith(".image"));
        assertEquals(0,files==null?0:files.length);
    }
    public void testCloseWhilePreparingLinkLeavesNothing() throws Exception {
        signIn();
        synchronized(ShareStore.LOCK) {
            Activity started=getInstrumentation().startActivitySync(incoming());
            boolean[] enabled={true};getInstrumentation().runOnMainSync(() -> enabled[0]=tagged(started,"share.save").isEnabled());
            assertFalse("저장하기 waits until the share is stored",enabled[0]);
            assertCloseWhilePreparingLeavesNothing(started);
        }
        awaitPreparedDraftDiscarded();
    }
    public void testCloseWhilePreparingImageLeavesNothing() throws Exception {
        signIn();
        Instrumentation.ActivityMonitor monitor=getInstrumentation().addMonitor(ShareActivity.class.getName(),null,false);
        synchronized(ShareStore.LOCK) {
            ShareTestSenderActivity.shareDirectly(getInstrumentation(),"image");
            Activity started=monitor.waitForActivityWithTimeout(10000);getInstrumentation().removeMonitor(monitor);assertNotNull(started);
            getInstrumentation().waitForIdleSync();
            assertCloseWhilePreparingLeavesNothing(started);
        }
        awaitPreparedDraftDiscarded();
    }
}
