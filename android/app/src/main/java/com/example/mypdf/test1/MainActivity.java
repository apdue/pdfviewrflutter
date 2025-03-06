package com.example.mypdf.test1;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final String CHANNEL = "com.example.mypdf.test1/install_referrer";
    private static final String PREFS_NAME = "InstallReferrerPrefs";
    private static final String REFERRER_KEY = "referrer";
    private static final String TIMESTAMP_KEY = "timestamp";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                Log.d(TAG, "Method call received: " + call.method);
                
                if (call.method.equals("getInstallReferrer")) {
                    Log.d(TAG, "getInstallReferrer called");
                    SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                    String referrer = prefs.getString(REFERRER_KEY, null);
                    long timestamp = prefs.getLong(TIMESTAMP_KEY, 0);
                    
                    Log.d(TAG, "Retrieved from SharedPreferences - Referrer: " + referrer);
                    Log.d(TAG, "Retrieved from SharedPreferences - Timestamp: " + timestamp);
                    
                    if (referrer != null) {
                        Log.d(TAG, "Returning referrer data to Flutter");
                        result.success(referrer);
                    } else {
                        Log.d(TAG, "No referrer data found");
                        result.success(null);  // Return null for direct installs
                    }
                } else {
                    result.notImplemented();
                }
            });
    }
} 