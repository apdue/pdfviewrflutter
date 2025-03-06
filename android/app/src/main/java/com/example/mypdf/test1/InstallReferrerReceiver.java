package com.example.mypdf.test1;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;

public class InstallReferrerReceiver extends BroadcastReceiver {
    private static final String TAG = "InstallReferrerReceiver";
    private static final String PREFS_NAME = "InstallReferrerPrefs";
    private static final String REFERRER_KEY = "referrer";
    private static final String TIMESTAMP_KEY = "timestamp";

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(TAG, "Received broadcast: " + intent.getAction());
        
        if (intent.getAction() != null && intent.getAction().equals("com.android.vending.INSTALL_REFERRER")) {
            Bundle extras = intent.getExtras();
            if (extras != null) {
                String referrer = extras.getString("referrer");
                Log.d(TAG, "Received referrer: " + referrer);

                if (referrer != null) {
                    SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                    SharedPreferences.Editor editor = prefs.edit();
                    editor.putString(REFERRER_KEY, referrer);
                    editor.putLong(TIMESTAMP_KEY, System.currentTimeMillis());
                    editor.apply();
                    Log.d(TAG, "Stored referrer in SharedPreferences: " + referrer);
                } else {
                    Log.d(TAG, "Referrer is null");
                }
            } else {
                Log.d(TAG, "No extras in intent");
            }
        } else {
            Log.d(TAG, "Not an INSTALL_REFERRER intent");
        }
    }
} 