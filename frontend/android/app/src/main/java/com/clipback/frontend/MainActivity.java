package com.clipback.frontend;

import android.content.Intent;
import com.clipback.frontend.image.HeicJpegConverter;
import com.clipback.frontend.share.ShareChannel;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private ShareChannel shareHandler;
    private MethodChannel shareChannel;
    private HeicJpegConverter imageHandler;
    private MethodChannel imageChannel;

    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        shareHandler = new ShareChannel(this);
        shareChannel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "com.huturu.app/share");
        shareChannel.setMethodCallHandler(shareHandler);
        imageHandler = new HeicJpegConverter();
        imageChannel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "com.huturu.app/image");
        imageChannel.setMethodCallHandler(imageHandler);
    }

    @Override public void cleanUpFlutterEngine(FlutterEngine engine) {
        if (shareChannel != null) shareChannel.setMethodCallHandler(null);
        if (shareHandler != null) shareHandler.dispose();
        if (imageChannel != null) imageChannel.setMethodCallHandler(null);
        if (imageHandler != null) imageHandler.dispose();
        super.cleanUpFlutterEngine(engine);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (shareHandler != null) shareHandler.onActivityResult(requestCode);
    }
}
