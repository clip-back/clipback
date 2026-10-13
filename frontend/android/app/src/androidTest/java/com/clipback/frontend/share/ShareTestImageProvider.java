package com.clipback.frontend.share;

import android.content.*;
import android.database.Cursor;
import android.graphics.*;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import java.io.*;

public final class ShareTestImageProvider extends ContentProvider {
    @Override public boolean onCreate(){return true;}
    @Override public String getType(Uri uri){return "image/png";}
    @Override public synchronized ParcelFileDescriptor openFile(Uri uri,String mode) throws FileNotFoundException {
        if(!"r".equals(mode))throw new FileNotFoundException("Read only");
        File image=new File(getContext().getCacheDir(),"share-fixture.png");
        if (!image.exists()) try(FileOutputStream output=new FileOutputStream(image)){
            Bitmap bitmap=Bitmap.createBitmap(640,480,Bitmap.Config.ARGB_8888); Canvas canvas=new Canvas(bitmap);canvas.drawColor(Color.rgb(255,235,205));
            Paint paint=new Paint();paint.setColor(Color.DKGRAY);paint.setTextSize(36);canvas.drawText("SHARE SCREENSHOT FIXTURE",24,230,paint);bitmap.compress(Bitmap.CompressFormat.PNG,100,output);bitmap.recycle();
        }catch(IOException error){image.delete();throw new FileNotFoundException("Fixture unavailable");}
        return ParcelFileDescriptor.open(image,ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public Cursor query(Uri uri,String[] projection,String selection,String[] selectionArgs,String sortOrder){return null;}
    @Override public Uri insert(Uri uri,ContentValues values){throw new UnsupportedOperationException();}
    @Override public int delete(Uri uri,String selection,String[] selectionArgs){throw new UnsupportedOperationException();}
    @Override public int update(Uri uri,ContentValues values,String selection,String[] selectionArgs){throw new UnsupportedOperationException();}
}
