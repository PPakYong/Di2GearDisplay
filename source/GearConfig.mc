import Toybox.Lang;
import Toybox.Application;

module GearConfig {

    const DEFAULT_FRONT as Array<Number> = [50, 34] as Array<Number>;
    const DEFAULT_REAR  as Array<Number> = [11,12,13,14,15,16,17,19,21,24,27,30] as Array<Number>;

    function getFrontTeeth() as Array<Number> {
        try {
            var val = Application.Properties.getValue("frontTeeth");
            if (val != null && val instanceof Lang.String) {
                return _parseTeeth(val as String);
            }
        } catch (e) {}
        return DEFAULT_FRONT;
    }

    function getRearTeeth() as Array<Number> {
        try {
            var val = Application.Properties.getValue("rearTeeth");
            if (val != null && val instanceof Lang.String) {
                return _parseTeeth(val as String);
            }
        } catch (e) {}
        return DEFAULT_REAR;
    }

    //! Monkey C's Lang.String has no split()/trim(), so parse the
    //! comma-separated list character by character.
    function _parseTeeth(s as String) as Array<Number> {
        var result = [] as Array<Number>;
        var token = "";
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == ',') {
                _addToken(result, token);
                token = "";
            } else if (c != ' ') {
                token += c.toString();
            }
        }
        _addToken(result, token);
        return (result.size() > 0) ? result : DEFAULT_FRONT;
    }

    function _addToken(result as Array<Number>, token as String) as Void {
        if (token.length() > 0) {
            var n = token.toNumber();
            if (n != null) {
                result.add(n);
            }
        }
    }

    function calcRatio(frontT as Number, rearT as Number) as Float {
        if (rearT == 0) { return 0.0f; }
        return frontT.toFloat() / rearT.toFloat();
    }

    function calcDevelopment(ratio as Float, wheelCircMm as Number) as Float {
        return ratio * wheelCircMm.toFloat() / 1000.0f;
    }
}
