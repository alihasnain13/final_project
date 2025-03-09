/// Matrix module 
module mat;
import std.stdio, std.math, std.conv;
import vec,utility;

/// matrix3x3
/// Note: The default constructed matrix is an identity matrix
struct mat3{
    // e is short for 'elements'
    float[9] e = [
        1,0,0,
        0,1,0,
        0,0,1,
    ];


    /// Constructor which sets the diagonal of the matrix
    /// The default is for an identity matrix to be produced.
    this(float diagonal){
       e[0] = diagonal; 
       e[4] = diagonal;
       e[8] = diagonal;
    }

    /// Build a matrix from 3 column vectors
    this(vec3 col0, vec3 col1, vec3 col2){
       this[0] = col0; 
       this[1] = col1; 
       this[2] = col2; 
    }
    /// Build a matrix from 16 elements
    this(float e0,float e1, float e2, 
         float e3,float e4, float e5, 
         float e6,float e7, float e8){
        e[0] = e0;
        e[1] = e1;
        e[2] = e2;
        e[3] = e3;
        e[4] = e4;
        e[5] = e5;
        e[6] = e6;
        e[7] = e7;
        e[8] = e8;
    }

    /// Build a mat3 from a mat4 matrix (cuts off the last row and column)
    this(mat4 input){
        e[0] = input.e[0];
        e[1] = input.e[1];
        e[2] = input.e[2];
        e[3] = input.e[4];
        e[4] = input.e[5];
        e[5] = input.e[6];
        e[6] = input.e[8];
        e[7] = input.e[9];
        e[8] = input.e[10];
    }

    /// Retrieve the static array for data values
    float[9] Data(){
        return this.e;
    }

    /// Retrieve the static array for data
    float* DataPtr(){
        return this.e.ptr;
    }

    /// Return the individual element 
    /// Usage: mat3[i]
	float opIndex(size_t i){
		return e[i];
	}
    /// Return the individual element
    /// Usage: mat3[i,j]
	float opIndex(size_t i, size_t j){
		return e[i*3 + j];
	}

    /// Assign to another mat3
    void opAssign(mat3 input){
        e = input.e;
    }
    /// Assign a ma3 from a larger mat4 matrix
    void opAssign(mat4 input){
        e[0] = input.e[0];
        e[1] = input.e[1];
        e[2] = input.e[2];
        e[3] = input.e[4];
        e[4] = input.e[5];
        e[5] = input.e[6];
        e[6] = input.e[8];
        e[7] = input.e[9];
        e[8] = input.e[10];
    }

    /// Assign matrix elements of matrix individually
    /// Usage: mat3[i] = value;
	void opIndexAssign(float value, size_t i){
		e[i] = value;
	}
    /// Assign matrix value using 2 dimensions
    /// Usage: mat3[i,j] = value;
	void opIndexAssign(float value, size_t i, size_t j){
		e[i*3 + j] = value;
	}
    /// Assign specific matrix column to a new column vector
    /// mat4 m;
    /// vec4 v;
    /// m[0] = v; // Sets first column of matrix to values of v.
    void opIndexAssign(vec3 v, size_t i){
        e[i]    = v[0];
        e[i+3]  = v[1];
        e[i+6]  = v[2];
    }
    /// Perform a binary operation (+,-,*,/) to each element of a matrix
    /// Usage: mat4[i] += value;
	void opIndexOpAssign(string op)(float value, size_t i){
		static if(op=="+"){
			e[i] += value;
		}
		static if(op=="-"){
			e[i] -= value;
		}
		static if(op=="*"){
			e[i] *= value;
		}
		static if(op=="/"){
			e[i] /= value;
		}
        assert(0,"op not implemented for opIndexOpAssign(float value, size_t i)");
	}
    /// Perform a binary operation (+,-,*,/) to each element of a matrix
    /// Usage: mat3[i,j] += value;
	void opIndexOpAssign(string op)(float value, size_t i, size_t j){
		static if(op=="+"){
			e[i*3 + j] += value;
		}
		static if(op=="-"){
			e[i*3 + j] -= value;
		}
		static if(op=="*"){
			e[i*3 + j] *= value;
		}
		static if(op=="/"){
			e[i*3 + j] /= value;
		}
        assert(0,"op not implemented for opIndexOpAssign(float value, size_t i, size_t j)");
	}

