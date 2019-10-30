package com.hkrt.common.scan;

import android.app.Activity;
import android.content.res.Resources;
import android.util.DisplayMetrics;
import android.view.Display;

import java.lang.reflect.Method;

public class NavigationBarHeightUtils {
    /**
     * 如果有NavigationBar则返回高度值，没有返回 0
     *
     * @return
     */
    public static int getNavigationBarHeight(Activity activity) {
        // boolean isHasNavigationBar = checkDeviceHasNavigationBar(activity);
        int nW = activity.getWindowManager().getDefaultDisplay().getWidth();
        int nWR = getWidthDpi(activity);
        if (nWR != nW) {
            // if (isHasNavigationBar) {
            Resources resources = activity.getResources();
            int resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android");
            //获取NavigationBar的高度
            int height = resources.getDimensionPixelSize(resourceId);
            return height;
        } else {
            return 0;
        }
    }

    public static int getWidthDpi(Activity activity) {
        int dpi = 0;
        Display display = activity.getWindowManager().getDefaultDisplay();
        DisplayMetrics dm = new DisplayMetrics();
        @SuppressWarnings("rawtypes")
        Class c;
        try {
            c = Class.forName("android.view.Display");
            @SuppressWarnings("unchecked")
            Method method = c.getMethod("getRealMetrics", DisplayMetrics.class);
            method.invoke(display, dm);
            dpi = dm.widthPixels;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return dpi;
    }

}
