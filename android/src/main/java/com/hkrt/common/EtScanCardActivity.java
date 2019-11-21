package com.hkrt.common;

import android.annotation.TargetApi;
import android.app.Activity;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PixelFormat;
import android.hardware.Camera;
import android.hardware.Camera.Size;
import android.os.Bundle;
import android.os.Environment;
import android.os.Vibrator;
import android.telephony.TelephonyManager;
import android.text.format.Time;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.Window;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.RelativeLayout;
import android.widget.Toast;

import com.etop.BankCard.BankCardAPI;
import com.etop.BankCard.BankCardInfoAPI;
import com.hkrt.common.scan.IdCardInfoConfig;
import com.hkrt.common.scan.NavigationBarHeightUtils;
import com.hkrt.common.scan.StreamEmpowerFileUtils;
import com.hkrt.common.scan.UserIdUtils;
import com.hkrt.common.views.BankViewfinderView;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.List;


/**
 * @author chenjinguang
 */
public class EtScanCardActivity extends Activity implements SurfaceHolder.Callback, Camera.PreviewCallback {
    private boolean bInitKernal = false;
    private BankCardAPI bankApi = null;
    private BankCardInfoAPI cardinfoapi = null;
    private static final String PATH = Environment.getExternalStorageDirectory() + "/alpha/BankCard/";
    private Camera mCamera;
    private SurfaceView mSurfaceView;
    private RelativeLayout mainRl;
    private SurfaceHolder surfaceHolder;
    private ImageButton ibBack;
    private ImageButton ibFlash;
    private int screenWidth;
    private int screenHeight;
    private Vibrator mVibrator;
    private Bitmap bitmap;
    private int preWidth = 0;
    private int preHeight = 0;
    private boolean isROI = false;
    private int[] m_ROI = {0, 0, 0, 0};
    private BankViewfinderView myView;
    private IdCardInfoConfig cardInfoConfig;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        writeEtScanLicense();
        File file = new File(PATH);
        if (!file.exists() && !file.isDirectory()) {
            file.mkdirs();
        }

        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);// 横屏
        Configuration cf = this.getResources().getConfiguration(); //获取设置的配置信息
        int noriention = cf.orientation;
        if (noriention == Configuration.ORIENTATION_LANDSCAPE) {
            if (!bInitKernal) {
                initKernal();//初始化核心
            }
        }
        requestWindowFeature(Window.FEATURE_NO_TITLE);// 隐藏标题
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);// 设置全屏
        // // 屏幕常亮
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.etop_activity_scan_card);

        cardInfoConfig = (IdCardInfoConfig) getIntent().getSerializableExtra(UserIdUtils.INTENT_CARD_CONFIG);
        if (cardInfoConfig == null) {
            cardInfoConfig = new IdCardInfoConfig();
        }
        cardInfoConfig.setStrSaveImagePath("/weizhangpu/");
        findView();
    }

    private void findView() {
        mSurfaceView = (SurfaceView) findViewById(R.id.etop_sv);
        mainRl = (RelativeLayout) findViewById(R.id.etop_rl_main);
        ibBack = (ImageButton) findViewById(R.id.etop_ib_back);
        ibFlash = (ImageButton) findViewById(R.id.etop_ib_flash);

        DisplayMetrics metric = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(metric);
        screenWidth = metric.widthPixels;   // 屏幕宽度（像素）
        screenHeight = metric.heightPixels; // 屏幕高度（像素）

        int back_w = (int) (screenWidth * 0.066796875);
        int back_h = (int) (back_w * 1);
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(back_w, back_h);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT, RelativeLayout.TRUE);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM, RelativeLayout.TRUE);
        layoutParams.leftMargin = (int) ((back_h / 2));
        layoutParams.bottomMargin = (int) (screenHeight * 0.15);
        ibBack.setLayoutParams(layoutParams);

        int flash_w = (int) (screenWidth * 0.066796875);
        int flash_h = (int) (flash_w * 69 / 106);
        layoutParams = new RelativeLayout.LayoutParams(flash_w, flash_h);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT, RelativeLayout.TRUE);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP, RelativeLayout.TRUE);
        layoutParams.leftMargin = (int) ((back_h / 2));
        layoutParams.topMargin = (int) (screenHeight * 0.15);
        ibFlash.setLayoutParams(layoutParams);

        surfaceHolder = mSurfaceView.getHolder();
        surfaceHolder.addCallback(this);
        surfaceHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);

        ibBack.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        ibFlash.setOnClickListener(new OnClickListener() {

            @Override
            public void onClick(View v) {
                if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) {
                    String mess = getResources().getString(R.string.toast_flash);
                    Toast.makeText(EtScanCardActivity.this, mess, Toast.LENGTH_LONG).show();
                } else {
                    if (mCamera != null) {
                        Camera.Parameters parameters = mCamera.getParameters();
                        String flashMode = parameters.getFlashMode();
                        if (flashMode.equals(Camera.Parameters.FLASH_MODE_TORCH)) {
                            parameters.setFlashMode(Camera.Parameters.FLASH_MODE_OFF);
                            parameters.setExposureCompensation(0);
                            ibFlash.setBackgroundResource(R.mipmap.etop_flash_off);
                        } else {
                            parameters.setFlashMode(Camera.Parameters.FLASH_MODE_TORCH);// 闪光灯常亮
                            parameters.setExposureCompensation(-1);
                            ibFlash.setBackgroundResource(R.mipmap.etop_flash_camera);
                        }
                        try {
                            mCamera.setParameters(parameters);
                        } catch (Exception e) {
                            String mess = getResources().getString(R.string.toast_flash);
                            Toast.makeText(EtScanCardActivity.this, mess, Toast.LENGTH_LONG).show();
                        }
                        mCamera.startPreview();
                    }
                }
            }
        });
    }

    public void writeEtScanLicense() {
        UserIdUtils.setUserId("947C5EC227912874BCB9");
        try {
            //2.写入授权文件
            //2.Write authorization file
            StreamEmpowerFileUtils.copyDataBase(this);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void surfaceCreated(final SurfaceHolder holder) {
        initKernal();//初始化识别核心

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
                String mess = getResources().getString(R.string.toast_camera);
                Toast.makeText(this, mess, Toast.LENGTH_SHORT).show();
                return;
            }
        }
        initCamera(holder);
    }

    @Override
    public void surfaceChanged(final SurfaceHolder holder, int format, int width, int height) {
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        try {
            if (bankApi != null) {
                bankApi.ScanEnd();
                bankApi = null;
            }
            if (cardinfoapi != null) {
                cardinfoapi.UninitCardInfo();
                cardinfoapi = null;
            }
            releaseCamera();
        } catch (Exception e) {
        }
    }

    /*************************初始化银行卡识别核心*************************/
    public void initKernal() {
        if (bankApi == null) {
            bankApi = new BankCardAPI();
            String cacheDir = (this.getExternalCacheDir()).getPath();
            String userIdPath = cacheDir + "/" + UserIdUtils.UserId + ".lic";
            TelephonyManager telephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);

            int nRet = bankApi.ScanStart("", userIdPath, UserIdUtils.UserId, 0x04, 0x02, telephonyManager, this);
            if (nRet != 0) {
                Toast.makeText(getApplicationContext(), "激活失败:nRet = " + nRet, Toast.LENGTH_SHORT).show();
                bInitKernal = false;
            } else {
                bInitKernal = true;
                if (cardinfoapi == null) {
                    cardinfoapi = new BankCardInfoAPI();
                    cardinfoapi.InitCardInfo();
                }

                String endTime = bankApi.GetEndTime();//获取一个授权结束的日期（2018-3-31）
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
                        Toast.makeText(EtScanCardActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                    //说明年份相同月份不同，且授权截止日期在下月7号之前
                } else if (year1 == year && month1 - month == 1 && day1 < 7) {
                    int days = getDays(year, month);//返回当月天数
                    int endDay = days + day1 - day + 1;
                    if (endDay <= 7 && endDay >= 0) {
                        Toast.makeText(EtScanCardActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                    //跨年，授权截止日期在1月份，并且在下月7号之前
                } else if (year1 - year == 1 && month1 == 1 && day1 < 7) {
                    int endDay = 32 + day1 - day;
                    if (endDay <= 7 && endDay >= 0) {
                        Toast.makeText(EtScanCardActivity.this, "授权将于" + endDay + "天后到期", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        }
    }


    @TargetApi(14)
    private void initCamera(SurfaceHolder holder) {
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
        if (!isROI) {
            int $t = screenHeight / 10;
            int t = $t;
            int b = screenHeight - t;
            int $l = (int) ((b - t) * 1.58577);
            int l = (screenWidth - $l) / 2;
            int r = screenWidth - l;
            double proportion = (double) screenWidth / (double) preWidth;
            double hproportion = (double) screenHeight / (double) preHeight;
            l = (int) (l / proportion);
            t = (int) (t / hproportion);
            r = (int) (r / proportion);
            b = (int) (b / hproportion);
            m_ROI[0] = l;
            m_ROI[1] = t;
            m_ROI[2] = r;
            m_ROI[3] = b;
            bankApi.SetRegion(l, t, r, b);
            isROI = true;
            myView = new BankViewfinderView(this, screenWidth, screenHeight);
            mainRl.addView(myView);
        }
        parameters.setPictureFormat(PixelFormat.JPEG);

        parameters.setPreviewSize(preWidth, preHeight);
        Log.e("预览宽度：" + preWidth, "预览高度：" + preHeight);

        try {
            mCamera.setPreviewDisplay(holder);
        } catch (IOException e) {
            e.printStackTrace();
        }
        if (parameters.getSupportedFocusModes().contains(
                Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
            parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);// 1连续对焦
        }
        mCamera.setPreviewCallback(this);
        mCamera.setParameters(parameters);
        mCamera.startPreview();
    }

    public String savePicture(Bitmap bitmap, String picName) {
        String strCaptureFilePath = Environment.getExternalStorageDirectory().getAbsolutePath() + "/weizhangpu/"+ picName;
        File dir = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/weizhangpu/");
        if (!dir.exists()) {
            dir.mkdirs();
        }
        File file = new File(strCaptureFilePath);
        if (file.exists()) {
            file.delete();
        }
        try {
            file.createNewFile();
            BufferedOutputStream bos = new BufferedOutputStream(new FileOutputStream(file));
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, bos);
            bos.flush();
            bos.close();

        } catch (IOException e) {
            Toast.makeText(getApplicationContext(), "图片存储失败,请检查SD卡", Toast.LENGTH_SHORT).show();
        }
        return strCaptureFilePath;
    }

    /**
     * 记录一个值，避免跳转同时两个相同的Activity
     */
    Boolean isSkip = true;

    @Override
    public void onPreviewFrame(byte[] data, Camera camera) {
        Camera.Parameters parameters = camera.getParameters();
        int buffl = 30;
        char recogval[] = new char[buffl];
        for (int i = 0; i < buffl; i++) {
            recogval[i] = 0;
        }
        int line[] = new int[4];
        line[0] = 0;
        line[1] = 0;
        line[2] = 0;
        line[3] = 0;
        int pLineWarp[] = new int[32000];
        int r = bankApi.ScanStreamNV21(data, parameters.getPreviewSize().width,
                parameters.getPreviewSize().height, line, recogval, pLineWarp);
        if (line[0] == 1) {
            if (myView != null) {
                myView.setLeftLine(1);
            }
        } else {
            if (myView != null) {
                myView.setLeftLine(0);
            }
        }
        if (line[1] == 1) {
            if (myView != null) {
                myView.setTopLine(1);
            }
        } else {
            if (myView != null) {
                myView.setTopLine(0);
            }
        }
        if (line[2] == 1) {
            if (myView != null) {
                myView.setRightLine(1);
            }
        } else {
            if (myView != null) {
                myView.setRightLine(0);
            }
        }
        if (line[3] == 1) {
            if (myView != null) {
                myView.setBottomLine(1);
            }
        } else {
            if (myView != null) {
                myView.setBottomLine(0);
            }
        }

        if (r == 0 && isSkip) {
            camera.stopPreview();
            isSkip = false;
            // 震动
            mVibrator = (Vibrator) getApplication().getSystemService(Service.VIBRATOR_SERVICE);
            mVibrator.vibrate(100);
            // 删除正常识别保存图片功能
            int[] datas = convertYUV420_NV21toARGB8888(data, parameters.getPreviewSize().width,
                    parameters.getPreviewSize().height);

            BitmapFactory.Options opts = new BitmapFactory.Options();
            opts.inInputShareable = true;
            opts.inPurgeable = true;
            bitmap = Bitmap.createBitmap(datas, parameters.getPreviewSize().width,
                    parameters.getPreviewSize().height, Bitmap.Config.ARGB_8888);
            System.out.println("m_ROI:" + m_ROI[0] + " " + m_ROI[1] + " " + m_ROI[2] + " " + m_ROI[3]);
            if (m_ROI[0] < 0) {
                m_ROI[0] = 0;
            }
            if (m_ROI[1] < 0) {
                m_ROI[1] = 0;
            }
            Bitmap tmpbitmap = Bitmap.createBitmap(bitmap, m_ROI[0], m_ROI[1], Math.abs(m_ROI[2] - m_ROI[0]), Math.abs(m_ROI[3] - m_ROI[1]));
            //savePicture(bitmap,"M");
            String path = savePicture(tmpbitmap, "bankCard.jpeg");

            String cardinfo[] = new String[4];
            cardinfoapi.GetCardInfo(recogval, cardinfo);
            recogval = String.valueOf(recogval).trim().toCharArray();

            Intent intent = new Intent();
            intent.putExtra("bankcard", String.valueOf(recogval));
            intent.putExtra("path", path);
            setResult(RESULT_OK, intent);
            finish();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        releaseCamera();
        if (bitmap != null) {
            bitmap.recycle();
            bitmap = null;
        }
        if (bankApi != null) {
            bankApi.ScanEnd();
            bankApi = null;
        }
        if (cardinfoapi != null) {
            cardinfoapi.UninitCardInfo();
            cardinfoapi = null;
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
        if (((year % 100 == 0) && year % 400 == 0) || ((year % 100 != 0) && year % 4 == 0)) {
            return true;
        } else {
            return false;
        }
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();
        finish();
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

    public static int[] convertYUV420_NV21toARGB8888(byte[] data, int width, int height) {
        int size = width * height;
        int offset = size;
        int[] pixels = new int[size];
        int u, v, y1, y2, y3, y4;

        for (int i = 0, k = 0; i < size; i += 2, k += 2) {
            y1 = data[i] & 0xff;
            y2 = data[i + 1] & 0xff;
            y3 = data[width + i] & 0xff;
            y4 = data[width + i + 1] & 0xff;

            u = data[offset + k] & 0xff;
            v = data[offset + k + 1] & 0xff;
            u = u - 128;
            v = v - 128;

            pixels[i] = convertYUVtoARGB(y1, u, v);
            pixels[i + 1] = convertYUVtoARGB(y2, u, v);
            pixels[width + i] = convertYUVtoARGB(y3, u, v);
            pixels[width + i + 1] = convertYUVtoARGB(y4, u, v);

            if (i != 0 && (i + 2) % width == 0) {
                i += width;
            }
        }

        return pixels;
    }

    private static int convertYUVtoARGB(int y, int u, int v) {
        int r, g, b;

        r = y + (int) 1.402f * u;
        g = y - (int) (0.344f * v + 0.714f * u);
        b = y + (int) 1.772f * v;
        r = r > 255 ? 255 : r < 0 ? 0 : r;
        g = g > 255 ? 255 : g < 0 ? 0 : g;
        b = b > 255 ? 255 : b < 0 ? 0 : b;
        return 0xff000000 | (r << 16) | (g << 8) | b;
    }

    //适配相机预览分辨率
    private Size getAdapterPreviewSize(List<Size> list, int screenWidth, int screenHeight) {
        double ASPECT_TOLERANCE = 0.005;//允许的比例误差
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
            if (size.height > 1200) {
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
}