    /// Perform matrix multiplication
    mat3 opBinary(string op)(mat3 m){
        static if(op=="*"){
            mat3 result;	
            for(int i=0; i < 3; i++){
                for(int j=0; j < 3; j++){
                    float sum=0.0f;
                    for(int k=0; k < 3; k++){
                        sum	 +=  this[i,k] * m[k,j];	
                    }	
                    result[i,j] = sum;
                }
            }
            return result;	
        }
        assert(0,"op not implemented for mat4 opBinary(mat4)");
    }

    /// Multiply a matrix by a vector
    /// e.g. For performing: m*v (where 'v' is on the right side)
    vec3 opBinary(string op)(vec3 v){
        static if(op=="*"){
            vec3 result;	

            result[0] = this.Row(0).Dot(v);
            result[1] = this.Row(1).Dot(v);
            result[2] = this.Row(2).Dot(v);

            return result;	
        }
        assert(0,"op not implemented for vec4 opBinary(vec4)");
    }

    /// Handy function for printing out the string representation of a matrix
    string toString(){
	    string result = 
                        this.Row(0).toString ~ "\n" ~
                        this.Row(1).toString ~ "\n" ~
                        this.Row(2).toString;
        return result;
    }
}


/// Return the row vector
vec3 Row(mat3 m, size_t col){
    size_t offset = col*3;
    return vec3(m.e[0+offset],m.e[1+offset],m.e[2+offset]);	
}

/// Return the column vector
vec3 Col(mat3 m, size_t c){
    return vec3(m.e[0+c],m.e[3+c],m.e[6+c]);	
}

/// Return an identity matrix 
mat3 Matrix3MakeIdentity(){
    mat3 result;
    for(int i=0; i < 9; i++){
        result[i] = 0.0f;
    }
    // Set diaganaol of matrix to 1
    result[0]  = 1.0f;
    result[4]  = 1.0f;
    result[8] = 1.0f;

    return result;
}

/// Checks if this is an identity matrix
bool MatrixIsIdentity(mat3 m){

    return (m[0] == 1.0f &&
        m[1] == 0.0f && 
        m[2] == 0.0f && 
        m[3] == 0.0f && 
        m[4] == 1.0f && 
        m[5] == 0.0f && 
        m[6] == 0.0f && 
        m[7] == 0.0f && 
        m[8] == 1.0f); 
}


/// Given a matrix, return the transposed version of the matrix
mat3 MatrixTranspose(mat3 m){
    mat3 result;
    for(int i=0; i < 3;i++){
        auto row = m.Row(i);
        result[i] = row; // opAssign does 'column' assignment
    }
    return result;
}



/// matrix4x4
/// Note: The default constructed matrix is an identity matrix
struct mat4{
    // e is short for 'elements'
    float[16] e = [
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    ];


    /// Constructor which sets the diagonal of the matrix
    /// The default is for an identity matrix to be produced.
    this(float diagonal){
       e[0] = diagonal; 
       e[5] = diagonal;
       e[10] = diagonal;
       e[15] = diagonal;
    }

    /// Build a matrix from 4 column vectors
    this(vec4 col0, vec4 col1, vec4 col2, vec4 col3){
       this[0] = col0; 
       this[1] = col1; 
       this[2] = col2; 
       this[3] = col3; 
    }
    /// Build a matrix from 16 elements
    this(float e0,float e1, float e2, float e3,
         float e4,float e5, float e6, float e7,
         float e8,float e9, float e10, float e11,
         float e12,float e13, float e14, float e15){
        e[0] = e0;
        e[1] = e1;
        e[2] = e2;
        e[3] = e3;
        e[4] = e4;
        e[5] = e5;
        e[6] = e6;
        e[7] = e7;
        e[8] = e8;
        e[9] = e9;
        e[10] = e10;
        e[11] = e11;
        e[12] = e12;
        e[13] = e13;
        e[14] = e14;
        e[15] = e15;
    }
    /// Retrieve the static array for data values
    float[16] Data(){
        return this.e;
    }

