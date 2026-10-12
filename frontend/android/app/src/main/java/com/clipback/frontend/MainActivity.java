package com.clipback.frontend;

import android.content.Intent;
import com.clipback.frontend.share.ShareChannel;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private ShareChannel shareHandler;
    private MethodChannel shareChannel;

    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        shareHandler = new ShareChannel(this);
        shareChannel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "com.huturu.app/share");
        shareChannel.setMethodCallHandler(shareHandler);
    }

    @Override public void cleanUpFlutterEngine(FlutterEngine engine) {
        if (shareChannel != null) shareChannel.setMethodCallHandler(null);
        if (shareHandler != null) shareHandler.dispose();
        super.cleanUpFlutterEngine(engine);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (shareHandler != null) shareHandler.onActivityResult(requestCode);
    }
}
