package com.clipback.frontend.share;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import org.json.JSONObject;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** A native share target. It never initializes Flutter or starts the launcher Activity. */
public class ShareActivity extends Activity implements ShareService.Listener {
    private static final ExecutorService INPUTS = Executors.newSingleThreadExecutor();
    private ShareStore store;
    private String draftId;
    private String intakeId;
    private long displayedRevision;
    private String displayedUser;
    private TextView status, account;
    private Button save, close;
    private LinearLayout content;
    private boolean successful, destroyed, loading, cancelledIntake;
    private String transientMessage;
    private android.window.OnBackInvokedCallback backCallback;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved); store = new ShareStore(this); build();
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            backCallback = this::closeShare;
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCallback);
        }
        if (saved != null) { draftId = saved.getString("draftId"); intakeId = saved.getString("intakeId"); }
        if (draftId != null) render();
        else if (this instanceof ShareRecoveryActivity) {
            draftId = getIntent().getStringExtra("draftId"); render();
        } else receive(getIntent(), false);
    }
    private int dp(int size) { return Math.round(size * getResources().getDisplayMetrics().density); }
    private TextView text(String value, int size) {
        TextView view = new TextView(this); view.setText(value); view.setTextSize(size); view.setTextColor(Color.rgb(44,43,39)); return view;
    }
    private void build() {
        if (android.os.Build.VERSION.SDK_INT >= 30) getWindow().setDecorFitsSystemWindows(false);
        else getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        getWindow().setStatusBarColor(Color.rgb(255,253,248));
        getWindow().setNavigationBarColor(Color.rgb(255,253,248));
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setBackgroundColor(Color.rgb(255,253,248));
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets.consumeSystemWindowInsets();
        });
        LinearLayout header = new LinearLayout(this); header.setGravity(Gravity.CENTER_VERTICAL); header.setPadding(dp(16),0,dp(16),0);
        TextView title = text("허투루에 저장", 20); title.setTypeface(null,1);
        header.addView(title,new LinearLayout.LayoutParams(0,dp(64),1)); title.setGravity(Gravity.CENTER_VERTICAL);
        close = new Button(this); close.setText("닫기"); close.setContentDescription("공유 닫기"); close.setOnClickListener(v -> closeShare());
        header.addView(close,new LinearLayout.LayoutParams(dp(80),dp(48))); root.addView(header);
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
        content = new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL); content.setPadding(dp(24),dp(20),dp(24),dp(24));
        scroll.addView(content); root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        setContentView(root); root.requestApplyInsets();
    }
    private void render() {
        if (destroyed) return;
        try {
            JSONObject draft = draftId == null ? null : store.draft(draftId);
            content.removeAllViews();
            if (draft == null) {
                TextView message = text(transientMessage != null ? transientMessage : successful ? "저장했어요" : "이 공유 항목은 이미 저장되었거나 만료되었습니다.",24); content.addView(message); return;
            }
            boolean active = ShareService.isActive(draftId);
            if ("sending".equals(draft.optString("state")) && !active) { store.setState(draftId,"unknown"); draft.put("state","unknown"); }
            if (active) ShareService.observe(draftId,this);
            TextView introduction = text("나중에 다시 발견할 순간",24); introduction.setTypeface(null,1); content.addView(introduction);
            TextView label = text(draft.getString("label"),17); label.setPadding(0,dp(24),0,dp(20)); label.setTextIsSelectable(true); content.addView(label);
            if ("image".equals(draft.getString("kind"))) {
                BitmapFactory.Options bounds = new BitmapFactory.Options(); bounds.inJustDecodeBounds=true;
                BitmapFactory.decodeFile(store.imageFile(draftId).getPath(),bounds);
                BitmapFactory.Options options = new BitmapFactory.Options(); options.inSampleSize=1;
                while (Math.max(bounds.outWidth,bounds.outHeight)/options.inSampleSize > 1200) options.inSampleSize *= 2;
                Bitmap bitmap = BitmapFactory.decodeFile(store.imageFile(draftId).getPath(),options);
                ImageView preview = new ImageView(this); preview.setContentDescription("공유 이미지 미리보기"); preview.setImageBitmap(bitmap); preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
                content.addView(preview,new LinearLayout.LayoutParams(-1,dp(240)));
            }
            JSONObject state=store.snapshot(), auth=state.optJSONObject("credential"); displayedRevision=state.getLong("revision");
            boolean valid=auth!=null && ShareStore.expiry(auth.getString("expiresAt"))>System.currentTimeMillis();
            displayedUser=valid?auth.getString("userId"):null;
            account=text(valid?"저장 계정: "+auth.getString("accountLabel"):"로그인 상태 확인이 필요해요",16); account.setPadding(0,dp(24),0,dp(16)); content.addView(account);
            boolean otherUser=valid && draft.has("userId") && !displayedUser.equals(draft.getString("userId"));
            boolean otherEnvironment=draft.has("apiBaseUrl") && !ShareStore.baseUrl().equals(draft.getString("apiBaseUrl"));
            status=text(transientMessage!=null?transientMessage:otherEnvironment?"다른 서버에서 시작한 공유입니다. 원래 앱 환경에서 확인해 주세요.":!valid?"초안을 보관했어요. 본앱을 열어 로그인 상태를 확인한 뒤 대기 중인 공유를 선택해 주세요.":otherUser?"처음 저장을 요청한 계정에서만 재시도할 수 있습니다.":active?"저장 중입니다. 닫아도 서버 처리가 완료될 수 있어요.":"unknown".equals(draft.getString("state"))?"이전 요청 결과를 확인하지 못했어요. 다시 시도하면 같은 요청으로 확인합니다.":"자동으로 분류해 보관할게요.",15);
            status.setPadding(0,0,0,dp(24)); content.addView(status);
            if (!valid && !draft.has("userId")) store.setState(draftId,"authRequired");
            save=new Button(this); save.setText(active?"저장 중…":"저장"); save.setContentDescription("공유 저장"); save.setEnabled(valid && !otherUser && !otherEnvironment && !active);
            save.setOnClickListener(v -> { save.setEnabled(false); status.setText("저장 중입니다. 닫아도 서버 처리가 완료될 수 있어요."); ShareService.execute(store,draftId,displayedRevision,displayedUser,this); });
            content.addView(save,new LinearLayout.LayoutParams(-1,dp(56)));
            if (!active && !"ready".equals(draft.getString("state"))) {
                Button discard = new Button(this); discard.setText("초안 삭제"); discard.setOnClickListener(v -> {
                    try { store.discard(draftId); finish(); } catch(Exception error) { status.setText("초안을 삭제하지 못했습니다. 다시 시도해 주세요."); }
                }); content.addView(discard,new LinearLayout.LayoutParams(-1,dp(48)));
            }
        } catch(Exception error) { showError("공유 정보를 읽지 못했습니다. 본앱에서 공유 준비를 다시 시도해 주세요."); }
    }
    private void receive(Intent intent, boolean additional) {
        if (!additional && intakeId == null) intakeId = java.util.UUID.randomUUID().toString();
        final String operationId = additional ? java.util.UUID.randomUUID().toString() : intakeId;
        loading=true; if (!additional) { content.removeAllViews(); content.addView(text("공유 내용을 준비하고 있어요…",18)); }
        INPUTS.execute(() -> {
            String id=null, error=null;
            try { id=ShareInput.receive(this,intent,store,operationId); } catch(Exception failure) { error=failure.getMessage(); }
            final String received=id, message=error;
            runOnUiThread(() -> {
                loading=false;
                if (cancelledIntake && !additional && received != null) {
                    INPUTS.execute(() -> { try { store.discard(received); } catch (Exception ignored) { } });
                    return;
                }
                if (destroyed) return;
                if (received==null) { if (additional) Toast.makeText(this,message,Toast.LENGTH_LONG).show(); else showError(message); }
                else if (additional) { Toast.makeText(this,"새 공유를 대기 항목에 보관했습니다. 본앱에서 확인해 주세요.",Toast.LENGTH_LONG).show(); }
                else { draftId=received; render(); }
            });
        });
    }
    private void showError(String message) { content.removeAllViews(); content.addView(text(message==null?"공유 내용을 확인해 주세요.":message,18)); }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); if (!(this instanceof ShareRecoveryActivity)) receive(intent,true); }
    @Override protected void onResume() { super.onResume(); if (draftId!=null && !successful) { ShareService.detach(this); render(); } }
    @Override protected void onSaveInstanceState(Bundle out) { super.onSaveInstanceState(out); out.putString("draftId",draftId); out.putString("intakeId",intakeId); }
    @Override protected void onDestroy() {
        destroyed=true; ShareService.detach(this);
        if (android.os.Build.VERSION.SDK_INT >= 33 && backCallback != null) getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(backCallback);
        super.onDestroy();
    }
    @Override public void onBackPressed() { closeShare(); }
    private void closeShare() {
        if (loading && draftId == null) { cancelledIntake = true; finish(); return; }
        try {
            JSONObject draft=draftId==null?null:store.draft(draftId);
            if(draft!=null && ShareService.isActive(draftId)) store.setState(draftId,"unknown");
            else if (draft!=null && !draft.has("userId") && "ready".equals(draft.getString("state"))) store.discard(draftId);
            finish();
        } catch(Exception error) { if(status!=null) status.setText("초안을 보관하지 못했습니다. 다시 시도해 주세요."); }
    }
    @Override public void finished(String id,String message,boolean success) {
        if(destroyed || !id.equals(draftId))return;
        successful=success; transientMessage=message;
        if(success) { content.removeAllViews(); TextView title=text("저장했어요",28); title.setTypeface(null,1); content.addView(title); TextView detail=text(message,17); detail.setPadding(0,dp(24),0,0); content.addView(detail); }
        else render();
    }
}
