package com.clipback.frontend.image;

import android.annotation.TargetApi;
import android.graphics.Bitmap;
import android.graphics.ImageDecoder;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Converts the save screen's HEIC/HEIF photo to JPEG (#380): full resolution, orientation
 * applied by the platform decoder, and no source metadata (so no GPS). HEIF decoding needs
 * Android 9 (API 28); older devices and decode failures reply null, so the app uploads the
 * original and the server's 415 shows the supported-format message.
 */
public final class HeicJpegConverter implements MethodChannel.MethodCallHandler {
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!"heicToJpeg".equals(call.method)) {
            result.notImplemented();
            return;
        }
        byte[] bytes = call.argument("bytes");
        Integer quality = call.argument("quality");
        if (bytes == null || quality == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.success(null);
            return;
        }
        executor.execute(() -> {
            byte[] jpeg = convert(bytes, quality);
            main.post(() -> result.success(jpeg));
        });
    }

    @TargetApi(Build.VERSION_CODES.P)
    static byte[] convert(byte[] bytes, int quality) {
        Bitmap bitmap = null;
        try {
            bitmap = ImageDecoder.decodeBitmap(
                ImageDecoder.createSource(ByteBuffer.wrap(bytes)),
                (decoder, info, source) -> decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE));
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            // Bitmap.compress writes pixels only: no EXIF, GPS or orientation tag.
            return bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out) ? out.toByteArray() : null;
        } catch (Exception | OutOfMemoryError error) {
            return null;
        } finally {
            if (bitmap != null) bitmap.recycle();
        }
    }

    public void dispose() {
        executor.shutdownNow();
    }
}
