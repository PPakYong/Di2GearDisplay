using Toybox.BluetoothLowEnergy as Ble;
import Toybox.Lang;
import Toybox.System;

//! BLE manager + delegate that reads Shimano Di2 gear data over Bluetooth LE.
//!
//! WHY BLE (and not AntPlus.Shifting): Shimano Di2 does NOT follow the ANT+
//! Shifting profile, so `Toybox.AntPlus.Shifting` returns nothing/garbage on
//! every device. On the Edge Explore 2 the generic-ANT path is unavailable as
//! well, so a Connect IQ data field must act as a BLE central and read the
//! gear data directly from the Di2 unit. That is what this class does.
//!
//! ⚠️ PLACEHOLDERS: Shimano's Di2 BLE (E-TUBE) protocol is proprietary and
//! undocumented. The SERVICE_UUID / GEAR_CHAR_UUID and the byte layout in
//! `_parseGear()` below are GUESSES. They MUST be replaced with the real
//! values captured from your own bike — see SNIFFING-GUIDE.md. Until then the
//! field will scan/connect but cannot decode gears.
class Di2BleManager extends Ble.BleDelegate {

    // ---- PLACEHOLDER UUIDs — replace after sniffing (SNIFFING-GUIDE.md) ----
    // The 128-bit GATT service that exposes Di2 gear/shifting state.
    private const SERVICE_UUID   = "00000000-0000-0000-0000-000000000000";
    // The characteristic that NOTIFIES the current gear position.
    private const GEAR_CHAR_UUID = "00000000-0000-0000-0000-000000000000";
    // Substring used to recognise the Di2 unit by its advertised name.
    // Shimano units typically advertise as "SHIMANO …" — confirm/adjust.
    private const NAME_MATCH     = "SHIMANO";
    // ------------------------------------------------------------------------

    // Connection states surfaced to the view.
    enum {
        STATE_INIT,
        STATE_SCANNING,
        STATE_PAIRING,
        STATE_CONNECTED,
        STATE_READY,
        STATE_ERROR
    }

    private var _state as Number = STATE_INIT;
    private var _device as Ble.Device or Null = null;

    // Gear state read off the sensor.
    public var frontIndex as Number = 0;
    public var frontMax   as Number = 0;
    public var rearIndex  as Number = 0;
    public var rearMax    as Number = 0;
    public var frontTeeth as Number = 0;
    public var rearTeeth  as Number = 0;
    public var ratio      as Float  = 0.0f;

    // Tooth tables (from properties / defaults) used to map an index -> teeth.
    private var _frontTable as Array<Number>;
    private var _rearTable  as Array<Number>;

    function initialize() {
        BleDelegate.initialize();
        _frontTable = GearConfig.getFrontTeeth();
        _rearTable  = GearConfig.getRearTeeth();
    }

    //! Begin scanning. Called once from the app on launch.
    function start() as Void {
        try {
            Ble.setDelegate(self);
            _registerProfile();
            _state = STATE_SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        } catch (e) {
            _state = STATE_ERROR;
            System.println("BLE start failed: " + e.getErrorMessage());
        }
    }

    function getState() as Number {
        return _state;
    }

    private function _registerProfile() as Void {
        // Registering the profile lets getService()/getCharacteristic() resolve
        // after connection. The CCCD descriptor is needed to enable notifies.
        var profile = {
            :uuid => Ble.stringToUuid(SERVICE_UUID),
            :characteristics => [{
                :uuid => Ble.stringToUuid(GEAR_CHAR_UUID),
                :descriptors => [ Ble.cccdUuid() ]
            }]
        };
        Ble.registerProfile(profile);
    }

    // ---- BleDelegate callbacks --------------------------------------------

    function onProfileRegister(uuid as Ble.Uuid, status as Ble.Status) as Void {
        System.println("profile register status: " + status);
    }

    function onScanResults(scanResults as Ble.Iterator) as Void {
        for (var r = scanResults.next(); r != null; r = scanResults.next()) {
            var sr = r as Ble.ScanResult;
            var name = sr.getDeviceName();
            if (name != null && name.find(NAME_MATCH) != null) {
                _state = STATE_PAIRING;
                Ble.setScanState(Ble.SCAN_STATE_OFF);
                _device = Ble.pairDevice(sr);
                return;
            }
        }
    }

    function onScanStateChange(scanState as Ble.ScanState, status as Ble.Status) as Void {
    }

    function onConnectedStateChanged(device as Ble.Device, state as Ble.ConnectionState) as Void {
        if (state == Ble.CONNECTION_STATE_CONNECTED) {
            _device = device;
            _state  = STATE_CONNECTED;
            _subscribeGear();
        } else {
            // Lost/refused connection — fall back to scanning.
            _device = null;
            _state  = STATE_SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        }
    }

    private function _subscribeGear() as Void {
        try {
            var svc = _device.getService(Ble.stringToUuid(SERVICE_UUID));
            if (svc == null) { _state = STATE_ERROR; return; }
            var ch = svc.getCharacteristic(Ble.stringToUuid(GEAR_CHAR_UUID));
            if (ch == null) { _state = STATE_ERROR; return; }
            var cccd = ch.getDescriptor(Ble.cccdUuid());
            if (cccd != null) {
                cccd.requestWrite([0x01, 0x00]b);  // 0x0001 = enable notifications
            }
        } catch (e) {
            _state = STATE_ERROR;
        }
    }

    function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Void {
        if (status == Ble.STATUS_SUCCESS) {
            _state = STATE_READY;  // notifications enabled; gear data will flow
        }
    }

    function onCharacteristicChanged(char as Ble.Characteristic, value as ByteArray) as Void {
        _parseGear(value);
    }

    // ---- PLACEHOLDER parse — replace after sniffing (SNIFFING-GUIDE.md) -----
    //! Decode a Di2 gear notification payload. The real byte layout is unknown
    //! until you capture live notifications. The body below is a GUESS of the
    //! form [frontIndex, frontMax, rearIndex, rearMax, …]. Adjust the offsets
    //! (and any bit-packing) to match what you actually capture.
    private function _parseGear(value as ByteArray) as Void {
        if (value == null || value.size() < 4) { return; }
        frontIndex = value[0];
        frontMax   = value[1];
        rearIndex  = value[2];
        rearMax    = value[3];
        _recompute();
    }
    // ------------------------------------------------------------------------

    private function _recompute() as Void {
        frontTeeth = _lookup(_frontTable, frontIndex);
        rearTeeth  = _lookup(_rearTable, rearIndex);
        ratio = (rearTeeth > 0) ? frontTeeth.toFloat() / rearTeeth.toFloat() : 0.0f;
    }

    private function _lookup(table as Array<Number>, index as Number) as Number {
        if (index > 0 && index <= table.size()) {
            return table[index - 1];
        }
        return 0;
    }
}