    /// Retrieve the static array for data
    float* DataPtr(){
        return this.e.ptr;
    }

    /// Return the individual element 
    /// Usage: mat4[i]
	float opIndex(size_t i){
		return e[i];
	}
    /// Return the individual element
    /// Usage: mat4[i,j]
	float opIndex(size_t i, size_t j){
		return e[i*4 + j];
	}
    /// Assign to another mat4
    void opAssign(mat4 input){
        e = input.e;
    }
    /// Assign matrix elements of matrix individually
    /// Usage: mat4[i] = value;
	void opIndexAssign(float value, size_t i){
		e[i] = value;
	}
    /// Assign matrix value using 2 dimensions
    /// Usage: mat4[i,j] = value;
	void opIndexAssign(float value, size_t i, size_t j){
		e[i*4 + j] = value;
	}
    /// Assign specific matrix column to a new column vector
    /// mat4 m;
    /// vec4 v;
    /// m[0] = v; // Sets first column of matrix to values of v.
    void opIndexAssign(vec4 v, size_t i){
        e[i]    = v[0];
        e[i+4]  = v[1];
        e[i+8]  = v[2];
        e[i+12] = v[3];
    }
    /// Perform a binary operation (+,-,*,/) to each element of a matrix
    /// Usage: mat4[i] += value;
	void opIndexOpAssign(string op)(float value, size_t i){
		static if(op=="+"){
			e[i] += value;
		}
		static if(op=="-"){
			e[i] -= value;
		}
		static if(op=="*"){
			e[i] *= value;
		}
		static if(op=="/"){
			e[i] /= value;
		}
		assert(0,"op not implemented for opIndexOpAssign(float value, size_t i)");
	}
    /// Perform a binary operation (+,-,*,/) to each element of a matrix
    /// Usage: mat4[i,j] += value;
	void opIndexOpAssign(string op)(float value, size_t i, size_t j){
		static if(op=="+"){
			e[j*4 + i] += value;
		}
		static if(op=="-"){
			e[j*4 + i] -= value;
		}
		static if(op=="*"){
			e[j*4 + i] *= value;
		}
		static if(op=="/"){
			e[j*4 + i] /= value;
		}
        assert(0,"op not implemented for opIndexOpAssign(float value, size_t i, size_t j)");
	}

    /// Perform matrix binary operations 
    mat4 opBinary(string op)(mat4 m){
        static if(op=="+"){
            mat4 result;	
            for(int i=0; i < 16; i++){
                    result[i] = this[i]+m[i];
            }
						return result;
				}
        static if(op=="*"){
            mat4 result;	
            for(int i=0; i < 4; i++){
                for(int j=0; j < 4; j++){
                    float sum=0.0f;
                    for(int k=0; k < 4; k++){
                        sum	 +=  this[i,k] * m[k,j];	
                    }	
                    result[i,j] = sum;
                }
            }
            return result;	
        }
        assert(0,"op not implemented for mat4 opBinary(mat4)");
    }

    /// Multiply a matrix by a vector
    /// e.g. For performing: m*v (where 'v' is on the right side)
    vec4 opBinary(string op)(vec4 v){
        static if(op=="*"){
            vec4 result;	

            result[0] = this.Row(0).Dot(v);
            result[1] = this.Row(1).Dot(v);
            result[2] = this.Row(2).Dot(v);
            result[3] = this.Row(3).Dot(v);

            return result;	
        }
        assert(0,"op not implemented for vec4 opBinary(vec4)");
    }

    /// Handy function for printing out the string representation of a matrix
    string toString(){
	    string result = 
                        this.Row(0).toString ~ "\n" ~
                        this.Row(1).toString ~ "\n" ~
                        this.Row(2).toString ~ "\n" ~
                        this.Row(3).toString;
        return result;
    }
}

/// Helper function that will print two matrices side by side
void MatrixDebugPrint(string name1, mat4 m1, string name2, mat4 m2){
    writeln(name1,"\t\t",name2);
    for(int i=0; i < 4; i++){
        writeln(m1.Row(i),"\t",m2.Row(i));
    }
}

