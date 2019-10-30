package com.hkrt.common;

import android.annotation.TargetApi;
import android.app.Activity;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.hardware.Camera;
import android.hardware.Camera.Size;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Vibrator;
import android.telephony.TelephonyManager;
import android.text.format.Time;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.etop.SIDCard.SIDCardAPI;
import com.hkrt.common.scan.IdCardInfoConfig;
import com.hkrt.common.scan.NavigationBarHeightUtils;
import com.hkrt.common.scan.StreamEmpowerFileUtils;
import com.hkrt.common.scan.UserIdUtils;
import com.hkrt.common.views.SIDViewfinderView;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * @author 陈金广
 */
public class EtScanActivity extends Activity implements SurfaceHolder.Callback, Camera.PreviewCallback {

    private Camera mCamera;
    private SurfaceView surfaceView;
    private RelativeLayout mainrl;
    private SurfaceHolder surfaceHolder;
    private SIDCardAPI sidApi = null;
    private boolean isFristRecog = true;
    private int preWidth = 0;
    private int preHeight = 0;
    private int screenWidth;
    private int screenHeight;
    private SIDViewfinderView myView = null;
    //    private boolean bInitKernal = false;
    private ImageButton ibBack;
    private ImageButton ibFlashOn;
    private ImageButton ibFlashOff;
    private TextView tvSign;
    private Vibrator mVibrator;
    private boolean isBackside = false;
    private String userId = UserIdUtils.getUserId();
    private IdCardInfoConfig cardInfoConfig;
    private Boolean isSaveImage;
    private String saveImagePATH;
    private String strCaptureFilePath;
    private String strCaptureFileHeadPath;

