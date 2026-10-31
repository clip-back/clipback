package com.clipback.frontend.share;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.*;
import android.net.Uri;
import android.os.Bundle;
import android.widget.*;

/** Installed only in the instrumentation APK; exercises the real Android chooser and URI grants. */
public final class ShareTestSenderActivity extends Activity {
    /** Shares straight to 허투루 from this sender's own process, so the image URI grant is real. */
    static void shareDirectly(Instrumentation instrumentation,String kind) {
        Context context=instrumentation.getContext();
        context.startActivity(new Intent(context,ShareTestSenderActivity.class).putExtra("direct",kind).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }
    private static Intent image() {
        Uri uri=Uri.parse("content://com.huturu.app.test.shareimage/screenshot.png");
        Intent share=new Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        share.setClipData(ClipData.newRawUri("Screenshot",uri));
        return share;
    }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        if("image".equals(getIntent().getStringExtra("direct"))) {
            startActivity(image().setClassName("com.huturu.app","com.clipback.frontend.share.ShareActivity"));finish();return;
        }
        LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(32,100,32,32);
        TextView title=new TextView(this);title.setText("Share fixture sender\nReturn here after closing 허투루");title.setTextSize(24);root.addView(title);
        Button link=new Button(this);link.setText("Share YouTube link");link.setOnClickListener(v ->
            startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"https://youtu.be/dQw4w9WgXcQ"),"Share with")));root.addView(link);
        Button image=new Button(this);image.setText("Share screenshot URI");image.setOnClickListener(v -> startActivity(Intent.createChooser(image(),"Share with")));root.addView(image);
        setContentView(root);
    }
}
