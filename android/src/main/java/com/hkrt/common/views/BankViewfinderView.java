package com.hkrt.common.views;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.view.View;

import com.hkrt.common.R;


public class BankViewfinderView extends View {
	private static final long ANIMATION_DELAY = 10L;
	private Paint paint;
	private Paint paintLine;
	private int maskColor;
	private int frameColor;
	private int laserColor;
	private int leftLine = 0;
	private int topLine = 0;
	private int rightLine = 0;
	private int bottomLine = 0;

	private Rect frame;

	int w, h;
	private Paint mTextPaint;  
    private String mText;  

	public BankViewfinderView(Context context, int w, int h) {
		super(context);
		this.w = w;
		this.h = h;
		paint = new Paint();
		paintLine = new Paint();
		Resources resources = getResources();
		maskColor = resources.getColor(R.color.viewfinder_mask);
		frameColor = resources.getColor(R.color.viewfinder_frame);//
		laserColor = resources.getColor(R.color.viewfinder_laser);// 
	}

	public void setLeftLine(int leftLine) {
		this.leftLine = leftLine;
	}

	public void setTopLine(int topLine) {
		this.topLine = topLine;
	}

	public void setRightLine(int rightLine) {
		this.rightLine = rightLine;
	}

	public void setBottomLine(int bottomLine) {
		this.bottomLine = bottomLine;
	}

	@Override
	public void onDraw(Canvas canvas) {
		int width = canvas.getWidth();
		int height = canvas.getHeight();

		int t,b,l,r;

		int $t = h / 10;
		t = $t;
		b = h - t;
		int $l = (int) ((b - t) * 1.585);
		l = (w - $l) / 2;
		r = w - l;

		l = l + 30;
		t = t + 19;
		r = r - 30;
		b = b - 19;
		frame = new Rect(l, t, r, b);
		paint.setColor(maskColor);
		canvas.drawRect(0, 0, width, frame.top, paint);
		canvas.drawRect(0, frame.top, frame.left, frame.bottom + 1, paint);
		canvas.drawRect(frame.right + 1, frame.top, width, frame.bottom + 1,
				paint);
		canvas.drawRect(0, frame.bottom + 1, width, height, paint);

		paintLine.setColor(frameColor);
		paintLine.setStrokeWidth(8);
		paintLine.setAntiAlias(true);
		int num = (b - t) / 6;
		canvas.drawLine(l - 4, t, l + num, t, paintLine);
		canvas.drawLine(l, t, l, t + num, paintLine);

		canvas.drawLine(r, t, r - num, t, paintLine);
		canvas.drawLine(r, t - 4, r, t + num, paintLine);

		canvas.drawLine(l - 4, b, l + num, b, paintLine);
		canvas.drawLine(l, b, l, b - num, paintLine);

		canvas.drawLine(r, b, r - num, b, paintLine);
		canvas.drawLine(r, b + 4, r, b - num, paintLine);

		if (leftLine == 1) {
			canvas.drawLine(l, t, l, b, paintLine);
		}
		if (rightLine == 1) {
			canvas.drawLine(r, t, r, b, paintLine);
		}
		if (topLine == 1) {
			canvas.drawLine(l, t, r, t, paintLine);
		}
		if (bottomLine == 1) {
			canvas.drawLine(l, b, r, b, paintLine);
		}
		mText = "请将银行卡置于框内并尝试四边对齐，尽量在光线明亮的地方进行扫描";
		mTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
		mTextPaint.setStrokeWidth(3);
		mTextPaint.setTextSize((h - b) * 5 / 16);
		mTextPaint.setColor(laserColor);
		mTextPaint.setTextAlign(Paint.Align.CENTER);
		canvas.drawText(mText, w / 2, h * 2 / 5, mTextPaint);
		String mText1 = "1234  5678  9012  3456";
		mTextPaint.setTextSize((h - b) * 7/ 10);
		mTextPaint.setColor(laserColor);
		mTextPaint.setTextAlign(Paint.Align.CENTER);
		canvas.drawText(mText1, w / 2, (b - (b - t) * 2 / 5) + (h - b) * 7 / 20,
				mTextPaint);
		if (frame == null) {
			return;
		}

		postInvalidateDelayed(ANIMATION_DELAY);
	}
}
