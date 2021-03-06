package com.hkrt.common;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import org.json.JSONObject;

import java.util.ArrayList;

import io.flutter.BuildConfig;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import static android.app.Activity.RESULT_OK;

/**
 * FlutterPlugin
 */
public class FlutterPlugin implements MethodCallHandler, PluginRegistry.ActivityResultListener {

    Activity activity;

    Result result;

    public FlutterPlugin(Activity activity) {
        this.activity = activity;
    }

    /**
     * Plugin registration.
     */

    static Registrar mRegistrar;

    public static void registerWith(Registrar registrar) {
        mRegistrar = registrar;
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_plugin");
        FlutterPlugin plugin = new FlutterPlugin(registrar.activity());
        channel.setMethodCallHandler(plugin);
        registrar.addActivityResultListener(plugin);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        this.result = result;
        switch (call.method) {
            case "getPlatformVersion":
//                Intent intent = new Intent(new Intent(mRegistrar.context(), EtScanActivity.class));
//                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
//                mRegistrar.context().startActivity(intent);
//                System.out.println("----- " + mRegistrar.activity().getLocalClassName());
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "getIdCardFront":
                showScanView();
                Intent intent = new Intent(mRegistrar.context(), EtScanActivity.class);
                intent.putExtra("side", "front");
                mRegistrar.activity().startActivityForResult(intent, 1110);
                break;
            case "getIdCardBack":
                intent = new Intent(mRegistrar.context(), EtScanActivity.class);
                intent.putExtra("side", "back");
                mRegistrar.activity().startActivityForResult(intent, 1111);
                break;
            case "getBankCard":
                intent = new Intent(mRegistrar.context(), EtScanCardActivity.class);
                mRegistrar.activity().startActivityForResult(intent, 1112);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void showScanView() {

    }


    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        try {
            switch (requestCode) {
                case 1110:
                    System.out.println("----    " + 1110);
                    if (resultCode == RESULT_OK) {
                        System.out.println("----    " + 1111);
                        ArrayList<String> dataStr = (ArrayList<String>) data.getSerializableExtra("listResult");
                        System.out.println("----    " + 1112);
                        JSONObject jsonObject = new JSONObject();
                        jsonObject.put("idCardName", dataStr.get(0));
                        jsonObject.put("idCardAddress", dataStr.get(4));
                        jsonObject.put("idCardNum", dataStr.get(5));
                        jsonObject.put("idCardBirth", dataStr.get(3));
                        for (String item : dataStr) {
                            Log.e("hkrt", item);
                        }
                        String path = data.getStringExtra("imagepath");
                        jsonObject.put("cardImageFontPath", path);
                        result.success(jsonObject.toString());
                    } else {
                        result.success("fail");
                    }
                    break;
                case 1111:
                    if (resultCode == RESULT_OK) {
                        ArrayList<String> dataStr = (ArrayList<String>) data.getSerializableExtra("listResult");
                        String side = data.getStringExtra("side");
                        JSONObject jsonObject = new JSONObject();
                        jsonObject.put("idCardIssuingAuthority", dataStr.get(0));
                        jsonObject.put("idCardExpDate", dataStr.get(1));
                        for (String item : dataStr) {
                            if(BuildConfig.DEBUG){
                                Log.e("hkrt", item);
                            }
                        }
                        String path = data.getStringExtra("imagepath");
                        jsonObject.put("cardImageBackPath", path);
                        result.success(jsonObject.toString());
                    } else {
                        result.success("fail");
                    }
                    break;
                case 1112:
                    if (resultCode == RESULT_OK) {
//                ArrayList<String> dataStr = (ArrayList<String>) data.getSerializableExtra("listResult");
                        String bankcard = data.getStringExtra("bankcard");
                        String path = data.getStringExtra("path");
                        JSONObject jsonObject = new JSONObject();
                        jsonObject.put("bankCardNo", bankcard);
                        jsonObject.put("bankCardImgPath", path);
                        if(BuildConfig.DEBUG){
                            Log.e("hkrt", jsonObject.toString());
                        }
                        result.success(jsonObject.toString());
                    } else {
                        result.success("fail");
                    }
                    break;
                default:
                    break;
            }
        }catch (Exception  e){
            e.printStackTrace();
        }
        return true;
    }
}