/// Helper function to visualize mat4 * vec4
void MatrixVectorDebugPrint(string name1, mat4 m, string name2, vec4 v){
    writeln(name1,"\t\t",name2);
    for(int i=0; i < 4; i++){
        if(i!=2){
        writeln(m.Row(i),"\t",v[i]);
        }else{
        writeln(m.Row(i)," (op)\t",v[i]);
        }
    }
}



/// Return the row vector
vec4 Row(mat4 m, size_t col){
    size_t offset = col*4;
    return vec4(m.e[0+offset],m.e[1+offset],m.e[2+offset],m.e[3+offset]);	
}

/// Return the column vector
vec4 Col(mat4 m, size_t c){
    return vec4(m.e[0+c],m.e[4+c],m.e[8+c],m.e[12+c]);	
}

/// Return an identity matrix 
mat4 MatrixMakeIdentity(){
    mat4 result;
    for(int i=0; i < 16; i++){
        result[i] = 0.0f;
    }
    // Set diaganaol of matrix to 1
    result[0]  = 1.0f;
    result[5]  = 1.0f;
    result[10] = 1.0f;
    result[15] = 1.0f;

    return result;
}

/// Checks if this is an identity matrix
bool MatrixIsIdentity(mat4 m){

    return (m[0] == 1.0f &&
        m[1] == 0.0f && 
        m[2] == 0.0f && 
        m[3] == 0.0f && 
        m[4] == 0.0f && 
        m[5] == 1.0f && 
        m[6] == 0.0f && 
        m[7] == 0.0f && 
        m[8] == 0.0f && 
        m[9] == 0.0f && 
        m[10] == 1.0f &&
        m[11] == 0.0f &&
        m[12] == 0.0f &&
        m[13] == 0.0f &&
        m[14] == 0.0f &&
        m[15] == 1.0f);
}


/// Given a matrix, return the transposed version of the matrix
mat4 MatrixTranspose(mat4 m){
    mat4 result;
    for(int i=0; i < 4;i++){
        auto row = m.Row(i);
        result[i] = row; // opAssign does 'column' assignment
    }
    return result;
}

/// Make X-Axis Rotation Matrix with the 'angle' that you want
/// to rotate about
mat4 MatrixMakeXRotation(float radians){
    // Always ensure identity matrix
    mat4 result = MatrixMakeIdentity();

    float s = sin(radians);
    float c = cos(radians);

    result[5] = c;
    result[6] = -s;

    result[9]  = s;
    result[10] = c;

    return result;
}

/// Make Y-Axis Rotation Matrix with the 'angle' that you want
/// to rotate about
mat4 MatrixMakeYRotation(float radians){
    // Always ensure identity matrix
    mat4 result = MatrixMakeIdentity();

    float s = sin(radians);
    float c = cos(radians);

    result[0] = c;
    result[2] = s;

    result[8]  = -s;
    result[10] = c;

    return result;
}

/// Make Z-Axis Rotation Matrix with the 'angle' that you want
/// to rotate about
mat4 MatrixMakeZRotation(float radians){
    // Always ensure identity matrix
    mat4 result = MatrixMakeIdentity();

    float s = sin(radians);
    float c = cos(radians);

    result[0] = c;
    result[1] = -s;

    result[4]  = s;
    result[5] = c;

    return result;
}

/// Rotates a matrix about an arbitrary axis (specified by the vector)
/// a specifed number of radians
mat3 MatrixMakeRotation(float radians, vec3 vector){
    vec3 v = vector.Normalize();
	mat3 result = mat3(1.0f);

	float cosa = cos(radians);
	float sina = sin(radians);

	vec3 temp = v * (1 - cosa);

	result[0,0] = (cosa + temp.x * v.x);
	result[0,1] = (       temp.x * v.y + sina * v.z);
	result[0,2] = (       temp.x * v.z - sina * v.y);
	result[1,0] = (       temp.y * v.x - sina * v.z);
	result[1,1] = (cosa + temp.y * v.y);
	result[1,2] = (       temp.y * v.z + sina * v.x);
	result[2,0] = (       temp.z * v.x + sina * v.y);
	result[2,1] = (       temp.z * v.y - sina * v.x);
	result[2,2] = (cosa + temp.z * v.z);

    return result;
}