    private String side;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        UserIdUtils.setUserId("947C5EC227912874BCB9");
        try {
            //2.写入授权文件
            //2.Write authorization file
            StreamEmpowerFileUtils.copyDataBase(this);
        } catch (IOException e) {
            e.printStackTrace();
        }
        side = getIntent().getStringExtra("side");
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        //获取设置的配置信息
        Configuration cf = this.getResources().getConfiguration();
        int noriention = cf.orientation;
        if (noriention == Configuration.ORIENTATION_LANDSCAPE) {
            initCardKernal();//初始化核心
        }

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        // // 屏幕常亮
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_etscan);

        cardInfoConfig = (IdCardInfoConfig) getIntent().getSerializableExtra(UserIdUtils.INTENT_CARD_CONFIG);
        if (cardInfoConfig == null) {
            cardInfoConfig = new IdCardInfoConfig();
        }
        cardInfoConfig.setStrSaveImagePath("/weizhangpu/");
        isSaveImage = cardInfoConfig.getIsSaveImage();
        saveImagePATH = Environment.getExternalStorageDirectory() + cardInfoConfig.getStrSaveImagePath();
        File file = new File(saveImagePATH);
        if (!file.exists() && !file.isDirectory()) {
            file.mkdirs();
        }
        findView();
    }

    @TargetApi(Build.VERSION_CODES.ECLAIR)
    private void findView() {
        surfaceView = findViewById(R.id.etop_sv);
        mainrl = findViewById(R.id.etop_rl_main);
        ibBack = findViewById(R.id.etop_ib_back);
        ibFlashOn = findViewById(R.id.etop_ib_flash_on);
        ibFlashOff = findViewById(R.id.etop_ib_flash_off);
        tvSign = findViewById(R.id.etop_tv_sign);

        DisplayMetrics metric = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(metric);
        screenWidth = metric.widthPixels; // 屏幕宽度（像素）
        screenHeight = metric.heightPixels; // 屏幕高度（像素）

        int backW = (int) (screenWidth * 0.066796875);
        int backH = backW;
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(backW, backH);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT, RelativeLayout.TRUE);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM, RelativeLayout.TRUE);

        layoutParams.leftMargin = (int) ((backH / 2));
        layoutParams.bottomMargin = (int) (screenHeight * 0.15);
        ibBack.setLayoutParams(layoutParams);

        int flashW = (int) (screenWidth * 0.066796875);
        int flashH = (int) (flashW * 69 / 106);
        layoutParams = new RelativeLayout.LayoutParams(flashW, flashH);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT, RelativeLayout.TRUE);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP, RelativeLayout.TRUE);
        layoutParams.leftMargin = (int) ((backH / 2));
        layoutParams.topMargin = (int) (screenHeight * 0.15);
        ibFlashOn.setLayoutParams(layoutParams);
        ibFlashOff.setLayoutParams(layoutParams);
        ibFlashOff.setVisibility(View.INVISIBLE);

        layoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT);
        layoutParams.addRule(RelativeLayout.CENTER_IN_PARENT, RelativeLayout.TRUE);
        tvSign.setLayoutParams(layoutParams);
        if (isBackside) {
            tvSign.setText("二代证背面");
            tvSign.setTextColor(Color.GREEN);
            tvSign.setTextSize(TypedValue.COMPLEX_UNIT_PX, screenHeight / 20);
        } else {
            tvSign.setText("二代证正面");
            tvSign.setTextColor(Color.GREEN);
            tvSign.setTextSize(TypedValue.COMPLEX_UNIT_PX, screenHeight / 20);
        }
        if (myView == null) {
            myView = new SIDViewfinderView(EtScanActivity.this, screenWidth, screenHeight);
            mainrl.addView(myView);
        }

        surfaceHolder = surfaceView.getHolder();
        surfaceHolder.addCallback(EtScanActivity.this);
        surfaceHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
        surfaceView.setFocusable(true);
        surfaceView.setOnClickListener(view -> {
            if (mCamera != null) {
                mCamera.cancelAutoFocus();
                Camera.Parameters params = mCamera.getParameters();
                params.setFocusMode(Camera.Parameters.FLASH_MODE_AUTO);
                mCamera.setParameters(params);
                mCamera.autoFocus((success, camera) -> {
                    if (success) {
                        Camera.Parameters params1 = mCamera.getParameters();
                        params1.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                        mCamera.setParameters(params1);
                    }
                });
            }
        });
        mOnClick();
    }

    private void mOnClick() {
        ibBack.setOnClickListener(v -> finish());
        ibFlashOff.setOnClickListener(new OnClickListener() {
            @TargetApi(Build.VERSION_CODES.ECLAIR)
            @Override
            public void onClick(View v) {
                if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) {
                    String mess = "当前设备不支持闪光灯";
                    Toast.makeText(EtScanActivity.this, mess, Toast.LENGTH_SHORT).show();
                } else {
                    if (mCamera != null) {
                        Camera.Parameters parameters = mCamera.getParameters();
                        String flashMode = parameters.getFlashMode();

                        if (flashMode.equals(Camera.Parameters.FLASH_MODE_TORCH)) {
                            parameters.setFlashMode(Camera.Parameters.FLASH_MODE_OFF);
                            try {
                                mCamera.setParameters(parameters);
                            } catch (Exception e) {
                                String mess = "当前设备不支持闪光灯";
                                Toast.makeText(getApplicationContext(), mess, Toast.LENGTH_SHORT).show();
                            }
                            ibFlashOff.setVisibility(View.INVISIBLE);
                            ibFlashOn.setVisibility(View.VISIBLE);
                        }
                    }
                }
            }
        });
        ibFlashOn.setOnClickListener(new OnClickListener() {

            @TargetApi(Build.VERSION_CODES.ECLAIR)
            @Override
            public void onClick(View v) {
                if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) {
                    String mess = "当前设备不支持闪光灯";
                    Toast.makeText(getApplicationContext(), mess, Toast.LENGTH_SHORT).show();
                } else {
                    if (mCamera != null) {
                        Camera.Parameters parameters = mCamera.getParameters();
                        String flashMode = parameters.getFlashMode();
                        if (!(flashMode.equals(Camera.Parameters.FLASH_MODE_TORCH))) {
                            parameters.setFlashMode(Camera.Parameters.FLASH_MODE_TORCH);// 闪光灯常亮
                            try {
                                mCamera.setParameters(parameters);
                            } catch (Exception e) {
                                String mess = "当前设备不支持闪光灯";
                                Toast.makeText(getApplicationContext(), mess, Toast.LENGTH_SHORT).show();
                            }
                            ibFlashOn.setVisibility(View.INVISIBLE);
                            ibFlashOff.setVisibility(View.VISIBLE);
                        }
                    }
                }
            }
        });
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        isFristRecog = true;
        if (mCamera == null) {
            try {
                mCamera = Camera.open();
                Camera.Parameters mParameters = mCamera.getParameters(); //针对魅族手机
                mCamera.setParameters(mParameters);
            } catch (Exception e) {
                e.printStackTrace();
                if (mCamera != null) {
                    mCamera.release();
                    mCamera = null;
                }
                String mess = "无法启用相机";
                Toast.makeText(this, mess, Toast.LENGTH_SHORT).show();
                return;
            }
        }
        initCamera();
    }

    @Override
    public void surfaceChanged(final SurfaceHolder holder, int format, int width, int height) {
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        releaseCamera();//相机用完，资源释放
        releaseKernal();
    }

    /***********************初始化识别核心************************/
    @TargetApi(Build.VERSION_CODES.FROYO)
    private void initCardKernal() {
        if (sidApi == null) {
            sidApi = new SIDCardAPI();
            //SIDCardSetRecogType  在初始化核心成功之后调用
            String cacheDir = (this.getExternalCacheDir()).getPath();
            String useridPath = cacheDir + "/" + userId + ".lic";
            TelephonyManager telephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
            int nRet = sidApi.SIDCardKernalInit("", useridPath, userId, 0x02, 0x02, telephonyManager, this);
            if (nRet != 0) {
                Toast.makeText(EtScanActivity.this, "激活失败，ErrorCode：" + nRet, Toast.LENGTH_SHORT).show();
            } else {
                //就像这样
                if ("back".equals(side)) {
                    isBackside = true;
                    sidApi.SIDCardSetRecogType(2);
                } else if ("front".equals(side)) {
                    isBackside = false;
                    sidApi.SIDCardSetRecogType(1);
                }
                String endTime = sidApi.SIDCardGetEndTime();//获取一个授权结束的日期（2018-5-31）
                String[] time = endTime.split("-");
                int year1 = Integer.parseInt(time[0]);
                int month1 = Integer.parseInt(time[1]);
                int day1 = Integer.parseInt(time[2]);
                //Toast.makeText(getApplicationContext(), endTime, Toast.LENGTH_SHORT).show();

                Time timeSystem = new Time();
                timeSystem.setToNow(); // 取得系统时间。
                int year = timeSystem.year;//年
                int month = timeSystem.month + 1;//月
                int day = timeSystem.monthDay;//日

                if (year1 == year && month1 == month) {//说明年月相同
                    int endDay = day1 - day + 1;
                    if (endDay <= 7 && endDay >= 0) {
                        Toast.makeText(EtScanActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                    //说明年份相同月份不同，且授权截止日期在下月7号之前
                } else if (year1 == year && month1 - month == 1 && day1 < 7) {
                    int days = getDays(year, month);//返回当月天数
                    int endDay = days + day1 - day + 1;
                    if (endDay <= 7 && endDay >= 0) {
                        Toast.makeText(EtScanActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                    //跨年，授权截止日期在1月份，并且在下月7号之前
                } else if (year1 - year == 1 && month1 == 1 && day1 < 7) {
                    int endDay = 32 + day1 - day;
                    if (endDay <= 7 && endDay >= 0) {
                        Toast.makeText(EtScanActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        }
    }

    @TargetApi(14)
    private void initCamera() {
        Camera.Parameters parameters = mCamera.getParameters();
        List<Size> list = parameters.getSupportedPreviewSizes();
        Size previewSize = getAdapterPreviewSize(list, NavigationBarHeightUtils.getWidthDpi(this), screenHeight);
        if (previewSize != null) {
            preWidth = previewSize.width;
            preHeight = previewSize.height;
        } else {
            preWidth = 1280;
            preHeight = 720;
        }

        parameters.setPictureFormat(PixelFormat.JPEG);

        parameters.setPreviewSize(preWidth, preHeight);
        if (parameters.getSupportedFocusModes().contains(
                Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
            parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
        }
        if (parameters.isZoomSupported()) {
            parameters.setZoom(2);
        }
        try {
            mCamera.setPreviewDisplay(surfaceHolder);
        } catch (IOException e) {
            e.printStackTrace();
        }
        mCamera.setPreviewCallback(EtScanActivity.this);
        mCamera.setParameters(parameters);
        mCamera.startPreview();
    }

    @Override
    public void onPreviewFrame(final byte[] data, Camera camera) {
        int buffl = 256;
        char recogval[] = new char[buffl];
        int r = sidApi.SIDCardRecognizeNV21(data, preWidth, preHeight, recogval, buffl);
        if (r == 0 && isFristRecog) {
            isFristRecog = false;
            mVibrator = (Vibrator) getApplication().getSystemService(
                    Service.VIBRATOR_SERVICE);
            mVibrator.vibrate(50);

            if (isSaveImage) {
                if (Environment.getExternalStorageState().equals(Environment.MEDIA_MOUNTED)) {
                    if (!isBackside) {
                        strCaptureFilePath = saveImagePATH +"androidIdCardRight.jpg";
                        strCaptureFileHeadPath = saveImagePATH +  "headandroidIdCardRight.jpg";
                    } else {
                        strCaptureFilePath = saveImagePATH +  "androidIdCardLeft.jpg";
                        strCaptureFileHeadPath = saveImagePATH + "headandroidIdCardLeft.jpg";
                    }
                    File file = new File(strCaptureFilePath);
                    if (file.exists()) {
                        file.delete();
                    }
                    sidApi.SIDCardSaveCardImage(strCaptureFilePath);
                    sidApi.SIDCardSaveHeadImage(strCaptureFileHeadPath);
                } else {
                    Toast.makeText(this, "SD卡异常", Toast.LENGTH_SHORT).show();
                }
            }

            ArrayList<String> listResult = new ArrayList<>();
            int nRecog = sidApi.SIDCardGetRecogType();
            if (nRecog == 1) {
                for (int i = 0; i < 6; i++) {
                    listResult.add(sidApi.SIDCardGetResult(i));
                }
            } else if (nRecog == 2) {
                for (int i = 6; i < 8; i++) {
                    listResult.add(sidApi.SIDCardGetResult(i));
                }
            }
            Intent intent =  new Intent() ;
            intent.putExtra("listResult", listResult);
            intent.putExtra("imagepath", strCaptureFilePath);
            intent.putExtra("side", side);
            setResult(RESULT_OK,intent );
            finish();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        releaseCamera();//释放相机资源
        /*********核心用完释放，否则下次初始化核心会失败*********/
        releaseKernal();
    }

    @Override
    protected void onDestroy() {
        /*********核心用完释放，否则下次初始化核心会失败*********/
        releaseKernal();
        super.onDestroy();

    }

    private void releaseKernal() {
        if (sidApi != null) {
            sidApi.SIDCardKernalUnInit();
            sidApi = null;
        }
    }

    /**
     * 释放相机资源
     */
    private void releaseCamera() {
        if (mCamera != null) {
            mCamera.setPreviewCallback(null);
            mCamera.stopPreview();
            mCamera.release();
            mCamera = null;
        }
    }

    //返回当月天数
    int getDays(int year, int month) {
        int days;
        int FebDay = 28;
        if (isLeap(year)) {
            FebDay = 29;
        }
        switch (month) {
            case 1:
            case 3:
            case 5:
            case 7:
            case 8:
            case 10:
            case 12:
                days = 31;
                break;
            case 4:
            case 6:
            case 9:
            case 11:
                days = 30;
                break;
            case 2:
                days = FebDay;
                break;
            default:
                days = 0;
                break;
        }
        return days;
    }

    private boolean isLeap(int year) {
        return ((year % 100 == 0) && year % 400 == 0) || ((year % 100 != 0) && year % 4 == 0);
    }

    private Size getAdapterPreviewSize(List<Size> list, int screenWidth, int screenHeight) {
        double ASPECT_TOLERANCE = 0.01;//允许的比例误差
        double targetRatio = (double) screenHeight / screenWidth;
        if (targetRatio > 1) {
            targetRatio = (double) screenWidth / screenHeight;
        }
        Size optimalSize = null;
        for (Size size : list) {
            double ratio = (double) size.height / size.width;
            if (ratio > 1) {
                ratio = (double) size.width / size.height;
            }
            if (size.height < 700) {
                continue;
            }
            if (Math.abs(ratio - targetRatio) < ASPECT_TOLERANCE) {
                if (optimalSize != null) {
                    if (optimalSize.width > size.width || optimalSize.height > size.height) {
                        optimalSize = size;
                    }
                } else {
                    optimalSize = size;
                }
            }
        }
        return optimalSize;
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (isFinishing()) {
            setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        }
    }

    //@Override
    //public boolean onKeyDown(int keyCode, KeyEvent event) {
    // return super.onKeyDown(keyCode, event);
    //}
}


