package com.example.mypdf.test1;

import android.content.Context;
import androidx.annotation.NonNull;

import com.android.installreferrer.api.InstallReferrerClient;
import com.android.installreferrer.api.InstallReferrerStateListener;
import com.android.installreferrer.api.ReferrerDetails;
import com.android.installreferrer.api.InstallReferrerClient.InstallReferrerResponse;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class InstallReferrerPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Context context;
    private InstallReferrerClient referrerClient;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "install_referrer");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("getReferrerDetails")) {
            getReferrerDetails(result);
        } else {
            result.notImplemented();
        }
    }

    private void getReferrerDetails(Result result) {
        try {
            referrerClient = InstallReferrerClient.newBuilder(context).build();
            referrerClient.startConnection(new InstallReferrerStateListener() {
                @Override
                public void onInstallReferrerSetupFinished(int responseCode) {
                    try {
                        switch (responseCode) {
                            case InstallReferrerResponse.OK:
                                try {
                                    ReferrerDetails response = referrerClient.getInstallReferrer();
                                    String referrerUrl = response.getInstallReferrer();
                                    
                                    // Check if referrer is empty or null
                                    if (referrerUrl == null || referrerUrl.isEmpty()) {
                                        java.util.Map<String, Object> emptyData = new java.util.HashMap<>();
                                        emptyData.put("error", "NO_REFERRAL");
                                        emptyData.put("code", "NO_DATA");
                                        result.success(emptyData);
                                        return;
                                    }

                                    // Create response map with referrer data
                                    java.util.Map<String, Object> referrerData = new java.util.HashMap<>();
                                    referrerData.put("referrerUrl", referrerUrl);
                                    referrerData.put("referrerClickTime", response.getReferrerClickTimestampSeconds());
                                    referrerData.put("appInstallTime", response.getInstallBeginTimestampSeconds());
                                    referrerData.put("instantExperienceLaunched", response.getGooglePlayInstantParam());
                                    
                                    result.success(referrerData);
                                } catch (Exception e) {
                                    java.util.Map<String, Object> errorData = new java.util.HashMap<>();
                                    errorData.put("error", "NO_REFERRAL");
                                    errorData.put("code", "ERROR_READING");
                                    result.success(errorData);
                                }
                                break;
                            case InstallReferrerResponse.FEATURE_NOT_SUPPORTED:
                                java.util.Map<String, Object> notSupportedData = new java.util.HashMap<>();
                                notSupportedData.put("error", "NO_REFERRAL");
                                notSupportedData.put("code", "NOT_SUPPORTED");
                                result.success(notSupportedData);
                                break;
                            case InstallReferrerResponse.SERVICE_UNAVAILABLE:
                                java.util.Map<String, Object> unavailableData = new java.util.HashMap<>();
                                unavailableData.put("error", "NO_REFERRAL");
                                unavailableData.put("code", "UNAVAILABLE");
                                result.success(unavailableData);
                                break;
                            default:
                                java.util.Map<String, Object> unknownData = new java.util.HashMap<>();
                                unknownData.put("error", "NO_REFERRAL");
                                unknownData.put("code", "UNKNOWN");
                                result.success(unknownData);
                                break;
                        }
                    } finally {
                        referrerClient.endConnection();
                    }
                }

                @Override
                public void onInstallReferrerServiceDisconnected() {
                    java.util.Map<String, Object> disconnectedData = new java.util.HashMap<>();
                    disconnectedData.put("error", "NO_REFERRAL");
                    disconnectedData.put("code", "DISCONNECTED");
                    result.success(disconnectedData);
                }
            });
        } catch (Exception e) {
            java.util.Map<String, Object> errorData = new java.util.HashMap<>();
            errorData.put("error", "NO_REFERRAL");
            errorData.put("code", "INIT_ERROR");
            result.success(errorData);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
} 