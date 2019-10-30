package com.etop.SIDCard;

import android.content.Context;
import android.telephony.TelephonyManager;

public class SIDCardAPI {
	static {
		System.loadLibrary("AndroidSIDCard");
	}
	
	
	public native int SIDCardKernalInit(String szSysPath, String FilePath, String CommpanyName, int nProductType, int nAultType, TelephonyManager telephonyManager, Context context);
	public native void SIDCardKernalUnInit();
	public native int SIDCardRecognizeNV21(byte[] ImageStreamNV21, int Width, int Height, char[] Buffer, int BufferLen);
	//识别
	public native int SIDCardRecognizeNV21Corner(byte[]data,int Width,int Height,int[]line_x,int[] line_y);
	public native int SIDCardRecognizeNV21Android(byte[]data,int Width,int Height,int[]line_x,int[] line_y,int nType);
	//剪线
	public native int SIDCardDetectNV21Corner(byte[]data,int Width,int Height,int[]line_x,int[]line_y);
	public native String SIDCardGetResult(int nIndex);
	public native int SIDCardSaveCardImage(String path);
	public native int SIDCardSaveHeadImage(String path);
	public native int SIDCardRecogOtherImgaeFileW(String path, char[] Buffer, int BufferLen);
	public native int SIDCardSetRecogType(int nType);
	public native int SIDCardGetRecogType();
	public native int SIDCardGetImgDirection();
	public native int SIDCardCheckIsCopy();
	public native String SIDCardGetEndTime();
	public native int SIDCardRecogImgaeFile(String filePath);//图像路径
}
