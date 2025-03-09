/// Utility math functions
module utility;

import std.math;

/// Returns the value in radians given an angle.
/// Intuitively, we tend to think in 'angles' as humans,
/// but graphics libraries and math functions (e.g. sine) often
/// take 'radians' as the input.
float ToRadians(float angle){
    return (PI/180.0f)*angle;
}

/// Given a value in radians, convert to an angle
float ToAngle(float radians){
    return (180.0f/PI)*radians;
}

/// Example conversions from degrees to radians
unittest{
    assert(ToRadians(120).isClose(2.09439),"120 radian conversion");
    assert(ToRadians(180).isClose(PI),"180 radian conversion");
}

/// Example conversions from radians to degrees
unittest{
    assert(ToAngle(2.09439).isClose(120),"2.09439 radian conversion");
    assert(ToAngle(PI).isClose(180),"PI angle conversion");
}

