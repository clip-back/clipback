package com.clipback.frontend.share;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import java.io.*;
import java.util.regex.*;

final class ShareInput {
    private static final Pattern URL = Pattern.compile("https?://[^\\s<>]+", Pattern.CASE_INSENSITIVE);
    static String receive(Context context, Intent intent, ShareStore store) throws Exception {
        return receive(context, intent, store, java.util.UUID.randomUUID().toString());
    }
    static String receive(Context context, Intent intent, ShareStore store, String operationId) throws Exception {
        if (store.draft(operationId) != null) return operationId;
        if (!Intent.ACTION_SEND.equals(intent.getAction())) throw rejected("링크 하나 또는 이미지 한 장만 공유할 수 있습니다.");
        String mime = intent.getType();
        if ("text/plain".equals(mime)) {
            CharSequence value = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
            String text = value == null ? "" : value.toString();
            if (text.length() > 5000) throw rejected("공유 텍스트가 너무 깁니다.");
            Matcher matcher = URL.matcher(text);
            if (!matcher.find()) throw rejected("Instagram 또는 YouTube 링크를 공유해 주세요.");
            String url = matcher.group().replaceAll("[),.]+$", "");
            if (matcher.find()) throw rejected("한 번에 링크 하나만 공유해 주세요.");
            Uri parsed = Uri.parse(url); String host = parsed.getHost();
            host = host == null ? "" : host.toLowerCase(java.util.Locale.ROOT);
            int defaultPort = "https".equalsIgnoreCase(parsed.getScheme()) ? 443 : 80;
            boolean supported = host.equals("youtube.com") || host.endsWith(".youtube.com") || host.equals("youtu.be") ||
                host.equals("instagram.com") || host.equals("www.instagram.com") || host.equals("m.instagram.com");
            if (url.length() > 2048 || parsed.getUserInfo() != null || (parsed.getPort() != -1 && parsed.getPort() != defaultPort) || !supported)
                throw rejected("Instagram 또는 YouTube 링크만 저장할 수 있습니다.");
            return store.create(operationId, url, text, null, null);
        }
        if (mime != null && mime.startsWith("image/")) {
            Object stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (!(stream instanceof Uri) || !"content".equals(((Uri) stream).getScheme())) throw rejected("읽을 수 있는 이미지 한 장을 공유해 주세요.");
            if (intent.getClipData() != null && intent.getClipData().getItemCount() > 1) throw rejected("이미지는 한 장씩 공유해 주세요.");
            byte[] bytes;
            try (InputStream input = context.getContentResolver().openInputStream((Uri) stream); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                if (input == null) throw rejected("이미지를 읽을 수 없습니다.");
                byte[] buffer = new byte[8192]; int length;
                while ((length = input.read(buffer)) != -1) {
                    if (out.size() + length > ShareStore.MAX_IMAGE) throw rejected("이미지는 10MiB 이하만 공유할 수 있습니다.");
                    out.write(buffer, 0, length);
                }
                bytes = out.toByteArray();
            } catch (ShareFailure rejection) { throw rejection; }
            // A missing URI grant or unreadable provider is the sender's input, not a storage failure.
            catch (Exception unreadable) { throw rejected("이미지를 읽을 수 없습니다."); }
            String actual = imageMime(bytes);
            if (actual == null) throw rejected("PNG, JPEG, WebP 이미지만 지원합니다. HEIC와 동영상은 지원하지 않습니다.");
            android.graphics.BitmapFactory.Options bounds = new android.graphics.BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw rejected("이미지 파일을 읽을 수 없습니다.");
            return store.create(operationId, null, null, bytes, actual);
        }
        throw rejected("Instagram·YouTube 링크 또는 PNG·JPEG·WebP 이미지를 공유해 주세요.");
    }
    private static ShareFailure rejected(String reason) { return new ShareFailure(ShareFailure.Kind.REJECTED, reason); }
    static String imageMime(byte[] data) {
        if (data.length >= 8 && (data[0]&255)==137 && data[1]==80 && data[2]==78 && data[3]==71 && data[4]==13 && data[5]==10 && data[6]==26 && data[7]==10) return "image/png";
        if (data.length >= 3 && (data[0]&255)==255 && (data[1]&255)==216 && (data[2]&255)==255) return "image/jpeg";
        if (data.length >= 12 && data[0]==82 && data[1]==73 && data[2]==70 && data[3]==70 && data[8]==87 && data[9]==69 && data[10]==66 && data[11]==80) return "image/webp";
        return null;
    }
}
