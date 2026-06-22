import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.AntPlus;

class Di2GearDisplayApp extends WatchUi.DataField {

    hidden var mFrontGear   as Number = 0;
    hidden var mRearGear    as Number = 0;
    hidden var mFrontIndex  as Number = 0;
    hidden var mRearIndex   as Number = 0;
    hidden var mFrontTotal  as Number = 0;
    hidden var mRearTotal   as Number = 0;
    hidden var mGearRatio   as Float   = 0.0f;

    hidden var mShiftingSensor as AntPlus.ShiftingSensor or Null = null;

    hidden var mFieldWidth  as Number = 0;
    hidden var mFieldHeight as Number = 0;

    hidden var mFrontTeeth  as Array<Number> = [50, 34] as Array<Number>;
    hidden var mRearTeeth   as Array<Number> = [11,12,13,14,15,17,19,21,24,27,30] as Array<Number>;

    function initialize() {
        DataField.initialize();
        _initShiftingSensor();
    }

    hidden function _initShiftingSensor() as Void {
        try {
            mShiftingSensor = new AntPlus.ShiftingSensor(
                new AntPlus.ShiftingListener() {
                    function onShiftingData(data as AntPlus.ShiftingData) as Void {
                        _onShiftingData(data);
                    }
                }
            );
            if (mShiftingSensor != null) {
                mShiftingSensor.open();
            }
        } catch (e) {
            mShiftingSensor = null;
            _setDemoGear();
        }
    }

    hidden function _onShiftingData(data as AntPlus.ShiftingData) as Void {
        mFrontIndex = data.frontGear;
        mRearIndex  = data.rearGear;
        mFrontTotal = data.frontGearCount;
        mRearTotal  = data.rearGearCount;

        if (mFrontIndex > 0 && mFrontIndex <= mFrontTeeth.size()) {
            mFrontGear = mFrontTeeth[mFrontIndex - 1];
        }
        if (mRearIndex > 0 && mRearIndex <= mRearTeeth.size()) {
            mRearGear = mRearTeeth[mRearIndex - 1];
        }

        if (mRearGear > 0) {
            mGearRatio = mFrontGear.toFloat() / mRearGear.toFloat();
        }
    }

    hidden function _setDemoGear() as Void {
        mFrontIndex = 1;
        mRearIndex  = 5;
        mFrontTotal = 2;
        mRearTotal  = 11;
        mFrontGear  = mFrontTeeth[0];
        mRearGear   = mRearTeeth[4];
        mGearRatio  = mFrontGear.toFloat() / mRearGear.toFloat();
    }

    function onLayout(dc as Dc) as Void {
        mFieldWidth  = dc.getWidth();
        mFieldHeight = dc.getHeight();
    }

    function compute(info as Activity.Info) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK)
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
        var accentColor = Graphics.COLOR_ORANGE;

        dc.setColor(bgColor, bgColor);
        dc.fillRectangle(0, 0, mFieldWidth, mFieldHeight);

        var w = mFieldWidth;
        var h = mFieldHeight;
        var cx = w / 2;

        if (mShiftingSensor == null && mFrontGear == 0) {
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL,
                "Di2 없음", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var topY = (h * 0.10).toNumber();
        var midY = (h * 0.48).toNumber();
        var botY = (h * 0.80).toNumber();

        var frontStr = (mFrontGear > 0) ? mFrontGear.toString() : "--";
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - (w * 0.18).toNumber(), topY,
            Graphics.FONT_NUMBER_HOT, frontStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY, Graphics.FONT_NUMBER_HOT, "×",
            Graphics.TEXT_JUSTIFY_CENTER);

        var rearStr = (mRearGear > 0) ? mRearGear.toString() : "--";
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + (w * 0.18).toNumber(), topY,
            Graphics.FONT_NUMBER_HOT, rearStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var ratioStr = (mGearRatio > 0.0f)
            ? mGearRatio.format("%.2f")
            : "--.--";
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY, Graphics.FONT_NUMBER_MEDIUM, ratioStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var idxStr = Lang.format("F$1$/$2$  R$3$/$4$", [
            mFrontIndex, mFrontTotal,
            mRearIndex,  mRearTotal
        ]);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, botY, Graphics.FONT_XTINY, idxStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - dc.getFontHeight(Graphics.FONT_XTINY) - 2,
            Graphics.FONT_XTINY, "GEAR RATIO",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onRelease() as Void {
        if (mShiftingSensor != null) {
            mShiftingSensor.close();
            mShiftingSensor = null;
        }
    }
}
