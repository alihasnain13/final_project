module engine.math;
import std.math : tan, sqrt, sin, cos;
struct Vec3 {
    float x, y, z;
    this(float x, float y, float z) { this.x = x; this.y = y; this.z = z; }
    Vec3 opBinary(string op)(Vec3 o) const if(op == "+") { return Vec3(x+o.x, y+o.y, z+o.z); }
    Vec3 opBinary(string op)(Vec3 o) const if(op == "-") { return Vec3(x-o.x, y-o.y, z-o.z); }
}
struct Mat4 {
    float[16] m;
    this(float[16] data) { m = data; }
    static Mat4 identity() { return Mat4([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]); }
    Mat4 opBinary(string op)(Mat4 rhs) const if(op == "*") {
        Mat4 result;
        foreach(row; 0 .. 4)
            foreach(col; 0 .. 4) {
                float sum = 0;
                foreach(k; 0 .. 4)
                    sum += m[k*4 + col] * rhs.m[row*4 + k];
                result.m[row*4 + col] = sum;
            }
        return result;
    }
}
Mat4 perspective(float fovDeg, float aspect, float near, float far) {
    float fovRad = fovDeg * 3.14159f / 180.0f;
    float f = 1.0f / tan(fovRad/2.0f);
    float nf = 1.0f / (near - far);
    float[16] pm = [ f/aspect, 0, 0, 0,
                     0, f, 0, 0,
                     0, 0, (far+near)*nf, -1,
                     0, 0, (2*far*near)*nf, 0 ];
    return Mat4(pm);
}
Mat4 lookAt(Vec3 eye, Vec3 center, Vec3 up) {
    // A simple implementation of lookAt.
    auto f = (center - eye); // you may add normalization here
    auto s = Vec3(
        f.y*up.z - f.z*up.y,
        f.z*up.x - f.x*up.z,
        f.x*up.y - f.y*up.x
    ); // normalize s if needed
    auto u = Vec3(
        s.y*f.z - s.z*f.y,
        s.z*f.x - s.x*f.z,
        s.x*f.y - s.y*f.x
    );
    float[16] lm = [ s.x, u.x, -f.x, 0,
                     s.y, u.y, -f.y, 0,
                     s.z, u.z, -f.z, 0,
                     0,   0,    0,   1 ];
    Mat4 rot = Mat4(lm);
    float[16] trans = [ 1,0,0,0,
                         0,1,0,0,
                         0,0,1,0,
                         -eye.x, -eye.y, -eye.z, 1 ];
    Mat4 transM = Mat4(trans);
    return rot * transM;
}
