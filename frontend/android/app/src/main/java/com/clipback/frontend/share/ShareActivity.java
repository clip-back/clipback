package com.clipback.frontend.share;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import com.clipback.frontend.R;
import org.json.JSONObject;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The 공유 저장 시트 shown over the sending app (Figma 233:3420, completion toast 233:3430).
 * It never initializes Flutter or starts the launcher Activity.
 */
public class ShareActivity extends Activity implements ShareService.Listener {
    private static final ExecutorService INPUTS = Executors.newSingleThreadExecutor();
    private static final int MAIN = 0xFFFFD75C, TEXT = 0xFF1A1A1A, SUBTLE = 0xFF767676, SUBTLER = 0xFFD1D1D1;
    /** The design has no duration; 1.5 seconds is the temporary value from the share sheet spec. */
    private static final long TOAST_MILLIS = 1500;
    private ShareStore store;
    private String draftId, intakeId;
    /** The alert on screen; restored after recreation and deciding what [닫기] keeps. */
    private ShareFailure shown;
    private long displayedRevision;
    private String displayedUser;
    private View background, sheet, toast;
    private Button save;
    private AlertDialog alert;
    private float dragStart;
    private boolean successful, destroyed, loading, cancelledIntake, closing;
    private android.window.OnBackInvokedCallback backCallback;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved); store = new ShareStore(this); build(saved == null);
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            backCallback = this::closeShare;
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCallback);
        }
        if (saved != null) {
            draftId = saved.getString("draftId"); intakeId = saved.getString("intakeId");
            successful = saved.getBoolean("successful");
            // Without a stored share, receiving again shows the same rejection or storage alert.
            if (draftId != null && saved.getString("alertKind") != null)
                shown = new ShareFailure(ShareFailure.Kind.valueOf(saved.getString("alertKind")), saved.getString("alertMessage"));
        }
        if (successful) complete();
        else if (draftId != null) bind();
        else receive(getIntent(), false);
        if (!successful && alert == null && shown != null) showAlert(shown);
    }
    private int dp(float size) { return Math.round(size * getResources().getDisplayMetrics().density); }
    /** Pretendard is read from the Flutter assets already packaged in this APK. */
    private Typeface font(String weight) { return Typeface.createFromAsset(getAssets(), "flutter_assets/assets/fonts/Pretendard-" + weight + ".otf"); }
    private TextView text(String value, Typeface font, int size, int color) {
        TextView view = new TextView(this); view.setText(value); view.setTextSize(size); view.setTextColor(color); view.setTypeface(font);
        view.setLetterSpacing(-0.025f); view.setIncludeFontPadding(false); view.setGravity(Gravity.CENTER); return view;
    }
    private GradientDrawable shape(int color, float... radii) {
        GradientDrawable shape = new GradientDrawable(); shape.setColor(color);
        if (radii.length == 1) shape.setCornerRadius(dp(radii[0]));
        else shape.setCornerRadii(new float[]{dp(radii[0]),dp(radii[0]),dp(radii[1]),dp(radii[1]),dp(radii[2]),dp(radii[2]),dp(radii[3]),dp(radii[3])});
        return shape;
    }
    private void build(boolean entering) {
        Window window = getWindow();
        if (android.os.Build.VERSION.SDK_INT >= 30) window.setDecorFitsSystemWindows(false);
        else window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        window.setStatusBarColor(Color.TRANSPARENT); window.setNavigationBarColor(Color.TRANSPARENT);
        if (android.os.Build.VERSION.SDK_INT >= 29) window.setNavigationBarContrastEnforced(false);
        if (android.os.Build.VERSION.SDK_INT >= 31) {
            // Figma bg_diim: 2px blur + 50% black. The OS skips the blur when cross-window blur is unavailable.
            window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND);
            WindowManager.LayoutParams attributes = window.getAttributes(); attributes.setBlurBehindRadius(dp(2)); window.setAttributes(attributes);
        }
        Typeface semiBold = font("SemiBold"), medium = font("Medium");
        FrameLayout root = new FrameLayout(this);
        background = new View(this); background.setTag("share.background"); background.setBackgroundColor(0x80000000);
        background.setContentDescription("공유 닫기"); background.setOnClickListener(v -> closeShare());
        root.addView(background, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout panel = new LinearLayout(this); panel.setTag("share.sheet"); panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL); panel.setBackground(shape(Color.WHITE, 24, 24, 0, 0)); panel.setOnTouchListener(this::drag);
        View handle = new View(this); handle.setBackground(shape(SUBTLER, 100));
        LinearLayout.LayoutParams handleLayout = new LinearLayout.LayoutParams(dp(50), dp(5)); handleLayout.setMargins(0, dp(8), 0, dp(19));
        panel.addView(handle, handleLayout);
        save = new Button(this); save.setTag("share.save"); save.setText("저장하기"); save.setTextSize(16); save.setTextColor(TEXT);
        save.setTypeface(semiBold); save.setLetterSpacing(-0.025f);
        save.setAllCaps(false); save.setStateListAnimator(null); save.setBackground(shape(MAIN, 8));
        save.setMinHeight(dp(56)); save.setMinimumHeight(dp(56)); save.setPadding(dp(16), dp(8), dp(16), dp(8)); save.setEnabled(false);
        save.setOnClickListener(v -> { save.setEnabled(false); ShareService.execute(store, draftId, displayedRevision, displayedUser, this); });
        panel.addView(save, new LinearLayout.LayoutParams(-1, -2));
        TextView guide = text("전송한 정보는 AI가 직접 분류해서 저장할게요!", medium, 14, SUBTLE);
        LinearLayout.LayoutParams guideLayout = new LinearLayout.LayoutParams(-1, -2); guideLayout.topMargin = dp(16);
        panel.addView(guide, guideLayout);
        FrameLayout.LayoutParams sheetLayout = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        root.addView(panel, sheetLayout); sheet = panel;

        LinearLayout bar = new LinearLayout(this); bar.setTag("share.toast"); bar.setGravity(Gravity.CENTER); bar.setVisibility(View.GONE);
        bar.setBackground(shape(TEXT, 4)); bar.setMinimumHeight(dp(44)); bar.setPadding(dp(16), dp(12), dp(16), dp(12));
        ImageView check = new ImageView(this); check.setImageResource(R.drawable.share_check); check.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        bar.addView(check, new LinearLayout.LayoutParams(dp(20), dp(20)));
        LinearLayout.LayoutParams doneLayout = new LinearLayout.LayoutParams(-2, -2); doneLayout.setMarginStart(dp(8));
        bar.addView(text("저장 완료!", semiBold, 16, MAIN), doneLayout);
        FrameLayout.LayoutParams toastLayout = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        root.addView(bar, toastLayout); toast = bar;

        root.setOnApplyWindowInsetsListener((view, insets) -> {
            int left = insets.getSystemWindowInsetLeft(), right = insets.getSystemWindowInsetRight();
            // Figma keeps 32 below the content; a taller navigation or gesture inset takes its place.
            int bottom = Math.max(dp(32), insets.getSystemWindowInsetBottom());
            sheet.setPadding(dp(16) + left, 0, dp(16) + right, bottom);
            toastLayout.setMargins(dp(16) + left, 0, dp(16) + right, bottom); toast.setLayoutParams(toastLayout);
            return insets;
        });
        setContentView(root); root.requestApplyInsets();
        if (entering) {
            background.setAlpha(0); background.animate().alpha(1).setDuration(250);
            sheet.setTranslationY(getResources().getDisplayMetrics().heightPixels); sheet.animate().translationY(0).setDuration(250);
        }
    }
    /** Dragging the sheet down past a quarter of its height closes it. */
    private boolean drag(View view, MotionEvent event) {
        if (closing) return true;
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN: dragStart = event.getRawY(); sheet.animate().cancel(); break;
            case MotionEvent.ACTION_MOVE: sheet.setTranslationY(Math.max(0, event.getRawY() - dragStart)); break;
            case MotionEvent.ACTION_UP: if (sheet.getTranslationY() > sheet.getHeight() / 4f) { closeShare(); break; } // otherwise settle back
            case MotionEvent.ACTION_CANCEL: sheet.animate().translationY(0).setDuration(150); break;
        }
        return true;
    }
    private void hideSheet() { sheet.animate().translationY(sheet.getHeight()).setDuration(200).withEndAction(() -> sheet.setVisibility(View.GONE)); }
    private void leave() {
        if (closing) return;
        closing = true; sheet.animate().translationY(sheet.getHeight()).setDuration(200); toast.animate().alpha(0).setDuration(200);
        background.animate().alpha(0).setDuration(200).withEndAction(this::finish);
    }
    private void bind() {
        try {
            JSONObject draft = store.draft(draftId);
            if (draft == null) { if (shown == null) showAlert(ShareFailure.Kind.MISSING); return; }
            boolean active = ShareService.isActive(draftId);
            boolean unconfirmed = "unknown".equals(draft.optString("state")) && !active;
            if ("sending".equals(draft.optString("state")) && !active) { store.setState(draftId, "unknown"); unconfirmed = true; }
            if (active) ShareService.observe(draftId, this);
            JSONObject state = store.snapshot(), auth = state.optJSONObject("credential"); displayedRevision = state.getLong("revision");
            boolean valid = auth != null && ShareStore.expiry(auth.getString("expiresAt")) > System.currentTimeMillis();
            displayedUser = valid ? auth.getString("userId") : null;
            boolean otherUser = valid && draft.has("userId") && !displayedUser.equals(draft.getString("userId"));
            boolean otherEnvironment = draft.has("apiBaseUrl") && !ShareStore.baseUrl().equals(draft.getString("apiBaseUrl"));
            if (!valid && !draft.has("userId")) store.setState(draftId, "authRequired");
            save.setEnabled(valid && !otherUser && !otherEnvironment && !active);
            // A recreated window keeps the alert it was showing.
            if (shown != null) { if (shown.kind == ShareFailure.Kind.LOGIN) hideSheet(); return; }
            // States without a sheet design show an OS alert.
            if (otherEnvironment) showAlert(ShareFailure.Kind.OTHER_ENVIRONMENT);
            else if (!valid) { hideSheet(); showAlert(ShareFailure.Kind.LOGIN); }
            else if (otherUser) showAlert(ShareFailure.Kind.ACCOUNT_CHANGED);
            // A save whose process ended before its result can be confirmed again with the same request.
            else if (unconfirmed) showAlert(ShareFailure.Kind.UNCONFIRMED);
        } catch (java.security.GeneralSecurityException unreadable) {
            // Q9②: the share is kept but its credential (Keystore) cannot be read, so login is required.
            try { JSONObject draft = store.draft(draftId); if (draft != null && !draft.has("userId")) store.setState(draftId, "authRequired"); }
            catch (Exception ignored) { }
            if (shown == null) showAlert(ShareFailure.Kind.LOGIN);
            if (shown.kind == ShareFailure.Kind.LOGIN) hideSheet();
        } catch (Exception error) {
            // Other storage read/write failures cannot confirm the share is kept: 보관 실패 (Q9③).
            if (shown == null) showAlert(ShareFailure.Kind.STORAGE_FAILED);
        }
    }
    private void receive(Intent intent, boolean additional) {
        if (!additional && intakeId == null) intakeId = java.util.UUID.randomUUID().toString();
        final String operationId = additional ? java.util.UUID.randomUUID().toString() : intakeId;
        if (!additional) loading = true;
        INPUTS.execute(() -> {
            String id=null; ShareFailure error=null;
            try { id=ShareInput.receive(this,intent,store,operationId); }
            catch(Exception failure) { error=failure instanceof ShareFailure ? (ShareFailure)failure : new ShareFailure(ShareFailure.Kind.STORAGE_FAILED,failure.getMessage()); }
            final String received=id; final ShareFailure message=error;
            runOnUiThread(() -> {
                if (!additional) loading=false;
                if (cancelledIntake && !additional && received != null) {
                    INPUTS.execute(() -> { try { store.discard(received); } catch (Exception ignored) { } });
                    return;
                }
                if (destroyed) return;
                if (received==null) { if (additional) Toast.makeText(this,message.body(),Toast.LENGTH_LONG).show(); else showAlert(message); }
                else if (additional) { Toast.makeText(this,"새 공유를 대기 항목에 보관했습니다. 본앱에서 확인해 주세요.",Toast.LENGTH_LONG).show(); }
                else { draftId=received; bind(); }
            });
        });
    }
    private void showAlert(ShareFailure.Kind kind) { showAlert(new ShareFailure(kind, null)); }
    /** The #122 failure classes in an OS alert; cancelling it (back, outside tap) is the same as [닫기]. */
    private void showAlert(ShareFailure failure) {
        shown = failure;
        if (alert != null) alert.dismiss();
        AlertDialog.Builder builder = new AlertDialog.Builder(this).setTitle(failure.kind.title).setMessage(failure.body())
            .setNegativeButton("닫기", (dialog, which) -> closeShare()).setOnCancelListener(dialog -> closeShare());
        if (failure.kind.retries()) builder.setPositiveButton("다시 시도", (dialog, which) -> retry());
        else if (failure.kind.opensApp()) builder.setPositiveButton("허투루 열기", (dialog, which) -> openApp());
        alert = builder.show();
        alert.getButton(AlertDialog.BUTTON_NEGATIVE).setTag("share.alert.close");
        Button positive = alert.getButton(AlertDialog.BUTTON_POSITIVE);
        if (positive != null) positive.setTag(failure.kind.retries() ? "share.alert.retry" : "share.alert.open");
    }
    /** Same share, same Idempotency-Key: the server confirms instead of saving twice. */
    private void retry() {
        shown = null; alert = null; save.setEnabled(false);
        ShareService.execute(store, draftId, displayedRevision, displayedUser, this);
    }
    /** Starts the main app, then closes the share window with the [닫기] result. */
    private void openApp() {
        startActivity(getPackageManager().getLaunchIntentForPackage(getPackageName()));
        closeShare();
    }
    private void complete() {
        hideSheet(); toast.setVisibility(View.VISIBLE); toast.announceForAccessibility("저장 완료!");
        toast.postDelayed(this::leave, TOAST_MILLIS);
    }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); receive(intent,true); }
    @Override protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out); out.putString("draftId",draftId); out.putString("intakeId",intakeId);
        out.putBoolean("successful",successful);
        if (shown != null) { out.putString("alertKind",shown.kind.name()); out.putString("alertMessage",shown.getMessage()); }
    }
    @Override protected void onDestroy() {
        destroyed=true; ShareService.detach(this); if (alert != null) alert.dismiss();
        if (android.os.Build.VERSION.SDK_INT >= 33 && backCallback != null) getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(backCallback);
        super.onDestroy();
    }
    @Override public void onBackPressed() { closeShare(); }
    private void closeShare() {
        if (closing) return;
        if (loading && draftId == null) { cancelledIntake = true; leave(); return; }
        try {
            JSONObject draft=draftId==null?null:store.draft(draftId);
            if (draft!=null && shown!=null && shown.kind.discards()) store.discard(draftId);
            else if(draft!=null && ShareService.isActive(draftId)) store.setState(draftId,"unknown");
            // An unsent share closed before saving is dropped; an alert's share stays for the main app.
            else if (draft!=null && shown==null && !draft.has("userId") && "ready".equals(draft.getString("state"))) store.discard(draftId);
            leave();
        } catch(Exception error) {
            if (alert != null) alert.dismiss();
            // [다시 시도] repeats the close; [닫기] and cancelling leave the share window with the device's items as they are.
            alert = new AlertDialog.Builder(this).setMessage("초안을 보관하지 못했습니다. 다시 시도해 주세요.")
                .setPositiveButton("다시 시도", (dialog, which) -> closeShare()).setNegativeButton("닫기", (dialog, which) -> leave())
                .setOnCancelListener(dialog -> leave()).show();
        }
    }
    @Override public void finished(String id,String message,boolean success) {
        if(destroyed || closing || !id.equals(draftId) || !success)return;
        successful=true; complete();
    }
    @Override public void failed(String id,ShareFailure failure) {
        if(destroyed || closing || !id.equals(draftId))return;
        showAlert(failure);
    }
}
