import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.AntPlus;

//! Application entry point. The manifest `entry` must extend AppBase; the
//! data field itself is provided as the initial view.
class Di2GearDisplayApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [ new Di2GearView() ];
    }
}

//! Named listener. Monkey C does not support anonymous inner classes, so the
//! callback is implemented in a dedicated subclass that forwards to the view.
class Di2ShiftingListener extends AntPlus.ShiftingListener {

    hidden var mView as Di2GearView;

    function initialize(view as Di2GearView) {
        ShiftingListener.initialize();
        mView = view;
    }

    function onShiftingUpdate(data as AntPlus.ShiftingStatus) as Void {
        mView.onShiftingUpdate(data);
    }
}

class Di2GearView extends WatchUi.DataField {

    hidden var mFrontGear   as Number = 0;
    hidden var mRearGear    as Number = 0;
    hidden var mFrontIndex  as Number = 0;
    hidden var mRearIndex   as Number = 0;
    hidden var mFrontTotal  as Number = 0;
    hidden var mRearTotal   as Number = 0;
    hidden var mGearRatio   as Float   = 0.0f;

    hidden var mShifting as AntPlus.Shifting or Null = null;

    hidden var mFieldWidth  as Number = 0;
    hidden var mFieldHeight as Number = 0;

    // Fallback tooth counts, used only when the sensor does not report gear
    // size (some Shimano systems report indices but not teeth).
    hidden var mFrontTeeth  as Array<Number> = [50, 34] as Array<Number>;
    hidden var mRearTeeth   as Array<Number> = [11,12,13,14,15,16,17,19,21,24,27,30] as Array<Number>;

    function initialize() {
        DataField.initialize();
        _initShifting();
    }

    hidden function _initShifting() as Void {
        try {
            mShifting = new AntPlus.Shifting(new Di2ShiftingListener(self));
        } catch (e) {
            mShifting = null;
            _setDemoGear();
        }
    }

    //! Called from the listener when new shifting data arrives.
    function onShiftingUpdate(data as AntPlus.ShiftingStatus) as Void {
        var front = data.frontDerailleur;
        var rear  = data.rearDerailleur;

        if (front != null) {
            mFrontIndex = front.gearIndex;
            mFrontTotal = front.gearMax;
            mFrontGear  = _teeth(front.gearSize, mFrontTeeth, front.gearIndex);
        }
        if (rear != null) {
            mRearIndex = rear.gearIndex;
            mRearTotal = rear.gearMax;
            mRearGear  = _teeth(rear.gearSize, mRearTeeth, rear.gearIndex);
        }

        if (mRearGear > 0) {
            mGearRatio = mFrontGear.toFloat() / mRearGear.toFloat();
        }
    }

    //! Prefer the gear size reported by the sensor; fall back to the
    //! configured tooth table indexed by the current gear index.
    hidden function _teeth(reportedSize as Number, table as Array<Number>, index as Number) as Number {
        if (reportedSize > 0) {
            return reportedSize;
        }
        if (index > 0 && index <= table.size()) {
            return table[index - 1];
        }
        return 0;
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

        if (mShifting == null && mFrontGear == 0) {
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
}
