package com.easemob.djp.record_amr;

import android.content.Context;
import android.media.MediaPlayer;
import android.media.MediaRecorder;

import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;


/** RecordAmrPlugin */
public class RecordAmrPlugin implements FlutterPlugin, MethodCallHandler, MediaPlayer.OnCompletionListener {
  private static final String TAG = "RecordAmr";

  private MethodChannel channel;
  //文件路径
  private String filePath;
  //文件夹路径
  private String FolderPath = "/EMRecord/";

  private MediaRecorder mMediaRecorder;

  private MediaPlayer mediaPlayer;

  private Context context;


  private Handler mainHandler = new Handler(Looper.getMainLooper());

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "record_amr");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("startVoiceRecord")) {
      this.startRecord(result);
    }
    else if (call.method.equals("stopVoiceRecord")) {
      this.stopRecord(result);
    }
    else if (call.method.equals("cancelVoiceRecord")) {
      this.cancelRecord(result);
    }
    else if (call.method.equals("play")) {
      HashMap map = (HashMap) call.arguments;
      String path = (String) map.get("path");
      this.play(path, result);
    }
    else if (call.method.equals("stopPlaying")) {
      this.stop(result);
    }
   else{
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  private long startTime;

  // 开始录音
  private void startRecord(Result result) {
    if (mMediaRecorder == null)
      mMediaRecorder = new MediaRecorder();
    try {
      startTime = System.currentTimeMillis();
      mMediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);// 设置麦克风
      mMediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.DEFAULT);
      mMediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
      filePath = context.getFilesDir().getPath() + "/" + startTime + ".amr" ;
      mMediaRecorder.setOutputFile(filePath);
      mMediaRecorder.prepare();
      mMediaRecorder.start();
      updateMicStatus();
      result.success(Boolean.valueOf(true));
    } catch (Exception e) {
      mMediaRecorder.reset();
      mMediaRecorder.release();
      mMediaRecorder = null;
      filePath = "";
      result.success(Boolean.valueOf(false));
    }
  }

  // 停止录音
  private void stopRecord(Result result) {

    Map<String, Object> map = new HashMap<>();
    map.put("duration", 0L);
    map.put("path", "");
    do {
      try {
        if (mMediaRecorder == null) {
          break;
        }else {
          mMediaRecorder.stop();
          map.put("duration", (System.currentTimeMillis() - startTime) / 1000);
          map.put("path", filePath);
          mMediaRecorder.reset();
          mMediaRecorder.release();
          filePath = "";
          break;
        }
      }catch (RuntimeException e){
        File file = new File(filePath);
        if (file.exists())
        {
          file.delete();
        }

      }finally {
        mMediaRecorder = null;
        filePath = "";
      }
    }while (false);

    result.success(map);
  }

  private void cancelRecord(Result result) {
    mMediaRecorder.stop();
    mMediaRecorder.reset();
    mMediaRecorder.release();
    mMediaRecorder = null;
    filePath = "";
    result.success(Boolean.valueOf(true));
  }

  private void play(String path, Result result) {

    if (mediaPlayer != null && filePath.equals(path)) {
      result.success(Boolean.TRUE);
      return;
    } else {
      if (filePath != null) {
        stop(null);
      }
    }
    this.stop(null);

    filePath = path;
    mediaPlayer = new  MediaPlayer();
    try {
      mediaPlayer.setDataSource(path);
      mediaPlayer.setOnCompletionListener(this);
      mediaPlayer.prepare();
      mediaPlayer.start();
      result.success(Boolean.TRUE);
    } catch (IOException e) {
      result.success(Boolean.FALSE);
      e.printStackTrace();
    }
  }

  private void stop(Result result) {
    if (mediaPlayer != null) {
      if (mediaPlayer.isPlaying() == true) {
          mediaPlayer.stop();
      }
      mediaPlayer.reset();
      mediaPlayer.release();
      mediaPlayer = null;
    }
    if (result != null) {
      HashMap map = new HashMap();
      map.put("error", Boolean.FALSE);
      map.put("path" , filePath != null ? filePath : "");
      channel.invokeMethod("stopPlaying", map);
    }
    filePath = null;
  }

  private double BASE = 3000;
  private int SPACE = 300;// 间隔取样时间

  // 获取麦克风音量大小
  private void updateMicStatus() {
    if (mMediaRecorder != null) {
      double ratio = (double)mMediaRecorder.getMaxAmplitude() / BASE;
      double db = 0;// 分贝
      if (ratio > 1) ratio = 1;
      db = ratio;
      final double finalDb = db;
      mainHandler.post(new Runnable() {
        @Override
        public void run() {
          channel.invokeMethod("volume", finalDb);
        }
      });
      mHandler.postDelayed(mUpdateMicStatusTimer, SPACE);
    }
  }

  private final Handler mHandler = new Handler();
  private Runnable mUpdateMicStatusTimer = new Runnable() {
    public void run() {
      updateMicStatus();
    }
  };

  @Override
  public void onCompletion(MediaPlayer mediaPlayer) {
    mediaPlayer.stop();
    mediaPlayer.reset();
    mediaPlayer.release();
    this.mediaPlayer = null;
    HashMap map = new HashMap();
    map.put("error", Boolean.FALSE);
    map.put("path" , filePath != null ? filePath : "");
    channel.invokeMethod("stopPlaying", map);
    filePath = null;
  }
}


