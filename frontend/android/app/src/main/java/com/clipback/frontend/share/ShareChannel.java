package com.clipback.frontend.share;

import android.app.Activity;
import android.content.Intent;
import io.flutter.plugin.common.MethodChannel;
import org.json.*;
import java.util.*;

public final class ShareChannel implements MethodChannel.MethodCallHandler {
    public static final int RECOVERY_REQUEST = 8073;
    private final Activity activity;
    private final ShareStore store;
    private MethodChannel.Result pending;
    public ShareChannel(Activity activity) { this.activity=activity; store=new ShareStore(activity); }
    @Override public void onMethodCall(io.flutter.plugin.common.MethodCall call, MethodChannel.Result result) {
        try {
            switch(call.method) {
                case "getState": result.success(convert(store.snapshot())); break;
                case "blockCredential": result.success(store.blockCredential()); break;
                case "publishCredential": result.success(store.publishCredential(new JSONObject((Map<?,?>)call.arguments))); break;
                case "presentDraft":
                    String id=call.argument("id");
                    if(pending!=null) { result.error("busy","공유 창이 이미 열려 있습니다.",null); break; }
                    if(store.draft(id)==null) { result.error("missing","공유 항목이 없습니다.",null); break; }
                    pending=result;
                    try {
                        activity.startActivityForResult(new Intent(activity,ShareRecoveryActivity.class).putExtra("draftId",id),RECOVERY_REQUEST);
                    } catch (Exception failure) { pending=null; throw failure; }
                    break;
                case "acknowledgeReceipts": store.acknowledge(call.argument("ids")); result.success(null); break;
                default: result.notImplemented();
            }
        } catch(Exception failure) { result.error("share_storage","공유 정보를 보관하지 못했습니다. 다시 시도해 주세요.",null); }
    }
    public void onActivityResult(int requestCode) { if(requestCode==RECOVERY_REQUEST && pending!=null) { pending.success(null); pending=null; } }
    public void dispose() { if(pending!=null) { pending.error("disposed","공유 창 연결이 종료되었습니다.",null); pending=null; } }
    static Object convert(Object value) throws JSONException {
        if(value==JSONObject.NULL)return null;
        if(value instanceof JSONObject) { Map<String,Object> result=new HashMap<>(); Iterator<String> keys=((JSONObject)value).keys(); while(keys.hasNext()){String key=keys.next();result.put(key,convert(((JSONObject)value).get(key)));}return result; }
        if(value instanceof JSONArray) { List<Object> result=new ArrayList<>(); for(int i=0;i<((JSONArray)value).length();i++)result.add(convert(((JSONArray)value).get(i)));return result; }
        return value;
    }
}
