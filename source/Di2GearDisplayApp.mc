import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point. The manifest `entry` must extend AppBase; the
//! data field itself is provided as the initial view.
class Di2GearDisplayApp extends Application.AppBase {

    private var _ble as Di2BleManager or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        // Di2 must be read over BLE (see Di2BleManager for the rationale).
        _ble = new Di2BleManager();
        _ble.start();
        return [ new Di2GearView(_ble) ];
    }
}

class Di2GearView extends WatchUi.DataField {

    hidden var mBle as Di2BleManager;

    hidden var mFieldWidth  as Number = 0;
    hidden var mFieldHeight as Number = 0;

    function initialize(ble as Di2BleManager) {
        DataField.initialize();
        mBle = ble;
    }

    function onLayout(dc as Dc) as Void {
        mFieldWidth  = dc.getWidth();
        mFieldHeight = dc.getHeight();
    }

    function compute(info as Activity.Info) as Void {
        // Gear state is pushed asynchronously by the BLE delegate; nothing to
        // pull from Activity.Info here.
    }

    //! Map BLE connection state to a short Korean status line.
    hidden function _statusText() as String or Null {
        switch (mBle.getState()) {
            case Di2BleManager.STATE_SCANNING: return "Di2 검색중…";
            case Di2BleManager.STATE_PAIRING:  return "연결중…";
            case Di2BleManager.STATE_CONNECTED: return "연결중…";
            case Di2BleManager.STATE_ERROR:    return "BLE 오류";
            default: return null;
        }
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

        var hasData = (mBle.frontTeeth > 0 || mBle.rearTeeth > 0);

        // No gear data yet: show the connection status instead of empty gears.
        if (!hasData) {
            var status = _statusText();
            if (status == null) { status = "Di2 없음"; }
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL,
                status, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var topY = (h * 0.10).toNumber();
        var midY = (h * 0.48).toNumber();
        var botY = (h * 0.80).toNumber();

        var frontStr = (mBle.frontTeeth > 0) ? mBle.frontTeeth.toString() : "--";
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - (w * 0.18).toNumber(), topY,
            Graphics.FONT_NUMBER_HOT, frontStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY, Graphics.FONT_NUMBER_HOT, "×",
            Graphics.TEXT_JUSTIFY_CENTER);

        var rearStr = (mBle.rearTeeth > 0) ? mBle.rearTeeth.toString() : "--";
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + (w * 0.18).toNumber(), topY,
            Graphics.FONT_NUMBER_HOT, rearStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var ratioStr = (mBle.ratio > 0.0f)
            ? mBle.ratio.format("%.2f")
            : "--.--";
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY, Graphics.FONT_NUMBER_MEDIUM, ratioStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var idxStr = Lang.format("F$1$/$2$  R$3$/$4$", [
            mBle.frontIndex, mBle.frontMax,
            mBle.rearIndex,  mBle.rearMax
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