/// Make Scale Matrix with the x,y,z dimensions you want.
mat4 MatrixMakeScale(vec3 v){
    // Always ensure identity matrix
    mat4 result = MatrixMakeIdentity();

    result[0]  = v[0];
    result[5]  = v[1];
    result[10] = v[2];

    return result;
}

/// Make Translation Matrix to translate the x,y,z coordinates.
mat4 MatrixMakeTranslation(vec3 v){
    // Always ensure identity matrix
    mat4 result = MatrixMakeIdentity();

    result[3]  = v[0];
    result[7]  = v[1];
    result[11] = v[2];

    return result;
}

/// fovy is the 'vertical' field of view angle in radians
/// Note: Sources:
///      - https://unspecified.wordpress.com/2012/06/21/calculating-the-gluperspective-matrix-and-other-opengl-matrix-maths/
///    	 - https://github.com/arkanis/single-header-file-c-libs/blob/master/math_3d.h
mat4 MatrixMakePerspective(float fovy, float aspect_ratio, float zNear, float zFar) {
	float f = 1.0f / tan(fovy / 2.0f);
	float ar = aspect_ratio;
	float nd = zNear;
	float fd = zFar;
	
	return mat4(
		 f / ar,           0,                0,                0,
		 0,                f,                0,                0,
		 0,                0,               (fd+nd)/(nd-fd),  (2*fd*nd)/(nd-fd),
		 0,                0,               -1,                0
	);
}


/// Identity matrix creation and identity matrix test
unittest{
    mat4 m;
    m[0] = 1.0f;
    m[1,2] = 9.0f;
    m = MatrixMakeIdentity();
    assert(m[0] == 1.0f, "Identity check");
    assert(m[1] == 0.0f, "Identity check");
    assert(m[2] == 0.0f, "Identity check");
    assert(m[3] == 0.0f, "Identity check");
    assert(m[4] == 0.0f, "Identity check");
    assert(m[5] == 1.0f, "Identity check");
    assert(m[6] == 0.0f, "Identity check");
    assert(m[7] == 0.0f, "Identity check");
    assert(m[8] == 0.0f, "Identity check");
    assert(m[9] == 0.0f, "Identity check");
    assert(m[10] == 1.0f, "Identity check");
    assert(m[11] == 0.0f, "Identity check");
    assert(m[12] == 0.0f, "Identity check");
    assert(m[13] == 0.0f, "Identity check");
    assert(m[14] == 0.0f, "Identity check");
    assert(m[15] == 1.0f, "Identity check");

    assert(m.MatrixIsIdentity() == true, "Identity function check");
}

/// Printing of row vectors
unittest{
    writeln("Row vectors");
	mat4 m;
	writeln(m);

	writeln(m.Row(0));
	writeln(m.Row(1));
	writeln(m.Row(2));
	writeln(m.Row(3));
}

/// Printing of column vectors
unittest{
    writeln("Column vectors");
    mat4 m;
    writeln(m);

    writeln(m.Col(0));
    writeln(m.Col(1));
    writeln(m.Col(2));
    writeln(m.Col(3));
}

/// Assign a new column to matrix
unittest{
    writeln("New column vector assignment");
    mat4 m;
    vec4 v = vec4(5,5,5,5);
    m[2] = v;
    writeln(m);
}

/// Transpose
unittest{
    writeln("Transpose test");
    mat4 m = mat4(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
    writeln(m.MatrixTranspose());
}

/// Matrix multiplication
unittest{
    writeln("matrix multiplication");
	mat4 m1;
	mat4 m2;
	mat4 m3 = m1*m2;

	writeln(m3);
    assert(m3.MatrixIsIdentity(), "Matrix should be identity");
}

unittest{
   	writeln("matrix by vector multiplication test"); 
	mat4 m;
    vec4 v = vec4(1,2,3,0);

    writeln(m*v);
}


